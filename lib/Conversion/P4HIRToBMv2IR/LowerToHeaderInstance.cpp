#include <string>

#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/LogicalResult.h"
#include "mlir/IR/BuiltinAttributeInterfaces.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/Value.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Support/LLVM.h"
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

P4HIR::StructType isStructWithHeaders(mlir::Type ty) {
    if (auto refTy = dyn_cast<P4HIR::ReferenceType>(ty))
        return isStructWithHeaders(refTy.getObjectType());
    auto structTy = dyn_cast<P4HIR::StructType>(ty);
    if (!structTy) return nullptr;
    // We avoid checking recursively here, it should be handled somewhere else
    assert(
        llvm::none_of(structTy.getFields(),
                      [](P4HIR::FieldInfo field) { return isa<P4HIR::StructType>(field.type); }) &&
        "No structs within structs");
    if (llvm::any_of(structTy.getFields(),
                     [](P4HIR::FieldInfo field) { return isa<P4HIR::HeaderType>(field.type); })) {
        return structTy;
    }
    return nullptr;
}

P4HIR::HeaderType isHeaderOrRefToHeader(mlir::Type ty) {
    if (auto refTy = dyn_cast<P4HIR::ReferenceType>(ty))
        return isHeaderOrRefToHeader(refTy.getObjectType());
    if (auto headerTy = dyn_cast<P4HIR::HeaderType>(ty)) return headerTy;
    return nullptr;
}

LogicalResult splitStructAndAddInstances(Value val, P4HIR::StructType structTy, Location loc,
                                         StringRef parentName, Block &insertPoint,
                                         PatternRewriter &rewriter) {
    llvm::StringMap<BMv2IR::HeaderInstanceOp> instances;
    SmallPtrSet<Operation *, 5> fieldRefs;

    // Find the StructFieldRefOp that access the struct, add a header instance for every field
    // accessed
    for (auto user : val.getUsers()) {
        if (auto fieldRefOp = dyn_cast<P4HIR::StructFieldRefOp>(user)) {
            if (isa<P4HIR::HeaderType>(structTy.getFieldType(fieldRefOp.getFieldName())))
                fieldRefs.insert(fieldRefOp);
        }
    }

    for (auto op : fieldRefs) {
        auto fieldRefOp = dyn_cast<P4HIR::StructFieldRefOp>(op);
        auto name = fieldRefOp.getFieldName();
        auto instance = instances.find(name);
        BMv2IR::HeaderInstanceOp instanceOp = nullptr;
        if (instance != instances.end()) {
            instanceOp = instance->second;
        } else {
            PatternRewriter::InsertionGuard guard(rewriter);
            rewriter.setInsertionPointToStart(&insertPoint);
            instanceOp = rewriter.create<BMv2IR::HeaderInstanceOp>(
                loc, rewriter.getStringAttr(parentName + "_" + name),
                P4HIR::ReferenceType::get(structTy.getFieldType(name)));
        }
        rewriter.replaceOp(fieldRefOp, instanceOp);
    }
    return success();
}

LogicalResult addInstanceForHeader(Operation *op, P4HIR::HeaderType headerTy, Twine name,
                                   PatternRewriter &rewriter) {
    PatternRewriter::InsertionGuard guard(rewriter);
    rewriter.setInsertionPointAfter(op);
    rewriter.replaceOpWithNewOp<BMv2IR::HeaderInstanceOp>(op, rewriter.getStringAttr(name),
                                                          P4HIR::ReferenceType::get(headerTy));

    return success();
}

LogicalResult addInstanceForHeader(BlockArgument arg, P4HIR::HeaderType headerTy, Twine name,
                                   PatternRewriter &rewriter) {
    PatternRewriter::InsertionGuard guard(rewriter);
    rewriter.setInsertionPointToStart(arg.getParentBlock());
    auto newInstance = rewriter.create<BMv2IR::HeaderInstanceOp>(
        arg.getLoc(), rewriter.getStringAttr(name), P4HIR::ReferenceType::get(headerTy));
    rewriter.replaceAllUsesWith(arg, newInstance);

    return success();
}

struct ParserOpPattern : public OpRewritePattern<P4HIR::ParserOp> {
    using OpRewritePattern<P4HIR::ParserOp>::OpRewritePattern;

    mlir::LogicalResult matchAndRewrite(P4HIR::ParserOp parserOp,
                                        mlir::PatternRewriter &rewriter) const override {
        SmallVector<BlockArgument> argsToProcess;
        for (auto &arg : parserOp.getArguments()) {
            auto ty = arg.getType();
            std::string parentName =
                (parserOp.getSymName() + std::to_string(arg.getArgNumber())).str();
            if (auto headerTy = isHeaderOrRefToHeader(ty)) {
                if (failed(addInstanceForHeader(arg, headerTy, parentName, rewriter)))
                    return parserOp->emitError("Failed to process parserOp");
            } else if (auto structTy = isStructWithHeaders(ty)) {
                if (failed(splitStructAndAddInstances(arg, structTy, parserOp.getLoc(), parentName,
                                                      parserOp.getBody().front(), rewriter)))
                    return parserOp->emitError("Failed to process parserOp");
            }
        }
        return mlir::success();
    }
};

struct VariableOpPattern : public OpRewritePattern<P4HIR::VariableOp> {
    using OpRewritePattern<P4HIR::VariableOp>::OpRewritePattern;

    mlir::LogicalResult matchAndRewrite(P4HIR::VariableOp variableOp,
                                        mlir::PatternRewriter &rewriter) const override {
        auto refTy = variableOp.getType();
        auto ty = refTy.getObjectType();
        auto maybeName = variableOp.getName();
        if (!maybeName.has_value())
            return variableOp.emitError("Unnamed variable can't be lowered to header instance");
        auto name = maybeName.value();
        // FIXME: Add support for other parents, alternatively we could remove IsolatedFromAbove
        // from Parsers and always add header instances to ModuleOp's main block
        auto parserParent = variableOp->getParentOfType<P4HIR::ParserOp>();
        if (!parserParent) return variableOp.emitError("Unexpected VariableOp parent");

        auto res = TypeSwitch<Type, LogicalResult>(ty)
                       .Case([&](P4HIR::StructType structTy) -> LogicalResult {
                           if (failed(splitStructAndAddInstances(
                                   variableOp.getResult(), structTy, variableOp.getLoc(), name,
                                   parserParent.getBody().front(), rewriter)))
                               return variableOp.emitError("Error translating variableOp");
                           return success();
                       })
                       .Case([&](P4HIR::HeaderType headerTy) -> LogicalResult {
                           if (failed(addInstanceForHeader(variableOp, headerTy,
                                                           parserParent.getSymName() + "_" + name,
                                                           rewriter)))
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
                return isHeaderOrRefToHeader(ty) || isStructWithHeaders(ty);
            });
        });
        target.addDynamicallyLegalOp<P4HIR::VariableOp>([](P4HIR::VariableOp varOp) {
            auto refTy = varOp.getType();
            auto ty = refTy.getObjectType();
            return !isa<P4HIR::HeaderType>(ty) && !isStructWithHeaders(ty);
        });

        // TODO: add support for controls and other ops that may lead to header instances
        patterns.add<ParserOpPattern, VariableOpPattern>(patterns.getContext());

        if (failed(applyPartialConversion(getOperation(), target, std::move(patterns))))
            signalPassFailure();
    }
};

}  // anonymous namespace
