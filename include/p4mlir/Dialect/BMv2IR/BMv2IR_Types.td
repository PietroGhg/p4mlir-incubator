#ifndef P4MLIR_DIALECT_BMv2IR_BMv2IR_TYPES_TD
#define P4MLIR_DIALECT_BMv2IR_BMv2IR_TYPES_TD

include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/BuiltinTypes.td"

include "p4mlir/Dialect/BMv2IR/BMv2IR_Dialect.td"

//===----------------------------------------------------------------------===//
// BMv2IR type definitions.
//===----------------------------------------------------------------------===//

class BMv2IR_Type<string name, string typeMnemonic, list<Trait> traits = []>
    : TypeDef<BMv2IR_Dialect, name, traits> {
  let mnemonic = typeMnemonic;
}

// P4HeaderType represents a complete header type definition
def BMv2_HeaderType : BMv2IR_Type<"Header", "header"> {
  let summary = "BMv2 header type";
  let description = [{
    Represents a P4 header according to the
    [BMv2 JSON spec](https://github.com/p4lang/behavioral-model/blob/main/docs/JSON_format.md#header_types)
    
    The type encodes:
    - A unique name for the header type
    - A unique integer ID
    - An array of fields (name, bitwidth, optional signed flag)
    - Optional length expression for variable-length headers
    - Optional maximum length for variable-length headers
    
    Variable-length fields are represented with bitwidth = -1.
    At most one field can be variable-length.
  }];
  
  let parameters = (ins
    StringRefParameter<"struct name">:$name,
    ArrayRefParameter<"BMv2IR::FieldInfo", "struct fields">:$fields,
    OptionalParameter<"int">:$max_length
  );
  
  let assemblyFormat = [{
    `<` $name `,` `[` $fields `]`
    (`,` `max_length` `=` $max_length^)?
    `>`
  }];
  
  let genVerifyDecl = 1;
  
  // Add verification for constraints
  let extraClassDeclaration = [{
    /// Check if this header type has a variable-length field
    bool hasVariableLengthField() const;
    
    /// Verify type constraints
    ::mlir::LogicalResult verify();
  }];
}

#endif // P4MLIR_DIALECT_BMv2IR_BMv2IR_TYPES_TD
