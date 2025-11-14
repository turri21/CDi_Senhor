`include "../util.svh"

module yuv_frame_adr_fifo (
    input clk,
    input reset,
    // Input
    input planar_yuv_s wdata,
    input we,
    // Output
    input strobe,
    output bit valid,
    output planar_yuv_s q,
    // State
    output [3:0] cnt
);

    planar_yuv_s ram[16];

    // Clock domain of output
    bit [3:0] raddr;  // 512 x 8

    // Clock domain of input
    bit [3:0] waddr;  // 64 x 64

    assign cnt = waddr - raddr;

    always_ff @(posedge clk) begin
        if (reset) begin
            waddr <= 0;
            raddr <= 0;
        end else if (we) begin
            ram[waddr] <= wdata;
            waddr <= waddr + 1;

            assert (cnt < 10);
            assert (cnt < 10);
        end

        if (strobe) begin
            raddr <= raddr + 1;

            assert (cnt > 0);
            assert (cnt > 0);
        end

        q <= ram[raddr];
        valid <= raddr != waddr;
    end

endmodule : yuv_frame_adr_fifo

