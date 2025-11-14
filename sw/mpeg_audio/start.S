    .section .init
    .globl _start
_start:
    # Set up the stack pointer
    la sp, _stack_top

    # Optionally clear .bss section
    la a0, __bss_start
    la a1, __bss_end
    beq a0, a1, 1f
0:
    sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, 0b
1:

    # Jump to main()
    call main

    # If main returns, just loop forever
1:
    j 1b
