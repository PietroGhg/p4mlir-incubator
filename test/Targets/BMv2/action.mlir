// RUN: p4mlir-to-json --p4hir-to-bmv2-json %s --split-input-file | FileCheck %s

!b48i = !p4hir.bit<48>
module {
  bmv2ir.header_instance @egress0_ethernet : !bmv2ir.header<"ethernet_t", [dstAddr:!p4hir.bit<48>, srcAddr:!p4hir.bit<48>, etherType:!p4hir.bit<16>], max_length = 14>
  p4hir.func action @rewrite_src_dst_mac(%arg0: !b48i {p4hir.annotations = {name = "smac"}, p4hir.dir = #p4hir<dir undir>, p4hir.param_name = "smac"}, %arg1: !b48i {p4hir.annotations = {name = "dmac"}, p4hir.dir = #p4hir<dir undir>, p4hir.param_name = "dmac"}) annotations {name = "egress.rewrite_src_dst_mac"} {
    %0 = bmv2ir.field @egress0_ethernet["srcAddr"] -> !b48i
    bmv2ir.assign %arg0 : !b48i to %0 : !b48i
    %1 = bmv2ir.field @egress0_ethernet["dstAddr"] -> !b48i
    bmv2ir.assign %arg1 : !b48i to %1 : !b48i
    p4hir.return
  }
}
// CHECK: "actions": [
// CHECK:     {
// CHECK:       "name": "rewrite_src_dst_mac",
// CHECK:       "primitives": [
// CHECK:         {
// CHECK:           "op": "assign",
// CHECK:           "parameters": [
// CHECK:             {
// CHECK:               "type": "field",
// CHECK:               "value": [
// CHECK:                 "egress0_ethernet",
// CHECK:                 "srcAddr"
// CHECK:               ]
// CHECK:             },
// CHECK:             {
// CHECK:               "type": "runtime_data",
// CHECK:               "value": 0
// CHECK:             }
// CHECK:           ]
// CHECK:         },
// CHECK:         {
// CHECK:           "op": "assign",
// CHECK:           "parameters": [
// CHECK:             {
// CHECK:               "type": "field",
// CHECK:               "value": [
// CHECK:                 "egress0_ethernet",
// CHECK:                 "dstAddr"
// CHECK:               ]
// CHECK:             },
// CHECK:             {
// CHECK:               "type": "runtime_data",
// CHECK:               "value": 1
// CHECK:             }
// CHECK:           ]
// CHECK:         }
// CHECK:       ],
// CHECK:       "runtime_data": [
// CHECK:         {
// CHECK:           "bitwidth": 48,
// CHECK:           "name": "smac"
// CHECK:         },
// CHECK:         {
// CHECK:           "bitwidth": 48,
// CHECK:           "name": "dmac"
// CHECK:         }
// CHECK:       ]
// CHECK:     }
// CHECK:   ]
