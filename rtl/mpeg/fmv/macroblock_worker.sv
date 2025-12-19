module macroblock_worker (
    input clk_mpeg,
    input reset_dsp_enabled_clk_mpeg,

    input dmem_cmd_valid_1,
    input dmem_cmd_ready_1,
    input [31:0] dmem_cmd_payload_address_1,
    input [31:0] dmem_cmd_payload_data_1,
    input [3:0] dmem_cmd_payload_mask_1,
    input dmem_cmd_payload_write_1,

    output [31:0] shared12_out_1,

    ddr_if.to_host ddrif
);
    parameter bit [3:0] unit_index = 0;

    assign ddrif.byteenable = 8'hff;

    wire [31:0] memory_out_i2;
    wire [31:0] memory_out_d2;

    wire [31:0] shared12_out_2;
    bit  [31:0] soft_state2  /*verilator public_flat_rd*/ = 0;

    worker_firmware_memory core2mem (
        .clk(clk_mpeg),
        .addr2(imem_cmd_payload_address_2[11:2]),
        .data_out2(memory_out_i2),
        .be2(0),
        .we2(0),
        .data_in2(0),
        .addr1(dmem_cmd_payload_address_2[11:2]),
        .data_in1(dmem_cmd_payload_data_2),
        .we1(dmem_cmd_payload_address_2[31:28] == 0 && dmem_cmd_valid_2 && dmem_cmd_ready_2 && 
                dmem_cmd_payload_write_2 && !reset_dsp_enabled_clk_mpeg),
        .be1(dmem_cmd_payload_mask_2),
        .data_out1(memory_out_d2)
    );

    dualport_shared_ram shared12 (
        .clk(clk_mpeg),
        .addr2(dmem_cmd_payload_address_2[13:2]),
        .data_out2(shared12_out_2),
        .be2(dmem_cmd_payload_mask_2),
        .we2(dmem_cmd_payload_address_2[31:28]==4 && dmem_cmd_valid_2 && dmem_cmd_ready_2 && dmem_cmd_payload_write_2),
        .data_in2(dmem_cmd_payload_data_2),
        .addr1(dmem_cmd_payload_address_1[13:2]),
        .data_in1(dmem_cmd_payload_data_1),
        .we1(dmem_cmd_payload_address_1[31:28]==4 && dmem_cmd_payload_address_1[27:24] == unit_index && dmem_cmd_valid_1 && dmem_cmd_ready_1 && dmem_cmd_payload_write_1),
        .be1(dmem_cmd_payload_mask_1),
        .data_out1(shared12_out_1)
    );


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

    /*verilator tracing_off*/
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
        .clk(clk_mpeg),
        .reset(reset_dsp_enabled_clk_mpeg)
    );
    /*verilator tracing_on*/

    bit cache_miss_2;
    bit [2:0] cache_hit_adr_2;
    wire [63:0] cache_2_out;
    bit [1:0] data_burst_cnt_2;
    bit [23-3:0] cache_adr_2[8] = '{default: 8000};
    bit [7:0] cache_entry_valid_2;
    bit [2:0] cache_write_adr_2 = 0;

`ifdef VERILATOR
    bit [23-3:0] missed_cache_adr_2[16] = '{default: 8000};
    bit [3:0] missed_cache_adr_index_2;
`endif

    always_comb begin
        integer i;
        bit cache_hit;

        imem_cmd_ready_2 = 1;
        imem_rsp_payload_word_2 = memory_out_i2;

        dmem_cmd_ready_2 = 1;
        dmem_rsp_payload_data_2 = memory_out_d2;

        // Stall on DDR write until resolved
        if (ddrif.acquire && dmem_cmd_valid_2 && dmem_cmd_payload_write_2 && dmem_cmd_payload_address_2[31:28] == 4'd5)
            dmem_cmd_ready_2 = 0;

        // Stall on DDR read until resolved
        if (dmem_cmd_payload_address_2_q[31:28] == 4'd5 && !dmem_cmd_payload_write_2_q && dmem_cmd_valid_2_q && ddrif.acquire)
            dmem_cmd_ready_2 = 0;

        // Handle read directly after write to avoid read and write at the same time
        if (dmem_cmd_payload_address_2[31:28] == 4'd5 && !dmem_cmd_payload_write_2 && dmem_cmd_valid_2 && ddrif.acquire)
            dmem_cmd_ready_2 = 0;

        cache_hit_adr_2 = 0;
        cache_miss_2 = 0;
        cache_hit = 0;
        for (i = 0; i < 8; i++) begin
            if (cache_entry_valid_2[i] && (dmem_cmd_payload_address_2[23:3] >= cache_adr_2[i]) && (dmem_cmd_payload_address_2[23:3] <= cache_adr_2[i] + 2)) begin
                cache_hit_adr_2 = 3'(i);
                cache_hit = 1;
            end
        end
        cache_miss_2 = !cache_hit;

        if (dmem_cmd_valid_2_q) begin
            case (dmem_cmd_payload_address_2_q[31:28])
                4'd5: begin  // Video SRAM region
                    dmem_rsp_payload_data_2 = dmem_cmd_payload_address_2_q[2] ?
                     cache_2_out[63:32] :
                     cache_2_out[31:0];
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
    bit signed [15:0] shared_buffer_level = 0;

    wire shared_buffer_level_inc = dmem_cmd_payload_address_1 == 32'h10000014 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1;
    wire shared_buffer_level_dec = dmem_cmd_payload_address_2 == 32'h10000014 && dmem_cmd_payload_write_2 && dmem_cmd_valid_2;

    bit [31:0] dmem_cmd_payload_address_2_q;
    bit dmem_cmd_valid_2_q;
    bit dmem_cmd_ready_2_q;
    bit dmem_cmd_payload_write_2_q;

    // Instruction fetch logic for core 2
    always_ff @(posedge clk_mpeg) begin
        imem_rsp_valid_2 <= 0;

        if (imem_cmd_valid_2) begin
            imem_rsp_valid_2 <= 1;
            imem_rsp_payload_id_2 <= imem_cmd_payload_id_2;
        end
    end

    // 0011 like the N64 core to force a base of 0x30000000
    localparam bit [3:0] DDR_CORE_BASE = 4'b0011;

    bit [2:0] cache_temp_adr_20;
    bit [1:0] cache_temp_adr_21;  // range 0 to 2. never 3

    cache64_8_3 cache_2 (
        .data(ddrif.rdata),
        .read_addr({cache_temp_adr_21, cache_temp_adr_20}),
        .write_addr({data_burst_cnt_2, cache_write_adr_2}),
        .we(data_burst_cnt_2 != 3 && ddrif.rdata_ready),
        .clk(clk_mpeg),
        .q(cache_2_out)
    );

    always_comb begin
        cache_temp_adr_20 = cache_hit_adr_2;
        cache_temp_adr_21 = 2'(dmem_cmd_payload_address_2[23:3] - cache_adr_2[cache_hit_adr_2]);
        // Handle special case of reading directly after burst has finished
        if (ddrif.rdata_ready && data_burst_cnt_2 == 2) begin
            cache_temp_adr_20 = cache_write_adr_2;
            cache_temp_adr_21 = 0;
        end
    end

    always_ff @(posedge clk_mpeg) begin
        shared_buffer_level <= shared_buffer_level + (shared_buffer_level_inc ? 1:0) - (shared_buffer_level_dec ? 1 : 0);
    end

    always_ff @(posedge clk_mpeg) begin
        integer i;

        dmem_rsp_valid_2 <= 0;

        if (!ddrif.busy && ddrif.write) begin
            ddrif.write   <= 0;
            ddrif.acquire <= 0;
        end

        if (!ddrif.busy && ddrif.read) begin
            ddrif.read <= 0;
        end

        if (data_burst_cnt_2 != 3 && ddrif.rdata_ready) begin
            data_burst_cnt_2 <= data_burst_cnt_2 + 1;
            if (data_burst_cnt_2 == 2) begin
                ddrif.read <= 0;
                ddrif.acquire <= 0;
                dmem_rsp_valid_2 <= 1;
                cache_write_adr_2 <= cache_write_adr_2 + 1;
            end
        end

        if (dmem_cmd_ready_2) begin
            if (dmem_cmd_valid_2) begin
                dmem_cmd_payload_address_2_q <= dmem_cmd_payload_address_2;
                dmem_cmd_payload_write_2_q   <= dmem_cmd_payload_write_2;
            end
            dmem_cmd_valid_2_q <= dmem_cmd_valid_2;
        end
        dmem_cmd_ready_2_q <= dmem_cmd_ready_2;


        if (dmem_cmd_payload_address_2 == 32'h1000000c && dmem_cmd_payload_write_2 && dmem_cmd_valid_2 && dmem_cmd_ready_2) begin
            $display("Core 2 stopped at %x with code %x", imem_cmd_payload_address_2,
                     dmem_cmd_payload_data_2);
            $finish();
        end

        if (dmem_cmd_payload_address_2 == 32'h10000030 && dmem_cmd_payload_write_2 && dmem_cmd_valid_2)
            soft_state2 <= dmem_cmd_payload_data_2;

        // Core 2 memory access
        if (dmem_cmd_valid_2 && dmem_cmd_ready_2) begin
            dmem_rsp_payload_id_2 <= dmem_cmd_payload_id_2;
            dmem_rsp_valid_2 <= 1;

            case (dmem_cmd_payload_address_2[31:28])
                4'd5: begin  // Core 1 private memory
                    //assert(dmem_cmd_payload_address_2[1:0] == 2'b00);

                    if (dmem_cmd_payload_write_2) begin
                        assert (ddrif.write == 0);
                        ddrif.addr <= {DDR_CORE_BASE, dmem_cmd_payload_address_2[27:3]};

                        if (dmem_cmd_payload_address_2[2] == 1'b1) begin
                            ddrif.write <= dmem_cmd_payload_mask_2[3];
                            ddrif.acquire <= dmem_cmd_payload_mask_2[3];
                            ddrif.burstcnt <= 1;
                            // verilog_format: off
                            if (dmem_cmd_payload_mask_2[0]) ddrif.wdata[39:32] <= dmem_cmd_payload_data_2[7:0];
                            if (dmem_cmd_payload_mask_2[1]) ddrif.wdata[47:40] <= dmem_cmd_payload_data_2[15:8];
                            if (dmem_cmd_payload_mask_2[2]) ddrif.wdata[55:48] <= dmem_cmd_payload_data_2[23:16];
                            if (dmem_cmd_payload_mask_2[3]) ddrif.wdata[63:56] <= dmem_cmd_payload_data_2[31:24];
                        end else begin
                            if (dmem_cmd_payload_mask_2[0]) ddrif.wdata[7:0] <= dmem_cmd_payload_data_2[7:0];
                            if (dmem_cmd_payload_mask_2[1]) ddrif.wdata[15:8] <= dmem_cmd_payload_data_2[15:8];
                            if (dmem_cmd_payload_mask_2[2]) ddrif.wdata[23:16] <= dmem_cmd_payload_data_2[23:16];
                            if (dmem_cmd_payload_mask_2[3]) ddrif.wdata[31:24] <= dmem_cmd_payload_data_2[31:24];
                        end
                        // verilog_format: on
                    end else if (cache_miss_2) begin
                        // $display("Cache Miss 2 %x %x", dmem_cmd_payload_address_2, dmem_cmd_payload_address_2[27:3]);
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        ddrif.burstcnt <= 3;
                        data_burst_cnt_2 <= 0;
                        dmem_rsp_valid_2 <= 0;
                        ddrif.addr <= {DDR_CORE_BASE, dmem_cmd_payload_address_2[27:3]};
                        cache_adr_2[cache_write_adr_2] <= dmem_cmd_payload_address_2[23:3];
                        cache_entry_valid_2[cache_write_adr_2] <= 1;

`ifdef VERILATOR
                        // Check quality of cache. Can we get faster with a bigger cache?
                        for (i = 0; i < 16; i++) begin
                            if (dmem_cmd_payload_address_2[23:3] == missed_cache_adr_2[i]) begin
                                $display("Cache 2 Miss with recently requested address %x %x",
                                         dmem_cmd_payload_address_2,
                                         dmem_cmd_payload_address_2[27:3]);
                                //$finish();
                            end
                        end
                        missed_cache_adr_2[missed_cache_adr_index_2] <= dmem_cmd_payload_address_2[23:3];
                        missed_cache_adr_index_2 <= missed_cache_adr_index_2 + 1;
`endif
                    end else begin
                        //$display("Cache Hit %x %x",dmem_cmd_payload_address_2,dmem_cmd_payload_address_2[27:3]);
                    end

                end
                4'd4: begin  // Shared SRAM region
                end
                4'd1: begin  // I/O Area
                    if (dmem_cmd_payload_address_2[15:0] == 16'h1110) begin
                        //$display("Cache clear 2 at %x", dmem_cmd_payload_address_2);
                        cache_entry_valid_2 <= 0;
                    end
                end

                4'd0: begin  // Core 2 private memory
                end
                default: ;

            endcase
        end


    end

endmodule

// Quartus Prime Verilog Template
// Simple Dual Port RAM with separate read/write addresses and
// single read/write clock

module cache64_8_3 #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 5
) (
    input [(DATA_WIDTH-1):0] data,
    input [(ADDR_WIDTH-1):0] read_addr,
    write_addr,
    input we,
    clk,
    output reg [(DATA_WIDTH-1):0] q
);

    // Declare the RAM variable
    // It can be smaller since only 8*3 elements are required
    reg [DATA_WIDTH-1:0] ram[8*3];

    always @(posedge clk) begin
        // Write
        if (we) ram[write_addr] <= data;

        // Read (if read_addr == write_addr, return OLD data).	To return
        // NEW data, use = (blocking write) rather than <= (non-blocking write)
        // in the write assignment.	 NOTE: NEW data may require extra bypass
        // logic around the RAM.
        q <= ram[read_addr];
    end

endmodule


