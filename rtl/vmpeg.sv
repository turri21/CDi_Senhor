

module vmpeg (
    input clk,
    input clk_mpeg,
    input reset,
    // CPU interface
    input [23:1] address,
    input [15:0] din,
    output bit [15:0] dout,
    input uds,
    input lds,
    input write_strobe,
    input cs,
    output bit bus_ack,
    output intreq,
    input intack,
    output req,
    input ack,
    output rdy,
    input dtc,
    input done_in,
    output done_out,

    ddr_if.to_host ddrif,

    // Video synchronization and output
    input hsync,
    input vsync,
    input hblank,
    input vblank,
    output rgb888_s vidout,

    // Audio Out
    output signed [15:0] audio_left,
    output signed [15:0] audio_right,
    input sample_tick44,

    output bit mpeg_ram_enabled,  // Prohibits detection of MPEG RAM by the OS RAM crawler
    output bit debug_video_fifo_overflow
);
    wire access = cs && (uds || lds);

    wire dma_data_valid = ack && dtc;
    bit mpeg_word_valid_q;

    // Get bytes from words for better analysis for state machines
    bit [7:0] mpeg_temp;
    wire [7:0] mpeg_data  /*verilator public_flat_rd*/ = mpeg_word_valid_q ? mpeg_temp : din[15:8];
    wire mpeg_data_valid  /*verilator public_flat_rd*/ = mpeg_word_valid_q || mpeg_word_valid;

    wire fma_packet_body  /*verilator public_flat_rd*/;
    wire fmv_packet_body  /*verilator public_flat_rd*/;

    always_ff @(posedge clk) begin
        mpeg_word_valid_q <= mpeg_word_valid;
        if (mpeg_word_valid) mpeg_temp <= din[7:0];
    end

    wire mpeg_xferwrite = (address[15:1] == 15'h206F) && bus_ack && write_strobe && access;
    wire mpeg_word_valid = dma_data_valid || mpeg_xferwrite;
    bit  dma_for_fma;
    wire fmv_data_valid  /*verilator public_flat_rd*/ = mpeg_data_valid && !dma_for_fma;
    wire fma_data_valid  /*verilator public_flat_rd*/ = mpeg_data_valid && dma_for_fma;

    wire fmv_word_data_valid  /*verilator public_flat_rd*/ = mpeg_word_valid && !dma_for_fma;
    wire fma_word_data_valid  /*verilator public_flat_rd*/ = mpeg_word_valid && dma_for_fma;

    wire event_decoding_started;
    wire event_frame_decoded;
    wire event_underflow;
    bit  dsp_reset_input_fifo;
    bit  fma_dsp_enable = 0;
    bit  fmv_dsp_enable = 0;

    mpeg_audio audio (
        .clk(clk),
        .reset,
        .dsp_enable(fma_dsp_enable),
        .reset_input_fifo(dsp_reset_input_fifo),
        .data_byte(mpeg_data),
        .data_strobe(fma_data_valid && fma_packet_body),
        .fifo_full(),
        .audio_left(audio_left),
        .audio_right(audio_right),
        .sample_tick44(sample_tick44),
        .playback_active(),
        .event_decoding_started(event_decoding_started),
        .event_frame_decoded(event_frame_decoded),
        .event_underflow(event_underflow)
    );

    wire video_fifo_full;
    wire fmv_event_sequence_header;
    wire fmv_event_group_of_pictures;
    wire fmv_event_picture;
    wire [15:0] fmv_tmpref;
    // TIMECD @ 00E04058
    // [21:16] 6 Bit Frames? Not BCD
    // [27:22] 6 Bit Seconds? Not BCD
    // [5:0] 6 Bit Minutes? Not BCD
    // Where are the hours?
    wire [31:0] fmv_timecode;
    bit fmv_playback_active;
    wire fmv_event_playback_underflow;

    mpeg_video video (
        .clk30(clk),
        .clk60(clk_mpeg),
        .reset,
        .dsp_enable(fmv_dsp_enable),
        .playback_active(fmv_playback_active),
        .data_byte(mpeg_data),
        .data_strobe(fmv_data_valid && fmv_packet_body),
        .fifo_full(video_fifo_full),
        .ddrif,
        .hsync,
        .vsync,
        .hblank,
        .vblank,
        .vidout,
        .display_offset_x(video_ctrl_x_display[8:0]),
        .display_offset_y(video_ctrl_y_display[8:0]),
        .event_playback_underflow(fmv_event_playback_underflow)
    );

    always_ff @(posedge clk) begin
        if (reset) debug_video_fifo_overflow <= 0;
        else if (video_fifo_full) debug_video_fifo_overflow <= 1;
    end

    mpeg_video_start_code_decoder startcode (
        .clk,
        .reset,
        .mpeg_data(mpeg_data),
        .data_valid(fmv_data_valid && fmv_packet_body),
        .event_sequence_header(fmv_event_sequence_header),
        .event_group_of_pictures(fmv_event_group_of_pictures),
        .event_picture(fmv_event_picture),
        .tmpref(fmv_tmpref),
        .timecode(fmv_timecode)
    );


    wire signed [32:0] fma_system_clock_reference_start_time;
    wire fma_system_clock_reference_start_time_valid;
    wire signed [32:0] fmv_system_clock_reference_start_time;
    wire fmv_system_clock_reference_start_time_valid;

    mpeg_demuxer #(
        .unit("FMA")
    ) audio_demuxer (
        .clk,
        .reset(reset || (fma_command_register == 1)),
        .mpeg_data(mpeg_data),
        .data_valid(fma_data_valid),
        .mpeg_packet_body(fma_packet_body),
        .dclk(fma_dclk),
        .system_clock_reference_start_time(fma_system_clock_reference_start_time),
        .system_clock_reference_start_time_valid(fma_system_clock_reference_start_time_valid)
    );

    mpeg_demuxer #(
        .unit("FMV")
    ) video_demuxer (
        .clk,
        .reset(reset || fmv_dsp_enable == 0),
        .mpeg_data(mpeg_data),
        .data_valid(fmv_data_valid),
        .mpeg_packet_body(fmv_packet_body),
        .dclk(fma_dclk),
        .system_clock_reference_start_time(fmv_system_clock_reference_start_time),
        .system_clock_reference_start_time_valid(fmv_system_clock_reference_start_time_valid)
    );

    typedef struct packed {
        bit erdv;  // ?
        bit erdd;  // ?
        bit vcup;  // ?
        bit pai;   // Pause Interrupt ?

        bit vsync;  // Vertical Synchronization ?
        bit eii;    // End ISO Indicator ?
        bit esi;    // End Sequence Indicator ?
        bit tim;    // Timer

        bit dcl;   // ?
        bit ovf;   // Overflow ?
        bit ndat;  // No data ?
        bit rfb;   // Request for bits ?

        bit eod;  // End Of Data
        bit pic;  // Picture Decoded
        bit gop;  // GOP Decoded
        bit seq;  // SEQ Decoded
    } interrupt_flags_s;

    // FMA CMD @ 00E03000
    // 0001 Stop?
    // 8002 DMA Start
    bit [15:0] fma_command_register;
    // FMA STAT @ 00E03002
    // 0000
    // 0014
    // 0004 Frame Header Updated
    // FMA ISO End Detected Status      STAT_EOI            BIT_MASK(0)
    // FMA Audio Stream Changed Status  STAT_CSU            BIT_MASK(1)
    // FMA Frame Header Updated Status  STAT_UPD            BIT_MASK(2)
    // FMA Underflow Status             STAT_UNF            BIT_MASK(3)
    // FMA Decoding Started Status      STAT_DEC            BIT_MASK(4)
    bit [15:0] fma_status_register;
    // FMA ISR @ 00E0301A
    // 0100 Timer?
    // 0104 Updated Header and Timer?
    // 0114 Decoding Started
    // FMA ISO End Detected Interrupt   ISR_EOI            BIT_MASK(0)
    // FMA Changed Stream Interrupt     ISR_CSU            BIT_MASK(1)
    // FMA Updated Header Interrupt     ISR_UPD            BIT_MASK(2)
    // FMA Underflow Interrupt          ISR_UNF            BIT_MASK(3)
    // FMA Decoding Started Interrupt   ISR_DEC            BIT_MASK(4)
    // FMA Error Interrupt              ISR_ERR            BIT_MASK(5)
    // FMA Poll Interrupt               ISR_POLL           BIT_MASK(8)
    bit [15:0] fma_interrupt_status_register;
    // FMA IER @ 00E0301C
    bit [15:0] fma_interrupt_enable_register;
    // FMA IVEC @ 00E0300C
    bit [15:0] fma_interrupt_vector_register = 0;
    // FMA DCLKH @ 00E03010, DCLKH @ 00E03012
    // Increments with 45 kHz
    bit [31:0] fma_dclk;
    bit [15:0] fma_dclkl_latch;

    // FMV SYSCMD @ 00E040C0
    (* keep *) (* noprune *) bit [15:0] fmv_command_register = 0;
    // FMV ISR @ 00E04062
    interrupt_flags_s fmv_interrupt_status_register;
    // FMV IER @ 00E04060
    interrupt_flags_s fmv_interrupt_enable_register;
    // FMV IVEC @ 00E040DC
    bit [15:0] fmv_interrupt_vector_register = 0;
    // FMV TCNT @ 00E04064 (also named SYS_TIM)
    // according to fmvdrv sources:
    // 29700 -1 for 5.28 seconds
    // 56 -1 for 10ms interrupt
    // 75 -1 for 12.333ms interrupt
    // 225 - 1 for 40 ms interrupt
    // so we have about 5,625 ticks per ms
    // this means 5625 tick per second
    // this means 90 kHz / 5625 Hz = 16 Perfect to the power of 2
    bit [15:0] fmv_timer_compare_register = 56 - 1;

    wire fmv_intreq = (fmv_interrupt_status_register & fmv_interrupt_enable_register) != 0;
    wire fma_intreq = (fma_interrupt_status_register & fma_interrupt_enable_register) != 0;
    assign intreq = fma_intreq || fmv_intreq;

    bit [15:0] video_ctrl_y_active = 0;
    bit [15:0] video_ctrl_x_active = 0;
    bit [15:0] video_ctrl_y_offset = 0;
    bit [15:0] video_ctrl_x_offset = 0;
    bit [15:0] video_ctrl_y_display = 0;
    bit [15:0] video_ctrl_x_display = 0;
    bit [15:0] image_height2 = 0;
    bit [15:0] image_width2 = 0;
    bit [15:0] image_rt;

    typedef struct packed {
        bit show_next;
        bit show;
        bit hide;
        bit reserved;
        bit vid_off;
        bit vid_on;
        bit sbuf;
        bit regs_upd;
        bit scroll;
        bit [1:0] vbuf;
    } video_command_s;

    bit [5:0] mpeg_ram_enabled_cnt;

    always_comb begin
        dout = 0;

        case (address[15:1])
            15'h1800: dout = fma_command_register;  // 0x0E03000
            15'h1801: dout = fma_status_register;  // 0x0E03002
            15'h1806: dout = fma_interrupt_vector_register;  //
            15'h1808: dout = fma_dclk[31:16];  // 0x0E03010
            15'h1809: dout = fma_dclkl_latch;  // 0x0E03012
            15'h180D: dout = fma_interrupt_status_register;  // 0x0E0301A
            15'h180E: dout = fma_interrupt_enable_register;  // 0x0E0301C
            15'h1812: dout = 16'h0004;  // HF2 Flag of DSP56001?

            15'h2001: dout = 16'h0180;  // 00E04002 ??
            15'h2002: dout = 16'h0118;  // 00E04004 ??
            15'h2003: dout = image_rt;  // 00E04006 ??
            15'h2029: dout = 16'h0180;  // e04052 Pic Size High??
            15'h202a: dout = 16'h0118;  // e04054 Pic Size Low??
            15'h202b: dout = image_rt;  // e04056 Pic Rt ??
            15'h202c: dout = fmv_timecode[31:16];  // 00E04058 Time Code High??
            15'h202d: dout = fmv_timecode[15:0];  // 00E0405A Time Code Low??
            15'h202e: dout = fmv_tmpref;  // 00E0405C TMP REF?? SYS_VSR?
            15'h202f: dout = 16'h2000;  // 00E0405E ?? STS ? always 2000 on cdiemu
            15'h2030: dout = fmv_interrupt_enable_register;  // 0E04060
            15'h2031: dout = fmv_interrupt_status_register;  // 0E04062
            15'h2032: dout = fmv_timer_compare_register;  // 0E04064
            15'h2036: dout = video_ctrl_y_offset;  // 0E0406C
            15'h2037: dout = video_ctrl_x_offset;  // 0E0406E
            15'h2038: dout = video_ctrl_y_active;  // 0E04070
            15'h2039: dout = video_ctrl_x_active;  // 0E04072
            15'h203a: dout = video_ctrl_y_display;  // 0E04074
            15'h203b: dout = video_ctrl_x_display;  // 0E04076
            15'h2050: dout = 16'hffff;  // 00E040A0 ?? Always ffff on cdiemu
            15'h2052: dout = 16'h0001;  // 00E040A4 ??
            15'h2055: dout = 16'h0001;  // e040aa ??
            15'h2056: dout = 16'h0001;  // e040ac ??
            15'h206e: dout = fmv_interrupt_vector_register;  //

            default: ;
        endcase

        if (intack) begin
            if (fma_intreq)
                dout = {fma_interrupt_vector_register[7:0], fma_interrupt_vector_register[7:0]};
            else dout = {fmv_interrupt_vector_register[10:3], fmv_interrupt_vector_register[10:3]};
        end
    end

    bit vsync_q;
    bit dma_active;
    assign req = dma_active;
    assign rdy = dma_active;

    // Divides 30 Mhz to 45 kHz
    localparam bit [9:0] kFmaClockDivider = 667;
    bit [9:0] fma_dclk_shadow_cnt = 0;

    // Increments at 90 kHz
    bit [15+5:0] timer_cnt = 0;

    bit vsync_flipflop;

    always @(posedge clk) begin
        bus_ack <= 0;
        vsync_q <= vsync;
        dsp_reset_input_fifo <= 0;

        if (reset) begin
            dma_active <= 0;
            fma_command_register <= 0;
            fma_dclk <= 0;
            fma_dsp_enable <= 0;
            fma_interrupt_enable_register <= 0;
            fma_interrupt_status_register <= 0;
            fma_interrupt_vector_register <= 0;
            fma_status_register <= 0;
            fmv_dsp_enable <= 0;
            fmv_interrupt_enable_register <= 0;
            fmv_interrupt_status_register <= 0;
            fmv_playback_active <= 0;
            mpeg_ram_enabled <= 0;
            mpeg_ram_enabled_cnt <= 0;
            timer_cnt <= 0;

        end else begin
            if (vsync && !vsync_q) fmv_interrupt_status_register.vsync <= 1;

            if (vsync && !vsync_q) vsync_flipflop <= !vsync_flipflop;

            if (fmv_event_sequence_header) fmv_interrupt_status_register.seq <= 1;
            if (fmv_event_group_of_pictures) fmv_interrupt_status_register.gop <= 1;
            if (fmv_event_picture) fmv_interrupt_status_register.pic <= 1;
            if (fmv_event_playback_underflow) begin
                fmv_interrupt_status_register.eod  <= 1;
                fmv_interrupt_status_register.ndat <= 1;
            end

            if (event_decoding_started) begin
                // Decoding started
                fma_status_register[4] <= 1;
                fma_interrupt_status_register[4] <= 1;
            end

            if (event_frame_decoded) begin
                // Resetting Decoding started
                fma_status_register[4] <= 0;

                // Frame Header Updated
                fma_status_register[2] <= 1;
                fma_interrupt_status_register[2] <= 1;
            end

            if (event_underflow) begin
                // Underflow
                fma_status_register[3] <= 1;
                fma_interrupt_status_register[3] <= 1;
            end

            if (fma_dclk_shadow_cnt == kFmaClockDivider - 1) begin
                fma_dclk_shadow_cnt <= 0;
                fma_dclk <= fma_dclk + 1;

                if (timer_cnt[15+3:0+3] == fmv_timer_compare_register) begin
                    fmv_interrupt_status_register.tim <= 1;
                    fma_interrupt_status_register[8] <= 1;
                    timer_cnt <= 0;
                end else begin
                    timer_cnt <= timer_cnt + 1;
                end

                if (fma_system_clock_reference_start_time_valid && fma_dclk == fma_system_clock_reference_start_time[32:1] && !fma_dsp_enable) begin
                    fma_dsp_enable <= 1;
                end

                if (fmv_system_clock_reference_start_time_valid && fma_dclk == fmv_system_clock_reference_start_time[32:1] && !fmv_playback_active) begin
                    fmv_playback_active <= 1;
                end

            end else begin
                fma_dclk_shadow_cnt <= fma_dclk_shadow_cnt + 1;
            end

            if (done_in && ack) begin
                fma_command_register[15] <= 0;
                dma_active <= 0;
                dma_for_fma <= 0;
            end

            if (access) begin
                bus_ack <= !bus_ack;

                if (bus_ack) begin
                    if (write_strobe)
                        $display("DVC Write %x %x %d %d", {address[23:1], 1'b0}, din, uds, lds);
                    else $display("DVC Read %x %x %d %d", {address[23:1], 1'b0}, dout, uds, lds);
                end

                if (!write_strobe && bus_ack) begin
                    if (address[15:1] == 15'h2031) begin
                        // Reading the Interrupt Status Register probably resets it? TODO
                        fmv_interrupt_status_register <= 0;
                    end

                    if (address[15:1] == 15'h180D) begin
                        // Reading the Interrupt Status Register probably resets it? TODO
                        fma_interrupt_status_register <= 0;
                    end

                    if (address[15:1] == 15'h1808) begin
                        fma_dclkl_latch <= fma_dclk[15:0];
                    end
                end

                if (write_strobe && bus_ack) begin
                    //if (address[13:1] ==
                    mpeg_ram_enabled_cnt <= mpeg_ram_enabled_cnt + 1;
                    if (mpeg_ram_enabled_cnt == 6'b111111) begin
                        mpeg_ram_enabled <= 1;
                        if (!mpeg_ram_enabled) $display("MPEG RAM Enabled!");
                    end

                    case (address[15:1])
                        15'h1800: begin
                            $display("FMA CMD %x %x", address[15:1], din);

                            /*
                            FMA CMD 1800 0001 Stop ?
                            FMA CMD 1800 0002 Start ?
                            FMA CMD 1800 8002 DMA Transfer
                            */

                            fma_command_register <= din;
                            if (din[15]) begin
                                dma_active  <= 1;
                                dma_for_fma <= 1;
                            end

                            if (din == 2 && fma_command_register == 1) begin
                                // Stop command?
                                fma_dsp_enable <= 0;
                                dsp_reset_input_fifo <= 1;
                            end
                        end
                        15'h1806: begin
                            $display("FMA IVEC %x %x", address[15:1], din);
                            fma_interrupt_vector_register <= din;
                        end
                        15'h180E: begin
                            fma_interrupt_enable_register <= din;
                            $display("FMA IER %x %x", address[15:1], din);
                        end

                        15'h2030: begin
                            fmv_interrupt_enable_register <= din;
                            $display("FMV Write IER Register %x %x", address[15:1], din);
                        end
                        15'h2031: begin
                            // TODO interrupt_status_register;
                        end
                        15'h2032: begin  // 0E04064
                            $display("FMV Write TCNT Register %x %x", address[15:1], din);
                            fmv_timer_compare_register <= din;
                        end
                        15'h2057: begin
                            $display("FMV Write TRLD Register %x %x", address[15:1], din);
                            timer_cnt <= 0;
                        end
                        15'h2060: begin
                            $display("FMV Write SYSCMD Register %x %x", address[15:1], din);
                            /*
                            according to cdiemu in this order when playing videos
	                          FMV SYSCMD 2000 RELEASE
	                          FMV SYSCMD 0100 RESET
	                          FMV SYSCMD 1000 START
	                          FMV SYSCMD 8000 DMA

	                        according to fmvd.txt
                              0010 Pause
	                          0100 Clear FIFO
	                          1000 Decoder on
	                          2000 Decoder off
	                          8000 Start DMA
                            */
                            fmv_command_register <= din;

                            if (din[15]) begin  // 8000 DMA
                                dma_active  <= 1;
                                dma_for_fma <= 0;
                            end

                            if (din[8]) begin  // 0100 Clear FIFO? What to do?
                                fmv_dsp_enable <= 0;
                                fmv_playback_active <= 0;
                            end

                            if (din[13]) begin  // 2000 Decoder off
                                fmv_dsp_enable <= 0;
                                fmv_playback_active <= 0;
                            end

                            if (din[12]) begin  // 1000 Decoder on
                                fmv_dsp_enable <= 1;
                            end

                        end
                        15'h2061: begin
                            $display("FMV Write VIDCMD Register %x %x", address[15:1], din);
                        end
                        15'h206F: begin  // 0E040DE
                            $display("FMV Write XFER Register %x %x", address[15:1], din);
                        end
                        15'h206E: begin
                            fmv_interrupt_vector_register <= din;
                            $display("FMV Write IVEC Register %x %x", address[15:1], din);
                        end

                        15'h2036: begin
                            $display("FMV Write Y Offset %x %x", address[15:1], din);
                            video_ctrl_y_offset <= din;  // seems to be always 001A
                        end
                        15'h2037: begin
                            $display("FMV Write X Offset %x %x", address[15:1], din);
                            video_ctrl_x_offset <= din;  // seems to be always 004A
                        end
                        15'h2038: begin
                            $display("FMV Write Y Active %x %x", address[15:1], din);
                            video_ctrl_y_active <= din;
                        end
                        15'h2039: begin
                            $display("FMV Write X Active %x %x", address[15:1], din);
                            video_ctrl_x_active <= din;
                        end
                        15'h203a: begin
                            $display("FMV Write Y Display %x %x ?", address[15:1], din);
                            video_ctrl_y_display <= din;
                        end
                        15'h203b: begin
                            $display("FMV Write X Display %x %x ?", address[15:1], din);
                            video_ctrl_x_display <= din;
                        end
                        15'h2001: begin
                            $display("FMV Write Image Width2 %x %x", address[15:1], din);
                            image_width2 <= din;
                        end
                        15'h2002: begin
                            $display("FMV Write Image Height2 %x %x", address[15:1], din);
                            image_height2 <= din;
                        end
                        15'h2003: begin
                            $display("FMV Write Image RT? %x %x", address[15:1], din);
                            image_rt <= din;
                        end
                        default: ;
                    endcase
                end
            end
        end
    end


endmodule


