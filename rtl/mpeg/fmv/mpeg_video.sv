`timescale 1 ns / 1 ps
`include "../util.svh"

function [31:0] ones_mask(bit [4:0] n);
    begin
        ones_mask = (32'h1 << n) - 1;  // n ones at LSB
    end
endfunction

module mpeg_video (
    input clk30,
    input clk60,
    input reset,
    input dsp_enable,

    input  [7:0] data_byte,
    input        data_strobe,
    output       fifo_full,

    ddr_if.to_host ddrif,

    output rgb888_s vidout,
    input           hsync,
    input           vsync,
    input           hblank,
    input           vblank
);

    ddr_if worker_ddr ();
    ddr_if player_ddr ();

    ddr_mux ddrmux (
        .clk(clk60),
        .x  (ddrif),
        .a  (worker_ddr),
        .b  (player_ddr)
    );

    assign worker_ddr.byteenable = 8'hff;
    assign worker_ddr.read = 0;
    assign worker_ddr.burstcnt = 1;

    bit [15:0] dct_coeff_result;
    bit dct_coeff_huffman_active = 0;
    wire dct_coeff_result_valid;
    dct_coeff_huffman_decoder huff (
        .clk(clk30),
        .reset,
        .data_valid(dct_coeff_huffman_active && hw_read_mem_ready && !dct_coeff_result_valid),
        .data(mpeg_in_fifo_out[31-hw_read_bit_shift]),
        .result_valid(dct_coeff_result_valid),
        .result(dct_coeff_result)
    );

    // 8kB of MPEG stream memory to fill from outside
    wire [31:0] mpeg_in_fifo_out;

    bit  [12:0] mpeg_input_stream_fifo_raddr;
    always_comb begin
        mpeg_input_stream_fifo_raddr = dmem_cmd_payload_address_1[14:2];

        if (hw_read_count != 0) begin
            mpeg_input_stream_fifo_raddr = mpeg_stream_byte_index[14:2];

            if (hw_read_mem_ready && (!hw_read_aligned_access || mpeg_stream_bit_index[4:0]==5'b11111) )
                mpeg_input_stream_fifo_raddr = mpeg_input_stream_fifo_raddr + 1;
        end
    end

    big_mpeg_input_stream_fifo in_fifo (
        .clk(clk30),
        // In, invert endianness at the same time
        .waddr({mpeg_stream_fifo_write_adr[14:2], 2'b11 - mpeg_stream_fifo_write_adr[1:0]}),
        .wdata(data_byte),
        .we(data_strobe),
        // Out (32 bit CPU interface)
        .raddr(mpeg_input_stream_fifo_raddr),
        .q(mpeg_in_fifo_out)
    );

    bit [4:0] hw_read_count = 0;
    bit [31:0] hw_read_result = 32;

    // Word Address
    bit [27:0] mpeg_stream_fifo_write_adr;
    bit [31:0] mpeg_stream_bit_index;
    wire [28:0] mpeg_stream_byte_index = mpeg_stream_bit_index[31:3];

    // Word address
    wire [27:0] mpeg_stream_fifo_read_adr = mpeg_stream_byte_index[27:0];

    wire [27:0] fifo_level /*verilator public_flat_rd*/ = mpeg_stream_fifo_write_adr - mpeg_stream_fifo_read_adr;
    assign fifo_full = mpeg_stream_fifo_write_adr > (mpeg_stream_fifo_read_adr + 28'd30000);

    bit hw_read_mem_ready = 0;
    wire [4:0] hw_read_bit_shift = mpeg_stream_bit_index[4:0];

    wire [5:0] hw_read_remaining_bits_in_dword = 32 - hw_read_bit_shift;
    wire hw_read_aligned_access = (6'(hw_read_count) <= hw_read_remaining_bits_in_dword);
    wire [ 4:0] hw_read_count_aligned = hw_read_aligned_access ? hw_read_count : hw_read_remaining_bits_in_dword[4:0];
    wire [31:0] hw_read_mask = ones_mask(hw_read_count_aligned);

    always_ff @(posedge clk30) begin
        if (fifo_full) begin
            $display("FIFO FULL");
            $finish();
        end


        hw_read_mem_ready <= 0;

        if (reset) begin
            mpeg_stream_fifo_write_adr <= 0;
            mpeg_stream_bit_index <= 0;
            hw_read_count <= 0;
        end else begin
            if (data_strobe) begin
                mpeg_stream_fifo_write_adr <= mpeg_stream_fifo_write_adr + 1;
            end

            if (dmem_cmd_payload_write_1 && dmem_cmd_valid_1) begin
                if (dmem_cmd_payload_address_1 == 32'h10002000)
                    mpeg_stream_fifo_write_adr <= dmem_cmd_payload_data_1[27:0];
                if (dmem_cmd_payload_address_1 == 32'h10002004)
                    mpeg_stream_bit_index <= dmem_cmd_payload_data_1;
                if (dmem_cmd_payload_address_1 == 32'h10002008) begin
                    hw_read_count  <= dmem_cmd_payload_data_1[4:0];
                    hw_read_result <= 0;
                end
                if (dmem_cmd_payload_address_1 == 32'h1000200c) begin
                    hw_read_count <= 1;
                    dct_coeff_huffman_active <= 1;
                end
            end

            if (hw_read_count_aligned != 0) begin
                hw_read_mem_ready <= 1;

                if (hw_read_mem_ready) begin

                    hw_read_result <= (hw_read_result<<hw_read_count_aligned) |
                        ((mpeg_in_fifo_out >> (32 - hw_read_count_aligned - hw_read_bit_shift)) & hw_read_mask);

                    mpeg_stream_bit_index <= mpeg_stream_bit_index + 32'(hw_read_count_aligned);
                    hw_read_count <= hw_read_count - hw_read_count_aligned;
                end
            end
        end

        if (reset || dct_coeff_result_valid) begin
            dct_coeff_huffman_active <= 0;
            mpeg_stream_bit_index <= mpeg_stream_bit_index;
            hw_read_count <= 0;
        end else if (dct_coeff_huffman_active) begin
            hw_read_count <= 1;
            hw_read_mem_ready <= 1;
        end
    end

    bit  [31:0] frames_decoded;

    // Memory arrays
    wire [31:0] memory_out_i1;
    wire [31:0] memory_out_d1;
    decoder_firmware_memory core1mem (
        .clk(clk30),
        .addr2(imem_cmd_payload_address_1[13:2]),
        .data_out2(memory_out_i1),
        .be2(0),
        .we2(0),
        .data_in2(0),
        .addr1(dmem_cmd_payload_address_1[13:2]),
        .data_in1(dmem_cmd_payload_data_1),
        .we1(dmem_cmd_payload_address_1[31:28]==0 && dmem_cmd_valid_1 && dmem_cmd_ready_1 && dmem_cmd_payload_write_1),
        .be1(dmem_cmd_payload_mask_1),
        .data_out1(memory_out_d1)
    );

    wire [31:0] memory_out_i2;
    wire [31:0] memory_out_d2;
    worker_firmware_memory core2mem (
        .clk(clk60),
        .addr2(imem_cmd_payload_address_2[12:2]),
        .data_out2(memory_out_i2),
        .be2(0),
        .we2(0),
        .data_in2(0),
        .addr1(dmem_cmd_payload_address_2[12:2]),
        .data_in1(dmem_cmd_payload_data_2),
        .we1(dmem_cmd_payload_address_2[31:28]==0 && dmem_cmd_valid_2 && dmem_cmd_ready_2 && dmem_cmd_payload_write_2),
        .be1(dmem_cmd_payload_mask_2),
        .data_out1(memory_out_d2)
    );

    wire [31:0] memory_out_i3;
    wire [31:0] memory_out_d3;
    worker_firmware_memory core3mem (
        .clk(clk60),
        .addr2(imem_cmd_payload_address_3[12:2]),
        .data_out2(memory_out_i3),
        .be2(0),
        .we2(0),
        .data_in2(0),
        .addr1(dmem_cmd_payload_address_3[12:2]),
        .data_in1(dmem_cmd_payload_data_3),
        .we1(dmem_cmd_payload_address_3[31:28]==0 && dmem_cmd_valid_3 && dmem_cmd_ready_3 && dmem_cmd_payload_write_3),
        .be1(dmem_cmd_payload_mask_3),
        .data_out1(memory_out_d3)
    );

    wire [31:0] shared12_out_2;
    wire [31:0] shared12_out_1;
    dualport_shared_ram shared12 (
        .clk2(clk60),
        .addr2(dmem_cmd_payload_address_2[12:2]),
        .data_out2(shared12_out_2),
        .be2(dmem_cmd_payload_mask_2),
        .we2(dmem_cmd_payload_address_2[31:28]==4 && dmem_cmd_valid_2 && dmem_cmd_ready_2 && dmem_cmd_payload_write_2),
        .data_in2(dmem_cmd_payload_data_2),
        .addr1(dmem_cmd_payload_address_1[12:2]),
        .clk1(clk30),
        .data_in1(dmem_cmd_payload_data_1),
        .we1(dmem_cmd_payload_address_1[31:28]==4 && dmem_cmd_payload_address_1[27:24] == 1 && dmem_cmd_valid_1 && dmem_cmd_ready_1 && dmem_cmd_payload_write_1),
        .be1(dmem_cmd_payload_mask_1),
        .data_out1(shared12_out_1)
    );

    wire [31:0] shared13_out_3;
    wire [31:0] shared13_out_1;
    dualport_shared_ram shared13 (
        .clk2(clk60),
        .addr2(dmem_cmd_payload_address_3[12:2]),
        .data_out2(shared13_out_3),
        .be2(dmem_cmd_payload_mask_3),
        .we2(dmem_cmd_payload_address_3[31:28]==4 && dmem_cmd_valid_3 && dmem_cmd_ready_3 && dmem_cmd_payload_write_3),
        .data_in2(dmem_cmd_payload_data_3),
        .addr1(dmem_cmd_payload_address_1[12:2]),
        .clk1(clk30),
        .data_in1(dmem_cmd_payload_data_1),
        .we1(dmem_cmd_payload_address_1[31:28]==4 && dmem_cmd_payload_address_1[27:24] == 0 && dmem_cmd_valid_1 && dmem_cmd_ready_1 && dmem_cmd_payload_write_1),
        .be1(dmem_cmd_payload_mask_1),
        .data_out1(shared13_out_1)
    );

    // Core 1 signals
    wire        imem_cmd_valid_1;
    bit         imem_cmd_ready_1;
    wire [ 0:0] imem_cmd_payload_id_1;
    wire [31:0] imem_cmd_payload_address_1;
    bit         imem_rsp_valid_1;
    bit  [ 0:0] imem_rsp_payload_id_1;
    bit         imem_rsp_payload_error_1;
    bit  [31:0] imem_rsp_payload_word_1;
    wire        dmem_cmd_valid_1;
    bit         dmem_cmd_ready_1;
    wire [ 0:0] dmem_cmd_payload_id_1;
    wire        dmem_cmd_payload_write_1;
    wire [31:0] dmem_cmd_payload_address_1;
    wire [31:0] dmem_cmd_payload_data_1;
    wire [ 1:0] dmem_cmd_payload_size_1;
    wire [ 3:0] dmem_cmd_payload_mask_1;
    wire        dmem_cmd_payload_io_1;
    wire        dmem_cmd_payload_fromHart_1;
    wire [15:0] dmem_cmd_payload_uopId_1;
    bit         dmem_rsp_valid_1;
    bit  [ 0:0] dmem_rsp_payload_id_1;
    bit         dmem_rsp_payload_error_1;
    bit  [31:0] dmem_rsp_payload_data_1;

    // Core 2 signals
    wire        imem_cmd_valid_2;
    bit         imem_cmd_ready_2;
    wire [ 0:0] imem_cmd_payload_id_2;
    wire [31:0] imem_cmd_payload_address_2;
    bit         imem_rsp_valid_2;
    bit  [ 0:0] imem_rsp_payload_id_2;
    bit         imem_rsp_payload_error_2;
    bit  [31:0] imem_rsp_payload_word_2;
    wire        dmem_cmd_valid_2;
    bit         dmem_cmd_ready_2;
    wire [ 0:0] dmem_cmd_payload_id_2;
    wire        dmem_cmd_payload_write_2;
    wire [31:0] dmem_cmd_payload_address_2;
    wire [31:0] dmem_cmd_payload_data_2;
    wire [ 1:0] dmem_cmd_payload_size_2;
    wire [ 3:0] dmem_cmd_payload_mask_2;
    wire        dmem_cmd_payload_io_2;
    wire        dmem_cmd_payload_fromHart_2;
    wire [15:0] dmem_cmd_payload_uopId_2;
    bit         dmem_rsp_valid_2;
    bit  [ 0:0] dmem_rsp_payload_id_2;
    bit         dmem_rsp_payload_error_2;
    bit  [31:0] dmem_rsp_payload_data_2;

    // Core 3 signals
    wire        imem_cmd_valid_3;
    bit         imem_cmd_ready_3;
    wire [ 0:0] imem_cmd_payload_id_3;
    wire [31:0] imem_cmd_payload_address_3;
    bit         imem_rsp_valid_3;
    bit  [ 0:0] imem_rsp_payload_id_3;
    bit         imem_rsp_payload_error_3;
    bit  [31:0] imem_rsp_payload_word_3;
    wire        dmem_cmd_valid_3;
    bit         dmem_cmd_ready_3;
    wire [ 0:0] dmem_cmd_payload_id_3;
    wire        dmem_cmd_payload_write_3;
    wire [31:0] dmem_cmd_payload_address_3;
    wire [31:0] dmem_cmd_payload_data_3;
    wire [ 1:0] dmem_cmd_payload_size_3;
    wire [ 3:0] dmem_cmd_payload_mask_3;
    wire        dmem_cmd_payload_io_3;
    wire        dmem_cmd_payload_fromHart_3;
    wire [15:0] dmem_cmd_payload_uopId_3;
    bit         dmem_rsp_valid_3;
    bit  [ 0:0] dmem_rsp_payload_id_3;
    bit         dmem_rsp_payload_error_3;
    bit  [31:0] dmem_rsp_payload_data_3;

    /*verilator tracing_off*/
    VexiiRiscv vexii1 (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),
        .FetchCachelessPlugin_logic_bus_cmd_valid(imem_cmd_valid_1),
        .FetchCachelessPlugin_logic_bus_cmd_ready(imem_cmd_ready_1),
        .FetchCachelessPlugin_logic_bus_cmd_payload_id(imem_cmd_payload_id_1),
        .FetchCachelessPlugin_logic_bus_cmd_payload_address(imem_cmd_payload_address_1),
        .FetchCachelessPlugin_logic_bus_rsp_valid(imem_rsp_valid_1),
        .FetchCachelessPlugin_logic_bus_rsp_payload_id(imem_rsp_payload_id_1),
        .FetchCachelessPlugin_logic_bus_rsp_payload_error(imem_rsp_payload_error_1),
        .FetchCachelessPlugin_logic_bus_rsp_payload_word(imem_rsp_payload_word_1),
        .LsuCachelessPlugin_logic_bus_cmd_valid(dmem_cmd_valid_1),
        .LsuCachelessPlugin_logic_bus_cmd_ready(dmem_cmd_ready_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_id(dmem_cmd_payload_id_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_write(dmem_cmd_payload_write_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_address(dmem_cmd_payload_address_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_data(dmem_cmd_payload_data_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_size(dmem_cmd_payload_size_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_mask(dmem_cmd_payload_mask_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_io(dmem_cmd_payload_io_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_fromHart(dmem_cmd_payload_fromHart_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_uopId(dmem_cmd_payload_uopId_1),
        .LsuCachelessPlugin_logic_bus_rsp_valid(dmem_rsp_valid_1),
        .LsuCachelessPlugin_logic_bus_rsp_payload_id(dmem_rsp_payload_id_1),
        .LsuCachelessPlugin_logic_bus_rsp_payload_error(dmem_rsp_payload_error_1),
        .LsuCachelessPlugin_logic_bus_rsp_payload_data(dmem_rsp_payload_data_1),
        .clk(clk30),
        .reset(reset || !dsp_enable)
    );


    flag_cross_domain cross_reset (
        .clk_a(clk30),
        .clk_b(clk60),
        .flag_in_clk_a(reset_dsp_enabled),
        .flag_out_clk_b(reset_dsp_enabled_clk60)
    );
    wire reset_dsp_enabled = reset || !dsp_enable;
    wire reset_dsp_enabled_clk60;

    VexiiRiscv vexii2 (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),
        .FetchCachelessPlugin_logic_bus_cmd_valid(imem_cmd_valid_2),
        .FetchCachelessPlugin_logic_bus_cmd_ready(imem_cmd_ready_2),
        .FetchCachelessPlugin_logic_bus_cmd_payload_id(imem_cmd_payload_id_2),
        .FetchCachelessPlugin_logic_bus_cmd_payload_address(imem_cmd_payload_address_2),
        .FetchCachelessPlugin_logic_bus_rsp_valid(imem_rsp_valid_2),
        .FetchCachelessPlugin_logic_bus_rsp_payload_id(imem_rsp_payload_id_2),
        .FetchCachelessPlugin_logic_bus_rsp_payload_error(imem_rsp_payload_error_2),
        .FetchCachelessPlugin_logic_bus_rsp_payload_word(imem_rsp_payload_word_2),
        .LsuCachelessPlugin_logic_bus_cmd_valid(dmem_cmd_valid_2),
        .LsuCachelessPlugin_logic_bus_cmd_ready(dmem_cmd_ready_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_id(dmem_cmd_payload_id_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_write(dmem_cmd_payload_write_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_address(dmem_cmd_payload_address_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_data(dmem_cmd_payload_data_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_size(dmem_cmd_payload_size_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_mask(dmem_cmd_payload_mask_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_io(dmem_cmd_payload_io_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_fromHart(dmem_cmd_payload_fromHart_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_uopId(dmem_cmd_payload_uopId_2),
        .LsuCachelessPlugin_logic_bus_rsp_valid(dmem_rsp_valid_2),
        .LsuCachelessPlugin_logic_bus_rsp_payload_id(dmem_rsp_payload_id_2),
        .LsuCachelessPlugin_logic_bus_rsp_payload_error(dmem_rsp_payload_error_2),
        .LsuCachelessPlugin_logic_bus_rsp_payload_data(dmem_rsp_payload_data_2),
        .clk(clk60),
        .reset(reset_dsp_enabled_clk60)
    );

    VexiiRiscv vexii3 (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),
        .FetchCachelessPlugin_logic_bus_cmd_valid(imem_cmd_valid_3),
        .FetchCachelessPlugin_logic_bus_cmd_ready(imem_cmd_ready_3),
        .FetchCachelessPlugin_logic_bus_cmd_payload_id(imem_cmd_payload_id_3),
        .FetchCachelessPlugin_logic_bus_cmd_payload_address(imem_cmd_payload_address_3),
        .FetchCachelessPlugin_logic_bus_rsp_valid(imem_rsp_valid_3),
        .FetchCachelessPlugin_logic_bus_rsp_payload_id(imem_rsp_payload_id_3),
        .FetchCachelessPlugin_logic_bus_rsp_payload_error(imem_rsp_payload_error_3),
        .FetchCachelessPlugin_logic_bus_rsp_payload_word(imem_rsp_payload_word_3),
        .LsuCachelessPlugin_logic_bus_cmd_valid(dmem_cmd_valid_3),
        .LsuCachelessPlugin_logic_bus_cmd_ready(dmem_cmd_ready_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_id(dmem_cmd_payload_id_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_write(dmem_cmd_payload_write_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_address(dmem_cmd_payload_address_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_data(dmem_cmd_payload_data_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_size(dmem_cmd_payload_size_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_mask(dmem_cmd_payload_mask_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_io(dmem_cmd_payload_io_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_fromHart(dmem_cmd_payload_fromHart_3),
        .LsuCachelessPlugin_logic_bus_cmd_payload_uopId(dmem_cmd_payload_uopId_3),
        .LsuCachelessPlugin_logic_bus_rsp_valid(dmem_rsp_valid_3),
        .LsuCachelessPlugin_logic_bus_rsp_payload_id(dmem_rsp_payload_id_3),
        .LsuCachelessPlugin_logic_bus_rsp_payload_error(dmem_rsp_payload_error_3),
        .LsuCachelessPlugin_logic_bus_rsp_payload_data(dmem_rsp_payload_data_3),
        .clk(clk60),
        .reset(reset_dsp_enabled_clk60)
    );

    /*verilator tracing_on*/

    wire [31:0] frame_adr  /*verilator public_flat_rd*/ = dmem_cmd_payload_data_1;
    wire expose_frame /*verilator public_flat_rd*/ = (dmem_cmd_payload_address_1 == 32'h10000010 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1) ;
    bit [31:0] soft_state1  /*verilator public_flat_rd*/ = 0;
    bit [31:0] soft_state2  /*verilator public_flat_rd*/ = 0;
    bit [31:0] soft_state3  /*verilator public_flat_rd*/ = 0;

    always_comb begin
        imem_cmd_ready_3 = 1;
        imem_rsp_payload_word_3 = memory_out_i3;

        dmem_cmd_ready_3 = 1;
        dmem_rsp_payload_data_3 = memory_out_d3;

        if (dmem_cmd_valid_3_q && dmem_cmd_ready_3_q) begin
            case (dmem_cmd_payload_address_3_q[31:28])
                4'd5: begin  // Video SRAM region
                    dmem_rsp_payload_data_3 = 0;
                end
                4'd4: begin  // Shared SRAM region
                    dmem_rsp_payload_data_3 = shared13_out_3;
                end
                4'd1: begin
                    // I/O Area
                    // Magic Number for Core 3
                    dmem_rsp_payload_data_3 = 32'h00004212;
                end
                4'd0: begin
                    dmem_rsp_payload_data_3 = memory_out_d3;
                end
                default: begin
                    dmem_rsp_payload_data_3 = memory_out_d3;
                end
            endcase
        end
    end

    always_comb begin
        imem_cmd_ready_2 = 1;
        imem_rsp_payload_word_2 = memory_out_i2;

        dmem_cmd_ready_2 = 1;
        dmem_rsp_payload_data_2 = memory_out_d2;

        if (worker_ddr.acquire && dmem_cmd_valid_2 && dmem_cmd_ready_2 && dmem_cmd_payload_address_2[31:28] == 4'd5)
            dmem_cmd_ready_2 = 0;


        if (dmem_cmd_valid_2_q && dmem_cmd_ready_2_q) begin
            case (dmem_cmd_payload_address_2_q[31:28])
                4'd5: begin  // Video SRAM region
                    dmem_rsp_payload_data_2 = 0;
                end
                4'd4: begin  // Shared SRAM region
                    dmem_rsp_payload_data_2 = shared12_out_2;
                end
                4'd1: begin
                    // I/O Area
                    // Magic Number for Core 2
                    dmem_rsp_payload_data_2 = 32'h00004218;
                end
                4'd0: begin
                    dmem_rsp_payload_data_2 = memory_out_d2;
                end
                default: begin
                    dmem_rsp_payload_data_2 = memory_out_d2;
                end
            endcase
        end

    end

    always_comb begin
        imem_cmd_ready_1 = 1;
        imem_rsp_payload_word_1 = memory_out_i1;

        dmem_cmd_ready_1 = hw_read_count == 0;
        dmem_rsp_payload_data_1 = reverse_endian_32(mpeg_in_fifo_out);

        if (dmem_cmd_valid_1_q && dmem_cmd_ready_1_q) begin
            case (dmem_cmd_payload_address_1_q[31:28])
                4'd4: begin  // Shared SRAM region
                    if (dmem_cmd_payload_address_1_q[27:24] == 1)
                        dmem_rsp_payload_data_1 = shared12_out_1;
                    else dmem_rsp_payload_data_1 = shared13_out_1;
                end
                4'd1: begin
                    // I/O Area
                    if (!dmem_cmd_payload_write_1_q) begin
                        if (dmem_cmd_payload_address_1_q == 32'h10002000)
                            dmem_rsp_payload_data_1 = {4'b0000, mpeg_stream_fifo_write_adr};
                        if (dmem_cmd_payload_address_1_q == 32'h10002004)
                            dmem_rsp_payload_data_1 = mpeg_stream_bit_index;
                        if (dmem_cmd_payload_address_1_q == 32'h10002008)
                            dmem_rsp_payload_data_1 = hw_read_result;
                        if (dmem_cmd_payload_address_1_q == 32'h1000200c)
                            dmem_rsp_payload_data_1 = {16'b0, dct_coeff_result};
                    end
                end
                4'd0: begin
                    dmem_rsp_payload_data_1 = memory_out_d1;
                end
                default: begin
                    // Assign the rest of the memory to the MPEG FIFO to fake a real big file
                    dmem_rsp_payload_data_1 = reverse_endian_32(mpeg_in_fifo_out);
                end
            endcase
        end

    end


    // Assuming 30 MHz clock rate and 25 Hz frame rate
    localparam TICKS_PER_FRAME = 1200000;

    bit signed [15:0] shared_buffer_level = 0;

    wire shared_buffer_level_inc = dmem_cmd_payload_address_1 == 32'h10000014 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1;
    wire shared_buffer_level_dec1 = dmem_cmd_payload_address_2 == 32'h10000014 && dmem_cmd_payload_write_2 && dmem_cmd_valid_2;
    wire shared_buffer_level_dec2 = dmem_cmd_payload_address_3 == 32'h10000014 && dmem_cmd_payload_write_3 && dmem_cmd_valid_3;

    wire shared_buffer_level_dec1_clk30;
    wire shared_buffer_level_dec2_clk30;

    flag_cross_domain cross1 (
        .clk_a(clk60),
        .clk_b(clk30),
        .flag_in_clk_a(shared_buffer_level_dec1),
        .flag_out_clk_b(shared_buffer_level_dec1_clk30)
    );

    flag_cross_domain cross2 (
        .clk_a(clk60),
        .clk_b(clk30),
        .flag_in_clk_a(shared_buffer_level_dec2),
        .flag_out_clk_b(shared_buffer_level_dec2_clk30)
    );

    bit [31:0] dmem_cmd_payload_address_1_q;
    bit dmem_cmd_valid_1_q;
    bit dmem_cmd_ready_1_q;
    bit dmem_cmd_payload_write_1_q;

    bit [31:0] dmem_cmd_payload_address_2_q;
    bit dmem_cmd_valid_2_q;
    bit dmem_cmd_ready_2_q;
    bit dmem_cmd_payload_write_2_q;

    bit [31:0] dmem_cmd_payload_address_3_q;
    bit dmem_cmd_valid_3_q;
    bit dmem_cmd_ready_3_q;
    bit dmem_cmd_payload_write_3_q;

    always_ff @(posedge clk30) begin
        imem_rsp_valid_1 <= 0;
        dmem_rsp_valid_1 <= 0;

        dmem_cmd_payload_address_1_q <= dmem_cmd_payload_address_1;
        dmem_cmd_valid_1_q <= dmem_cmd_valid_1;
        dmem_cmd_ready_1_q <= dmem_cmd_ready_1;
        dmem_cmd_payload_write_1_q <= dmem_cmd_payload_write_1;

        shared_buffer_level <= shared_buffer_level + (shared_buffer_level_inc ? 1:0) - (shared_buffer_level_dec1_clk30 ? 1 : 0) - (shared_buffer_level_dec2_clk30 ? 1:0);

        if (dmem_cmd_payload_address_1 == 32'h1000000c && dmem_cmd_payload_write_1 && dmem_cmd_valid_1)begin
            $display("Core 1 stopped at %x with code %x", imem_cmd_payload_address_1,
                     dmem_cmd_payload_data_1);
            $finish();
        end
        if (dmem_cmd_payload_address_1 == 32'h10000030 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1)
            soft_state1 <= dmem_cmd_payload_data_1;

        if (expose_frame) begin
            frames_decoded <= frames_decoded + 1;
        end

        if (dmem_cmd_payload_address_1 == 32'h10000000 && dmem_cmd_valid_1 && dmem_cmd_payload_write_1 && dmem_cmd_ready_1)
            $display("Debug out %x", dmem_cmd_payload_data_1);

        // Core 1 memory access
        if (dmem_cmd_valid_1 && dmem_cmd_ready_1) begin
            dmem_rsp_payload_id_1 <= dmem_cmd_payload_id_1;
            dmem_rsp_valid_1 <= 1;

            case (dmem_cmd_payload_address_1[31:28])
                4'd4: begin  // Shared SRAM region
                end
                4'd1: begin
                end
                4'd0: begin
                end
                default: ;
            endcase
        end

        // Instruction fetch logic for core 1
        if (imem_cmd_valid_1) begin
            imem_rsp_valid_1 <= 1;
            imem_rsp_payload_id_1 <= imem_cmd_payload_id_1;
        end
    end

    // 0011 like the N64 core to force a base of 0x30000000
    localparam bit [3:0] DDR_CORE_BASE = 4'b0011;

    always_ff @(posedge clk60) begin

        if (!worker_ddr.busy) begin
            worker_ddr.write   <= 0;
            worker_ddr.acquire <= 0;
        end

        imem_rsp_valid_2 <= 0;
        dmem_rsp_valid_2 <= 0;
        imem_rsp_valid_3 <= 0;
        dmem_rsp_valid_3 <= 0;

        dmem_cmd_payload_address_2_q <= dmem_cmd_payload_address_2;
        dmem_cmd_valid_2_q <= dmem_cmd_valid_2;
        dmem_cmd_ready_2_q <= dmem_cmd_ready_2;
        dmem_cmd_payload_write_2_q <= dmem_cmd_payload_write_2;

        dmem_cmd_payload_address_3_q <= dmem_cmd_payload_address_3;
        dmem_cmd_valid_3_q <= dmem_cmd_valid_3;
        dmem_cmd_ready_3_q <= dmem_cmd_ready_3;
        dmem_cmd_payload_write_3_q <= dmem_cmd_payload_write_3;

        if (dmem_cmd_payload_address_2 == 32'h1000000c && dmem_cmd_payload_write_2 && dmem_cmd_valid_2) begin
            $display("Core 2 stopped at %x with code %x", imem_cmd_payload_address_2,
                     dmem_cmd_payload_data_2);
            $finish();
        end
        if (dmem_cmd_payload_address_3 == 32'h1000000c && dmem_cmd_payload_write_3 && dmem_cmd_valid_3) begin
            $display("Core 3 stopped at %x with code %x", imem_cmd_payload_address_3,
                     dmem_cmd_payload_data_3);
            $finish();
        end

        if (dmem_cmd_payload_address_2 == 32'h10000030 && dmem_cmd_payload_write_2 && dmem_cmd_valid_2)
            soft_state2 <= dmem_cmd_payload_data_2;
        if (dmem_cmd_payload_address_3 == 32'h10000030 && dmem_cmd_payload_write_3 && dmem_cmd_valid_3)
            soft_state3 <= dmem_cmd_payload_data_3;

        // Core 2 memory access
        if (dmem_cmd_valid_2 && dmem_cmd_ready_2) begin
            dmem_rsp_payload_id_2 <= dmem_cmd_payload_id_2;
            dmem_rsp_valid_2 <= 1;

            case (dmem_cmd_payload_address_2[31:28])
                4'd5: begin  // Core 1 private memory
                    //assert(dmem_cmd_payload_address_2[1:0] == 2'b00);

                    if (dmem_cmd_payload_write_2) begin
                        assert (worker_ddr.write == 0);

                        worker_ddr.addr <= {DDR_CORE_BASE, dmem_cmd_payload_address_2[27:3]};

                        if (dmem_cmd_payload_address_2[2] == 1'b1) begin
                            worker_ddr.write   <= dmem_cmd_payload_mask_2[3];
                            worker_ddr.acquire <= 1;
                            // verilog_format: off
                            if (dmem_cmd_payload_mask_2[0]) worker_ddr.wdata[39:32] <= dmem_cmd_payload_data_2[7:0];
                            if (dmem_cmd_payload_mask_2[1]) worker_ddr.wdata[47:40] <= dmem_cmd_payload_data_2[15:8];
                            if (dmem_cmd_payload_mask_2[2]) worker_ddr.wdata[55:48] <= dmem_cmd_payload_data_2[23:16];
                            if (dmem_cmd_payload_mask_2[3]) worker_ddr.wdata[63:56] <= dmem_cmd_payload_data_2[31:24];
                        end else begin
                            if (dmem_cmd_payload_mask_2[0]) worker_ddr.wdata[7:0] <= dmem_cmd_payload_data_2[7:0];
                            if (dmem_cmd_payload_mask_2[1]) worker_ddr.wdata[15:8] <= dmem_cmd_payload_data_2[15:8];
                            if (dmem_cmd_payload_mask_2[2]) worker_ddr.wdata[23:16] <= dmem_cmd_payload_data_2[23:16];
                            if (dmem_cmd_payload_mask_2[3]) worker_ddr.wdata[31:24] <= dmem_cmd_payload_data_2[31:24];
                        end
                        // verilog_format: on
                    end

                end
                4'd4: begin  // Shared SRAM region
                end
                4'd0: begin  // Core 2 private memory

                end
                default: ;

            endcase
        end

        // Instruction fetch logic for core 2
        if (imem_cmd_valid_2) begin
            imem_rsp_valid_2 <= 1;
            imem_rsp_payload_id_2 <= imem_cmd_payload_id_2;
        end

        // Core 3 memory access
        if (dmem_cmd_valid_3 && dmem_cmd_ready_3) begin
            dmem_rsp_payload_id_3 <= dmem_cmd_payload_id_3;
            dmem_rsp_valid_3 <= 1;

            case (dmem_cmd_payload_address_3[31:28])
                4'd4: begin  // Shared SRAM region
                end
                4'd0: begin  // Core 3 private memory
                end
                default: ;
            endcase
        end

        if (imem_cmd_valid_3) begin
            imem_rsp_valid_3 <= 1;
            imem_rsp_payload_id_3 <= imem_cmd_payload_id_3;
        end

    end

    frameplayer frameplayer (
        .clk(clk30),
        .clkddr(clk60),
        .reset,
        .ddrif(player_ddr),
        .vidout,
        .hsync,
        .vsync,
        .hblank,
        .vblank
    );

endmodule

// https://www.intel.com/content/www/us/en/docs/programmable/683082/21-3/mixed-width-dual-port-ram.html
// 8192x8 write and 2048x32 read
// So, this is 8KB of memory
module big_mpeg_input_stream_fifo (
    input [14:0] waddr,
    input [7:0] wdata,
    input we,
    input clk,
    input [12:0] raddr,
    output logic [31:0] q
);

    logic [3:0][7:0] ram[8192];
    always_ff @(posedge clk) begin
        if (we) ram[waddr[14:2]][waddr[1:0]] <= wdata;
        q <= ram[raddr];
    end
endmodule : big_mpeg_input_stream_fifo


// Quartus Prime SystemVerilog Template
//
// True Dual-Port RAM with different read/write addresses and single read/write clock
// and with a control for writing single bytes into the memory word; byte enable

// Read during write produces old data on ports A and B and old data on mixed ports
// For device families that do not support this mode (e.g. Stratix V) the ram is not inferred

module decoder_firmware_memory #(
    parameter int BYTE_WIDTH = 8,
    ADDRESS_WIDTH = 12,
    BYTES = 4,
    DATA_WIDTH_R = BYTE_WIDTH * BYTES
) (
    input [ADDRESS_WIDTH-1:0] addr1,
    input [ADDRESS_WIDTH-1:0] addr2,
    input [BYTES-1:0] be1,
    input [BYTES-1:0] be2,
    input [DATA_WIDTH_R-1:0] data_in1,
    input [DATA_WIDTH_R-1:0] data_in2,
    input we1,
    we2,
    clk,
    output [DATA_WIDTH_R-1:0] data_out1,
    output [DATA_WIDTH_R-1:0] data_out2
);
    localparam RAM_DEPTH = 9500 >> 2;

    // model the RAM with two dimensional packed array
    logic [BYTES-1:0][BYTE_WIDTH-1:0] ram[0:RAM_DEPTH-1];

    initial $readmemh("../rtl/mpeg/fmv/firmware.mem", ram);

    reg [DATA_WIDTH_R-1:0] data_reg1;
    reg [DATA_WIDTH_R-1:0] data_reg2;

    // port A
    always_ff @(posedge clk) begin
        if (we1) begin
            // edit this code if using other than four bytes per word
            if (be1[0]) ram[addr1][0] <= data_in1[7:0];
            if (be1[1]) ram[addr1][1] <= data_in1[15:8];
            if (be1[2]) ram[addr1][2] <= data_in1[23:16];
            if (be1[3]) ram[addr1][3] <= data_in1[31:24];
        end
        data_reg1 <= ram[addr1];
    end

    assign data_out1 = data_reg1;

    // port B
    always_ff @(posedge clk) begin
        if (we2) begin
            // edit this code if using other than four bytes per word
            if (be2[0]) ram[addr2][0] <= data_in2[7:0];
            if (be2[1]) ram[addr2][1] <= data_in2[15:8];
            if (be2[2]) ram[addr2][2] <= data_in2[23:16];
            if (be2[3]) ram[addr2][3] <= data_in2[31:24];
        end
        data_reg2 <= ram[addr2];
    end

    assign data_out2 = data_reg2;

endmodule : decoder_firmware_memory


// Quartus Prime SystemVerilog Template
//
// True Dual-Port RAM with different read/write addresses and single read/write clock
// and with a control for writing single bytes into the memory word; byte enable

// Read during write produces old data on ports A and B and old data on mixed ports
// For device families that do not support this mode (e.g. Stratix V) the ram is not inferred

module worker_firmware_memory #(
    parameter int BYTE_WIDTH = 8,
    ADDRESS_WIDTH = 11,
    BYTES = 4,
    DATA_WIDTH_R = BYTE_WIDTH * BYTES
) (
    input [ADDRESS_WIDTH-1:0] addr1,
    input [ADDRESS_WIDTH-1:0] addr2,
    input [BYTES-1:0] be1,
    input [BYTES-1:0] be2,
    input [DATA_WIDTH_R-1:0] data_in1,
    input [DATA_WIDTH_R-1:0] data_in2,
    input we1,
    we2,
    clk,
    output [DATA_WIDTH_R-1:0] data_out1,
    output [DATA_WIDTH_R-1:0] data_out2
);
    localparam RAM_DEPTH = 4100 >> 2;

    // model the RAM with two dimensional packed array
    logic [BYTES-1:0][BYTE_WIDTH-1:0] ram[0:RAM_DEPTH-1]  /* synthesis ramstyle = "no_rw_check" */;

    initial $readmemh("../rtl/mpeg/fmv/firmware2.mem", ram);

    reg [DATA_WIDTH_R-1:0] data_reg1;
    reg [DATA_WIDTH_R-1:0] data_reg2;

    // port A
    always @(posedge clk) begin
        if (we1) begin
            // edit this code if using other than four bytes per word
            if (be1[0]) ram[addr1][0] <= data_in1[7:0];
            if (be1[1]) ram[addr1][1] <= data_in1[15:8];
            if (be1[2]) ram[addr1][2] <= data_in1[23:16];
            if (be1[3]) ram[addr1][3] <= data_in1[31:24];
        end
        data_reg1 <= ram[addr1];
    end

    assign data_out1 = data_reg1;

    // port B
    always @(posedge clk) begin
        if (we2) begin
            // edit this code if using other than four bytes per word
            if (be2[0]) ram[addr2][0] <= data_in2[7:0];
            if (be2[1]) ram[addr2][1] <= data_in2[15:8];
            if (be2[2]) ram[addr2][2] <= data_in2[23:16];
            if (be2[3]) ram[addr2][3] <= data_in2[31:24];
        end
        data_reg2 <= ram[addr2];
    end

    assign data_out2 = data_reg2;

endmodule : worker_firmware_memory


// Quartus Prime SystemVerilog Template
//
// True Dual-Port RAM with different read/write addresses and single read/write clock
// and with a control for writing single bytes into the memory word; byte enable

// Read during write produces old data on ports A and B and old data on mixed ports
// For device families that do not support this mode (e.g. Stratix V) the ram is not inferred

module dual_port_videoram #(
    parameter int BYTE_WIDTH = 8,
    ADDRESS_WIDTH = 11,
    BYTES = 4,
    DATA_WIDTH_R = BYTE_WIDTH * BYTES
) (
    input [ADDRESS_WIDTH-1:0] addr1,
    input [ADDRESS_WIDTH-1:0] addr2,
    input [BYTES-1:0] be1,
    input [BYTES-1:0] be2,
    input [DATA_WIDTH_R-1:0] data_in1,
    input [DATA_WIDTH_R-1:0] data_in2,
    input we1,
    we2,
    clk,
    output [DATA_WIDTH_R-1:0] data_out1,
    output [DATA_WIDTH_R-1:0] data_out2
);
    localparam RAM_DEPTH = 5000 >> 2;

    // model the RAM with two dimensional packed array
    logic [BYTES-1:0][BYTE_WIDTH-1:0] ram[0:RAM_DEPTH-1]  /* synthesis ramstyle = "no_rw_check" */;

    reg [DATA_WIDTH_R-1:0] data_reg1;
    reg [DATA_WIDTH_R-1:0] data_reg2;

    // port A
    always @(posedge clk) begin
        if (we1) begin
            // edit this code if using other than four bytes per word
            if (be1[0]) ram[addr1][0] <= data_in1[7:0];
            if (be1[1]) ram[addr1][1] <= data_in1[15:8];
            if (be1[2]) ram[addr1][2] <= data_in1[23:16];
            if (be1[3]) ram[addr1][3] <= data_in1[31:24];
        end
        data_reg1 <= ram[addr1];
    end

    assign data_out1 = data_reg1;

    // port B
    always @(posedge clk) begin
        if (we2) begin
            // edit this code if using other than four bytes per word
            if (be2[0]) ram[addr2][0] <= data_in2[7:0];
            if (be2[1]) ram[addr2][1] <= data_in2[15:8];
            if (be2[2]) ram[addr2][2] <= data_in2[23:16];
            if (be2[3]) ram[addr2][3] <= data_in2[31:24];
        end
        data_reg2 <= ram[addr2];
    end

    assign data_out2 = data_reg2;

endmodule : dual_port_videoram


// Quartus Prime SystemVerilog Template
//
// True Dual-Port RAM with different read/write addresses and single read/write clock
// and with a control for writing single bytes into the memory word; byte enable

// Read during write produces old data on ports A and B and old data on mixed ports
// For device families that do not support this mode (e.g. Stratix V) the ram is not inferred

module dualport_shared_ram #(
    parameter int BYTE_WIDTH = 8,
    ADDRESS_WIDTH = 11,
    BYTES = 4,
    DATA_WIDTH_R = BYTE_WIDTH * BYTES
) (
    input [ADDRESS_WIDTH-1:0] addr1,
    input [ADDRESS_WIDTH-1:0] addr2,
    input [BYTES-1:0] be1,
    input [BYTES-1:0] be2,
    input [DATA_WIDTH_R-1:0] data_in1,
    input [DATA_WIDTH_R-1:0] data_in2,
    input we1,
    input we2,
    input clk1,
    input clk2,
    output [DATA_WIDTH_R-1:0] data_out1,
    output [DATA_WIDTH_R-1:0] data_out2
);
    localparam RAM_DEPTH = 8192 >> 2;

    // model the RAM with two dimensional packed array
    /* verilator lint_off MULTIDRIVEN */
    logic [BYTES-1:0][BYTE_WIDTH-1:0] ram[0:RAM_DEPTH-1]  /* synthesis ramstyle = "no_rw_check" */;
    /* verilator lint_on MULTIDRIVEN */

    reg [DATA_WIDTH_R-1:0] data_reg1;
    reg [DATA_WIDTH_R-1:0] data_reg2;

    // port A
    always @(posedge clk1) begin
        if (we1) begin
            // edit this code if using other than four bytes per word
            if (be1[0]) ram[addr1][0] <= data_in1[7:0];
            if (be1[1]) ram[addr1][1] <= data_in1[15:8];
            if (be1[2]) ram[addr1][2] <= data_in1[23:16];
            if (be1[3]) ram[addr1][3] <= data_in1[31:24];
        end
        data_reg1 <= ram[addr1];
    end

    assign data_out1 = data_reg1;

    // port B
    always @(posedge clk2) begin
        if (we2) begin
            // edit this code if using other than four bytes per word
            if (be2[0]) ram[addr2][0] <= data_in2[7:0];
            if (be2[1]) ram[addr2][1] <= data_in2[15:8];
            if (be2[2]) ram[addr2][2] <= data_in2[23:16];
            if (be2[3]) ram[addr2][3] <= data_in2[31:24];
        end
        data_reg2 <= ram[addr2];
    end

    assign data_out2 = data_reg2;

endmodule : dualport_shared_ram




