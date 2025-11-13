#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.h"

#include "llvm/ADT/TypeSwitch.h"
#include "llvm/Support/LogicalResult.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/DialectImplementation.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.h"

using namespace mlir;
using namespace P4::P4MLIR;

template <>
struct mlir::FieldParser<P4::P4MLIR::BMv2IR::FieldInfo> {
    static FailureOr<P4::P4MLIR::BMv2IR::FieldInfo> parse(AsmParser &parser) {
        StringRef name;
        int size = 0;
        bool isSigned = false;
        if (failed(parser.parseKeyword(&name))) return failure();
        if (failed(parser.parseLess())) return failure();
        if (succeeded(parser.parseOptionalStar())) {
            size = BMv2IR::FieldInfo::kDynamic;
        } else if (failed(parser.parseInteger(size))) {
            return failure();
        }
        StringRef signStr;
        if (succeeded(parser.parseOptionalComma())) {
            if (llvm::succeeded(parser.parseOptionalKeyword(&signStr))) {
                llvm::errs() << "[ptrdbg] s: " << signStr << "\n";
                if (signStr == "s")
                    isSigned = true;
                else
                    return failure();
            }
        }
        if (failed(parser.parseGreater())) return failure();

        auto res = BMv2IR::FieldInfo(StringAttr::get(parser.getContext(), name), size, isSigned);
        llvm::errs() << "[ptrdbg] got " << res << "\n";
        return res;
    }
};

llvm::LogicalResult BMv2IR::HeaderType::verify(
    ::llvm::function_ref<::mlir::InFlightDiagnostic()> emitError, ::llvm::StringRef name,
    ::llvm::ArrayRef<BMv2IR::FieldInfo> fields, int max_length) {
    return success();
}

#define GET_TYPEDEF_CLASSES
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.cpp.inc"

llvm::hash_code P4::P4MLIR::BMv2IR::hash_value(P4::P4MLIR::BMv2IR::FieldInfo f) {
    return llvm::hash_value(f.name.getValue());
}

void BMv2IR::BMv2IRDialect::registerTypes() {
    addTypes<
#define GET_TYPEDEF_LIST
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.cpp.inc"  // NOLINT
        >();
}
