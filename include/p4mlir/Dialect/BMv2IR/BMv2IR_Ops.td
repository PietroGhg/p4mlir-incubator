#ifndef P4MLIR_DIALECT_BMv2IR_BMv2IR_OPS_TD
#define P4MLIR_DIALECT_BMv2IR_BMv2IR_OPS_TD

include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"


include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.td"
include "p4mlir/Dialect/BMv2IR/BMv2IR_Types.td"
include "p4mlir/Dialect/BMv2IR/BMv2IR_Attrs.td"

//===----------------------------------------------------------------------===//
// Base BMv2IR operation definition.
//===----------------------------------------------------------------------===//

class BMv2IR_Op<string mnemonic, list<Trait> traits = []> :
        Op<BMv2IR_Dialect, mnemonic, traits>;

def BMv2IR_ParserOp : BMv2IR_Op<"parser", [
    Symbol, SymbolTable,
    SingleBlock, NoTerminator
  ]> {
  let summary = "P4 parser definition";
  let description = [{
    Represents a P4 parser with an initial state and a set of parse states.
    
    Example:
    ```mlir
    bmv2.parser @my_parser init_state @start {
      // parse states here
    }
    ```
  }];
  
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    SymbolRefAttr:$init_state
  );
  
  let regions = (region SizedRegion<1>:$body);
  
  let assemblyFormat = [{
    $sym_name `init_state` $init_state $body attr-dict
  }];
}

def BMv2IR_ParserStateOp : BMv2IR_Op<"state",
   [HasParent<"ParserOp">,
    Symbol, NoTerminator]> {
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    OptionalAttr<BMv2_TransitionKeyArrayAttr>:$transition_key
  );
  
  let regions = (region 
      SizedRegion<1>:$parser_ops,
      SizedRegion<1>:$transitions);
  
  let assemblyFormat = [{
    $sym_name
    (`\n``transition_key` $transition_key^)?
    `\n` `transitions` $transitions
    `parser_ops` $parser_ops attr-dict
  }];
}

def BMv2IR_TransitionOp : BMv2IR_Op<"transition", [HasParent<"ParserStateOp">]> {
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
  
  // TODO: refine value and mask fields
  let arguments = (ins
    BMv2IR_TransitionKindAttr:$type,                              // "default", "hexstr", "parse_vset"
    OptionalAttr<SymbolRefAttr>:$next_state, // next state name or null
    OptionalAttr<AnyAttr>:$value,            // hexstr value or vset name (null if default)
    OptionalAttr<AnyAttr>:$mask             // mask hexstr or null
  );
  
  let assemblyFormat = "`<` $type (`,` $value^)? (`,` $mask^)? (`,` $next_state^)? `>` attr-dict";
}


def BMv2_ExtractOp : BMv2IR_Op<"extract", [HasParent<"ParserStateOp">]> {
  let summary = "Extract header operation";
  let description = [{
    Extracts the field of a header instance, header stack, or union stack element.
    
    Types:
    - regular: extraction to a regular header instance
    - stack: extraction to the end of a header stack
    - union_stack: extraction to the end of a header union stack
  }];
  
  let arguments = (ins
    BMv2IR_ExtractKindAttr:$extract_type,
    StrAttr:$value,
    OptionalAttr<StrAttr>:$union_member
  );
  
  let assemblyFormat = [{
    $extract_type $value (`union_member` $union_member^)? attr-dict
  }];
}

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_OPS_TD
