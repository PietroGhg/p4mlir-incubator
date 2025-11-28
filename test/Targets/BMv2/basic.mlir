// RUN: p4mlir-to-json --p4hir-to-bmv2-json %s | FileCheck %s
!b8i = !p4hir.bit<8>
#int1_b8i = #p4hir.int<1> : !b8i
#int2_b8i = #p4hir.int<2> : !b8i

// CHECK:{
// CHECK:  "header_types": [
// CHECK:    {
// CHECK:      "fields": [
// CHECK:        [
// CHECK:          "skip",
// CHECK:          8,
// CHECK:          false
// CHECK:        ]
// CHECK:      ],
// CHECK:      "id": 0,
// CHECK:      "name": "header_top"
// CHECK:    },
// CHECK:    {
// CHECK:      "fields": [
// CHECK:        [
// CHECK:          "type",
// CHECK:          8,
// CHECK:          false
// CHECK:        ],
// CHECK:        [
// CHECK:          "data",
// CHECK:          8,
// CHECK:          false
// CHECK:        ]
// CHECK:      ],
// CHECK:      "id": 1,
// CHECK:      "name": "header_one"
// CHECK:    },
// CHECK:    {
// CHECK:      "fields": [
// CHECK:        [
// CHECK:          "type",
// CHECK:          8,
// CHECK:          false
// CHECK:        ],
// CHECK:        [
// CHECK:          "data",
// CHECK:          16,
// CHECK:          false
// CHECK:        ]
// CHECK:      ],
// CHECK:      "id": 2,
// CHECK:      "name": "header_two"
// CHECK:    }
// CHECK:  ],
// CHECK:      "headers": [
// CHECK:    {
// CHECK:      "header_types": "header_top",
// CHECK:      "id": 0,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs1_top"
// CHECK:    },
// CHECK:    {
// CHECK:      "header_types": "header_one",
// CHECK:      "id": 1,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs1_one"
// CHECK:    },
// CHECK:    {
// CHECK:      "header_types": "header_two",
// CHECK:      "id": 2,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs1_two"
// CHECK:    },
// CHECK:    {
// CHECK:      "header_types": "header_one",
// CHECK:      "id": 3,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs_e_0"
// CHECK:    }
// CHECK:  ]
// CHECK:}
module {
  bmv2ir.parser @prs init_state @prs::@start {
    %0 = bmv2ir.header_instance @prs1_top : !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1>
    %1 = bmv2ir.header_instance @prs1_one : !bmv2ir.header<"header_one", [type:!p4hir.bit<8>, data:!p4hir.bit<8>], max_length = 2> -> !bmv2ir.header<"header_one", [type:!p4hir.bit<8>, data:!p4hir.bit<8>], max_length = 2>
    %2 = bmv2ir.header_instance @prs1_two : !bmv2ir.header<"header_two", [type:!p4hir.bit<8>, data:!p4hir.bit<16>], max_length = 3> -> !bmv2ir.header<"header_two", [type:!p4hir.bit<8>, data:!p4hir.bit<16>], max_length = 3>
    %3 = bmv2ir.header_instance @prs_e_0 : !bmv2ir.header<"header_one", [type:!p4hir.bit<8>, data:!p4hir.bit<8>], max_length = 2> -> !bmv2ir.header<"header_one", [type:!p4hir.bit<8>, data:!p4hir.bit<8>], max_length = 2>
    bmv2ir.state @start
     transition_key {
    }
     transitions {
      bmv2ir.transition type  default next_state @prs::@parse_headers
    }
     parser_ops {
      bmv2ir.extract  regular @prs1_top
    }
    bmv2ir.state @parse_headers
     transition_key {
      bmv2ir.lookahead<0, 8>
    }
     transitions {
      bmv2ir.transition type  hexstr value #int1_b8i next_state @prs::@parse_one
      bmv2ir.transition type  hexstr value #int2_b8i next_state @prs::@parse_two
      bmv2ir.transition type  hexstr value #int1_b8i mask #int2_b8i next_state @prs::@parse_two
      bmv2ir.transition type  default next_state @prs::@parse_bottom
    }
     parser_ops {
    }
    bmv2ir.state @parse_one
     transition_key {
    }
     transitions {
      bmv2ir.transition type  default next_state @prs::@parse_two
    }
     parser_ops {
      bmv2ir.extract  regular @prs_e_0
      bmv2ir.assign_header @prs_e_0 to @prs1_one
    }
    bmv2ir.state @parse_two
     transition_key {
    }
     transitions {
      bmv2ir.transition type  default next_state @prs::@parse_bottom
    }
     parser_ops {
      bmv2ir.extract  regular @prs1_two
    }
    bmv2ir.state @parse_bottom
     transition_key {
    }
     transitions {
      bmv2ir.transition type  default next_state @prs::@accept
    }
     parser_ops {
    }
    bmv2ir.state @accept
     transition_key {
    }
     transitions {
      bmv2ir.transition type  default
    }
     parser_ops {
    }
  }
}

