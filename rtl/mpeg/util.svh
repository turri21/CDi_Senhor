
function [31:0] reverse_endian_32;
    input [31:0] data_in;
    begin
        reverse_endian_32 = {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
    end
endfunction

