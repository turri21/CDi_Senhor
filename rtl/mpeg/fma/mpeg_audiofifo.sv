`timescale 1 ns / 1 ns

module mpeg_audiofifo (
    input clk,
    input reset,
    audiostream.sink in,
    audiostream.source out,
    output nearly_full,
    output half_full
);

    bit signed [15:0] mem[512];
    bit [8:0] read_index_d;
    bit [8:0] read_index_q;
    bit [8:0] write_index;
    bit [9:0] count;

    // The memory introduces one cycle delay. This is an issue
    // when the FIFO is empty. We want to avoid using the memory readout
    // when reading from a value that is just written
    bit indizes_equal_during_write_d;
    bit indizes_equal_during_write_q;

    assign out.write   = count != 0 && !reset && !indizes_equal_during_write_q;
    assign in.strobe   = count < 510 && !reset && in.write;

    // Every MPEG synthesis will create 32 samples
    // Let's have at least 70 samples to not starve during frame change
    assign nearly_full = count >= 510;
    assign half_full   = count >= 70;

    always_comb begin
        read_index_d = read_index_q;
        if (out.strobe && out.write) begin
            read_index_d = read_index_q + 1;
        end

        indizes_equal_during_write_d = write_index == read_index_d && in.write;
    end

    always_ff @(posedge clk) begin
        if (in.strobe && !out.strobe) count <= count + 1;
        if (!in.strobe && out.strobe && count != 0) count <= count - 1;

        if (reset) begin
            write_index <= 0;
            read_index_q <= 0;
            count <= 0;
        end else begin
            if (in.write && in.strobe) begin
                mem[write_index] <= in.sample;
                write_index <= write_index + 1;
            end

            out.sample <= mem[read_index_d];
            read_index_q <= read_index_d;
            indizes_equal_during_write_q <= indizes_equal_during_write_d;
        end
    end
endmodule
