// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include <stdint.h>
#include <stddef.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>

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
};

struct io_fifo_control *const fifo_ctrl = (struct io_fifo_control *)0x10002000;
struct frame_display_fifo *const frame_display_fifo = (struct frame_display_fifo *)0x10003000;

#define OUTPORT 0x10000000
#define OUTPORT_END 0x1000000c
#define OUTPORT_FRAME 0x10000010
#define OUTPORT_HANDLE_SHARED 0x10000014

#define OUT_DEBUG *(volatile uint32_t *)0x10000030

#include "shared.h"
#include "memtest.h"

extern caddr_t _end; /* _end is set in the linker command file */
extern caddr_t _sp;	 /* _end is set in the linker command file */
/* just in case, most boards have at least some memory */
#ifndef RAMSIZE
#define RAMSIZE (caddr_t)(1024 * 1024 * 4)
#endif

void print_chr(char ch);
void print_str(const char *p);
void stop_verilator();

// #define SOFT_CONVOLVE

#define PL_MPEG_IMPLEMENTATION
#define PLM_NO_STDIO
#include "pl_mpeg.h"

void print_chr(char ch)
{
	*((volatile uint8_t *)OUTPORT) = ch;
}

void print_str(const char *p)
{
	while (*p != 0)
		*((volatile uint8_t *)OUTPORT) = *(p++);
}

void stop_verilator()
{
	print_str("Nope\n");
	*((volatile uint8_t *)OUTPORT_END) = 1;
}

void sync_to_worker()
{
	struct image_synthesis_descriptor *desc = get_next_synthesis_desc();
	__asm volatile("" : : : "memory");
	desc->ready = 3;
	*((int *)OUTPORT_HANDLE_SHARED) = 1;
	__asm volatile("" : : : "memory");
	while (desc->ready == 3)
		__asm volatile("" : : : "memory");
}

void dct_coeff_read(plm_dma_buffer_t *buffer)
{
#if 0
	fifo_ctrl->hw_huffman_read_dct_coeff = 1;
	__asm volatile("" : : : "memory");
	*((volatile uint32_t *)OUTPORT) = fifo_ctrl->hw_huffman_read_dct_coeff;
	*((volatile uint32_t *)OUTPORT) = fifo_ctrl->read_bit_index;
#else
	*((volatile uint32_t *)OUTPORT) = plm_dma_buffer_read_vlc_uint(buffer, PLM_VIDEO_DCT_COEFF);
	*((volatile uint32_t *)OUTPORT) = fifo_ctrl->read_bit_index;
#endif
}

void main(void)
{
	*((volatile uint32_t *)OUTPORT) = sizeof(struct image_synthesis_descriptor);
#if 0
	static uint32_t testword;
	memory_interface_test(&testword);
	memory_interface_test((void*)0x41000030);
	memory_interface_test((void*)0x40000030);
	
	for(;;);
#endif
	// test_vector_unit();
	// stop_verilator();
	//  for(;;);
	// OUT_DEBUG = (int)image_synthesis_buffer;

	plm_dma_buffer_t *buffer = plm_buffer_create_with_memory((uint8_t *)0x20000000, 700 * 1024 * 1024, 0);
	if (!buffer)
		*((volatile uint8_t *)OUTPORT_END) = 2;

#if 0
	for (int i = 0; i < 10000; i++)
		dct_coeff_read(buffer);
	*((volatile uint8_t *)OUTPORT_END) = 0;
	for (;;)
		;
#endif

	while (!plm_dma_buffer_has(buffer, 1000))
		;

	plm_video_t *mpeg = plm_video_create_with_buffer(buffer, 0);
	if (!mpeg)
		*((volatile uint8_t *)OUTPORT_END) = 3;

	int cnt = 0;

	for (;;)
	{
		plm_frame_t *frame = plm_video_decode(mpeg);

		if (frame)
		{
			OUT_DEBUG = 27;

			sync_to_worker();
			worker_cnt++;
			sync_to_worker();

			OUT_DEBUG = 28;

			// Give some feedback to the user that we are running
			*((volatile uint32_t *)OUTPORT) = frame->time;

			//*((volatile uint32_t *)OUTPORT) = frame->width;
			//*((volatile uint32_t *)OUTPORT) = frame->height;
			//*((volatile uint32_t *)OUTPORT) = (uint32_t)frame->y.data;
			//*((volatile uint32_t *)OUTPORT) = (uint32_t)frame->cr.data;
			//*((volatile uint32_t *)OUTPORT) = (uint32_t)frame->cb.data;
			__asm volatile("" : : : "memory");
			*((volatile plm_frame_t **)OUTPORT_FRAME) = frame;
			frame_display_fifo->y_adr = (uint32_t)frame->y.data;
			frame_display_fifo->u_adr = (uint32_t)frame->cb.data;
			frame_display_fifo->v_adr = (uint32_t)frame->cr.data;
			frame_display_fifo->width = frame->width;
			frame_display_fifo->height = frame->height;
			frame_display_fifo->frameperiod = mpeg->framerate;
			__asm volatile("" : : : "memory");

			cnt++;
		}
		else
		{
			// End simulation since the MPEG stream has ended
			//*((volatile uint8_t *)OUTPORT_END) = 0;
		}
	}
}

/*
 * sbrk -- changes heap size size. Get nbytes more
 *         RAM. We just increment a pointer in what's
 *         left of memory on the board.
 */
caddr_t _sbrk(int nbytes)
{
	static caddr_t heap_ptr = NULL;
	caddr_t base;

	if (heap_ptr == NULL)
	{
		heap_ptr = (caddr_t)&_sp;
	}

	if ((RAMSIZE - heap_ptr) >= 0)
	{
		base = heap_ptr;
		heap_ptr += nbytes;
		return (base);
	}
	else
	{
		errno = ENOMEM;
		return ((caddr_t)-1);
	}
}
