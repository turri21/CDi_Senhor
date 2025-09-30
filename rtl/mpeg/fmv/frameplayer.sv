
`include "../../bus.svh"
`include "../../videotypes.svh"
`include "../util.svh"

module frameplayer (
    input clkvideo,
    input clkddr,
    input reset,

    ddr_if.to_host ddrif,

    output rgb888_s vidout,
    input           hsync,
    input           vsync,
    input           hblank,
    input           vblank,

    input planar_yuv_s frame,
    input [8:0] frame_width,  // expected to be clocked at clkddr
    input [8:0] frame_height,  // expected to be clocked at clkddr
    input [8:0] offset_y,  // expected to be clocked at clkvideo
    input [8:0] offset_x,  // expected to be clocked at clkvideo

    input latch_frame_clkvideo,
    input latch_frame_clkddr,
    input invalidate_latched_frame
);

    assign ddrif.byteenable = 8'hff;
    assign ddrif.write = 0;

    planar_yuv_s latched_frame;
    bit latched_frame_valid;
    bit current_frame_valid;

    always_ff @(posedge clkddr) begin
        if (reset_clkddr || invalidate_latched_frame) begin
            latched_frame_valid <= 0;
        end else if (latch_frame_clkddr) begin
            latched_frame <= frame;
            latched_frame_valid <= 1;
            //$display("Latched frame %x", latched_frame);
        end
    end

    bit [8:0] frame_width_clkvideo = 100;
    bit [8:0] frame_height_clkvideo = 100;

    always_ff @(posedge clkvideo) begin
        if (latch_frame_clkvideo) begin
            frame_width_clkvideo  <= frame_width;
            frame_height_clkvideo <= frame_height;
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

    wire new_line_started = hsync && !hsync_q && (vertical_offset_wait == 0);
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
        .clk_out(clkvideo),
        .strobe(luma_fifo_strobe),
        .valid(y_valid),
        .q(current_color.y)
    );

    flag_cross_domain cross_new_line_started (
        .clk_a(clkvideo),
        .clk_b(clkddr),
        .flag_in_clk_a(new_line_started),
        .flag_out_clk_b(new_line_started_clkddr)
    );

    flag_cross_domain cross_reset (
        .clk_a(clkvideo),
        .clk_b(clkddr),
        .flag_in_clk_a(reset),
        .flag_out_clk_b(reset_clkddr)
    );

    signal_cross_domain cross_vblank (
        .clk_a(clkvideo),
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
        .clk_out(clkvideo),
        .q(current_color.u),
        .raddr(chroma_read_addr)
    );

    ddr_chroma_line_buffer line_buffer_v (
        .clk_in(clkddr),
        .reset(new_line_started_clkddr),
        .wdata(ddrif.rdata),
        .we(ddrif.rdata_ready && target_v),
        .clk_out(clkvideo),
        .q(current_color.v),
        .raddr(chroma_read_addr)
    );


    bit [10:0] pixelcnt;
    bit [8:0] linecnt;
    bit hsync_q;
    bit line_alternate;
    bit u_requested;
    bit v_requested;

    bit [8:0] vertical_offset_wait;
    bit [8:0] horizontal_offset_wait;

    always_ff @(posedge clkvideo) begin
        hsync_q <= hsync;

        if (reset || vsync) begin
            linecnt <= 0;
            vertical_offset_wait <= offset_y;
        end else if (!vblank && hsync && !hsync_q) begin
            if (vertical_offset_wait != 0) vertical_offset_wait <= vertical_offset_wait - 1;
            else linecnt <= linecnt + 1;
        end

        if (chroma_fifo_strobe) chroma_read_addr <= chroma_read_addr + 1;

        if (hblank || reset) begin
            pixelcnt <= 0;
            chroma_fifo_strobe <= 0;
            luma_fifo_strobe <= 0;
            chroma_read_addr <= 0;
            horizontal_offset_wait <= offset_x;
        end else if (!vblank && !hblank && pixelcnt < frame_width_clkvideo << 2 && linecnt < frame_height_clkvideo && vertical_offset_wait==0 && current_frame_valid) begin

            if (horizontal_offset_wait != 0) horizontal_offset_wait <= horizontal_offset_wait - 1;
            else begin
                pixelcnt <= pixelcnt + 1;
                luma_fifo_strobe <= pixelcnt[1:0] == 3 - 2;
                chroma_fifo_strobe <= pixelcnt[2:0] == 7 - 2;
                assert (y_valid);
            end
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

    wire vertical_offset_wait_not_null_clkddr;
    signal_cross_domain cross_vertical_offset_wait_not_null (
        .clk_a(clkvideo),
        .clk_b(clkddr),
        .signal_in_clk_a(vertical_offset_wait != 0),
        .signal_out_clk_b(vertical_offset_wait_not_null_clkddr)
    );

    always_ff @(posedge clkddr) begin
        if (!ddrif.busy) begin
            ddrif.read <= 0;
        end

        if (reset_clkddr || vblank_clkddr || vertical_offset_wait_not_null_clkddr) begin
            fetchstate <= IDLE;
            address_y <= latched_frame.y_adr;
            address_u <= latched_frame.u_adr;
            address_v <= latched_frame.v_adr;
            current_frame_valid <= latched_frame_valid;
            target_y <= 0;
            target_u <= 0;
            target_v <= 0;
            line_alternate <= 0;
            u_requested <= 0;
            v_requested <= 0;
        end else if (current_frame_valid) begin
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
                        address_u <= address_u + 29'(frame_width / 2);
                        ddrif.burstcnt <= 8'(frame_width / 16);
                        data_burst_cnt <= 6'(frame_width / 16);
                        fetchstate <= WAITING;
                        target_u <= 1;
                    end else if (!v_requested) begin
                        v_requested <= 1;
                        ddrif.addr <= {DDR_CORE_BASE, address_v[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        address_v <= address_v + 29'(frame_width / 2);
                        ddrif.burstcnt <= 8'(frame_width / 16);
                        data_burst_cnt <= 6'(frame_width / 16);
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

        if ((pixelcnt >= (frame_width_clkvideo << 2)) || (linecnt >= frame_height_clkvideo) || (vertical_offset_wait!=0) || (horizontal_offset_wait!=0) || !current_frame_valid) begin
            vidout.r = 0;
            vidout.g = 0;
            vidout.b = 0;
        end
    end

endmodule
