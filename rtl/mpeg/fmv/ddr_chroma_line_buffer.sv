
// For U and V which needs to be doubled in height.
// To avoid fetching the same data twice, we cache it here
module ddr_chroma_line_buffer (
    // Input
    input clk_in,
    input reset,
    input [63:0] wdata,
    input we,
    // Output
    input clk_out,
    input [7:0] raddr,  // 256 x 8
    output bit [7:0] q
);

    // The maximum resolution for MPEG should be 384
    // Since U and V are halfed, we need 192 pixels of storage
    // To be safe, we go for 200

    bit [4:0] waddr;  // 32 x 64
    bit [7:0][7:0] ram[256/8];

    always_ff @(posedge clk_in) begin
        if (reset) waddr <= 0;

        if (we) begin
            ram[waddr] <= wdata;
            waddr <= waddr + 1;
        end
    end

    always_ff @(posedge clk_out) begin
        q <= ram[raddr[7:3]][raddr[2:0]];
    end

endmodule : ddr_chroma_line_buffer

