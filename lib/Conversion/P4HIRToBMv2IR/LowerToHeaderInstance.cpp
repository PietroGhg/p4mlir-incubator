#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/LogicalResult.h"
#include "mlir/IR/BuiltinAttributeInterfaces.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Value.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Support/WalkResult.h"
#include "mlir/Transforms/DialectConversion.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Ops.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.h"
#include "p4mlir/Dialect/P4CoreLib/P4CoreLib_Dialect.h"
#include "p4mlir/Dialect/P4CoreLib/P4CoreLib_Ops.h"
#include "p4mlir/Dialect/P4HIR/P4HIR_Dialect.h"
#include "p4mlir/Dialect/P4HIR/P4HIR_Ops.h"

#define DEBUG_TYPE "lower-to-header-instance"

using namespace mlir;

namespace P4::P4MLIR {
#define GEN_PASS_DEF_LOWERTOHEADERINSTANCE
#include "p4mlir/Conversion/P4HIRToBMv2IR/Passes.cpp.inc"
}  // namespace P4::P4MLIR

using namespace P4::P4MLIR;

namespace {

P4HIR::StructType isStructOrRefToStruct(mlir::Type ty) {
    if (auto refTy = dyn_cast<P4HIR::ReferenceType>(ty))
        return isStructOrRefToStruct(refTy.getObjectType());
    auto structTy = dyn_cast<P4HIR::StructType>(ty);
    if (!structTy) return nullptr;
    // We avoid checking recursively here, it should be handled somewhere else
    assert(
        llvm::none_of(structTy.getFields(),
                      [](P4HIR::FieldInfo field) { return isa<P4HIR::StructType>(field.type); }) &&
        "No structs within structs");
    return structTy;
}

P4HIR::HeaderType isHeaderOrRefToHeader(mlir::Type ty) {
    if (auto refTy = dyn_cast<P4HIR::ReferenceType>(ty))
        return isHeaderOrRefToHeader(refTy.getObjectType());
    if (auto headerTy = dyn_cast<P4HIR::HeaderType>(ty)) return headerTy;
    return nullptr;
}

LogicalResult handleFieldAccess(StringRef name, Operation *op, P4HIR::StructType structTy,
                                SmallVector<Operation *> &fieldRefs,
                                SmallVector<Operation *> &bitRefs) {
    auto fieldTy = structTy.getFieldType(name);
    if (isa<P4HIR::HeaderType>(fieldTy))
        fieldRefs.push_back(op);
    else if (isa<P4HIR::BitsType, P4HIR::VarBitsType>(fieldTy))
        bitRefs.push_back(op);
    else
        return op->emitError("Unsupported FieldRefOp");

    return success();
};

LogicalResult handleStructUse(Operation *user, P4HIR::StructType structTy,
                              SmallVector<Operation *> &fieldRefs,
                              SmallVector<Operation *> &bitRefs,
                              SmallVector<Operation *> &eraseList) {
    auto loc = user->getLoc();

    if (auto fieldRefOp = dyn_cast<P4HIR::StructFieldRefOp>(user)) {
        if (failed(handleFieldAccess(fieldRefOp.getFieldName(), fieldRefOp, structTy, fieldRefs,
                                     bitRefs)))
            return failure();
    } else if (auto readOp = dyn_cast<P4HIR::ReadOp>(user)) {
        for (auto readUser : readOp.getResult().getUsers()) {
            auto extract = dyn_cast<P4HIR::StructExtractOp>(readUser);
            if (!extract)
                return emitError(loc, "Unsupported read use ")
                       << readUser->getName().getIdentifier();
            if (failed(handleFieldAccess(extract.getFieldName(), extract, structTy, fieldRefs,
                                         bitRefs)))
                return failure();
        }
        // Explicitly remove readOp to avoid unrealized_casts
        eraseList.push_back(readOp);
    } else {
        return emitError(loc, "Unsupported struct use ") << user->getName().getIdentifier();
    }
    return success();
}

FailureOr<std::pair<SmallVector<Operation *>, SmallVector<Operation *>>> findFieldRefs(
    P4HIR::ControlLocalOp controlLocal, Location loc, P4HIR::StructType structTy,
    SmallVector<Operation *> &eraseList) {
    auto parent = controlLocal->getParentOfType<P4HIR::ControlOp>();
    auto moduleOp = controlLocal->getParentOfType<ModuleOp>();
    if (!parent || !moduleOp) return {};
    SmallVector<Operation *> fieldRefs;
    SmallVector<Operation *> bitRefs;
    auto walkRes = parent->walk([&](P4HIR::SymToValueOp symRef) {
        auto decl = symRef.getDecl();
        auto op = mlir::SymbolTable::lookupSymbolIn(moduleOp, decl);
        if (op == controlLocal.getOperation()) {
            for (auto user : symRef->getUsers()) {
                if (failed(handleStructUse(user, structTy, fieldRefs, bitRefs, eraseList)))
                    return WalkResult::interrupt();
            }
        }
        return WalkResult::advance();
    });
    if (walkRes.wasInterrupted()) return failure();

    return {{fieldRefs, bitRefs}};
}

// Adds instances from a StructType, splitting the struct to create separate instances for
// the header fields, and creating a new struct containing only the bit fields if necessary
LogicalResult splitStructAndAddInstances(Value val, P4HIR::StructType structTy, Location loc,
                                         StringRef parentName, ModuleOp moduleOp,
                                         PatternRewriter &rewriter) {
    auto ctx = rewriter.getContext();
    llvm::StringMap<BMv2IR::HeaderInstanceOp> instances;
    SmallVector<Operation *> fieldRefs;  // FieldRefs accessessing header fields
    SmallVector<Operation *> bitRefs;    // FieldRefs accessing bit fields
    SmallVector<Operation *> eraseList;
    P4HIR::ControlLocalOp controlLocal = nullptr;

    // Find the StructFieldRefOp that access the struct
    for (auto user : val.getUsers()) {
        if (auto cLocal = dyn_cast<P4HIR::ControlLocalOp>(user)) {
            if (controlLocal != nullptr) {
                return emitError(loc, "Expected at most one ControlLocalOp for every argument");
            }
            controlLocal = cLocal;
            continue;
        }
        if (failed(handleStructUse(user, structTy, fieldRefs, bitRefs, eraseList)))
            return failure();
    }

    // Add uses coming from ControlLocalOp
    if (controlLocal) {
        const auto maybeRefs = findFieldRefs(controlLocal, loc, structTy, eraseList);
        if (failed(maybeRefs))
            return controlLocal->emitError("Error while processing control local op");
        auto [fRefs, bRefs] = maybeRefs.value();
        for (auto op : fRefs) fieldRefs.push_back(op);
        for (auto op : bRefs) bitRefs.push_back(op);
    }

    // Add HeaderInstanceOps for StructFieldRefOps that reference header fields
    for (auto op : fieldRefs) {
        StringRef name =
            llvm::TypeSwitch<Operation *, StringRef>(op)
                .Case([](P4HIR::StructFieldRefOp fieldRefOp) { return fieldRefOp.getFieldName(); })
                .Case([](P4HIR::StructExtractOp extractOp) { return extractOp.getFieldName(); });
        auto instance = instances.find(name);
        BMv2IR::HeaderInstanceOp instanceOp = nullptr;
        PatternRewriter::InsertionGuard guard(rewriter);
        auto fieldTy = structTy.getFieldType(name);
        if (instance != instances.end()) {
            instanceOp = instance->second;
        } else {
            rewriter.setInsertionPointToStart(moduleOp.getBody());
            instanceOp = rewriter.create<BMv2IR::HeaderInstanceOp>(
                loc, rewriter.getStringAttr(parentName + "_" + name),
                P4HIR::ReferenceType::get(fieldTy));
            instances.insert({name, instanceOp});
        }
        rewriter.setInsertionPointAfter(op);
        Operation *newOp =
            rewriter.create<BMv2IR::SymToValueOp>(op->getLoc(), instanceOp.getHeaderType(),
                                                  SymbolRefAttr::get(ctx, instanceOp.getSymName()));
        if (isa<P4HIR::StructExtractOp>(op))
            newOp = rewriter.create<P4HIR::ReadOp>(op->getLoc(), fieldTy, newOp->getResult(0));
        rewriter.replaceOp(op, newOp->getResult(0));
    }

    if (bitRefs.empty()) {
        for (auto op : eraseList) rewriter.eraseOp(op);
        return success();
    }

    // Since the struct has bit fields, we create a new type dropping the header fields, and add a
    // header instance for it

    SmallVector<P4HIR::FieldInfo> bitFields;
    unsigned totalSize = 0;
    for (auto field : structTy.getFields()) {
        if (auto bitTy = dyn_cast<P4HIR::BitsType>(field.type)) {
            totalSize += bitTy.getWidth();
            bitFields.push_back(field);
        } else if (auto varBitTy = dyn_cast<P4HIR::VarBitsType>(field.type)) {
            totalSize += varBitTy.getMaxWidth();
            bitFields.push_back(field);
        }
    }
    // Add a padding field if necessary
    unsigned padding = totalSize % 8;
    if (padding != 0) {
        auto padTy = P4HIR::BitsType::get(ctx, 8 - padding, false);
        P4HIR::FieldInfo padInfo{rewriter.getStringAttr("_padding"), padTy};
        bitFields.push_back(padInfo);
    }

    PatternRewriter::InsertionGuard guard(rewriter);
    rewriter.setInsertionPointToStart(moduleOp.getBody());
    auto newTy = P4HIR::StructType::get(rewriter.getContext(), structTy.getName(), bitFields,
                                        structTy.getAnnotations());
    auto newInstance = rewriter.create<BMv2IR::HeaderInstanceOp>(
        loc, rewriter.getStringAttr(parentName), P4HIR::ReferenceType::get(newTy));
    for (auto op : bitRefs) {
        StringRef name =
            llvm::TypeSwitch<Operation *, StringRef>(op)
                .Case([](P4HIR::StructFieldRefOp fieldRefOp) { return fieldRefOp.getFieldName(); })
                .Case([](P4HIR::StructExtractOp extractOp) { return extractOp.getFieldName(); });
        rewriter.setInsertionPointAfter(op);
        auto symToVal = rewriter.create<BMv2IR::SymToValueOp>(
            op->getLoc(), newInstance.getHeaderType(),
            SymbolRefAttr::get(ctx, newInstance.getSymName()));
        Operation *newOp = rewriter.create<P4HIR::StructFieldRefOp>(op->getLoc(), symToVal, name);
        if (isa<P4HIR::StructExtractOp>(op))
            newOp = rewriter.create<P4HIR::ReadOp>(op->getLoc(), op->getResult(0).getType(),
                                                   newOp->getResult(0));
        rewriter.replaceOp(op, newOp->getResult(0));
    }

    for (auto op : eraseList) rewriter.eraseOp(op);
    return success();
}

LogicalResult addInstanceForHeader(Operation *op, P4HIR::HeaderType headerTy, Twine name,
                                   PatternRewriter &rewriter) {
    PatternRewriter::InsertionGuard guard(rewriter);
    auto moduleOp = op->getParentOfType<ModuleOp>();
    assert(moduleOp);
    rewriter.setInsertionPointToStart(moduleOp.getBody());
    auto instance = rewriter.create<BMv2IR::HeaderInstanceOp>(
        op->getLoc(), rewriter.getStringAttr(name), P4HIR::ReferenceType::get(headerTy));
    rewriter.setInsertionPointAfter(op);
    rewriter.replaceOpWithNewOp<BMv2IR::SymToValueOp>(
        op, instance.getHeaderType(),
        SymbolRefAttr::get(rewriter.getContext(), instance.getSymName()));

    return success();
}

LogicalResult addInstanceForHeader(BlockArgument arg, P4HIR::HeaderType headerTy, Twine name,
                                   ModuleOp moduleOp, PatternRewriter &rewriter) {
    PatternRewriter::InsertionGuard guard(rewriter);
    rewriter.setInsertionPointToStart(moduleOp.getBody());
    auto newInstance = rewriter.create<BMv2IR::HeaderInstanceOp>(
        arg.getLoc(), rewriter.getStringAttr(name), P4HIR::ReferenceType::get(headerTy));

    for (auto &use : arg.getUses()) {
        Operation *user = use.getOwner();
        rewriter.setInsertionPointToStart(user->getBlock());
        auto opIndex = use.getOperandNumber();
        auto symRef = rewriter.create<BMv2IR::SymToValueOp>(
            user->getLoc(), newInstance.getHeaderType(),
            SymbolRefAttr::get(rewriter.getContext(), newInstance.getSymName()));
        user->setOperand(opIndex, symRef.getResult());
    }

    return success();
    ;
}

struct ParserOpPattern : public OpRewritePattern<P4HIR::ParserOp> {
    using OpRewritePattern<P4HIR::ParserOp>::OpRewritePattern;

    mlir::LogicalResult matchAndRewrite(P4HIR::ParserOp parserOp,
                                        mlir::PatternRewriter &rewriter) const override {
        auto moduleOp = parserOp->getParentOfType<ModuleOp>();
        if (!moduleOp) return failure();
        for (auto &arg : parserOp.getArguments()) {
            auto ty = arg.getType();
            std::string parentName =
                (parserOp.getSymName() + std::to_string(arg.getArgNumber())).str();
            if (auto headerTy = isHeaderOrRefToHeader(ty)) {
                if (failed(addInstanceForHeader(arg, headerTy, parentName, moduleOp, rewriter)))
                    return parserOp->emitError("Failed to process parserOp");
            } else if (auto structTy = isStructOrRefToStruct(ty)) {
                if (failed(splitStructAndAddInstances(arg, structTy, parserOp.getLoc(), parentName,
                                                      moduleOp, rewriter)))
                    return parserOp->emitError("Failed to process parserOp");
            }
        }

        return mlir::success();
    }
};

struct ControlOpPatter : public OpRewritePattern<P4HIR::ControlOp> {
    using OpRewritePattern<P4HIR::ControlOp>::OpRewritePattern;

    mlir::LogicalResult matchAndRewrite(P4HIR::ControlOp controlOp,
                                        mlir::PatternRewriter &rewriter) const override {
        auto moduleOp = controlOp->getParentOfType<ModuleOp>();
        if (!moduleOp) return failure();
        for (auto &arg : controlOp.getArguments()) {
            auto ty = arg.getType();
            std::string parentName =
                (controlOp.getSymName() + std::to_string(arg.getArgNumber())).str();
            if (auto headerTy = isHeaderOrRefToHeader(ty)) {
                if (failed(addInstanceForHeader(arg, headerTy, parentName, moduleOp, rewriter)))
                    return controlOp->emitError("Failed to process ControlOp");
            } else if (auto structTy = isStructOrRefToStruct(ty)) {
                if (failed(splitStructAndAddInstances(arg, structTy, controlOp.getLoc(), parentName,
                                                      moduleOp, rewriter)))
                    return controlOp->emitError("Failed to process ControlOp");
            }
        }
        // Remove ControlLocalOp and P4HIR::SymToValueOp since they are unused at this point
        SmallVector<Operation *> eraseList;
        controlOp.walk(
            [&](P4HIR::ControlLocalOp controlLocal) { eraseList.push_back(controlLocal); });
        controlOp.walk([&](P4HIR::SymToValueOp symRef) { eraseList.push_back(symRef); });
        for (auto op : eraseList) rewriter.eraseOp(op);

        return mlir::success();
    }
};

FailureOr<StringRef> getParentName(Operation *op) {
    auto parserParent = op->getParentOfType<P4HIR::ParserOp>();
    if (!parserParent) return op->emitError("Unexpected VariableOp parent");
    return parserParent.getSymName();
}

struct VariableOpPattern : public OpRewritePattern<P4HIR::VariableOp> {
    using OpRewritePattern<P4HIR::VariableOp>::OpRewritePattern;

    mlir::LogicalResult matchAndRewrite(P4HIR::VariableOp variableOp,
                                        mlir::PatternRewriter &rewriter) const override {
        auto moduleOp = variableOp->getParentOfType<ModuleOp>();
        auto refTy = variableOp.getType();
        auto ty = refTy.getObjectType();
        auto maybeName = variableOp.getName();
        if (!maybeName.has_value())
            return variableOp.emitError("Unnamed variable can't be lowered to header instance");
        auto name = maybeName.value();

        auto maybeParentName = getParentName(variableOp);
        if (failed(maybeParentName)) return failure();

        auto res =
            TypeSwitch<Type, LogicalResult>(ty)
                .Case([&](P4HIR::StructType structTy) -> LogicalResult {
                    if (failed(splitStructAndAddInstances(variableOp.getResult(), structTy,
                                                          variableOp.getLoc(), name, moduleOp,
                                                          rewriter)))
                        return variableOp.emitError("Error translating variableOp");
                    return success();
                })
                .Case([&](P4HIR::HeaderType headerTy) -> LogicalResult {
                    if (failed(addInstanceForHeader(
                            variableOp, headerTy, maybeParentName.value() + "_" + name, rewriter)))
                        return variableOp.emitError("Error translating variableOp");
                    return success();
                })
                .Default([](Type ty) { return failure(); });
        return res;
    }
};

struct LowerToHeaderInstancePass
    : public P4::P4MLIR::impl::LowerToHeaderInstanceBase<LowerToHeaderInstancePass> {
    void runOnOperation() override {
        auto &context = getContext();
        RewritePatternSet patterns(&context);
        ConversionTarget target(context);
        target.addLegalDialect<BMv2IR::BMv2IRDialect>();
        target.addLegalDialect<P4HIR::P4HIRDialect>();
        target.addLegalDialect<P4CoreLib::P4CoreLibDialect>();
        target.addDynamicallyLegalOp<P4HIR::ParserOp>([](P4HIR::ParserOp parserOp) {
            auto argsTy = parserOp.getArgumentTypes();
            return !llvm::any_of(argsTy, [](mlir::Type ty) {
                return isHeaderOrRefToHeader(ty) || isStructOrRefToStruct(ty);
            });
        });
        target.addDynamicallyLegalOp<P4HIR::ControlOp>([](P4HIR::ControlOp controlOp) {
            auto argsTy = controlOp.getArgumentTypes();
            return !llvm::any_of(argsTy, [](mlir::Type ty) {
                return isHeaderOrRefToHeader(ty) || isStructOrRefToStruct(ty);
            });
        });
        target.addDynamicallyLegalOp<P4HIR::VariableOp>([](P4HIR::VariableOp varOp) {
            auto refTy = varOp.getType();
            auto ty = refTy.getObjectType();
            return !isa<P4HIR::HeaderType>(ty) && !isStructOrRefToStruct(ty);
        });

        patterns.add<ParserOpPattern, VariableOpPattern, ControlOpPatter>(patterns.getContext());

        if (failed(applyPartialConversion(getOperation(), target, std::move(patterns))))
            signalPassFailure();
    }
};

}  // anonymous namespace
