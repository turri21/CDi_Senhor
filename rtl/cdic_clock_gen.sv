module cdic_clock_gen (
    input clk,
    input clk_audio,
    input reset,

    output sector_tick,
    output sample_tick37,
    output sample_tick44,
    output mpeg_45tick
);
    wire reset_audio;

    // We have 30 MHz as system clock for the CD-i CPU and MCD212
    // But for Audio we really want to have a stable sample rate that should
    // be interlocked with the CD sector frequency of 75 Hz
    // When clocked at 30 MHz and a sector rate of 75 Hz
    // 30e6 / 75 = 400000
    // 30e6 / 37800 = 793,650793650794
    // 30e6 / 44100 = 680,272108843538
    // This is not good because I can't device evenly
    // But clocked at 6615000 Hz, this issue is solved
    // 6615000 / 75 = 88200
    // 6615000 / 37800 = 175
    // 6615000 / 44100 = 150
    // MPEG needs 90 kHz as system clock reference
    // Since VMPEG hardware works on half of that, 45 kHz is better here
    // 6615000 / 45000 = 147
    localparam bit [17:0] kSectorPeriod = 88200;
    localparam bit [8:0] kSample37Period = 175;
    localparam bit [8:0] kSample44Period = 150;
    localparam bit [7:0] kMPEG45Period = 147;

    flag_cross_domain cross_reset (
        .clk_a(clk),
        .clk_b(clk_audio),
        .flag_in_clk_a(reset),
        .flag_out_clk_b(reset_audio)
    );

    bit [17:0] sector75counter;
    bit [ 8:0] sample37800counter;
    bit [ 8:0] sample44100counter;
    bit [ 7:0] mpeg45counter;

    // Simulate 75 sectors per second
    always_ff @(posedge clk_audio) begin
        if (reset_audio) begin
            sample37800counter <= 0;
            sample44100counter <= 0;
            sector75counter <= 0;
            mpeg45counter <= 0;
        end else begin
            if (sector75counter == 0) sector75counter <= kSectorPeriod - 1;
            else sector75counter <= sector75counter - 1;

            if (sample44100counter == 0) sample44100counter <= kSample44Period - 1;
            else sample44100counter <= sample44100counter - 1;

            if (sample37800counter == 0) sample37800counter <= kSample37Period - 1;
            else sample37800counter <= sample37800counter - 1;

            if (mpeg45counter == 0) mpeg45counter <= kMPEG45Period - 1;
            else mpeg45counter <= mpeg45counter - 1;
        end
    end

    wire sample_tick37_audio = sample37800counter == 0;
    wire sample_tick44_audio = sample44100counter == 0;
    wire sector_tick_audio = sector75counter == 0;
    wire mpeg_45tick_audio = mpeg45counter == 0;

    flag_cross_domain cross1 (
        .clk_a(clk_audio),
        .clk_b(clk),
        .flag_in_clk_a(sample_tick37_audio),
        .flag_out_clk_b(sample_tick37)
    );
    flag_cross_domain cross2 (
        .clk_a(clk_audio),
        .clk_b(clk),
        .flag_in_clk_a(sample_tick44_audio),
        .flag_out_clk_b(sample_tick44)
    );
    flag_cross_domain cross3 (
        .clk_a(clk_audio),
        .clk_b(clk),
        .flag_in_clk_a(sector_tick_audio),
        .flag_out_clk_b(sector_tick)
    );
    flag_cross_domain cross4 (
        .clk_a(clk_audio),
        .clk_b(clk),
        .flag_in_clk_a(mpeg_45tick_audio),
        .flag_out_clk_b(mpeg_45tick)
    );


endmodule
