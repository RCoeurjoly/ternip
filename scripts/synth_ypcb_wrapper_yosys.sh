#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

basejump_stl="${BASEJUMP_STL:?set BASEJUMP_STL to a BaseJump STL checkout}"
yosys="${YOSYS:-yosys}"
yosys_slang_so="${YOSYS_SLANG_SO:?set YOSYS_SLANG_SO to slang.so}"
out_json="${1:?usage: synth_ypcb_wrapper_yosys.sh <out-json> <out-stat-json>}"
out_stat_json="${2:?usage: synth_ypcb_wrapper_yosys.sh <out-json> <out-stat-json>}"

cd "${repo_root}"

cat > run-ypcb-wrapper-yosys.ys <<EOF
plugin -i ${yosys_slang_so}
read_slang --threads 1 --no-proc --ignore-assertions --top ypcb_ternip_core_wrapper \\
  -I. \\
  -Irtl \\
  -Iconfig \\
  -I${basejump_stl}/bsg_misc \\
  -I${basejump_stl}/bsg_dataflow \\
  -I${basejump_stl}/bsg_mem \\
  -DTERNIP_REDUCED_YPCB_CONFIG \\
  ${basejump_stl}/bsg_misc/bsg_adder_cin.sv \\
  ${basejump_stl}/bsg_misc/bsg_arb_round_robin.sv \\
  ${basejump_stl}/bsg_misc/bsg_circular_ptr.sv \\
  ${basejump_stl}/bsg_misc/bsg_counter_clear_up.sv \\
  ${basejump_stl}/bsg_misc/bsg_crossbar_o_by_i.sv \\
  ${basejump_stl}/bsg_misc/bsg_dff_en.sv \\
  ${basejump_stl}/bsg_misc/bsg_dff_reset.sv \\
  ${basejump_stl}/bsg_misc/bsg_encode_one_hot.sv \\
  ${basejump_stl}/bsg_misc/bsg_idiv_iterative_controller.sv \\
  ${basejump_stl}/bsg_misc/bsg_idiv_iterative.sv \\
  ${basejump_stl}/bsg_misc/bsg_imul_iterative.sv \\
  ${basejump_stl}/bsg_misc/bsg_mux_one_hot.sv \\
  ${basejump_stl}/bsg_misc/bsg_nor2.sv \\
  ${basejump_stl}/bsg_misc/bsg_round_robin_arb.sv \\
  ${basejump_stl}/bsg_mem/bsg_mem_1r1w_synth.sv \\
  ${basejump_stl}/bsg_mem/bsg_mem_1r1w.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_fifo_1r1w_small_hardened.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_fifo_1r1w_small_unhardened.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_fifo_1r1w_small.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_fifo_tracker.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_one_fifo.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_parallel_in_serial_out.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_round_robin_1_to_n.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_round_robin_n_to_1.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_serial_in_parallel_out_full.sv \\
  ${basejump_stl}/bsg_dataflow/bsg_two_fifo.sv \\
  rtl/ternip_pkg.sv \\
  rtl/ternip_vector_registers.sv \\
  rtl/common/ternip_gearbox_fifo.sv \\
  rtl/common/ternip_multioperand_accumulator.sv \\
  rtl/common/ternip_pipelined_interconnect.sv \\
  rtl/common/ternip_pipelined_mem.sv \\
  rtl/math/ternip_add.sv \\
  rtl/math/ternip_sub.sv \\
  rtl/math/ternip_mul.sv \\
  rtl/math/ternip_div.sv \\
  rtl/math/ternip_sqrt_int.sv \\
  rtl/math/ternip_sqrt.sv \\
  rtl/math/ternip_starmul.sv \\
  rtl/math/ternip_fixed_point_convert.sv \\
  rtl/math/ternip_round_robin_operation.sv \\
  rtl/math/ternip_csig.sv \\
  rtl/math/ternip_csig_parallelized.sv \\
  rtl/math/ternip_sig.sv \\
  rtl/math/ternip_sig_parallelized.sv \\
  rtl/math/ternip_silu.sv \\
  rtl/math/ternip_silu_parallelized.sv \\
  rtl/fus/ternip_loadstore.sv \\
  rtl/fus/ternip_rms.sv \\
  rtl/fus/ternip_rowwise_operation.sv \\
  rtl/fus/ternip_tmatmul.sv \\
  rtl/axi/s_axi_ternip_const_rd.v \\
  rtl/axi/s_axi_ternip_rst.v \\
  rtl/axi/s_axi_ternip_wait_for_interrupt.v \\
  rtl/axi/s_axi_ternip_write_byte.v \\
  rtl/ternip/ternip_core.sv \\
  rtl/ypcb/ypcb_ternip_core_wrapper.sv
hierarchy -top ypcb_ternip_core_wrapper -check
proc
flatten
synth_xilinx -family xc7 -top ypcb_ternip_core_wrapper -noiopad
tee -o ${out_stat_json} stat -json
write_json ${out_json}
EOF

"${yosys}" -s run-ypcb-wrapper-yosys.ys
