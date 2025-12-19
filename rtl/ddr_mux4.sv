`timescale 1 ns / 1 ps

// inspired by https://github.com/MiSTer-devel/Arcade-TaitoF2_MiSTer/blob/main/rtl/ddram.sv
module ddr_mux4 (
    input clk,

    ddr_if.to_host x,

    ddr_if.from_host a,
    ddr_if.from_host b,
    ddr_if.from_host c,
    ddr_if.from_host d
);

    bit a_active = 0;
    bit b_active = 0;
    bit c_active = 0;
    bit d_active = 0;

    always_comb begin
        a.rdata = x.rdata;
        b.rdata = x.rdata;
        c.rdata = x.rdata;
        d.rdata = x.rdata;

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
            c.busy = 1;
            c.rdata_ready = 0;
            d.busy = 1;
            d.rdata_ready = 0;
        end else if (b_active) begin
            x.addr = b.addr;
            x.wdata = b.wdata;
            x.read = b.read;
            x.write = b.write;
            x.burstcnt = b.burstcnt;
            x.byteenable = b.byteenable;

            b.busy = x.busy;
            b.rdata_ready = x.rdata_ready;
            b.rdata = x.rdata;

            c.busy = 1;
            c.rdata_ready = 0;
            a.busy = 1;
            a.rdata_ready = 0;
            d.busy = 1;
            d.rdata_ready = 0;
        end else if (c_active) begin
            x.addr = c.addr;
            x.wdata = c.wdata;
            x.read = c.read;
            x.write = c.write;
            x.burstcnt = c.burstcnt;
            x.byteenable = c.byteenable;

            c.busy = x.busy;
            c.rdata_ready = x.rdata_ready;
            c.rdata = x.rdata;

            a.busy = 1;
            a.rdata_ready = 0;
            b.busy = 1;
            b.rdata_ready = 0;
            d.busy = 1;
            d.rdata_ready = 0;
        end else if (d_active) begin
            x.addr = d.addr;
            x.wdata = d.wdata;
            x.read = d.read;
            x.write = d.write;
            x.burstcnt = d.burstcnt;
            x.byteenable = d.byteenable;

            d.busy = x.busy;
            d.rdata_ready = x.rdata_ready;
            d.rdata = x.rdata;

            a.busy = 1;
            a.rdata_ready = 0;
            b.busy = 1;
            b.rdata_ready = 0;
            c.busy = 1;
            c.rdata_ready = 0;
        end else begin
            a.busy = 1;
            a.rdata_ready = 0;
            b.busy = 1;
            b.rdata_ready = 0;
            c.busy = 1;
            c.rdata_ready = 0;
            d.busy = 1;
            d.rdata_ready = 0;

            x.addr = b.addr;
            x.wdata = b.wdata;
            x.read = 0;
            x.write = 0;
            x.burstcnt = 0;
            x.byteenable = 0;
        end
    end

    assign x.acquire = a.acquire | b.acquire | c.acquire | d.acquire;

    always_ff @(posedge clk) begin
        a_active <= 0;
        b_active <= 0;
        c_active <= 0;
        d_active <= 0;

        if (a_active && a.acquire) begin
            a_active <= 1;
        end else if (b_active && b.acquire) begin
            b_active <= 1;
        end else if (c_active && c.acquire) begin
            c_active <= 1;
        end else if (d_active && d.acquire) begin
            d_active <= 1;
        end else if (a.acquire) begin
            a_active <= 1;
        end else if (b.acquire) begin
            b_active <= 1;
        end else if (c.acquire) begin
            c_active <= 1;
        end else if (d.acquire) begin
            d_active <= 1;
        end
    end

endmodule
