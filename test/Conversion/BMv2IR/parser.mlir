// RUN: p4mlir-opt -p='builtin.module(p4hir-to-bmv2ir)' %s --split-input-file | FileCheck %s
!b16i = !p4hir.bit<16>
!b8i = !p4hir.bit<8>
!validity_bit = !p4hir.validity.bit
#everything = #p4hir.universal_set : !p4hir.set<!p4hir.dontcare>
!header_bottom = !p4hir.header<"header_bottom", length: !b8i, data: !p4hir.varbit<256>, __valid: !validity_bit>
!header_one = !p4hir.header<"header_one", type: !b8i, data: !b8i, __valid: !validity_bit>
!header_top = !p4hir.header<"header_top", skip: !b8i, __valid: !validity_bit>
!header_two = !p4hir.header<"header_two", type: !b8i, data: !b16i, __valid: !validity_bit>
#int1_b8i = #p4hir.int<1> : !b8i
#int2_b8i = #p4hir.int<2> : !b8i
!Headers_t = !p4hir.struct<"Headers_t", top: !header_top, one: !header_one, two: !header_two, bottom: !header_bottom>
module {
  p4hir.parser @prs(%arg0: !p4corelib.packet_in {p4hir.dir = #p4hir<dir undir>, p4hir.param_name = "p"}, %arg1: !p4hir.ref<!Headers_t> {p4hir.dir = #p4hir<dir out>, p4hir.param_name = "headers"})() {
// CHECK:  bmv2ir.parser @prs init_state @prs::@start {
    %0 = bmv2ir.header_instance @prs1_top : !p4hir.ref<!header_top> -> !p4hir.ref<!header_top>
// CHECK:    bmv2ir.header_instance @prs1_top : !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1>
    %1 = bmv2ir.header_instance @prs1_one : !p4hir.ref<!header_one> -> !p4hir.ref<!header_one>
// CHECK:    bmv2ir.header_instance @prs1_one : !bmv2ir.header<"header_one", [type:!p4hir.bit<8>, data:!p4hir.bit<8>], max_length = 2>
    %2 = bmv2ir.header_instance @prs1_two : !p4hir.ref<!header_two> -> !p4hir.ref<!header_two>
// CHECK:    bmv2ir.header_instance @prs1_two : !bmv2ir.header<"header_two", [type:!p4hir.bit<8>, data:!p4hir.bit<16>], max_length = 3>
    %e_0 = bmv2ir.header_instance @prs_e_0 : !p4hir.ref<!header_one> -> !p4hir.ref<!header_one>
// CHECK:    bmv2ir.header_instance @prs_e_0 : !bmv2ir.header<"header_one", [type:!p4hir.bit<8>, data:!p4hir.bit<8>], max_length = 2>
    p4hir.state @start {
      p4corelib.extract_header %0 : <!header_top> from %arg0 : !p4corelib.packet_in
      p4hir.transition to @prs::@parse_headers
    }
// CHECK:    bmv2ir.state @start
// CHECK:     transition_key {
// CHECK:    }
// CHECK:     transitions {
// CHECK:      bmv2ir.transition type  default next_state @prs::@parse_headers
// CHECK:    }
// CHECK:     parser_ops {
// CHECK:      bmv2ir.extract  regular @prs1_top
// CHECK:    }
    p4hir.state @parse_headers {
      %lookahead = p4corelib.packet_lookahead %arg0 : !p4corelib.packet_in -> !b8i
      p4hir.transition_select %lookahead : !b8i {
        p4hir.select_case {
          %c1_b8i = p4hir.const #int1_b8i
          %set = p4hir.set (%c1_b8i) : !p4hir.set<!b8i>
          p4hir.yield %set : !p4hir.set<!b8i>
        } to @prs::@parse_one
        p4hir.select_case {
          %c2_b8i = p4hir.const #int2_b8i
          %set = p4hir.set (%c2_b8i) : !p4hir.set<!b8i>
          p4hir.yield %set : !p4hir.set<!b8i>
        } to @prs::@parse_two
        p4hir.select_case {
          %c1_b8i = p4hir.const #int1_b8i
          %c2_b8i = p4hir.const #int2_b8i
          %mask = p4hir.mask(%c1_b8i, %c2_b8i) : !p4hir.set<!b8i>
          p4hir.yield %mask : !p4hir.set<!b8i>
        } to @prs::@parse_two
        p4hir.select_case {
          %everything = p4hir.const #everything
          p4hir.yield %everything : !p4hir.set<!p4hir.dontcare>
        } to @prs::@parse_bottom
      }
    }
// CHECK:    bmv2ir.state @parse_headers
// CHECK:     transition_key {
// CHECK:      bmv2ir.lookahead<0, 8>
// CHECK:    }
// CHECK:     transitions {
// CHECK:      bmv2ir.transition type  hexstr value #int1_b8i next_state @prs::@parse_one
// CHECK:      bmv2ir.transition type  hexstr value #int2_b8i next_state @prs::@parse_two
// CHECK:      bmv2ir.transition type  hexstr value #int1_b8i mask #int2_b8i next_state @prs::@parse_two
// CHECK:      bmv2ir.transition type  default next_state @prs::@parse_bottom
// CHECK:    }
// CHECK:     parser_ops {
// CHECK:    }
    p4hir.state @parse_one {
      p4corelib.extract_header %e_0 : <!header_one> from %arg0 : !p4corelib.packet_in
      %val = p4hir.read %e_0 : <!header_one>
      p4hir.assign %val, %1 : <!header_one>
      p4hir.transition to @prs::@parse_two
    }
// CHECK:    bmv2ir.state @parse_one
// CHECK:     transition_key {
// CHECK:    }
// CHECK:     transitions {
// CHECK:      bmv2ir.transition type  default next_state @prs::@parse_two
// CHECK:    }
// CHECK:     parser_ops {
// CHECK:      bmv2ir.extract  regular @prs_e_0
// CHECK:      bmv2ir.assign_header @prs_e_0 to @prs1_one
// CHECK:    }
    p4hir.state @parse_two {
      p4corelib.extract_header %2 : <!header_two> from %arg0 : !p4corelib.packet_in
      p4hir.transition to @prs::@parse_bottom
    }
// CHECK:    bmv2ir.state @parse_two
// CHECK:     transition_key {
// CHECK:    }
// CHECK:     transitions {
// CHECK:      bmv2ir.transition type  default next_state @prs::@parse_bottom
// CHECK:    }
// CHECK:     parser_ops {
// CHECK:      bmv2ir.extract  regular @prs1_two
// CHECK:    }
    p4hir.state @parse_bottom {
      p4hir.transition to @prs::@accept
    }
// CHECK:    bmv2ir.state @parse_bottom
// CHECK:     transition_key {
// CHECK:    }
// CHECK:     transitions {
// CHECK:      bmv2ir.transition type  default next_state @prs::@accept
// CHECK:    }
// CHECK:     parser_ops {
// CHECK:    }
    p4hir.state @accept {
      p4hir.parser_accept
    }
// CHECK:    bmv2ir.state @accept
// CHECK:     transition_key {
// CHECK:    }
// CHECK:     transitions {
// CHECK:      bmv2ir.transition type  default
// CHECK:    }
// CHECK:     parser_ops {
// CHECK:    }
    p4hir.transition to @prs::@start
  }
}

// -----

!b8i = !p4hir.bit<8>
!validity_bit = !p4hir.validity.bit
!bit_only = !p4hir.struct<"bit_only", bit: !b8i>
!header_top = !p4hir.header<"header_top", skip: !b8i, __valid: !validity_bit>
module {
  p4hir.parser @prs_only_bit(%arg0: !p4corelib.packet_in {p4hir.dir = #p4hir<dir undir>, p4hir.param_name = "p"}, %arg1: !p4hir.ref<!bit_only> {p4hir.dir = #p4hir<dir out>, p4hir.param_name = "headers"}, %arg2: !p4hir.ref<!header_top> {p4hir.dir = #p4hir<dir out>, p4hir.param_name = "headers"})() {
    %0 = bmv2ir.header_instance @prs_only_bit2 : !p4hir.ref<!header_top> -> !p4hir.ref<!header_top>
    %1 = bmv2ir.header_instance @prs_only_bit1 : !p4hir.ref<!bit_only> -> !p4hir.ref<!bit_only>
    %2 = bmv2ir.header_instance @prs_only_bit_top_0 : !p4hir.ref<!header_top> -> !p4hir.ref<!header_top>
// CHECK: %[[TOP:.*]] = bmv2ir.header_instance @prs_only_bit2 : !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1>
// CHECK: %[[BIT:.*]] = bmv2ir.header_instance @prs_only_bit1 : !bmv2ir.header<"bit_only", [bit:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"bit_only", [bit:!p4hir.bit<8>], max_length = 1>
// CHECK: %[[TOP_0:.*]] = bmv2ir.header_instance @prs_only_bit_top_0 : !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1>

    p4hir.state @start {
      p4corelib.extract_header %2 : <!header_top> from %arg0 : !p4corelib.packet_in
      %skip_field_ref = p4hir.struct_field_ref %2["skip"] : <!header_top>
      %val = p4hir.read %skip_field_ref : <!b8i>
      %bit_field_ref = p4hir.struct_field_ref %1["bit"] : <!bit_only>
      p4hir.assign %val, %bit_field_ref : <!b8i>
      %val_0 = p4hir.read %bit_field_ref : <!b8i>
      %skip_field_ref_1 = p4hir.struct_field_ref %0["skip"] : <!header_top>
      p4hir.assign %val_0, %skip_field_ref_1 : <!b8i>
      p4hir.transition to @prs_only_bit::@accept

// CHECK: bmv2ir.extract  regular @prs_only_bit_top_0
// CHECK: %[[SRC:.*]] = bmv2ir.field @prs_only_bit_top_0["skip"] -> !b8i
// CHECK: %[[DST:.*]] = bmv2ir.field @prs_only_bit1["bit"] -> !b8i
// CHECK: bmv2ir.assign %[[SRC]] : !b8i to %[[DST]] : !b8i
// CHECK: %[[DST2:.*]] = bmv2ir.field @prs_only_bit2["skip"] -> !b8i
// CHECK: bmv2ir.assign %[[DST]] : !b8i to %[[DST2]] : !b8i
    }
    p4hir.state @accept {
      p4hir.parser_accept
    }
    p4hir.transition to @prs_only_bit::@start
  }
}
