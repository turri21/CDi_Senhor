// https://www.intel.com/content/www/us/en/docs/programmable/683082/21-3/mixed-width-dual-port-ram.html
// 32768x8 write and 8192x32 read
// So, this is 32KB of memory
module mpeg_input_stream_fifo_32k (
    input [14:0] waddr,
    input [7:0] wdata,
    input we,
    input clkw,
    input clkr,
    input [12:0] raddr,
    output logic [31:0] q
);

    logic [3:0][7:0] ram[8192];
    always_ff @(posedge clkw) begin
        if (we) ram[waddr[14:2]][waddr[1:0]] <= wdata;
    end

    always_ff @(posedge clkr) begin
        q <= ram[raddr];
    end
endmodule : mpeg_input_stream_fifo_32k
