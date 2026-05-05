// Copyright (c) 2026 Ethan Sifferman
//
// SPDX-License-Identifier: BSD-3-Clause

// ypcb_ternip_core_wrapper
//
// Thin synthesis wrapper for the YPCB bring-up lane. The wrapper keeps the real
// ternip_core instruction and DDR stream interfaces externally visible, instead
// of tying them idle, so synthesis cannot optimize away the datapath.

module ypcb_ternip_core_wrapper (
    input  logic                                                clk_i,
    input  logic                                                rst_ni,

    output logic                                                instruction_ready_o,
    input  logic                                                instruction_valid_i,
    input  logic [ternip_pkg::InstructionWidth-1:0]             instruction_i,

    input  logic                                                loadstore_ddr_stream_ready_i,
    output logic                                                loadstore_ddr_stream_valid_o,
    output logic [ternip_pkg::DdrAddressWidth-1:0]              loadstore_ddr_stream_address_o,
    output logic                                                loadstore_ddr_stream_write_not_read_o,
    output logic [31:0]                                         loadstore_ddr_stream_length_o,

    output logic                                                loadstore_ddr_r_ready_o,
    input  logic                                                loadstore_ddr_r_valid_i,
    input  logic [ternip_pkg::FixedPointPrecision
                  * ternip_pkg::VectorParallelism - 1:0]        loadstore_ddr_r_data_i,

    input  logic                                                loadstore_ddr_w_ready_i,
    output logic                                                loadstore_ddr_w_valid_o,
    output logic [ternip_pkg::FixedPointPrecision
                  * ternip_pkg::VectorParallelism - 1:0]        loadstore_ddr_w_data_o,

    output logic [63:0]                                         loadstore_ddr_debug_o,

    input  logic                                                tmatmul_ddr_stream_ready_i,
    output logic                                                tmatmul_ddr_stream_valid_o,
    output logic [ternip_pkg::DdrAddressWidth-1:0]              tmatmul_ddr_stream_address_o,
    output logic [31:0]                                         tmatmul_ddr_stream_length_o,

    output logic                                                tmatmul_ddr_r_ready_o,
    input  logic                                                tmatmul_ddr_r_valid_i,
    input  logic [2 * ternip_pkg::TmatmulParallelism - 1:0]     tmatmul_ddr_r_data_i,

    output logic                                                stall_active_o,
    input  logic                                                stall_clear_i,

    output logic [7:0]                                          status_led_o
);

ternip_pkg::instruction_t instruction;
ternip_pkg::vector_chunk_t loadstore_ddr_r_data;
ternip_pkg::vector_chunk_t loadstore_ddr_w_data;
ternip_pkg::tmatmul_stream_data_t tmatmul_ddr_r_data;

assign instruction = instruction_i;
assign loadstore_ddr_r_data = loadstore_ddr_r_data_i;
assign loadstore_ddr_w_data_o = loadstore_ddr_w_data;
assign tmatmul_ddr_r_data = tmatmul_ddr_r_data_i;

assign status_led_o = {
    rst_ni,
    instruction_ready_o,
    instruction_valid_i,
    loadstore_ddr_stream_valid_o,
    loadstore_ddr_w_valid_o,
    tmatmul_ddr_stream_valid_o,
    tmatmul_ddr_r_ready_o,
    stall_active_o
};

ternip_core core (
    .clk_i,
    .rst_ni,

    .instruction_ready_o,
    .instruction_valid_i,
    .instruction_i(instruction),

    .loadstore_ddr_stream_ready_i,
    .loadstore_ddr_stream_valid_o,
    .loadstore_ddr_stream_address_o,
    .loadstore_ddr_stream_write_not_read_o,
    .loadstore_ddr_stream_length_o,

    .loadstore_ddr_r_ready_o,
    .loadstore_ddr_r_valid_i,
    .loadstore_ddr_r_data_i(loadstore_ddr_r_data),

    .loadstore_ddr_w_ready_i,
    .loadstore_ddr_w_valid_o,
    .loadstore_ddr_w_data_o(loadstore_ddr_w_data),

    .loadstore_ddr_debug_o,

    .tmatmul_ddr_stream_ready_i,
    .tmatmul_ddr_stream_valid_o,
    .tmatmul_ddr_stream_address_o,
    .tmatmul_ddr_stream_length_o,

    .tmatmul_ddr_r_ready_o,
    .tmatmul_ddr_r_valid_i,
    .tmatmul_ddr_r_data_i(tmatmul_ddr_r_data),

    .stall_active_o,
    .stall_clear_i
);

endmodule
