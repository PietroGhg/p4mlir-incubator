#ifndef P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
#define P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD

include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/CommonAttrConstraints.td"

include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.td"

class BMv2IR_Attr<string name, string attrMnemonic, list<Trait> traits = []>
    : AttrDef<BMv2IR_Dialect, name, traits> {
  let mnemonic = attrMnemonic;
}

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

def BMv2_Transition: BMv2IR_Attr<"Transition", "transition"> {
  let summary = "Parser transition";
  let description = [{
    Represents a single transition from a parse state.
    
    Types:
    - default: default transition (no value/mask)
    - hexstr: value-based transition with hexstring
    - parse_vset: parse value-set based transition
    
    The value and mask are hexstrings in the format described in the BMv2 JSON
    spec (concatenation of byte-padded fields). For example, if the transition
    key has a 12-bit field and a 2-bit field, values use 3 bytes (0x0aba03).
    
    next_state can be null for the last state in the parser.
  }];
  
  // TODO: refine this, don't use strings
  let parameters = (ins
    "mlir::StringAttr":$type,                              // "default", "hexstr", "parse_vset"
    OptionalParameter<"mlir::SymbolRefAttr">:$next_state, // next state name or null
    OptionalParameter<"mlir::Attribute">:$value,            // hexstr value or vset name (null if default)
    OptionalParameter<"mlir::Attribute">:$mask             // mask hexstr or null
  );
  
  let assemblyFormat = "`<` $type (`,` $value^)? (`,` $mask^)? (`,` $next_state^)? `>`";
}

def BMv2_TransitionKeyArrayAttr : 
    TypedArrayAttrBase<BMv2_TransitionKeyAttr, "array of transition keys">;

def BMv2_TransitionArrayAttr : 
    TypedArrayAttrBase<BMv2_Transition, "array of transition specs">;

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
