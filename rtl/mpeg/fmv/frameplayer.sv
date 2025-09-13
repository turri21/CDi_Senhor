
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
    input           vblank,

    input [28:0] frame_adr,
    input latch_frame
);

    assign ddrif.byteenable = 8'hff;
    assign ddrif.write = 0;

    bit [28:0] latched_frame_adr = 0;

    always_ff @(posedge clkddr) begin
        if (latch_frame) begin
            latched_frame_adr <= frame_adr;
            $display("Latched frame %x", latched_frame_adr);
        end
    end

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
    bit [8:0] linecnt;
    bit hsync_q;
    bit line_alternate;
    bit u_requested;
    bit v_requested;
    bit [8:0] frame_width = 368;
    bit [8:0] frame_height = 240;

    always_ff @(posedge clk) begin
        hsync_q <= hsync;

        if (reset || vsync) linecnt <= 0;
        else if (!vblank && hsync && !hsync_q) linecnt <= linecnt + 1;

        if (chroma_fifo_strobe) chroma_read_addr <= chroma_read_addr + 1;

        if (hblank || reset) begin
            pixelcnt <= 0;
            chroma_fifo_strobe <= 0;
            luma_fifo_strobe <= 0;
            chroma_read_addr <= 0;
        end else if (!vblank && !hblank && pixelcnt < frame_width << 2 && linecnt < frame_height) begin
            pixelcnt <= pixelcnt + 1;
            luma_fifo_strobe <= pixelcnt[1:0] == 3 - 2;
            chroma_fifo_strobe <= pixelcnt[2:0] == 7 - 2;
            assert (y_valid);
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

    bit [5:0] data_burst_cnt;

    // 0011 like the N64 core to force a base of 0x30000000
    localparam bit [3:0] DDR_CORE_BASE = 4'b0011;

    always_ff @(posedge clkddr) begin
        if (!ddrif.busy) begin
            ddrif.read <= 0;
        end

        if (reset_clkddr || vblank_clkddr) begin
            fetchstate <= IDLE;
            address_y <= latched_frame_adr + 29'h0;
            address_v <= latched_frame_adr + 29'h15900;  // 368*240 = 88320
            address_u <= latched_frame_adr + 29'h1af40;  // 368*240 + 88320/4
            target_y <= 0;
            target_u <= 0;
            target_v <= 0;
            line_alternate <= 0;
            u_requested <= 0;
            v_requested <= 0;
        end else begin
            if (new_line_started_clkddr && linecnt < frame_height) begin
                line_alternate <= !line_alternate;

                if (line_alternate) begin
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
                        ddrif.burstcnt <= 50;
                        data_burst_cnt <= 50;
                        address_y <= address_y + 8 * 50;
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

        if (pixelcnt >= (frame_width << 2) || linecnt >= frame_height) begin
            vidout.r = 0;
            vidout.g = 0;
            vidout.b = 0;
        end
    end

endmodule
