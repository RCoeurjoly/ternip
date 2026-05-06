module tb_gate2_tmatmul_parity;
  import ternip_pkg::*;

  localparam int TimeoutCyclesDefault = 200000;
  localparam int DdrReadsPerMatrix = (D * D) / TmatmulParallelism;

  string vector_file_path;
  string matrix_file_path;
  string output_file_path;
  int timeout_cycles;

  localparam vector_select_t VectorSelectUnderTest = 0;

  logic clk_i = 1'b0;
  logic rst_ni = 1'b0;

  ternip_pkg::fixed_point_t input_vector [0:D - 1];
  ternary_t matrix_data [0:(D * D) - 1];

  logic in_ready_o;
  logic in_valid_i = 1'b0;
  tmatmul_op_e in_operation_i = NO_TMATMUL_OP;
  vector_select_t in_vector_select_i = VectorSelectUnderTest;
  ddr_address_t in_go_matrix_address_i = '0;

  logic vector_request_ready_i;
  logic vector_request_valid_o;
  logic vector_request_write_not_read_o;
  vector_select_t vector_request_vector_select_o;
  vector_offset_t vector_request_vector_addr_o;
  vector_chunk_t vector_request_w_data_o;

  logic vector_read_ready_o;
  logic vector_read_valid_i;
  vector_offset_t vector_read_addr_i;
  vector_chunk_t vector_read_data_i;

  logic tmatmul_ddr_stream_ready_i = 1'b1;
  logic tmatmul_ddr_stream_valid_o;
  ddr_address_t tmatmul_ddr_stream_address_o;
  logic [31:0] tmatmul_ddr_stream_length_o;

  logic tmatmul_ddr_r_ready_o;
  logic tmatmul_ddr_r_valid_i = 1'b0;
  tmatmul_stream_data_t tmatmul_ddr_r_data_i;

  ternip_pkg::vector_chunk_t vector_registers[0:NumVectorRegisters - 1][0:NumChunksPerVector - 1];

  logic signed [FixedPointPrecision - 1:0] sw_output [0:D - 1];
  logic [31:0] ddr_cycle_index;

  ternip_tmatmul #(
      .D(D),
      .TmatmulParallelism(TmatmulParallelism),
      .FixedPointPrecision(FixedPointPrecision),
      .VectorParallelism(VectorParallelism),
      .NumVectorRegisters(NumVectorRegisters),
      .NumChunksPerVector(NumChunksPerVector),
      .DdrAddressWidth(DdrAddressWidth),
      .MatrixSizeInBytes(MatrixSizeInBytes)
  ) dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),

      .in_ready_o(in_ready_o),
      .in_valid_i(in_valid_i),
      .in_operation_i(in_operation_i),
      .in_vector_select_i(in_vector_select_i),
      .in_go_matrix_address_i(in_go_matrix_address_i),

      .vector_request_ready_i(vector_request_ready_i),
      .vector_request_valid_o(vector_request_valid_o),
      .vector_request_write_not_read_o(vector_request_write_not_read_o),
      .vector_request_vector_select_o(vector_request_vector_select_o),
      .vector_request_vector_addr_o(vector_request_vector_addr_o),
      .vector_request_w_data_o(vector_request_w_data_o),

      .vector_read_ready_o(vector_read_ready_o),
      .vector_read_valid_i(vector_read_valid_i),
      .vector_read_addr_i(vector_read_addr_i),
      .vector_read_data_i(vector_read_data_i),

      .ddr_stream_ready_i(tmatmul_ddr_stream_ready_i),
      .ddr_stream_valid_o(tmatmul_ddr_stream_valid_o),
      .ddr_stream_address_o(tmatmul_ddr_stream_address_o),
      .ddr_stream_length_o(tmatmul_ddr_stream_length_o),

      .ddr_r_ready_o(tmatmul_ddr_r_ready_o),
      .ddr_r_valid_i(tmatmul_ddr_r_valid_i),
      .ddr_r_data_i(tmatmul_ddr_r_data_i)
  );

  assign vector_request_ready_i = 1'b1;

  assign vector_read_valid_i = vector_request_valid_o && !vector_request_write_not_read_o;
  assign vector_read_addr_i = vector_request_vector_addr_o;

  always_comb begin
    if (vector_request_valid_o && !vector_request_write_not_read_o &&
        vector_request_vector_select_o < NumVectorRegisters &&
        vector_request_vector_addr_o < NumChunksPerVector) begin
      vector_read_data_i = vector_registers[vector_request_vector_select_o][vector_request_vector_addr_o];
    end else begin
      vector_read_data_i = '0;
    end

    tmatmul_ddr_r_data_i = '0;
    for (int ti = 0; ti < TmatmulParallelism; ti++) begin
      int unsigned read_index;
      read_index = ddr_cycle_index * TmatmulParallelism + ti;
      if (read_index < (D * D)) begin
        tmatmul_ddr_r_data_i[ti] = matrix_data[read_index];
      end
    end
  end

  // Simulate DDR reads directly from the matrix ROM while TMATMUL streams.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ddr_cycle_index <= '0;
      tmatmul_ddr_r_valid_i <= 1'b0;
    end else begin
      if (tmatmul_ddr_stream_valid_o && tmatmul_ddr_stream_ready_i) begin
        ddr_cycle_index <= '0;
        tmatmul_ddr_r_valid_i <= 1'b1;
      end

      if (tmatmul_ddr_r_ready_o && tmatmul_ddr_r_valid_i) begin
        if (ddr_cycle_index >= DdrReadsPerMatrix - 1) begin
          tmatmul_ddr_r_valid_i <= 1'b0;
          ddr_cycle_index <= '0;
        end else begin
          ddr_cycle_index <= ddr_cycle_index + 1;
        end
      end
    end
  end

  function automatic bit tmatmul_idle();
    return (dut.state_q === 2'b00) && (dut.tmatmul_operation_q === NO_TMATMUL_OP);
  endfunction

  task automatic log_state(input string label);
    $display("[gate2-tb] %s t=%0t state=%0d op=%0d queued=%0d in_ready=%0d in_valid=%0d ddr_stream_valid=%0d ddr_r_ready=%0d ddr_r_valid=%0d", label, $time, dut.state_q, dut.tmatmul_operation_q, dut.queued_valid_q, in_ready_o, in_valid_i, tmatmul_ddr_stream_valid_o, tmatmul_ddr_r_ready_o, tmatmul_ddr_r_valid_i);
  endtask

  task automatic wait_for_input_ready();
    int unsigned cycles;
    begin
      cycles = 0;
      while (!in_ready_o) begin
        cycles++;
        if (cycles > timeout_cycles) begin
          $fatal("Timeout waiting for in_ready");
        end
        @(posedge clk_i);
      end
    end
  endtask

  task automatic issue_command(input tmatmul_op_e op);
    int unsigned cycles;
    begin
      cycles = 0;
      while (!in_ready_o) begin
        cycles++;
        if (cycles > timeout_cycles) begin
          $fatal("Timeout waiting for in_ready");
        end
        @(posedge clk_i);
      end

      in_operation_i = op;
      in_vector_select_i = VectorSelectUnderTest;
      in_go_matrix_address_i = '0;
      in_valid_i = 1'b0;

      // Drive inputs on a cycle boundary before asserting valid so the DUT
      // observes a stable opcode and payload when sampling.
      @(posedge clk_i);

      in_valid_i = 1'b1;
      @(posedge clk_i);
      log_state($sformatf("sent command %0d", op));
      in_valid_i = 1'b0;
      in_operation_i = NO_TMATMUL_OP;
      in_go_matrix_address_i = '0;
    end
  endtask

  task automatic wait_for_tmatmul_complete();
    int unsigned cycles;
    begin
      cycles = 0;
      while (!tmatmul_idle()) begin
        cycles++;
        if (cycles > timeout_cycles) $fatal("Timeout waiting for TMATMUL to return to idle");
        @(posedge clk_i);
      end
    end
  endtask

  task automatic dump_outputs();
    int fd;
    begin
      fd = $fopen(output_file_path, "w");
      if (fd == 0) $fatal("Could not open output file %s", output_file_path);

      for (int chunk_idx = 0; chunk_idx < NumChunksPerVector; chunk_idx++) begin
        for (int lane = 0; lane < VectorParallelism; lane++) begin
          int unsigned element_idx;
          element_idx = (chunk_idx * VectorParallelism) + lane;
          sw_output[element_idx] = vector_registers[VectorSelectUnderTest][chunk_idx][lane];
          $fdisplay(fd, "%0d", $signed(sw_output[element_idx]));
        end
      end

      $fclose(fd);
    end
  endtask

  task automatic dump_memory_words(input int unsigned count);
    int unsigned idx;
    begin
      $display("[gate2-tb] importvector_mem dump=%0d", count);
      for (idx = 0; idx < count; idx++) begin
        $display("  import[%0d]=%0h", idx, dut.importvector.MEM[idx]);
      end

      $display("[gate2-tb] exportvector_mem dump=%0d", count);
      for (idx = 0; idx < count; idx++) begin
        $display("  export[%0d]=%0h", idx, dut.exportvector.MEM[idx]);
      end
    end
  endtask

  task automatic dump_matrix_stream_words(input int unsigned count);
    int unsigned idx;
    begin
      for (idx = 0; idx < count; idx++) begin
        $display("[gate2-tb] mat[%0d]=%0d", idx, matrix_data[idx]);
      end
    end
  endtask

  always #5 clk_i = ~clk_i;

  initial begin
    if (!$value$plusargs("vector_file=%s", vector_file_path)) $fatal("Missing +vector_file");
    if (!$value$plusargs("matrix_file=%s", matrix_file_path)) $fatal("Missing +matrix_file");
    if (!$value$plusargs("out_file=%s", output_file_path)) $fatal("Missing +out_file");
    if (!$value$plusargs("timeout_cycles=%0d", timeout_cycles)) timeout_cycles = TimeoutCyclesDefault;

    for (int i = 0; i < D; i++) begin
      input_vector[i] = '0;
    end

    $readmemh(vector_file_path, input_vector);
    $readmemh(matrix_file_path, matrix_data);

    // Hold reset low, then load the input vector and start parity replay.
    repeat (4) @(posedge clk_i);
    rst_ni <= 1'b1;
    @(posedge clk_i);

    for (int chunk = 0; chunk < NumChunksPerVector; chunk++) begin
      vector_registers[VectorSelectUnderTest][chunk] = '0;
    end

    for (int chunk = 0; chunk < NumChunksPerVector; chunk++) begin
      for (int lane = 0; lane < VectorParallelism; lane++) begin
        int unsigned element_idx;
        element_idx = (chunk * VectorParallelism) + lane;
        if (element_idx < D) begin
          vector_registers[VectorSelectUnderTest][chunk][lane] = input_vector[element_idx];
        end
      end
    end

    log_state("start");

    wait_for_tmatmul_complete();
    log_state("before import");
    issue_command(IMPORT);
    wait_for_tmatmul_complete();
    dump_memory_words(8);
    log_state("after import");

    issue_command(GO);
    wait_for_tmatmul_complete();
    dump_memory_words(8);
    dump_matrix_stream_words(16);
    log_state("after go");

    issue_command(EXPORT);
    wait_for_tmatmul_complete();
    log_state("after export");

    dump_outputs();

    $display("TB_SIM_OK");
    $finish;
  end
endmodule
