module mpeg_demuxer (
    input clk,
    input reset,
    input [7:0] mpeg_data,
    input data_valid,
    output bit mpeg_packet_body,
    input [31:0] dclk,  // Increments with 45 kHz
    output bit signed [32:0] system_clock_reference_start_time,
    output bit system_clock_reference_start_time_valid
);

    enum bit [4:0] {
        FMA_IDLE,
        FMA_MAGIC0,
        FMA_MAGIC1,
        FMA_MAGIC2,
        FMA_MAGIC3,
        FMA_MAGIC_MATCH,
        FMA_PACK0,
        FMA_PACK1,
        FMA_PACK2,
        FMA_PACK3,
        FMA_PACK4,
        FMA_PACK5,
        FMA_PES0,
        FMA_PES1,
        FMA_PES2,
        FMA_PES3,
        FMA_PES4,
        FMA_PES5,
        FMA_PES6,
        FMA_PES7,
        FMA_PES8,
        FMA_PES_DTS0,
        FMA_PES_DTS1,
        FMA_PES_DTS2,
        FMA_PES_DTS3,
        FMA_PES_DTS4

    } demux_state = FMA_IDLE;

    bit packet_length_decreasing;
    bit [15:0] packet_length;
    bit signed [32:0] system_clock_reference;
    bit [9:0] pack_cnt = 0;
    bit [32:0] presentation_time_stamp;
    bit [32:0] decoding_time_stamp;
    bit dts_present;

    always_ff @(posedge clk) begin
        if (reset) begin
            demux_state <= FMA_IDLE;
            system_clock_reference_start_time_valid <= 0;
        end else if (data_valid) begin

            if (packet_length_decreasing) begin
                packet_length <= packet_length - 1;
                if (packet_length == 1) begin
                    packet_length_decreasing <= 0;
                    mpeg_packet_body <= 0;
                end
            end

            casez ({
                demux_state, mpeg_data
            })
                // verilog_format: off
                {FMA_PACK5, 8'h??}: begin         
                    demux_state <= FMA_IDLE;
                    $display ("FMA PACK %x %d",mpeg_data,system_clock_reference);
                end
                
                {FMA_PACK4, 8'h??}: begin                    
                    demux_state <= FMA_PACK5;
                    system_clock_reference[6:0] <= mpeg_data[7:1];
                    pack_cnt <= pack_cnt +1;
                end
                {FMA_PACK3, 8'h??}: begin
                    demux_state <= FMA_PACK4;
                    system_clock_reference[14:7] <= mpeg_data;
                end
                {FMA_PACK2, 8'h??}: begin
                    demux_state <= FMA_PACK3;
                    system_clock_reference[21:15] <= mpeg_data[7:1];
                end
                {FMA_PACK1, 8'h??}: begin
                    demux_state <= FMA_PACK2;
                    system_clock_reference[29:22] <= mpeg_data;
                end
                {FMA_PACK0, 8'h??}: begin
                    demux_state <= FMA_PACK1;
                    system_clock_reference[32:30] <= mpeg_data[3:1];
                end

                {FMA_PES8, 8'h??}: begin         
                    demux_state <= FMA_IDLE;
                    $display ("FMA PES %x %d",mpeg_data,presentation_time_stamp);

                    // verilog_format: on
                    if (!system_clock_reference_start_time_valid) begin
                        system_clock_reference_start_time_valid <= 1;

                        system_clock_reference_start_time[32:1] <= dclk + presentation_time_stamp[32:1] - system_clock_reference[32:1];
                    end
                    // verilog_format: off
                end

                {FMA_PES_DTS4, 8'b???????1}: begin // DTS
                    decoding_time_stamp[6:0] <= mpeg_data[7:1];
                    mpeg_packet_body <= 1;
                    demux_state <= FMA_PES8;
                end
                {FMA_PES_DTS3, 8'h??}: begin // DTS
                    demux_state <= FMA_PES_DTS4;
                    decoding_time_stamp[14:7] <= mpeg_data;
                end
                {FMA_PES_DTS2, 8'b???????1}: begin // DTS
                    decoding_time_stamp[21:15] <= mpeg_data[7:1];
                    demux_state <= FMA_PES_DTS3;
                end
                {FMA_PES_DTS1, 8'h??}: begin // DTS
                    demux_state <= FMA_PES_DTS2;
                    decoding_time_stamp[29:22] <= mpeg_data;
                end
                {FMA_PES_DTS0, 8'b0001???1}: begin // DTS
                    decoding_time_stamp[32:30] <= mpeg_data[3:1];
                    demux_state <= FMA_PES_DTS1;
                end

                {FMA_PES7, 8'b???????1}: begin // PTS
                    presentation_time_stamp[6:0] <= mpeg_data[7:1];
                    if (dts_present) begin
                        demux_state <= FMA_PES_DTS0;
                    end else begin
                        mpeg_packet_body <= 1;
                        demux_state <= FMA_PES8;
                    end
                end
                {FMA_PES6, 8'h??}: begin // PTS
                    demux_state <= FMA_PES7;
                    presentation_time_stamp[14:7] <= mpeg_data;
                end
                {FMA_PES5, 8'b???????1}: begin // PTS
                    presentation_time_stamp[21:15] <= mpeg_data[7:1];
                    demux_state <= FMA_PES6;
                end
                {FMA_PES4, 8'h??}: begin // PTS
                    demux_state <= FMA_PES5;
                    presentation_time_stamp[29:22] <= mpeg_data;
                end
                {FMA_PES2, 8'b0010???1}: begin // PTS (no DTS)
                    presentation_time_stamp[32:30] <= mpeg_data[3:1];
                    dts_present <= 0;
                    demux_state <= FMA_PES4;
                end
                {FMA_PES2, 8'b0011???1}: begin // PTS and DTS
                    presentation_time_stamp[32:30] <= mpeg_data[3:1];
                    dts_present <= 1;
                    demux_state <= FMA_PES4;
                end
                {FMA_PES2, 8'b00001111}: begin // Neither PTS nor DTS
                    demux_state <= FMA_IDLE;
                    mpeg_packet_body <= 1;
                end
                {FMA_PES3, 8'h??}: begin
                    // just ignore STD buffer size second byte
                    demux_state <= FMA_PES2;
                end
                {FMA_PES2, 8'b01??????}: begin // STD buffer size
                    demux_state <= FMA_PES3;
                end

                {FMA_PES2, 8'hff}: begin // stuffing byte
                    demux_state <= FMA_PES2;
                end
                
                {FMA_PES1, 8'h??}: begin
                    demux_state <= FMA_PES2;
                    packet_length[7:0] <= mpeg_data;
                    packet_length_decreasing <= 1;
                end
                {FMA_PES0, 8'h??}: begin
                    demux_state <= FMA_PES1;
                    packet_length[15:8] <= mpeg_data;
                end

                {FMA_MAGIC_MATCH, 8'hba} : begin
                    demux_state <= FMA_PACK0;
                end
                {FMA_MAGIC_MATCH, 8'hC?} : begin
                    demux_state <= FMA_PES0;
                end
                {FMA_MAGIC_MATCH, 8'hE?} : begin
                    demux_state <= FMA_PES0;
                end
                {FMA_MAGIC2, 8'h01} : demux_state <= FMA_MAGIC_MATCH;
                {FMA_MAGIC2, 8'h00} : demux_state <= FMA_MAGIC2;
                {FMA_MAGIC0, 8'h00} : demux_state <= FMA_MAGIC2;
                {FMA_IDLE, 8'h00} : demux_state <= FMA_MAGIC0;
                default: demux_state <= FMA_IDLE;
            // verilog_format: on
            endcase

        end

    end

endmodule
