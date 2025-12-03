// RUN: p4mlir-to-json --p4hir-to-bmv2-json %s --split-input-file | FileCheck %s

!b8i = !p4hir.bit<8>
#int1_b8i = #p4hir.int<1> : !b8i
#int2_b8i = #p4hir.int<2> : !b8i
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
// CHECK:  "headers": [
// CHECK:    {
// CHECK:      "header_type": "header_top",
// CHECK:      "id": 0,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs1_top"
// CHECK:    },
// CHECK:    {
// CHECK:      "header_type": "header_one",
// CHECK:      "id": 1,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs1_one"
// CHECK:    },
// CHECK:    {
// CHECK:      "header_type": "header_two",
// CHECK:      "id": 2,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs1_two"
// CHECK:    },
// CHECK:    {
// CHECK:      "header_type": "header_one",
// CHECK:      "id": 3,
// CHECK:      "metadata": false,
// CHECK:      "name": "prs_e_0"
// CHECK:    }
// CHECK:  ],
// CHECK:  "parsers": [
// CHECK:    {
// CHECK:      "init_state": "start",
// CHECK:      "name": "prs",
// CHECK:      "parse_states": [
// CHECK:        {
// CHECK:          "name": "start",
// CHECK:          "parser_ops": [
// CHECK:            {
// CHECK:              "op": "extract",
// CHECK:              "parameters": [
// CHECK:                {
// CHECK:                  "type": "regular",
// CHECK:                  "value": "e_0"
// CHECK:                }
// CHECK:              ]
// CHECK:            }
// CHECK:          ],
// CHECK:          "transition_key": [],
// CHECK:          "transitions": [
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "parse_headers",
// CHECK:              "type": "default",
// CHECK:              "value": null
// CHECK:            }
// CHECK:          ]
// CHECK:        },
// CHECK:        {
// CHECK:          "name": "parse_headers",
// CHECK:          "parser_ops": [],
// CHECK:          "transition_key": [
// CHECK:            {
// CHECK:              "type": "lookahead",
// CHECK:              "value": [
// CHECK:                0,
// CHECK:                8
// CHECK:              ]
// CHECK:            }
// CHECK:          ],
// CHECK:          "transitions": [
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "parse_one",
// CHECK:              "type": "hexstr",
// CHECK:              "value": "1"
// CHECK:            },
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "parse_two",
// CHECK:              "type": "hexstr",
// CHECK:              "value": "2"
// CHECK:            },
// CHECK:            {
// CHECK:              "mask": "2",
// CHECK:              "next_state": "parse_two",
// CHECK:              "type": "hexstr",
// CHECK:              "value": "1"
// CHECK:            },
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "parse_bottom",
// CHECK:              "type": "default",
// CHECK:              "value": null
// CHECK:            }
// CHECK:          ]
// CHECK:        },
// CHECK:        {
// CHECK:          "name": "parse_one",
// CHECK:          "parser_ops": [
// CHECK:            {
// CHECK:              "op": "extract",
// CHECK:              "parameters": [
// CHECK:                {
// CHECK:                  "type": "regular",
// CHECK:                  "value": "e_0"
// CHECK:                }
// CHECK:              ]
// CHECK:            },
// CHECK:            {
// CHECK:              "op": "assign_header",
// CHECK:              "parameters": [
// CHECK:                {
// CHECK:                  "type": "header",
// CHECK:                  "value": "prs1_one"
// CHECK:                },
// CHECK:                {
// CHECK:                  "type": "header",
// CHECK:                  "value": "prs_e_0"
// CHECK:                }
// CHECK:              ]
// CHECK:            }
// CHECK:          ],
// CHECK:          "transition_key": [],
// CHECK:          "transitions": [
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "parse_two",
// CHECK:              "type": "default",
// CHECK:              "value": null
// CHECK:            }
// CHECK:          ]
// CHECK:        },
// CHECK:        {
// CHECK:          "name": "parse_two",
// CHECK:          "parser_ops": [
// CHECK:            {
// CHECK:              "op": "extract",
// CHECK:              "parameters": [
// CHECK:                {
// CHECK:                  "type": "regular",
// CHECK:                  "value": "e_0"
// CHECK:                }
// CHECK:              ]
// CHECK:            }
// CHECK:          ],
// CHECK:          "transition_key": [],
// CHECK:          "transitions": [
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "parse_bottom",
// CHECK:              "type": "default",
// CHECK:              "value": null
// CHECK:            }
// CHECK:          ]
// CHECK:        },
// CHECK:        {
// CHECK:          "name": "parse_bottom",
// CHECK:          "parser_ops": [],
// CHECK:          "transition_key": [],
// CHECK:          "transitions": [
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": "accept",
// CHECK:              "type": "default",
// CHECK:              "value": null
// CHECK:            }
// CHECK:          ]
// CHECK:        },
// CHECK:        {
// CHECK:          "name": "accept",
// CHECK:          "parser_ops": [],
// CHECK:          "transition_key": [],
// CHECK:          "transitions": [
// CHECK:            {
// CHECK:              "mask": null,
// CHECK:              "next_state": null,
// CHECK:              "type": "default",
// CHECK:              "value": null
// CHECK:            }
// CHECK:          ]
// CHECK:        }
// CHECK:      ]
// CHECK:    }
// CHECK:  ]
// CHECK:}

// -----

!b8i = !p4hir.bit<8>
module {
  bmv2ir.parser @prs_only_bit init_state @prs_only_bit::@start {
    %0 = bmv2ir.header_instance @prs_only_bit2 : !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1>
    %1 = bmv2ir.header_instance @prs_only_bit1 : !bmv2ir.header<"bit_only", [bit:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"bit_only", [bit:!p4hir.bit<8>], max_length = 1>
    %2 = bmv2ir.header_instance @prs_only_bit_top_0 : !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1> -> !bmv2ir.header<"header_top", [skip:!p4hir.bit<8>], max_length = 1>
    bmv2ir.state @start
     transition_key {
    }
     transitions {
      bmv2ir.transition type  default next_state @prs_only_bit::@accept
    }
     parser_ops {
      bmv2ir.extract  regular @prs_only_bit_top_0
      %3 = bmv2ir.field @prs_only_bit_top_0["skip"] -> !b8i
      %4 = bmv2ir.field @prs_only_bit1["bit"] -> !b8i
      bmv2ir.assign %3 : !b8i to %4 : !b8i
      %5 = bmv2ir.field @prs_only_bit2["skip"] -> !b8i
      bmv2ir.assign %4 : !b8i to %5 : !b8i
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

// CHECK: {
// CHECK:   "header_types": [
// CHECK:     {
// CHECK:       "fields": [
// CHECK:         [
// CHECK:           "skip",
// CHECK:           8,
// CHECK:           false
// CHECK:         ]
// CHECK:       ],
// CHECK:       "id": 0,
// CHECK:       "name": "header_top"
// CHECK:     },
// CHECK:     {
// CHECK:       "fields": [
// CHECK:         [
// CHECK:           "bit",
// CHECK:           8,
// CHECK:           false
// CHECK:         ]
// CHECK:       ],
// CHECK:       "id": 1,
// CHECK:       "name": "bit_only"
// CHECK:     }
// CHECK:   ],
// CHECK:   "headers": [
// CHECK:     {
// CHECK:       "header_type": "header_top",
// CHECK:       "id": 0,
// CHECK:       "metadata": false,
// CHECK:       "name": "prs_only_bit2"
// CHECK:     },
// CHECK:     {
// CHECK:       "header_type": "bit_only",
// CHECK:       "id": 1,
// CHECK:       "metadata": false,
// CHECK:       "name": "prs_only_bit1"
// CHECK:     },
// CHECK:     {
// CHECK:       "header_type": "header_top",
// CHECK:       "id": 2,
// CHECK:       "metadata": false,
// CHECK:       "name": "prs_only_bit_top_0"
// CHECK:     }
// CHECK:   ],
// CHECK:   "parsers": [
// CHECK:     {
// CHECK:       "init_state": "start",
// CHECK:       "name": "prs_only_bit",
// CHECK:       "parse_states": [
// CHECK:         {
// CHECK:           "name": "start",
// CHECK:           "parser_ops": [
// CHECK:             {
// CHECK:               "op": "extract",
// CHECK:               "parameters": [
// CHECK:                 {
// CHECK:                   "type": "regular",
// CHECK:                   "value": "e_0"
// CHECK:                 }
// CHECK:               ]
// CHECK:             },
// CHECK:             {
// CHECK:               "op": "assign",
// CHECK:               "parameters": [
// CHECK:                 {
// CHECK:                   "type": "field",
// CHECK:                   "value": [
// CHECK:                     "prs_only_bit1",
// CHECK:                     "bit"
// CHECK:                   ]
// CHECK:                 },
// CHECK:                 {
// CHECK:                   "type": "field",
// CHECK:                   "value": [
// CHECK:                     "prs_only_bit_top_0",
// CHECK:                     "skip"
// CHECK:                   ]
// CHECK:                 }
// CHECK:               ]
// CHECK:             },
// CHECK:             {
// CHECK:               "op": "assign",
// CHECK:               "parameters": [
// CHECK:                 {
// CHECK:                   "type": "field",
// CHECK:                   "value": [
// CHECK:                     "prs_only_bit2",
// CHECK:                     "skip"
// CHECK:                   ]
// CHECK:                 },
// CHECK:                 {
// CHECK:                   "type": "field",
// CHECK:                   "value": [
// CHECK:                     "prs_only_bit1",
// CHECK:                     "bit"
// CHECK:                   ]
// CHECK:                 }
// CHECK:               ]
// CHECK:             }
// CHECK:           ],
// CHECK:           "transition_key": [],
// CHECK:           "transitions": [
// CHECK:             {
// CHECK:               "mask": null,
// CHECK:               "next_state": "accept",
// CHECK:               "type": "default",
// CHECK:               "value": null
// CHECK:             }
// CHECK:           ]
// CHECK:         },
// CHECK:         {
// CHECK:           "name": "accept",
// CHECK:           "parser_ops": [],
// CHECK:           "transition_key": [],
// CHECK:           "transitions": [
// CHECK:             {
// CHECK:               "mask": null,
// CHECK:               "next_state": null,
// CHECK:               "type": "default",
// CHECK:               "value": null
// CHECK:             }
// CHECK:           ]
// CHECK:         }
// CHECK:       ]
// CHECK:     }
// CHECK:   ]
// CHECK: }
