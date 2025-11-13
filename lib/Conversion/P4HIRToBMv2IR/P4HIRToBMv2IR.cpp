#include <optional>

#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/Pass.h"
#include "p4mlir/Conversion/P4HIRToBMv2IR/Passes.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.h"
#include "p4mlir/Dialect/P4CoreLib/P4CoreLib_Dialect.h"
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
struct P4HIRToBMv2IRPass : public P4::P4MLIR::impl::P4HIRToBmv2IRBase<P4HIRToBMv2IRPass> {
    void runOnOperation() override {
        auto &ctx = getContext();
        SmallVector<BMv2IR::FieldInfo> fields;
        fields.emplace_back(StringAttr::get(&ctx, "one"), 10, false);
        fields.emplace_back(StringAttr::get(&ctx, "two"), 20, false);
        fields.emplace_back(StringAttr::get(&ctx, "two"), BMv2IR::FieldInfo::kDynamic, true);

        auto ht = BMv2IR::HeaderType::get(&ctx, "prova", fields, 20);
        llvm::errs() << "[ptrdbg] " << ht << "\n";
    }
};
}  // anonymous namespace
