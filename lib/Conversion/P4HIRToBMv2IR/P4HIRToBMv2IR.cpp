#include <optional>

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Support/LogicalResult.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"
#include "p4mlir/Conversion/P4HIRToBMv2IR/Passes.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Ops.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.h"
#include "p4mlir/Dialect/P4CoreLib/P4CoreLib_Dialect.h"
#include "p4mlir/Dialect/P4CoreLib/P4CoreLib_Ops.h"
#include "p4mlir/Dialect/P4HIR/P4HIR_Dialect.h"
#include "p4mlir/Dialect/P4HIR/P4HIR_Ops.h"

#define DEBUG_TYPE "p4hir-convert-to-bmv2"

using namespace mlir;

namespace P4::P4MLIR {
#define GEN_PASS_DEF_P4HIRTOBMV2IR
#include "p4mlir/Conversion/P4HIRToBMv2IR/Passes.cpp.inc"
}  // namespace P4::P4MLIR

using namespace P4::P4MLIR;

namespace {

BMv2IR::FieldInfo convertFieldInfo(P4HIR::FieldInfo p4Field) {
    return BMv2IR::FieldInfo(p4Field.name, p4Field.type);
}

struct P4HIRToBMv2IRTypeConverter : public mlir::TypeConverter {
    P4HIRToBMv2IRTypeConverter() {
        addConversion([&](mlir::Type t) { return t; });
        addConversion([&](P4HIR::HeaderType headerType) {
            SmallVector<BMv2IR::FieldInfo> newFields;
            for (auto field : headerType.getFields()) {
                newFields.push_back(convertFieldInfo(field));
            }
            return BMv2IR::HeaderType::get(headerType.getContext(), headerType.getName(),
                                           newFields);
        });
    }
};

struct ExtractOpConversionPattern : public OpConversionPattern<P4CoreLib::PacketExtractOp> {
    using OpConversionPattern<P4CoreLib::PacketExtractOp>::OpConversionPattern;

    LogicalResult matchAndRewrite(P4CoreLib::PacketExtractOp op, OpAdaptor operands,
                                  ConversionPatternRewriter &rewriter) const override {
        auto fieldRefOp = op.getHdr().getDefiningOp<P4HIR::StructFieldRefOp>();
        if (!fieldRefOp) return failure();
        auto fieldName = fieldRefOp.getFieldName();
        auto loc = op.getLoc();
        // TODO: don't hardcode strings
        // TODO: support non-default extracts
        auto newExtract = rewriter.create<BMv2IR::ExtractOp>(
            loc, rewriter.getStringAttr("default"), rewriter.getStringAttr(fieldName), nullptr);
        rewriter.replaceOp(op, newExtract);
        rewriter.eraseOp(fieldRefOp);
        return success();
    }
};

struct ParserStateOpConversionPattern : public OpConversionPattern<P4HIR::ParserStateOp> {
    using OpConversionPattern<P4HIR::ParserStateOp>::OpConversionPattern;

    LogicalResult matchAndRewrite(P4HIR::ParserStateOp op, OpAdaptor operands,
                                  ConversionPatternRewriter &rewriter) const override {
        auto loc = op.getLoc();
        auto context = rewriter.getContext();
        // TODO: add support to non-default transitions and transition keys
        SmallVector<Attribute> transitions;
        SmallPtrSet<Operation *, 3> eraseList;
        op.walk([&](P4HIR::ParserTransitionOp transitionOp) {
            auto transition =
                BMv2IR::TransitionAttr::get(context, rewriter.getStringAttr("default"),
                                            transitionOp.getStateAttr(), nullptr, nullptr);
            transitions.push_back(transition);
            eraseList.insert(transitionOp.getOperation());
        });
        // TODO: check how to tell them apart in the json spec
        op.walk([&](P4HIR::ParserAcceptOp acceptOp) {
            auto transition = BMv2IR::TransitionAttr::get(
                context, rewriter.getStringAttr("default"), nullptr, nullptr, nullptr);
            transitions.push_back(transition);
            eraseList.insert(acceptOp.getOperation());
        });
        op.walk([&](P4HIR::ParserRejectOp rejectOp) {
            auto transition = BMv2IR::TransitionAttr::get(
                context, rewriter.getStringAttr("default"), nullptr, nullptr, nullptr);
            transitions.push_back(transition);
            eraseList.insert(rejectOp.getOperation());
        });
        auto newState = rewriter.create<BMv2IR::ParserStateOp>(
            loc, op.getSymNameAttr(), rewriter.getArrayAttr(transitions), nullptr);
        newState.getRegion().takeBody(op.getRegion());
        rewriter.replaceOp(op, newState);
        for (Operation *op : eraseList) rewriter.eraseOp(op);
        return success();
    }
};

struct ParserOpConversionPattern : public OpConversionPattern<P4HIR::ParserOp> {
    using OpConversionPattern<P4HIR::ParserOp>::OpConversionPattern;

    LogicalResult matchAndRewrite(P4HIR::ParserOp op, OpAdaptor operands,
                                  ConversionPatternRewriter &rewriter) const override {
        auto loc = op.getLoc();
        // TODO: don't hardcode initial state?
        auto firstTransition = cast<P4HIR::ParserTransitionOp>(op.getBody().back().getTerminator());
        auto initState = SymbolRefAttr::get(rewriter.getStringAttr("start"));
        auto newParser = rewriter.create<BMv2IR::ParserOp>(loc, op.getSymNameAttr(), initState);
        rewriter.eraseOp(firstTransition);
        newParser.getRegion().takeBody(op.getRegion());
        rewriter.replaceOp(op, newParser);
        return success();
    }
};

struct P4HIRToBMv2IRPass : public P4::P4MLIR::impl::P4HIRToBmv2IRBase<P4HIRToBMv2IRPass> {
    void runOnOperation() override {
        MLIRContext &context = getContext();
        mlir::ModuleOp module = getOperation();
        ConversionTarget target(context);
        RewritePatternSet patterns(&context);
        P4HIRToBMv2IRTypeConverter converter;
        patterns.add<ParserOpConversionPattern, ParserStateOpConversionPattern,
                     ExtractOpConversionPattern>(converter, &context);

        target.markUnknownOpDynamicallyLegal([](Operation *) { return true; });
        target.addIllegalOp<P4HIR::ParserOp>();
        target.addIllegalOp<P4HIR::ParserStateOp>();
        target.addIllegalOp<P4CoreLib::PacketExtractOp>();
        if (failed(applyPartialConversion(module, target, std::move(patterns))))
            signalPassFailure();
    }
};
}  // anonymous namespace
