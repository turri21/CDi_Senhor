`ifndef HEADER_UTIL
`define HEADER_UTIL

function [31:0] reverse_endian_32;
    input [31:0] data_in;
    begin
        reverse_endian_32 = {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
    end
endfunction

// https://vlsiverify.com/verilog/verilog-codes/binary-to-gray/
module b2g_converter #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] binary,
    output [WIDTH-1:0] gray
);
    genvar i;
    generate
        for (i = 0; i < WIDTH - 1; i++) begin : bits
            assign gray[i] = binary[i] ^ binary[i+1];
        end
    endgenerate

    assign gray[WIDTH-1] = binary[WIDTH-1];
endmodule

// from https://vlsiverify.com/verilog/verilog-codes/gray-to-binary/
module g2b_converter #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] gray,
    output [WIDTH-1:0] binary
);
    /*
  assign binary[0] = gray[3] ^ gray[2] ^ gray[1] ^ gray[0];
  assign binary[1] = gray[3] ^ gray[2] ^ gray[1];
  assign binary[2] = gray[3] ^ gray[2];
  assign binary[3] = gray[3];
  */
    // OR
    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : bits
            assign binary[i] = ^(gray >> i);
        end
    endgenerate
endmodule


// A try to make a parametrized function. Doesn't suit well with Quartus
// This statement doesn't work
// always @(posedge clk_in) waddr_q <= GrayConv#(2)::gray(waddr);
/*
virtual class GrayConv #(
    parameter WIDTH
);
    static int i;
    static function [WIDTH-1:0] gray(input [WIDTH-1:0] binary);
        begin
            for (i = 0; i < WIDTH - 1; i++) begin : bits
                assign gray[i] = binary[i] ^ binary[i+1];
            end
        end
    endfunction
endclass
*/

`endif
