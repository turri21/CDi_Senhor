`timescale 1 ns / 1 ps

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
    input clk,
    output [DATA_WIDTH_R-1:0] data_out1,
    output [DATA_WIDTH_R-1:0] data_out2
);

    // For reasons yet unknown, Quartus is synthesizing this
    // templated RAM, but the data read from it is corrupted.
    // Because of this, black box RAM from Quartus is used instead for synthesis
`ifdef VERILATOR
    localparam RAM_DEPTH = 2048;

    // model the RAM with two dimensional packed array
    /* verilator lint_off MULTIDRIVEN */
    logic [BYTES-1:0][BYTE_WIDTH-1:0] ram[0:RAM_DEPTH-1]  /* synthesis ramstyle = "no_rw_check" */;
    /* verilator lint_on MULTIDRIVEN */

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

`else

    altsyncram altsyncram_component (
        .address_a(addr1),
        .address_b(addr2),
        .byteena_a(be1),
        .byteena_b(be2),
        .clock0(clk),
        .data_a(data_in1),
        .data_b(data_in2),
        .wren_a(we1),
        .wren_b(we2),
        .q_a(data_out1),
        .q_b(data_out2),
        .aclr0(1'b0),
        .aclr1(1'b0),
        .addressstall_a(1'b0),
        .addressstall_b(1'b0),
        .clock1(1'b1),
        .clocken0(1'b1),
        .clocken1(1'b1),
        .clocken2(1'b1),
        .clocken3(1'b1),
        .eccstatus(),
        .rden_a(1'b1),
        .rden_b(1'b1)
    );

    // verilog_format: off
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byteena_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2048,
		altsyncram_component.numwords_b = 2048,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 11,
		altsyncram_component.widthad_b = 11,
		altsyncram_component.width_a = 32,
		altsyncram_component.width_b = 32,
		altsyncram_component.width_byteena_a = 4,
		altsyncram_component.width_byteena_b = 4,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";
    // verilog_format: on
`endif
endmodule : dualport_shared_ram
