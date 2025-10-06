module cdic_clock_gen (
    input clk,
    input clk_audio,
    input reset,

    output sector_tick,
    output sample_tick37,
    output sample_tick44
);


    wire reset_audio;

    // When clocked at 30 MHz and a sector rate of 75 Hz
    // 30e6/75 = 400000
    // But clocked at 22226400 Hz
    // 22226400 / 75 = 296352
    // 22226400 / 37800 = 588
    // 22226400 / 44100 = 504
    localparam bit [23:0] kSectorPeriod = 296352;
    localparam bit [23:0] kSample37Period = 588;
    localparam bit [23:0] kSample44Period = 504;

    flag_cross_domain cross_reset (
        .clk_a(clk),
        .clk_b(clk_audio),
        .flag_in_clk_a(reset),
        .flag_out_clk_b(reset_audio)
    );

    bit [23:0] sample37800counter;
    bit [23:0] sample44100counter;
    bit [23:0] sector75counter;

    // Simulate 75 sectors per second
    always_ff @(posedge clk_audio) begin
        if (reset_audio) begin
            sample37800counter <= 0;
            sample44100counter <= 0;
            sector75counter <= 0;
        end else begin
            if (sector75counter == 0) sector75counter <= kSectorPeriod - 1;
            else sector75counter <= sector75counter - 1;

            if (sample44100counter == 0) sample44100counter <= kSample44Period - 1;
            else sample44100counter <= sample44100counter - 1;

            if (sample37800counter == 0) sample37800counter <= kSample37Period - 1;
            else sample37800counter <= sample37800counter - 1;
        end
    end

    wire sample_tick37_audio = sample37800counter == 0;
    wire sample_tick44_audio = sample44100counter == 0;
    wire sector_tick_audio = sector75counter == 0;

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


endmodule
