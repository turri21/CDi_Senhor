module mpeg_video_start_code_decoder (
    input clk,
    input reset,
    input [7:0] mpeg_data,
    input data_valid,

    output bit event_sequence_header,
    output bit event_group_of_pictures,
    output bit event_picture,
    output bit [15:0] tmpref,
    output bit [31:0] timecode
);

    bit [9:0] temperal_sequence_number;
    bit [9:0] next_sequence_number;
    bit [9:0] gop_cnt = 0;

    enum bit [3:0] {
        IDLE,
        MAGIC0,
        MAGIC1,
        MAGIC2,
        MAGIC3,
        MAGIC_MATCH,
        GOP0,
        GOP1,
        GOP2,
        GOP3,
        PIC0,
        PIC1,
        PIC2,
        PIC3,
        SLICE0,
        SEQHDR
    } finder_state = IDLE;

    always @(posedge clk) begin
        event_picture <= 0;
        event_group_of_pictures <= 0;
        event_sequence_header <= 0;

        if (data_valid) begin
            // $display ("MPEG %x",mpeg_data);
            casez ({
                finder_state, mpeg_data
            })
                // verilog_format: off

                {PIC3, 8'h??}: begin finder_state <= IDLE; 
                    $display ("PIC3 %x",mpeg_data);
                    event_picture <= 1;
                end
                {PIC2, 8'h??}: begin
                    finder_state <= PIC3;
                    if (next_sequence_number == temperal_sequence_number)
                    begin
                        tmpref[11:2] <= temperal_sequence_number;
                        $display ("PIC2 %x %d",mpeg_data,temperal_sequence_number);
                        next_sequence_number <= next_sequence_number + 1;
                    end
                    end
                {PIC1, 8'h??}: begin
                    finder_state <= PIC2;
                    //$display ("PIC1 %x",mpeg_data);
                    temperal_sequence_number[1:0] <= mpeg_data[7:6];
                    end
                {PIC0, 8'h??}: begin
                    finder_state <= PIC1;
                    //$display ("PIC0 %x",mpeg_data);
                    temperal_sequence_number[9:2] <= mpeg_data;
                    end
                {GOP3, 8'h??}: begin
                    finder_state <= IDLE;
                    $display ("GOP3 %x",mpeg_data);
                    event_group_of_pictures <= 1;
                    next_sequence_number <= 0;
                    timecode[16] <= mpeg_data[7];
                    $display ("Timecode %d:%d:%d",timecode[5:0],timecode[27:22], timecode[21:16]);
                end
                {GOP2, 8'h??}: begin
                    finder_state <= GOP3;
                    $display ("GOP2 %x",mpeg_data);
                    timecode[24:22] <= mpeg_data[7:5];
                    timecode[21:17] <= mpeg_data[4:0];
                    gop_cnt <= gop_cnt + 1;
                end
                {GOP1, 8'h??}: begin
                    finder_state <= GOP2;
                    $display ("GOP1 %x",mpeg_data);
                    // Seconds
                    timecode[27:25] <= mpeg_data[2:0];
                    end
                {GOP0, 8'h??}: begin finder_state <= GOP1; $display ("GOP0 %x",mpeg_data);end

                {SEQHDR, 8'h??}: begin
                    finder_state <= IDLE; 
                    $display ("SEQHDR %x",mpeg_data);
                    event_sequence_header <= 1;
                end

                {MAGIC_MATCH, 8'hb3} : begin finder_state <= SEQHDR;end
                {MAGIC_MATCH, 8'hb8} : finder_state <= GOP0;
                {MAGIC_MATCH, 8'h00} : finder_state <= PIC0;
                {MAGIC_MATCH, 8'h01} : finder_state <= SLICE0;
                {MAGIC2, 8'h01} : finder_state <= MAGIC_MATCH;
                {MAGIC2, 8'h00} : finder_state <= MAGIC2;
                {MAGIC0, 8'h00} : finder_state <= MAGIC2;
                {IDLE, 8'h00} : finder_state <= MAGIC0;
                default: finder_state <= IDLE;
            // verilog_format: on
            endcase
        end
    end

endmodule
