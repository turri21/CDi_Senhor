
`include "../../bus.svh"
`include "../../videotypes.svh"
`include "../util.svh"

module frameplayer (
    input clk,
    input clkddr,
    input reset,

    ddr_if.to_host ddrif,

    output rgb888_s vidout,
    input           hsync,
    input           vsync,
    input           hblank,
    input           vblank
);

    assign ddrif.byteenable = 8'hff;
    assign ddrif.write = 0;

    bit [28:0] address_y;
    bit [28:0] address_u;
    bit [28:0] address_v;

    enum bit [1:0] {
        IDLE,
        WAITING,
        SETTLE
    } fetchstate;

    wire y_half_empty;
    wire u_half_empty;
    wire v_half_empty;
    bit luma_fifo_strobe;
    bit chroma_fifo_strobe;

    wire y_valid;
    wire u_valid;
    wire v_valid;
    yuv_s current_color;

    bit target_y;
    bit target_u;
    bit target_v;

    wire new_line_started = hsync && !hsync_q;
    wire new_line_started_clkddr;

    wire reset_clkddr;
    wire vblank_clkddr;

    ddr_to_byte_fifo fifo_y (
        .clk_in(clkddr),
        .reset_in(vblank_clkddr),
        .reset_out(vblank),
        .wdata(ddrif.rdata),
        .we(ddrif.rdata_ready && target_y),
        .half_empty(y_half_empty),
        .clk_out(clk),
        .strobe(luma_fifo_strobe),
        .valid(y_valid),
        .q(current_color.y)
    );

    flag_cross_domain cross_new_line_started (
        .clk_a(clk),
        .clk_b(clkddr),
        .flag_in_clk_a(new_line_started),
        .flag_out_clk_b(new_line_started_clkddr)
    );

    flag_cross_domain cross_reset (
        .clk_a(clk),
        .clk_b(clkddr),
        .flag_in_clk_a(reset),
        .flag_out_clk_b(reset_clkddr)
    );

    signal_cross_domain cross_vblank (
        .clk_a(clk),
        .clk_b(clkddr),
        .signal_in_clk_a(vblank),
        .signal_out_clk_b(vblank_clkddr)
    );

    bit [7:0] chroma_read_addr;

    ddr_chroma_line_buffer line_buffer_u (
        .clk_in(clkddr),
        .reset(new_line_started_clkddr),
        .wdata(ddrif.rdata),
        .we(ddrif.rdata_ready && target_u),
        .clk_out(clk),
        .q(current_color.u),
        .raddr(chroma_read_addr)
    );

    ddr_chroma_line_buffer line_buffer_v (
        .clk_in(clkddr),
        .reset(new_line_started_clkddr),
        .wdata(ddrif.rdata),
        .we(ddrif.rdata_ready && target_v),
        .clk_out(clk),
        .q(current_color.v),
        .raddr(chroma_read_addr)
    );


    bit [10:0] pixelcnt;
    bit hsync_q;
    bit line_alternate;
    bit u_requested;
    bit v_requested;

    always_ff @(posedge clk) begin
        hsync_q <= hsync;

        if (chroma_fifo_strobe) chroma_read_addr <= chroma_read_addr + 1;

        if (hblank) begin
            pixelcnt <= 0;
            chroma_fifo_strobe <= 0;
            luma_fifo_strobe <= 0;
            chroma_read_addr <= 0;
        end else if (y_valid && !vblank && !hblank && pixelcnt < 368 * 4) begin
            pixelcnt <= pixelcnt + 1;
            luma_fifo_strobe <= pixelcnt[1:0] == 3;
            chroma_fifo_strobe <= pixelcnt[2:0] == 7;
        end else begin
            chroma_fifo_strobe <= 0;
            luma_fifo_strobe   <= 0;
        end

        /*
        if (fifo_strobe) pixeldebugcnt <= pixeldebugcnt + 1;
        if (hblank && pixeldebugcnt > 0) begin
            $display("Pixels %d", pixeldebugcnt);
            pixeldebugcnt <= 0;
        end
        */
    end

    bit [4:0] data_burst_cnt;

    // 0011 like the N64 core to force a base of 0x30000000
    localparam bit [3:0] DDR_CORE_BASE = 4'b0011;

    always_ff @(posedge clkddr) begin
        if (!ddrif.busy) begin
            ddrif.read <= 0;
        end

        if (reset_clkddr || vblank_clkddr) begin
            fetchstate <= IDLE;
            address_y <= 29'h0;
            address_v <= 29'h15900;  // 368*240 = 88320
            address_u <= 29'h1af40;  // 368*240 + 88320/4
            target_y <= 0;
            target_u <= 0;
            target_v <= 0;
            line_alternate <= 0;
            u_requested <= 0;
            v_requested <= 0;
        end else begin
            if (new_line_started_clkddr) begin
                line_alternate <= !line_alternate;

                if (!line_alternate) begin
                    u_requested <= 0;
                    v_requested <= 0;
                end
            end

            case (fetchstate)
                IDLE: begin
                    if (!u_requested) begin
                        u_requested <= 1;
                        ddrif.addr <= {DDR_CORE_BASE, address_u[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        address_u <= address_u + 8 * 184 / 8;
                        ddrif.burstcnt <= 25;
                        data_burst_cnt <= 25;
                        fetchstate <= WAITING;
                        target_u <= 1;
                    end else if (!v_requested) begin
                        v_requested <= 1;
                        ddrif.addr <= {DDR_CORE_BASE, address_v[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        address_v <= address_v + 8 * 184 / 8;
                        ddrif.burstcnt <= 25;
                        data_burst_cnt <= 25;
                        fetchstate <= WAITING;
                        target_v <= 1;
                    end else if (y_half_empty) begin
                        ddrif.addr <= {DDR_CORE_BASE, address_y[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        ddrif.burstcnt <= 2;
                        data_burst_cnt <= 2;
                        address_y <= address_y + 8 * 2;
                        fetchstate <= WAITING;
                        target_y <= 1;
                    end
                end
                WAITING: begin
                    if (ddrif.rdata_ready) begin
                        data_burst_cnt <= data_burst_cnt - 1;
                    end
                    if (data_burst_cnt == 0) begin
                        fetchstate <= IDLE;
                        target_y <= 0;
                        target_u <= 0;
                        target_v <= 0;
                        ddrif.acquire <= 0;
                    end
                end
                default: begin

                end
            endcase

        end
    end

    bit signed [9:0] r;
    bit signed [9:0] g;
    bit signed [9:0] b;

    function [7:0] clamp8(input signed [9:0] val);
        if (val > 255) clamp8 = 255;
        else if (val < 0) clamp8 = 0;
        else clamp8 = val[7:0];
    endfunction


    always_comb begin
        bit signed [9:0] y, u, v;

        y = {2'b00, current_color.y};
        u = {2'b00, current_color.u};
        v = {2'b00, current_color.v};

        // According to chapter 7.1 DELTA YUV DECODER
        r = (y * 256 + 351 * (v - 128)) / 256;
        g = (y * 256 - 86 * (u - 128) - 179 * (v - 128)) / 256;
        b = (y * 256 + 444 * (u - 128)) / 256;

        vidout.r = clamp8(r);
        vidout.g = clamp8(g);
        vidout.b = clamp8(b);
    end

endmodule

module ddr_to_byte_fifo (
    // Input
    input clk_in,
    input reset_in,
    input [63:0] wdata,
    input we,
    output half_empty,  // True if a space of 128 bit is available
    // Output
    input reset_out,
    input clk_out,
    input strobe,
    output bit valid,
    output bit [7:0] q
);

    bit [7:0][7:0] ram[8];

    // Clock domain of output
    bit [5:0] raddr;  // 32 x 8

    // Clock domain of input
    bit [2:0] waddr;  // 4 x 64

    // verilog_format: off
    // Transfer waddr from clk_in to clk_out
    bit [2:0] waddr_gray;
    b2g_converter #(.WIDTH(3)) waddr_to_gray1 (.binary(waddr),.gray(waddr_gray));
    bit [2:0] waddr_q;
    bit [2:0] waddr_q2;
    bit [2:0] waddr_q3;
    always @(posedge clk_in) waddr_q <= waddr_gray;
    always @(posedge clk_out) waddr_q2 <= waddr_q;
    always @(posedge clk_out) waddr_q3 <= waddr_q2;
    bit [2:0] waddr_clkout;
    g2b_converter #(.WIDTH(3)) waddr_to_binary1 (.binary(waddr_clkout),.gray(waddr_q3));

    // Transfer raddr from clk_out to clk_in
    bit [5:0] raddr_gray;
    b2g_converter #(.WIDTH(6)) raddr_to_gray2 (.binary(raddr),.gray(raddr_gray));
    bit [5:0] raddr_q;
    bit [5:0] raddr_q2;
    bit [5:0] raddr_q3;
    always @(posedge clk_out) raddr_q <= raddr_gray;
    always @(posedge clk_in) raddr_q2 <= raddr_q;
    always @(posedge clk_in) raddr_q3 <= raddr_q2;
    bit [5:0] raddr_clkin;
    g2b_converter #(.WIDTH(6)) raddr_to_binary2 (.binary(raddr_clkin),.gray(raddr_q3));
    
    // verilog_format: on

    wire [5:0] cnt_clkin = {waddr, 3'b0} - raddr_clkin;
    wire [5:0] cnt_clkout = {waddr_clkout, 3'b0} - raddr;

    // The threshold can't be set to exactly half.
    // There is a latency of this signal because of the clock synchronization above
    // The supplying machine might always provide more than requested becaues of this!
    assign half_empty = cnt_clkin < 16;

    always_ff @(posedge clk_in) begin
        if (reset_in) waddr <= 0;

        if (we) begin
            ram[waddr] <= wdata;
            waddr <= waddr + 1;
        end
    end

    always_ff @(posedge clk_out) begin
        if (reset_out) raddr <= 0;

        if (strobe) begin
            raddr <= raddr + 1;
        end

        q <= ram[raddr[5:3]][raddr[2:0]];
        valid <= cnt_clkout != 0;
    end

endmodule : ddr_to_byte_fifo


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

