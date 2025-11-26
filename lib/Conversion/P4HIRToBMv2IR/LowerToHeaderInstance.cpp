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

bool isStructWithHeaders(mlir::Type ty) {
    if (auto refTy = dyn_cast<P4HIR::ReferenceType>(ty))
        return isStructWithHeaders(refTy.getObjectType());
    auto structTy = dyn_cast<P4HIR::StructType>(ty);
    if (!structTy) return false;
    // We avoid checking recursively here, it should be handled somewhere else
    assert(
        llvm::none_of(structTy.getFields(),
                      [](P4HIR::FieldInfo field) { return isa<P4HIR::StructType>(field.type); }) &&
        "No structs inside structs");
    auto res = llvm::any_of(structTy.getFields(), [](P4HIR::FieldInfo field) {
        return isa<P4HIR::HeaderType>(field.type);
    });
    return res;
}

LogicalResult splitStructAndAddInstances(Value val, Location loc, StringRef parentName,
                                         Block &insertPoint, PatternRewriter &rewriter) {
    auto ty = val.getType();
    P4HIR::StructType structTy = nullptr;
    if (auto refTy = dyn_cast<P4HIR::ReferenceType>(ty)) {
        structTy = dyn_cast<P4HIR::StructType>(refTy.getObjectType());
    } else {
        structTy = dyn_cast<P4HIR::StructType>(ty);
    }

    if (!structTy) return failure();

    llvm::StringMap<BMv2IR::HeaderInstanceOp> instances;
    SmallPtrSet<Operation *, 5> fieldRefs;

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

struct ParserOpPattern : public OpRewritePattern<P4HIR::ParserOp> {
    using OpRewritePattern<P4HIR::ParserOp>::OpRewritePattern;

    mlir::LogicalResult matchAndRewrite(P4HIR::ParserOp parserOp,
                                        mlir::PatternRewriter &rewriter) const override {
        SmallVector<BlockArgument> argsToProcess;
        for (auto &arg : parserOp.getArguments()) {
            auto ty = arg.getType();
            if (isa<P4HIR::HeaderType>(ty) || isStructWithHeaders(ty)) {
                argsToProcess.push_back(arg);
            }
        }
        for (auto arg : argsToProcess) {
            std::string parentName =
                (parserOp.getSymName() + std::to_string(arg.getArgNumber())).str();
            // TODO: add support for headers used directly
            if (failed(splitStructAndAddInstances(arg, parserOp.getLoc(), parentName,
                                                  parserOp.getBody().front(), rewriter)))
                return parserOp->emitError("Failed to process parserOp");
        }
        return mlir::success();
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
        target.addDynamicallyLegalOp<P4HIR::ParserOp>([](P4HIR::ParserOp parserOp) {
            auto argsTy = parserOp.getArgumentTypes();
            return !llvm::any_of(argsTy, [](mlir::Type ty) {
                return isa<P4HIR::HeaderType>(ty) || isStructWithHeaders(ty);
            });
        });

        // TODO: add support for local variables and controls
        patterns.add<ParserOpPattern>(patterns.getContext());

        if (failed(applyPartialConversion(getOperation(), target, std::move(patterns))))
            signalPassFailure();
    }
};

}  // anonymous namespace
