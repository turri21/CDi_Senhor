`timescale 1 ns / 1 ps


// https://www.intel.com/content/www/us/en/docs/programmable/683082/21-3/mixed-width-dual-port-ram.html
// 8192x8 write and 2048x32 read
// So, this is 8KB of memory
module mpeg_input_stream_fifo (
    input [12:0] waddr,
    input [7:0] wdata,
    input we,
    input clk,
    input [10:0] raddr,
    output logic [31:0] q
);

    logic [3:0][7:0] ram[2048];
    always_ff @(posedge clk) begin
        if (we) ram[waddr[12:2]][waddr[1:0]] <= wdata;
        q <= ram[raddr];
    end
endmodule : mpeg_input_stream_fifo

