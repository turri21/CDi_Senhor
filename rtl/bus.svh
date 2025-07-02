`ifndef BUS_SVH
`define BUS_SVH

interface bus68k (
    input clk
);
    bit write_strobe;
    bit as;
    bit lds;
    bit uds;
    bit [15:0] data_out;
    bit [23:1] addr;
    bit bus_ack;
    bit [15:0] data_in;

    modport master(output write_strobe, as, lds, uds, data_out, addr, input bus_ack, data_in);
    modport slave(input write_strobe, as, lds, uds, data_out, addr, output bus_ack, data_in);

endinterface


interface pixelstream (
    input clk
);

    bit write;
    bit strobe;
    bit [7:0] pixel;

    modport source(output write, pixel, input strobe);
    modport sink(input write, pixel, output strobe);
endinterface

interface bytestream ();
    bit write;
    bit [7:0] data;

    modport source(output write, data);
    modport sink(input write, data);
endinterface

interface parallelel_spi ();
    bit [7:0] miso;
    bit [7:0] mosi;
    bit write;

    modport master(output mosi, write, input miso);
    modport slave(input mosi, write, output miso);
endinterface


interface audiostream ();
    bit write;
    bit strobe;
    bit signed [15:0] sample;

    modport source(output write, sample, input strobe);
    modport sink(input write, sample, output strobe);
endinterface


`endif
