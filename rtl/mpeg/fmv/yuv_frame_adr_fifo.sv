`include "../util.svh"

module yuv_frame_adr_fifo (
    // Input
    input clk_in,
    input reset_in,
    input planar_yuv_s wdata,
    input we,
    // Output
    input reset_out,
    input clk_out,
    input strobe,
    output bit valid,
    output planar_yuv_s q
);

    planar_yuv_s ram[16];

    // Clock domain of output
    bit [3:0] raddr;  // 512 x 8

    // Clock domain of input
    bit [3:0] waddr;  // 64 x 64

    // verilog_format: off
    // Transfer waddr from clk_in to clk_out
    bit [3:0] waddr_gray;
    b2g_converter #(.WIDTH(4)) waddr_to_gray1 (.binary(waddr),.gray(waddr_gray));
    bit [3:0] waddr_q;
    bit [3:0] waddr_q2;
    bit [3:0] waddr_q3;
    always @(posedge clk_in) waddr_q <= waddr_gray;
    always @(posedge clk_out) waddr_q2 <= waddr_q;
    always @(posedge clk_out) waddr_q3 <= waddr_q2;
    bit [3:0] waddr_clkout;
    g2b_converter #(.WIDTH(4)) waddr_to_binary1 (.binary(waddr_clkout),.gray(waddr_q3));

    // Transfer raddr from clk_out to clk_in
    bit [3:0] raddr_gray;
    b2g_converter #(.WIDTH(4)) raddr_to_gray2 (.binary(raddr),.gray(raddr_gray));
    bit [3:0] raddr_q;
    bit [3:0] raddr_q2;
    bit [3:0] raddr_q3;
    always @(posedge clk_out) raddr_q <= raddr_gray;
    always @(posedge clk_in) raddr_q2 <= raddr_q;
    always @(posedge clk_in) raddr_q3 <= raddr_q2;
    bit [3:0] raddr_clkin;
    g2b_converter #(.WIDTH(4)) raddr_to_binary2 (.binary(raddr_clkin),.gray(raddr_q3));
    
    // verilog_format: on

    wire [3:0] cnt_clkin = waddr - raddr_clkin;
    wire [3:0] cnt_clkout = waddr_clkout - raddr;

    always_ff @(posedge clk_in) begin
        if (reset_in) waddr <= 0;
        else if (we) begin
            ram[waddr] <= wdata;
            waddr <= waddr + 1;

            assert (cnt_clkout < 10);
            assert (cnt_clkin < 10);
        end
    end

    always_ff @(posedge clk_out) begin
        if (reset_out) raddr <= 0;
        else if (strobe) begin
            raddr <= raddr + 1;

            assert (cnt_clkout > 0);
            assert (cnt_clkin > 0);
        end

        q <= ram[raddr];
        valid <= cnt_clkout != 0;
    end

endmodule : yuv_frame_adr_fifo

