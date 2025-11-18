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

def BMv2_ParserOp : BMv2IR_Op<"parser", [
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

def ParserStateOp : BMv2IR_Op<"state",
   [HasParent<"ParserOp">,
    Symbol, NoTerminator]> {
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    OptionalAttr<BMv2_TransitionArrayAttr>:$transitions,
    OptionalAttr<BMv2_TransitionKeyArrayAttr>:$transition_key
  );
  
  let regions = (region SizedRegion<1>:$parser_ops);
  
  let assemblyFormat = [{
    $sym_name
    (`\n``transition_key` $transition_key^)?
    (`\n``transitions` $transitions^)?
    $parser_ops attr-dict
  }];
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
  
  // TODO: don't use strings
  let arguments = (ins
    StrAttr:$extract_type,
    StrAttr:$value,
    OptionalAttr<StrAttr>:$union_member
  );
  
  let assemblyFormat = [{
    $extract_type $value (`union_member` $union_member^)? attr-dict
  }];
}

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_OPS_TD
