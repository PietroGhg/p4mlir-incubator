#include <optional>

#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"
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

BMv2IR::FieldInfo convertFieldInfo(P4HIR::FieldInfo p4Field) {
  return BMv2IR::FieldInfo(p4Field.name, p4Field.type);
}

class P4HIRToBMv2IRTypeConverter : public mlir::TypeConverter {
 public:
    P4HIRToBMv2IRTypeConverter() {
      addConversion([&](mlir::Type t) { return t; });
      addConversion([&](P4HIR::HeaderType headerType) {
          SmallVector<BMv2IR::FieldInfo> newFields;
          for (auto field : headerType.getFields()) {
            newFields.push_back(convertFieldInfo(field));
          }
          return BMv2IR::HeaderType::get(headerType.getContext(), headerType.getName(), newFields);
          });
    }
};

struct P4HIRToBMv2IRPass : public P4::P4MLIR::impl::P4HIRToBmv2IRBase<P4HIRToBMv2IRPass> {
    void runOnOperation() override {}
};
} // anonymous namespace
