#ifndef P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
#define P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD

include "mlir/IR/BuiltinAttributeInterfaces.td"

include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.td"

class BMv2IR_Attr<string name, string attrMnemonic, list<Trait> traits = []>
    : AttrDef<BMv2IR_Dialect, name, traits> {
  let mnemonic = attrMnemonic;
}

def BMv2_TransitionKeyAttr : BMv2IR_Attr<"TransitionKey", "transition-key"> {
  let summary = "Transition key";
  let description = [{
    Represents a field in the parse state transition key.
    
    Types:
    - field: regular field reference
    - stack_field: field of last extracted instance in a stack
    - union_stack_field: field of last extracted instance in union stack
    - lookahead: lookahead field
  }];
  
  // TODO: don't use strings here
  let parameters = (ins
    "mlir::StringAttr":$type,    // "field", "stack_field", "union_stack_field", "lookahead"
    "mlir::StringAttr":$value    // field name or lookahead specification
  );
  
  let mnemonic = "transition_key";
  let assemblyFormat = "`<` $type `,` $value `>`";
}

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
    OptionalParameter<"mlir::StringAttr">:$value,            // hexstr value or vset name (null if default)
    OptionalParameter<"mlir::StringAttr">:$mask             // mask hexstr or null
  );
  
  let mnemonic = "trans_spec";
  let assemblyFormat = "`<` $type (`,` $value^)? (`,` $mask^)? (`,` $next_state^)? `>`";
}

def BMv2_TransitionKeyArrayAttr : 
    TypedArrayAttrBase<BMv2_TransitionKeyAttr, "array of transition keys">;

def BMv2_TransitionArrayAttr : 
    TypedArrayAttrBase<BMv2_Transition, "array of transition specs">;

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_ATTRS_TD
