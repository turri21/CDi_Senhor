#pragma once

#include <stdint.h>

struct io_fifo_control
{
	uint32_t write_byte_index;
	uint32_t read_bit_index;
	uint32_t hw_read_count;
	uint32_t hw_huffman_read_dct_coeff;
};

struct frame_display_fifo
{
	uint32_t y_adr;
	uint32_t u_adr;
	uint32_t v_adr;
	uint32_t width;
	uint32_t height;
	uint32_t frameperiod; // ticks of 30 MHz
	uint32_t fractional_pixel_width;
	uint32_t event_sequence_end;
	uint32_t first_intra_frame_of_gop;
	uint32_t event_buffer_underflow;
};

struct io_fifo_control *const fifo_ctrl = (struct io_fifo_control *)0x10002000;
struct frame_display_fifo *const frame_display_fifo = (struct frame_display_fifo *)0x10003000;

#define OUTPORT 0x10000000
#define OUTPORT_END 0x1000000c
#define OUTPORT_FRAME 0x10000010
#define OUTPORT_HANDLE_SHARED 0x10000014

#define OUT_DEBUG *(volatile uint32_t *)0x10000030

// Only for worker cores
#define INVALIDATE_CACHE *(volatile uint32_t *)0x10001110

