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

`define SAFE_CLOG2(x) ( (((x)==1) || ((x)==0)) ? 1 : $clog2(x) )

module ternip_pipelined_mem #(
    parameter int DATA_WIDTH      = 8,
    parameter int NUM_ENTRIES     = 256,
    parameter bit UNCOUPLED_READY = 0
) (
    input  logic                                clk_i,
    input  logic                                rst_ni,

    output logic                                request_ready_o,
    input  logic                                request_valid_i,
    input  logic                                request_write_not_read_i,
    input  logic [`SAFE_CLOG2(NUM_ENTRIES)-1:0] request_addr_i,
    input  logic [DATA_WIDTH-1:0]               request_w_data_i,

    input  logic                                read_ready_i,
    output logic                                read_valid_o,
    output logic [`SAFE_CLOG2(NUM_ENTRIES)-1:0] read_addr_o,
    output logic [DATA_WIDTH-1:0]               read_data_o
);

localparam int ADDR_WIDTH = `SAFE_CLOG2(NUM_ENTRIES);

logic [DATA_WIDTH-1:0] MEM [NUM_ENTRIES];

logic read_valid_d;
logic read_valid_q1;
logic read_valid_q2;

logic write_valid_d;
logic write_valid_q1;
logic write_valid_q2;

logic [ADDR_WIDTH-1:0] request_addr_q1;
logic [ADDR_WIDTH-1:0] request_addr_q2;
logic [DATA_WIDTH-1:0] request_w_data_q1;
logic [DATA_WIDTH-1:0] read_data_q2;

logic                                         buffer_in_ready;
logic                                         buffer_in_valid;
logic [$bits({read_addr_o, read_data_o})-1:0] buffer_in_data;

logic                                         buffer_out_ready;
logic                                         buffer_out_valid;
logic [$bits({read_addr_o, read_data_o})-1:0] buffer_out_data;

assign read_valid_d = (request_valid_i && !request_write_not_read_i);
assign write_valid_d = (request_valid_i && request_write_not_read_i);

logic stall1, stall2, stall3;

if (UNCOUPLED_READY) begin
    assign stall2 = !buffer_in_ready && read_valid_q2;
end else begin
    assign stall3 = !read_ready_i && read_valid_o;
    assign stall2 = stall3 && (read_valid_q2 || write_valid_q2);
end

assign stall1 = stall2 && (read_valid_q1 || write_valid_q1);
assign request_ready_o = !stall1;

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        read_valid_q1 <= 0;
        write_valid_q1 <= 0;
    end else if (!stall1) begin
        read_valid_q1 <= read_valid_d;
        write_valid_q1 <= write_valid_d;
    end
end
always_ff @(posedge clk_i) begin
    if (!stall1) begin
        request_addr_q1 <= request_addr_i;
        request_w_data_q1 <= request_w_data_i;
    end
    `ifndef SYNTHESIS
    if (!rst_ni) begin
        request_addr_q1 <= 'x;
        request_w_data_q1 <= 'x;
    end
    `endif
end

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        read_valid_q2 <= 0;
        write_valid_q2 <= 0;
    end else if (!stall2) begin
        read_valid_q2   <= read_valid_q1;
        write_valid_q2  <= write_valid_q1;
    end
end
always_ff @(posedge clk_i) begin
    if (!stall2) begin
        request_addr_q2 <= request_addr_q1;
    end
    `ifndef SYNTHESIS
    if (!rst_ni) begin
        request_addr_q2 <= 'x;
    end
    `endif
end

always_ff @(posedge clk_i) begin
    if (!stall2) begin
        if (write_valid_q1) begin
            MEM[request_addr_q1] <= request_w_data_q1;
        end else if (read_valid_q1) begin
            read_data_q2 <= MEM[request_addr_q1];
        end
    end
end

if (UNCOUPLED_READY) begin : uncoupled_ready
    assign buffer_in_valid = read_valid_q2;
    assign buffer_in_data = {request_addr_q2, read_data_q2};

    assign buffer_out_ready = read_ready_i;
    assign read_valid_o = buffer_out_valid;
    assign {read_addr_o, read_data_o} = buffer_out_data;

    ternip_pipelined_interconnect #(
        .DataWidth($bits(buffer_in_data)),
        .NumStages(1)
    ) buffer (
        .clk_i,
        .rst_ni,

        .in_ready_o(buffer_in_ready),
        .in_valid_i(buffer_in_valid),
        .in_data_i(buffer_in_data),

        .out_ready_i(buffer_out_ready),
        .out_valid_o(buffer_out_valid),
        .out_data_o(buffer_out_data)
    );
end else begin : coupled_ready
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            read_valid_o <= 1'b0;
        end else if (!stall3) begin
            read_valid_o <= read_valid_q2;
        end
    end
    always_ff @(posedge clk_i) begin
        if (!stall3) begin
            read_addr_o  <= read_valid_q2 ? request_addr_q2 : 'x;
            read_data_o  <= read_valid_q2 ? read_data_q2    : 'x;
        end
        `ifndef SYNTHESIS
        if (!rst_ni) begin
            read_addr_o <= 'x;
            read_data_o <= 'x;
        end
        `endif
    end
end

endmodule

`undef SAFE_CLOG2
