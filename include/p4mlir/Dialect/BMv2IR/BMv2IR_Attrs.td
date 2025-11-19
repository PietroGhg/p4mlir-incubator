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

def BMv2_FieldAttr : BMv2IR_Attr<"Field", "field"> {
  let summary = "BMv2 header field access";
  let description = [{
    Represents access to a field within a header instance.
    Contains a 2-tuple: (header_instance_name, field_member_name)
  }];
  
  let parameters = (ins
    "mlir::StringAttr":$headerInstance,
    "mlir::StringAttr":$fieldMember
  );
  
  let assemblyFormat = "`<` $headerInstance `,` $fieldMember `>`";
}

def BMv2_StackFieldAttr : BMv2IR_Attr<"StackField", "stack_field"> {
  let summary = "BMv2 header stack field access";
  let description = [{
    Represents access to a field in the last valid header instance in a stack.
    Contains a 2-tuple: (header_stack_name, field_member_name)
  }];
  
  let parameters = (ins
    "mlir::StringAttr":$headerStack,
    "mlir::StringAttr":$fieldMember
  );
  
  let assemblyFormat = "`<` $headerStack `,` $fieldMember `>`";
}

def BMv2_UnionStackFieldAttr : BMv2IR_Attr<"UnionStackField", "union_stack_field"> {
  let summary = "BMv2 header union stack field access";
  let description = [{
    Represents access to a field in the last valid union instance in a stack.
    Contains a 3-tuple: (header_union_stack_name, union_member_name, field_member_name)
  }];
  
  let parameters = (ins
    "mlir::StringAttr":$headerUnionStack,
    "mlir::StringAttr":$unionMember,
    "mlir::StringAttr":$fieldMember
  );
  
  let assemblyFormat = "`<` $headerUnionStack `,` $unionMember `,` $fieldMember `>`";
}

def BMv2_LookaheadAttr : BMv2IR_Attr<"Lookahead", "lookahead"> {
  let summary = "BMv2 parser lookahead";
  let description = [{
    Represents a lookahead operation in a parser.
    Contains a 2-tuple: (bit_offset, bitwidth)
  }];
  
  let parameters = (ins
    "mlir::IntegerAttr":$bitOffset,
    "mlir::IntegerAttr":$bitwidth
  );
  
  let assemblyFormat = "`<` $bitOffset `,` $bitwidth `>`";
}

def BMv2_TransitionKeyAttr : AnyAttrOf<[BMv2_FieldAttr, BMv2_StackFieldAttr, BMv2_UnionStackFieldAttr, BMv2_LookaheadAttr]>;

def BMv2_TransitionKeyArrayAttr : 
    TypedArrayAttrBase<BMv2_TransitionKeyAttr, "array of transition keys">;

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
