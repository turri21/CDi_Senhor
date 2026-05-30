	section .text

    org $400000

vector:
	dc.l $1234
	dc.l main

main:

	move.l #illegal_instruction,$10
	move.l #zero_divide,$14
	

	divu d0,d0
endless:
	bra endless

illegal_instruction:
	bra illegal_instruction

zero_divide:
	bra zero_divide




