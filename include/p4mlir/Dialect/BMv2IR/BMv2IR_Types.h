#ifndef P4MLIR_DIALECT_BMv2IR_BMv2IR_TYPES_H
#define P4MLIR_DIALECT_BMv2IR_BMv2IR_TYPES_H

// We explicitly do not use push / pop for diagnostic in
// order to propagate pragma further on
#include "llvm/ADT/APFloat.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/BuiltinAttributes.h"
#pragma GCC diagnostic ignored "-Wunused-parameter"

#include "mlir/IR/BuiltinTypes.h"

namespace P4::P4MLIR::BMv2IR {
struct FieldInfo {
    mlir::StringAttr name;
    int size;
    bool isSigned;

    FieldInfo(mlir::StringAttr name, int size, bool isSigned)
        : name(name), size(size), isSigned(isSigned) {}

    bool operator==(const FieldInfo &other) const {
        return name == other.name && size == other.size;
    }

    friend llvm::raw_ostream &operator<<(llvm::raw_ostream &os, const FieldInfo &f) {
        return os << f.name.data() << "<" << (f.size != kDynamic ? std::to_string(f.size) : "*")
                  << (f.isSigned ? ",s" : "") << ">";
    }

    friend llvm::hash_code hash_value(P4::P4MLIR::BMv2IR::FieldInfo f);
    static constexpr int kDynamic = -1;
};
}  // namespace P4::P4MLIR::BMv2IR

#define GET_TYPEDEF_CLASSES
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.h.inc"

#endif  // P4MLIR_DIALECT_BMv2IR_BMv2IR_TYPES_H
