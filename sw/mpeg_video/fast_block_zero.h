#pragma once

/*
 * This code feels stupid but seems to be required.
 * A loop is just detected by GCC and replaced with
 * memset during the optimization.
 * With this method, 64 words of 32 bit are set to zero.
 * This is quite fast since the loop is unrolled.
 */
static inline void fast_block_zero(int* block_data)
{
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;

	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
	*block_data=0;
	block_data++;
}
