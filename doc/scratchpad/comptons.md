# Compton's Interactive Encyclopedia (1995) - black screen on main menu

Analysis of https://github.com/MiSTer-devel/CDi_MiSTer/issues/14

Works fine on MAME and on cdiemu. Only this core seems to have issues.

The problem is not coming from potential faulty MCD212 emulation. A ram dump from MAME is working fine in videosim here.
So, the LCT might be faulty?

It should be something like this

    Line  46 Transparency Control MX:0 TB:0001 TA:1000
    ...
    Line  46 Coding A:0011 CLUT7 B:0011 CLUT7 NR:0 CS:0

But here it is like this

    Line  46 Transparency Control MX:0 TB:0000 TA:1000
    ...
    Line  46 Coding A:0011 CLUT7 B:0000 OFF NR:0 CS:0

Mixing is active, that is correct.


Here analysis from the core:

    DCA0 Start reading at 07b9d0
    DCA0 Write d0 407800 010000000111100000000000
    Line  46 Region CH0 0   CMD:0100   RF:0   Weight:30   X:   0
    Line  46 Weight A changed with Region 0 at    0 to 30
    DCA0 Write d1 608401 011000001000010000000001
    Line  46 Region CH0 1   CMD:0110   RF:0   Weight:33   X:   1
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    DCA0 Write c1 000008 000000000000000000001000
    Line  46 Transparency Control MX:0 TB:0000 TA:1000
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    DCA0 Write c2 000000 000000000000000000000000
    Plane A in front of Plane B
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    Line  46 Weight A changed with Region 0 at    0 to 30
    DCA0 Write c0 002023 000000000010000000100011
    Line  46 Coding A:0011 CLUT7 B:0000 OFF NR:0 CS:0


    0041bf62  00000008 00000005 00000001 00000001 00000015 00000000 000000f0 00000005  0007b9d0 00dfd7c0 00dfdef0 00d02e0a 0007b9d0 00dfd3e8 00dfd7c0 00dfd388
    CPU Read Access 0041bf64 51c9
    CPU Read Access 00d02e0a c100 <-- Seems to be the source
    CPU Read Access 00d02e0c 0008
    CPU Write Access 0007b9d8 c100 <-- Here is image coding written to LCT
    CPU Write Access 0007b9da 0008


This is performed by 

    Syscall @ 2519c6 8e I$SetStt 00000003 00000056 0000001c 00000001 00000015 00000002 000000f0 00000006  00d02e0a 00d049ea 00defa78 00defa74 00d02e0a 00d04a8c 00d0a7f8 00dfd428 SetStt SS_DC DC_PWrLCT at video pos 1668 265

The value was generated before here

    0027d086  c1000008 c1000000 00000017 80df038a 00000000 00000000 c2000000 00000000  80df038a 00d049ea 20df0334 00def9e0 00def9e0 00d04a8c 00d0a828 00d0a7c4
    0027d08a  c1000008 c1000000 00000017 80df038a 00000000 00000000 c2000000 00000000  00d02e0a 00d049ea 20df0334 00def9e0 00def9e0 00d04a8c 00d0a828 00d0a7c4
    CPU Read Access 0027d08c 206e
    CPU Write Access 00d02e0a c100   <-- Seems to be the source for DC_PWrLCT
    CPU Write Access 00d02e0c 0008

Now for MAME:

    DCA0 Write c1 000108 000000000000000100001000
    Line  46 Transparency Control MX:0 TB:0001 TA:1000

We are looking for c1000108.
This is the first occurence in MAME.

    0027d082  c1000108 c1000000 00000017 80ef048a 00000000 00000000 c2000000 00000000  80ef048a 00d049ea 20ef0434 00eefae0 00eefae0 00d04a8c 00d0a828 00d0a7c4
    0027d086  c1000108 c1000000 00000017 80ef048a 00000000 00000000 c2000000 00000000  00d02e0a 00d049ea 20ef0434 00eefae0 00eefae0 00d04a8c 00d0a828 00d0a7c4
    0027d08a  c1000108 c1000000 00000017 80ef048a 00000000 00000000 c2000000 00000000  00d02e0a 00d049ea 20ef0434 00eefae0 00eefae0 00d04a8c 00d0a828 00d0a7c4
    0027d08c  c1000108 c1000000 00000017 80ef048a 00000000 00000000 c2000000 00000000  00d02e0a 00d049ea 20ef0434 00eefae0 00eefae0 00d04a8c 00d0a828 00d0a7c4
    0027d090  c1000108 c1000000 00000017 80ef048a 00000000 00000000 c2000000 00000000  00d02e0e 00d049ea 20ef0434 00eefae0 00eefae0 00d04a8c 00d0a828 00d0a7c4

It is interesting that 0027d086 and 0027d082 are 4 byte apart. This is helpful for analysis

Let's split

    split -b 512k 0/video_ramdump.bin part-

part-ab is at 0x200000

    objcopy -I binary -O binary --reverse-bytes=2 part-ab part-ab_swap.rom


After going through the disassembly, it struck me.

    0027d062  20df0334 00000000 00000000 80df038a 00000000 00000000 c2000000 00000000  00000000 00d049ea 80df038a 00def9e0 00def9e0 00d04a8c 00d0a828 00d0a7c4
    CPU Read Access 0027d064 004c
    CPU Read Access 0027d066 6002
    CPU Read Access 80df03d6 0000
    CPU Read Access 80df03d8 0000

A 32 bit address in A2?

    $ cat log | grep df03d8
    CPU Write Access 00df03d8 0008
    CPU Write Access 00df03d8 0001
    CPU Write Access 00df03d8 0001
    CPU Read Access 00df03d8 0001
    CPU Read Access 80df03d8 0000
    CPU Read Access 80df03d8 0000
    CPU Read Access 00df03d8 0001
    CPU Read Access 80df03d8 0000
    CPU Read Access 80df03d8 0000

Ok, it turns out that the highest bit is set, which usually indicates an internal address.
But that is only valid when in SUPERVISOR mode according to the datasheet.
In USER mode, the access is always external and the highest byte is not used because of the 24 bit address bus.

