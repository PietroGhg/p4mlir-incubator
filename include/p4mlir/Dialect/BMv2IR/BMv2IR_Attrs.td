#ifndef P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
#define P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD

include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/CommonAttrConstraints.td"
include "mlir/IR/EnumAttr.td"

include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.td"

class BMv2IR_Attr<string name, string attrMnemonic, list<Trait> traits = []>
    : AttrDef<BMv2IR_Dialect, name, traits> {
  let mnemonic = attrMnemonic;
}

def BMv2IR_ExtractKind : IntEnum<"ExtractKind",
    "BMv2 extract operation kind",
    [
      I32EnumAttrCase<"Regular", 0, "regular">,
      I32EnumAttrCase<"Stack", 1, "stack">,
      I32EnumAttrCase<"UnionStack", 2, "union_stack">
    ], 32> {
  let cppNamespace = "P4::P4MLIR::BMv2IR";
}

def BMv2IR_ExtractKindAttr : EnumAttr<BMv2IR_Dialect, BMv2IR_ExtractKind, "extract_kind">;

def BMv2IR_TransitionKind : IntEnum<"TransitionKind",
    "BMv2 extract operation kind",
    [
      I32EnumAttrCase<"Default", 0, "default">,
      I32EnumAttrCase<"Hexstr", 1, "hexstr">,
      I32EnumAttrCase<"Parse_vset", 2, "parse_vset">
    ], 32> {
  let cppNamespace = "P4::P4MLIR::BMv2IR";
}

def BMv2IR_TransitionKindAttr : EnumAttr<BMv2IR_Dialect, BMv2IR_TransitionKind, "transition_kind">;

def BMv2IR_ActionTableAttr : BMv2IR_Attr<"ActionTable", "action-table"> {
  let summary = "Action-Table pair";
  let description = [{
    This attribute contains a pair of symbol references, one for an action and one for the corresponding next table in the next_table section of the BMv2 description of Tables.
  }];
  
  let parameters = (ins
    "mlir::SymbolRefAttr":$action,
    OptionalParameter<"mlir::SymbolRefAttr">:$table
  );
  
  let assemblyFormat = "`<` $action (`:` $table^)? `>`";
}

def BMv2IR_ActionTableArrayAttr : TypedArrayAttrBase<
  BMv2IR_ActionTableAttr, "array of action-table pair attributes">;

def BMv2IR_TableMatchKind : IntEnum<"TableMatchKind", "BMv2IR table match kind", [
    I32EnumAttrCase<"Valid", 0, "valid">,
    I32EnumAttrCase<"Exact", 1, "exact">,
    I32EnumAttrCase<"LPM", 2, "lpm">,
    I32EnumAttrCase<"Ternary", 3, "ternary">,
    I32EnumAttrCase<"Range", 4, "range">
], 32> {
    let cppNamespace = "P4::P4MLIR::BMv2IR";
}

def BMv2IR_TableMatchKindAttr : EnumAttr<BMv2IR_Dialect, BMv2IR_TableMatchKind, "table_key_kind">;

def BMv2IR_TableKeyAttr : BMv2IR_Attr<"TableKey", "table-key"> {
  let summary = "Table key description attribute";
  let description = [{
    Represents one element in a table match key with the following attributes:
      - match_type: The type of match (valid, exact, lpm, ternary, range)
      - target: Field reference as 2-tuple [header, field] or header string for 'valid' (BMv2 table
        keys can access only header instances or header fields).
      - mask: Optional static mask (byte-padded, same width as field)
      - name: Optional name for the match element (for logging/debugging)
  }];

  let parameters = (ins
      "TableMatchKind":$match_type,
      "mlir::SymbolRefAttr":$header,
      OptionalParameter<"mlir::StringAttr">:$fieldName,
      OptionalParameter<"mlir::DenseIntElementsAttr">:$mask,
      OptionalParameter<"mlir::StringAttr">:$name
  );

  // TODO: add verifier
  let assemblyFormat = [{
      `<` `type` $match_type `,` `header` $header (`[` $fieldName^ `]`)? (`,` `mask` `=` $mask^)? (`,` `name` `=` $name^)? `>`
  }];
}

def BMv2IR_TableKeyArrayAttr : TypedArrayAttrBase<BMv2IR_TableKeyAttr,
    "Array of match key elements">;

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
