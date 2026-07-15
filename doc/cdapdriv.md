# cdapdriv - the CDIC driver

A2 contains the driver struct

    long* (0x000, A2)  Memory address 0x00300000 which is the CDIC RAM
    char* (0x059, A2)
    long* (0x05e, A2)
    char* (0x064, A2)
    char* (0x065, A2)
    long* (0x086, A2)  Address of DMA unit
        * (0x08a, A2)
    shrt* (0x08c, A2)
    long* (0x08e, A2)  Function Pointer for IRQ
    shrt* (0x092, A2)  0x3ffe DBUF is stored here during IRQ
    shrt* (0x094, A2)  
    long* (0x09e, A2)  
    long* (0x0a2, A2)
    long* (0x0a6, A2)
    shrt* (0x0ae, A2)
    shrt* (0x0be, A2)  
    long* (0x114, A2)
    long* (0x128, A2)  Function pointer for IRQ
    shrt* (0x12c, A2)  0x3ffa AUDCTL is stored here during IRQ
    shrt* (0x12e, A2)
    shrt* (0x130, A2)
    shrt* (0x13a, A2)  Address of next audio map buffer?
    char* (0x150, A2)  Cleared on 042b7ce
                       Set to #1 on 042b424
    char* (0x152, A2)  Set to 0 when playback has stopped ?
                       Cleared on 0042b430 right after AUDCTL is forced to 0
                       Also cleared on 00429ed8 right after AUDCTL is forced to 0 during ss_pause
    char* (0x153, A2)
    char* (0x154, A2)
    long* (0x18e, A2)
    long* (0x198, A2)


0042a9ce    Function which does a DMA transfer to CDIC memory
            D0 Length?
            D2 Target address in CDIC memory
0042b86e    Function which prepares audio buffer 0x2800 for playback
0042b050    IRQ Handler
0042b744    Possible function to insert into (0x128,A2)
00429e12    setstat ss_pause


