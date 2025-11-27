#include "p4mlir/Targets/BMv2/Target.h"

#include <vector>

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/TypeSwitch.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/JSON.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Interfaces/DataLayoutInterfaces.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Tools/mlir-translate/Translation.h"
#include "p4mlir/Common/Registration.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.h"
#include "p4mlir/Dialect/BMv2IR/BMv2IR_Ops.h"

using namespace llvm;
using namespace mlir;
using namespace P4::P4MLIR;

static constexpr char const *header_types_str = "header_types";
static constexpr char const *header_type_str = "header_types";
static constexpr char const *headers_str = "headers";
static constexpr char const *name_str = "name";
static constexpr char const *fields_str = "fields";
static constexpr char const *metadata_str = "metadata";

static json::Object toJSON(BMv2IR::HeaderType headerTy) {
    json::Object res;

    json::Array fields;
    for (auto &field : headerTy.getFields()) {
        std::pair<std::string, bool> bitWidthSignedPair =
            llvm::TypeSwitch<Type, std::pair<std::string, bool>>(field.type)
                .Case([](P4HIR::BitsType bitTy) -> std::pair<std::string, bool> {
                    return {std::to_string(bitTy.getWidth()), bitTy.isSigned()};
                })
                .Case([](P4HIR::VarBitsType varBitTy) -> std::pair<std::string, bool> {
                    return {"*", varBitTy.isSignedInteger()};
                });

        json::Array fieldDesc{field.name.str(), bitWidthSignedPair.first,
                              bitWidthSignedPair.second};
        fields.push_back(std::move(fieldDesc));
    }

    res.insert({.K = fields_str, .V = std::move(fields)});
    res.insert({.K = name_str, .V = headerTy.getName()});

    return res;
}

static json::Object toJSON(BMv2IR::HeaderInstanceOp headerInstance) {
    json::Object res;
    auto name = cast<BMv2IR::HeaderType>(headerInstance.getType()).getName();
    res.insert({.K = name_str, .V = headerInstance.getSymName().str()});
    res.insert({.K = header_type_str, .V = name.str()});
    res.insert({.K = metadata_str, .V = headerInstance.getMetadata()});

    return res;
}

mlir::FailureOr<json::Value> P4::P4MLIR::bmv2irToJson(ModuleOp moduleOp) {
    json::Object root;
    json::ObjectKey headersNode(headers_str);

    // Emit header types and header instances
    SmallVector<BMv2IR::HeaderInstanceOp> headerInstances;
    moduleOp.walk([&](BMv2IR::HeaderInstanceOp instance) { headerInstances.push_back(instance); });
    llvm::SetVector<Type> headersTy;
    json::Array headerTyNodes;
    json::Array headerInstanceNodes;
    for (auto instance : headerInstances) {
        auto headerTy = dyn_cast<BMv2IR::HeaderType>(instance.getType());
        if (!headerTy) return instance.emitError("Unexpected type");
        bool inserted = headersTy.insert(headerTy);
        if (inserted) headerTyNodes.push_back(toJSON(headerTy));
        headerInstanceNodes.push_back(toJSON(instance));
    }
    root.insert({.K = header_types_str, .V = std::move(headerTyNodes)});
    root.insert({.K = headers_str, .V = std::move(headerInstanceNodes)});

    json::Value res(std::move(root));
    return res;
}

void P4::P4MLIR::registerToBMv2JSONTranslation() {
    TranslateFromMLIRRegistration registration(
        "p4hir-to-bmv2-json", "Translate MLIR to BMv2 JSON",
        [](Operation *op, raw_ostream &output) {
            auto moduleOp = dyn_cast<ModuleOp>(op);
            if (!moduleOp) return failure();
            if (failed(bmv2irToJson(moduleOp, output))) return failure();
            return success();
        },
        [](DialectRegistry &registry) { P4::P4MLIR::registerAllDialects(registry); });
}

LogicalResult P4::P4MLIR::bmv2irToJson(ModuleOp moduleOp, raw_ostream &output) {
    auto maybeJsonModule = bmv2irToJson(moduleOp);
    if (failed(maybeJsonModule)) return failure();

    output << llvm::formatv("{0:2}", *maybeJsonModule) << "\n";
    return success();
}
