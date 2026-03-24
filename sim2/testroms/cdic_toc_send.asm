	section .text

    org $400000

vector:
	dc.l $1234
    dc.l main

main:
	move.w #$0000,$303FFE ; Data buffer
	move.w #$2480,$303FFC ; CDIC IVEC
	move.l #cdicirq,$200
	move #$2000,SR

	move.w #$0024,$303C00 ; Command Register = Reset Mode 2
	move.w #$8000,$303FFE ; Data buffer

	move.w #$0027,$303C00 ; Command Register = Fetch TOC
	move.w #$C000,$303FFE ; Start the Read

	move.l #$2000,a1
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode

	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode
	jsr waitforcdicirq_store_subcode

	move.w #$0000,$303FFE ; Data buffer = 0, disable reading

	; Send CDIC DATA1 buffer
	move.l #$2000,a0
	move.l #(24*15),d1
loop:

wait_till_ready:
	move.b $80002013,d0
	btst.l #$2,d0
	beq wait_till_ready

	move.b (a0),d0
	move.b d0,$80002019
	adda.l #1,a0
	add.l #-1,d1
	bne loop

	; hexdump of octets with 12 columns
	; microcom /dev/ttyS1 -s 115200 > dump
	; hexdump -e '24/1 " %02X" "\n"' 0/uartlog
	; hexdump -e '24/1 " %02X" "\n"' dump

endless:
	bra endless


waitforcdicirq_store_subcode:
	move #0,d0
waitforcdicirqloop:
	cmp #0,d0
	beq waitforcdicirqloop

	; $930 for sector, but the first 12 bytes are cut off
	adda #$924,a0
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+

	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+

	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+

	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	move.b (a0)+,(a1)+
	
	rts

cdicirq:
	move.w $303FF4,d0 ; clear flags on ABUFD
	; ignore ABUF
	move.w $303FF6,d0 ; clear flags on XBUF

	btst.l #$f,d0
	beq noint

	move.w $303FFe,d0
	btst.l #$0,d0 ; check lowest bit of data buffer
	beq lower_buf
higher_buf:
	move.w #$8a0c,d1 ; DMA Control for 0x0A0C
	move.l #$300a00,a0 ; Buffer location in CDIC memory
	bra read_data
lower_buf:
	move.w #$800c,d1 ; DMA Control for 0x000C
	move.l #$300000,a0 ; Buffer location in CDIC memory
read_data:
	; Highest bit is set
	move #1,d0
	rte
noint:
	move #0,d0
	rte

