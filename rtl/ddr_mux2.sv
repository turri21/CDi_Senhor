`timescale 1 ns / 1 ps

// inspired by https://github.com/MiSTer-devel/Arcade-TaitoF2_MiSTer/blob/main/rtl/ddram.sv
module ddr_mux2 (
    input clk,

    ddr_if.to_host x,

    ddr_if.from_host a,
    ddr_if.from_host b
);

    reg a_active = 0;

    always_comb begin
        a.rdata = x.rdata;
        b.rdata = x.rdata;

        if (a_active) begin
            x.addr = a.addr;
            x.wdata = a.wdata;
            x.read = a.read;
            x.write = a.write;
            x.burstcnt = a.burstcnt;
            x.byteenable = a.byteenable;

            a.busy = x.busy;
            a.rdata_ready = x.rdata_ready;
            a.rdata = x.rdata;

            b.busy = 1;
            b.rdata_ready = 0;
        end else begin
            x.addr = b.addr;
            x.wdata = b.wdata;
            x.read = b.read;
            x.write = b.write;
            x.burstcnt = b.burstcnt;
            x.byteenable = b.byteenable;

            b.busy = x.busy;
            b.rdata_ready = x.rdata_ready;
            b.rdata = x.rdata;

            a.busy = 1;
            a.rdata_ready = 0;
        end
    end

    assign x.acquire = a.acquire | b.acquire;

    always_ff @(posedge clk) begin
        if (a.acquire & ~b.acquire) a_active <= 1;
        if (~a.acquire & b.acquire) a_active <= 0;
    end

endmodule
