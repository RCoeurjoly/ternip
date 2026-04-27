// Copyright (c) 2026 Ethan Sifferman
//
// Redistribution and use in source and binary forms, with or without modification, are permitted
// provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

module ternip_core import ternip_pkg::*; (
    input  logic                 clk_i,
    input  logic                 rst_ni,

    output logic                 instruction_ready_o,
    input  logic                 instruction_valid_i,
    input  instruction_t         instruction_i,

    input  logic                 vector_load_store_ddr_stream_ready_i,
    output logic                 vector_load_store_ddr_stream_valid_o,
    output ddr_address_t         vector_load_store_ddr_stream_address_o,
    output logic                 vector_load_store_ddr_stream_write_not_read_o,
    output logic [31:0]          vector_load_store_ddr_stream_length_o,

    output logic                 vector_load_store_ddr_r_ready_o,
    input  logic                 vector_load_store_ddr_r_valid_i,
    input  vector_chunk_t        vector_load_store_ddr_r_data_i,

    input  logic                 vector_load_store_ddr_w_ready_i,
    output logic                 vector_load_store_ddr_w_valid_o,
    output vector_chunk_t        vector_load_store_ddr_w_data_o,

    output logic [63:0]          vector_load_store_ddr_debug_o,

    input  logic                 tmatmul_ddr_stream_ready_i,
    output logic                 tmatmul_ddr_stream_valid_o,
    output ddr_address_t         tmatmul_ddr_stream_address_o,
    output logic [31:0]          tmatmul_ddr_stream_length_o,

    output logic                 tmatmul_ddr_r_ready_o,
    input  logic                 tmatmul_ddr_r_valid_i,
    input  tmatmul_stream_data_t tmatmul_ddr_r_data_i,

    output logic                 stall_active_o,
    input  logic                 stall_clear_i
);

logic          vector_request_ready;
logic          vector_request_valid;
logic          vector_request_write_not_read;
v_addr_t       vector_request_vector_select;
DI_t           vector_request_vector_addr;
vector_chunk_t vector_request_w_data;

logic          vector_read_ready;
logic          vector_read_valid;
DI_t           vector_read_addr;
vector_chunk_t vector_read_data;

ternip_vector_registers ternip_vector_registers (
    .clk_i,
    .rst_ni,

    .request_ready_o(vector_request_ready),
    .request_valid_i(vector_request_valid),
    .request_write_not_read_i(vector_request_write_not_read),
    .request_vector_select_i(vector_request_vector_select),
    .request_vector_addr_i(vector_request_vector_addr),
    .request_w_data_i(vector_request_w_data),

    .read_ready_i(vector_read_ready),
    .read_valid_o(vector_read_valid),
    .read_vector_select_o(),
    .read_addr_o(vector_read_addr),
    .read_data_o(vector_read_data)
);

logic                  vector_load_store_in_ready;
logic                  vector_load_store_in_valid;
load_store_operation_t vector_load_store_in_vector_operation;
ddr_address_t          vector_load_store_in_vector_memory_address;
v_addr_t               vector_load_store_in_vector_select;

logic                  vector_load_store_vector_request_valid;
logic                  vector_load_store_vector_request_write_not_read;
v_addr_t               vector_load_store_vector_request_vector_select;
DI_t                   vector_load_store_vector_request_vector_addr;
vector_chunk_t         vector_load_store_vector_request_w_data;

logic                  vector_load_store_vector_read_ready;

ternip_vector_load_store ternip_vector_load_store (
    .clk_i,
    .rst_ni,

    .in_ready_o(vector_load_store_in_ready),
    .in_valid_i(vector_load_store_in_valid),
    .in_vector_operation_i(vector_load_store_in_vector_operation),
    .in_vector_memory_address_i(vector_load_store_in_vector_memory_address),
    .in_vector_select_i(vector_load_store_in_vector_select),

    .vector_request_ready_i(vector_request_ready),
    .vector_request_valid_o(vector_load_store_vector_request_valid),
    .vector_request_write_not_read_o(vector_load_store_vector_request_write_not_read),
    .vector_request_vector_select_o(vector_load_store_vector_request_vector_select),
    .vector_request_vector_addr_o(vector_load_store_vector_request_vector_addr),
    .vector_request_w_data_o(vector_load_store_vector_request_w_data),

    .vector_read_ready_o(vector_load_store_vector_read_ready),
    .vector_read_valid_i(vector_read_valid),
    .vector_read_addr_i(vector_read_addr),
    .vector_read_data_i(vector_read_data),

    .ddr_stream_ready_i(vector_load_store_ddr_stream_ready_i),
    .ddr_stream_valid_o(vector_load_store_ddr_stream_valid_o),
    .ddr_stream_address_o(vector_load_store_ddr_stream_address_o),
    .ddr_stream_write_not_read_o(vector_load_store_ddr_stream_write_not_read_o),
    .ddr_stream_length_o(vector_load_store_ddr_stream_length_o),

    .ddr_r_ready_o(vector_load_store_ddr_r_ready_o),
    .ddr_r_valid_i(vector_load_store_ddr_r_valid_i),
    .ddr_r_data_i(vector_load_store_ddr_r_data_i),

    .ddr_w_ready_i(vector_load_store_ddr_w_ready_i),
    .ddr_w_valid_o(vector_load_store_ddr_w_valid_o),
    .ddr_w_data_o(vector_load_store_ddr_w_data_o),

    .debug_o(vector_load_store_ddr_debug_o)
);

logic          rowwise_operation_in_ready;
logic          rowwise_operation_in_valid;
operation_t    rowwise_operation_in_operation;

v_addr_t       rowwise_operation_in_vector1_r_select;
v_addr_t       rowwise_operation_in_vector2_r_select;
v_addr_t       rowwise_operation_in_vector3_r_select;

logic          rowwise_operation_vector_request_valid;
logic          rowwise_operation_vector_request_write_not_read;
v_addr_t       rowwise_operation_vector_request_vector_select;
DI_t           rowwise_operation_vector_request_vector_addr;
vector_chunk_t rowwise_operation_vector_request_w_data;

logic         rowwise_operation_vector_read_ready;

ternip_rowwise_operation ternip_rowwise_operation (
    .clk_i,
    .rst_ni,

    .in_ready_o(rowwise_operation_in_ready),
    .in_valid_i(rowwise_operation_in_valid),
    .in_operation_i(rowwise_operation_in_operation),

    .in_vector1_r_select_i(rowwise_operation_in_vector1_r_select),
    .in_vector2_r_select_i(rowwise_operation_in_vector2_r_select),
    .in_vector3_r_select_i(rowwise_operation_in_vector3_r_select),

    .vector_request_ready_i(vector_request_ready),
    .vector_request_valid_o(rowwise_operation_vector_request_valid),
    .vector_request_write_not_read_o(rowwise_operation_vector_request_write_not_read),
    .vector_request_vector_select_o(rowwise_operation_vector_request_vector_select),
    .vector_request_vector_addr_o(rowwise_operation_vector_request_vector_addr),
    .vector_request_w_data_o(rowwise_operation_vector_request_w_data),

    .vector_read_ready_o(rowwise_operation_vector_read_ready),
    .vector_read_valid_i(vector_read_valid),
    .vector_read_data_i(vector_read_data)
);

logic         rms_in_ready;
logic         rms_in_valid;
rms_op_t      rms_in_op;
v_addr_t      rms_in_vector1_select;
v_addr_t      rms_in_vector2_select;
immediate_t   rms_in_length;

logic          rms_vector_request_valid;
logic          rms_vector_request_write_not_read;
v_addr_t       rms_vector_request_vector_select;
DI_t           rms_vector_request_vector_addr;
vector_chunk_t rms_vector_request_w_data;

logic         rms_vector_read_ready;

ternip_rms ternip_rms (
    .clk_i,
    .rst_ni,

    .in_ready_o(rms_in_ready),
    .in_valid_i(rms_in_valid),
    .in_rms_op_i(rms_in_op),
    .in_vector1_select_i(rms_in_vector1_select),
    .in_vector2_select_i(rms_in_vector2_select),
    .in_rms_length_i(rms_in_length),

    .vector_request_ready_i(vector_request_ready),
    .vector_request_valid_o(rms_vector_request_valid),
    .vector_request_write_not_read_o(rms_vector_request_write_not_read),
    .vector_request_vector_select_o(rms_vector_request_vector_select),
    .vector_request_vector_addr_o(rms_vector_request_vector_addr),
    .vector_request_w_data_o(rms_vector_request_w_data),

    .vector_read_ready_o(rms_vector_read_ready),
    .vector_read_valid_i(vector_read_valid),
    .vector_read_addr_i(vector_read_addr),
    .vector_read_data_i(vector_read_data),

    .accumulator_out_valid_o(),
    .accumulator_out_result_o(),
    .rms_value_reciprocal_o(),
    .rms_value_reciprocal_valid_o()
);

logic          tmatmul_in_ready;
logic          tmatmul_in_valid;
v_addr_t       tmatmul_in_vector_select;
ddr_address_t  tmatmul_in_go_matrix_address;

tmatmul_op_t   tmatmul_in_operation;


logic          tmatmul_vector_request_valid;
logic          tmatmul_vector_request_write_not_read;
v_addr_t       tmatmul_vector_request_vector_select;
DI_t           tmatmul_vector_request_vector_addr;
vector_chunk_t tmatmul_vector_request_w_data;

logic          tmatmul_vector_read_ready;

ternip_tmatmul ternip_tmatmul (
    .clk_i,
    .rst_ni,

    .in_ready_o(tmatmul_in_ready),
    .in_valid_i(tmatmul_in_valid),
    .in_operation_i(tmatmul_in_operation),
    .in_go_matrix_address_i(tmatmul_in_go_matrix_address),
    .in_vector_select_i(tmatmul_in_vector_select),

    .vector_request_ready_i(vector_request_ready),
    .vector_request_valid_o(tmatmul_vector_request_valid),
    .vector_request_write_not_read_o(tmatmul_vector_request_write_not_read),
    .vector_request_vector_select_o(tmatmul_vector_request_vector_select),
    .vector_request_vector_addr_o(tmatmul_vector_request_vector_addr),
    .vector_request_w_data_o(tmatmul_vector_request_w_data),

    .vector_read_ready_o(tmatmul_vector_read_ready),
    .vector_read_valid_i(vector_read_valid),
    .vector_read_addr_i(vector_read_addr),
    .vector_read_data_i(vector_read_data),

    .ddr_stream_ready_i(tmatmul_ddr_stream_ready_i),
    .ddr_stream_valid_o(tmatmul_ddr_stream_valid_o),
    .ddr_stream_address_o(tmatmul_ddr_stream_address_o),
    .ddr_stream_length_o(tmatmul_ddr_stream_length_o),

    .ddr_r_ready_o(tmatmul_ddr_r_ready_o),
    .ddr_r_valid_i(tmatmul_ddr_r_valid_i),
    .ddr_r_data_i(tmatmul_ddr_r_data_i)
);

logic received_stall_command;
logic stall_active_q;

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        stall_active_q <= 0;
    end else begin
        if (received_stall_command) begin
            stall_active_q <= 1;
        end else if (stall_clear_i) begin
            stall_active_q <= 0;
        end
    end
end

assign stall_active_o = stall_active_q;

assign instruction_ready_o = (vector_load_store_in_ready
                              & rms_in_ready
                              & rowwise_operation_in_ready
                              & tmatmul_in_ready
                              & !stall_active_q);

always_comb begin
    vector_request_valid = 0;
    vector_request_write_not_read = 'x;
    vector_request_vector_select = 'x;
    vector_request_vector_addr = 'x;
    vector_request_w_data = 'x;

    unique case (1)
        vector_load_store_vector_request_valid: begin
            vector_request_valid = 1;
            vector_request_write_not_read = vector_load_store_vector_request_write_not_read;
            vector_request_vector_select = vector_load_store_vector_request_vector_select;
            vector_request_vector_addr = vector_load_store_vector_request_vector_addr;
            vector_request_w_data = vector_load_store_vector_request_w_data;
        end
        rms_vector_request_valid: begin
            vector_request_valid = 1;
            vector_request_write_not_read = rms_vector_request_write_not_read;
            vector_request_vector_select = rms_vector_request_vector_select;
            vector_request_vector_addr = rms_vector_request_vector_addr;
            vector_request_w_data = rms_vector_request_w_data;
        end
        rowwise_operation_vector_request_valid: begin
            vector_request_valid = 1;
            vector_request_write_not_read = rowwise_operation_vector_request_write_not_read;
            vector_request_vector_select = rowwise_operation_vector_request_vector_select;
            vector_request_vector_addr = rowwise_operation_vector_request_vector_addr;
            vector_request_w_data = rowwise_operation_vector_request_w_data;
        end
        tmatmul_vector_request_valid: begin
            vector_request_valid = 1;
            vector_request_write_not_read = tmatmul_vector_request_write_not_read;
            vector_request_vector_select = tmatmul_vector_request_vector_select;
            vector_request_vector_addr = tmatmul_vector_request_vector_addr;
            vector_request_w_data = tmatmul_vector_request_w_data;
        end
        default: ;
    endcase
end

assign vector_read_ready = (vector_load_store_vector_read_ready
                            | rms_vector_read_ready
                            | rowwise_operation_vector_read_ready
                            | tmatmul_vector_read_ready);

`ifndef SYNTHESIS
always @(posedge clk_i) if (rst_ni) begin
    assert final (1 >= $countones({
        vector_load_store_vector_request_valid,
        rms_vector_request_valid,
        rowwise_operation_vector_request_valid,
        tmatmul_in_valid
    })) else $fatal(0, "Conflict in vector_request_valid");
    assert final (1 >= $countones({
        vector_load_store_vector_read_ready,
        rms_vector_read_ready,
        rowwise_operation_vector_read_ready,
        tmatmul_vector_read_ready
    })) else $fatal(0, "Conflict in vector_read_ready");
end
`endif

always_comb begin
    vector_load_store_in_valid = '0;
    vector_load_store_in_vector_operation = NO_LS_OP;
    vector_load_store_in_vector_memory_address = 'x;
    vector_load_store_in_vector_select = 'x;

    rowwise_operation_in_valid = 0;
    rowwise_operation_in_operation = NOP;
    rowwise_operation_in_vector1_r_select = 'x;
    rowwise_operation_in_vector2_r_select = 'x;
    rowwise_operation_in_vector3_r_select = 'x;

    rms_in_valid = 0;
    rms_in_op = NO_RMS_OP;
    rms_in_vector1_select = 'x;
    rms_in_vector2_select = 'x;
    rms_in_length = 'x;

    tmatmul_in_valid = '0;
    tmatmul_in_operation = NO_TMATMUL_OP;
    tmatmul_in_go_matrix_address = 'x;
    tmatmul_in_vector_select = 'x;

    received_stall_command = 0;

    if (instruction_valid_i && instruction_ready_o) unique case (instruction_i.fu)
        LOAD_STORE: begin
            vector_load_store_in_valid = 1;
            vector_load_store_in_vector_operation = instruction_i.load_store_operation;
            vector_load_store_in_vector_memory_address = instruction_i.ddr_address;
            vector_load_store_in_vector_select = instruction_i.v_a;
        end
        ROWWISE_OPERATION: begin
            rowwise_operation_in_valid = 1;
            rowwise_operation_in_operation = instruction_i.operation;
            rowwise_operation_in_vector1_r_select = instruction_i.v_a;
            rowwise_operation_in_vector2_r_select = instruction_i.v_b;
            rowwise_operation_in_vector3_r_select = instruction_i.v_y;
        end
        TMATMUL: begin
            tmatmul_in_valid = 1;
            tmatmul_in_operation = instruction_i.tmatmul_op;
            tmatmul_in_go_matrix_address = instruction_i.ddr_address;
            tmatmul_in_vector_select = instruction_i.v_a;
        end
        RMS: begin
            rms_in_valid = 1;
            rms_in_op = instruction_i.rms_op;
            rms_in_vector1_select = instruction_i.v_a;
            rms_in_vector2_select = instruction_i.v_y;
            rms_in_length = instruction_i.ddr_address;
        end
        STALL: begin
            received_stall_command = 1;
        end
        default: ;
    endcase
end

endmodule
