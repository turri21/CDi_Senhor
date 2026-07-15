# Chaos Control

## Drops in MPEG Audio

Caused by false positives in Frame header detection.
Can be noticed during the introduction scene on the German version.

Problematic in `sonde.rtf` was this 

`B8 00 0A 58 00 07 FF FF FD A2 04 AB 55`

The header is starting with `FF FD`.
But the `FF` before that was wrongly detected.

Fixable by correctly jumping to the next header after the current one.

## Suddenly stopping CDIC audio when pausing frequently

The game makes use of 2 sound maps that are creating very early on during the bootup phase.

    Syscall @ 275d92 8e I$SetStt 00000004 0000003b 00000000 00000005 00000012 0000002e 00007b30 00000000  00dfbb60 00000230 0027180a 00275882 00d07b26 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Syscall @ 275db2 8e I$SetStt 00000004 0000003b 00000000 00000005 00000012 0000002e 00007b30 00000000  00df9d50 00000230 0027180a 00275882 00d07b26 00d07af4 00d08000 00dfd428 SetStt SS_SM

Afterwards those sound maps are used back and forth

    Written video_1497.png
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00000002 00000320 0000002e 0000002a 00000000  00d05f64 00d06490 00d01672 00231a42 00231a44 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1498.png
    Written video_1499.png
    Written video_1500.png
    Written video_1501.png
    Written video_1502.png
    Written video_1503.png
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00000001 00000320 0000002e 00007b30 00000000  00d05f64 00d06490 00000000 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1504.png
    Written video_1505.png
    Written video_1506.png
    Written video_1507.png
    Written video_1508.png
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00000002 00000320 0000002e 00007b30 00000000  00d05f64 00d06490 00000000 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1509.png
    Written video_1510.png
    Written video_1511.png
    Written video_1512.png
    Written video_1513.png
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00800001 00000320 00000000 00000000 00000000  00d05f64 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1514.png
    Written video_1515.png
    Written video_1516.png
    Written video_1517.png
    Written video_1518.png

Suddenly it stops, directly after resuming gameplay. This is the last one.

    Written video_1553.png
    Syscall @ 276754 8e I$SetStt 00000004 0080003b ffff0001 00000001 00000000 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1554.png
    Written video_1555.png

Going into log, it is weird that CODING 0xff is detected even so we just have started.

    Written video_1553.png
    ...
    Syscall @ 276754 8e I$SetStt 00000004 0080003b ffff0001 00000001 00000000 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    CDIC Write RAM 1905 0005
    Write CDIC 30320a 0005 1 1 1
    CDIC Read RAM 320a 00ff
    Read CDIC 303ff4 0000 1 1 0
    CDIC Read Audio Buffer Register 1ffa 0000
    CDIC Write RAM 1905 0005
    Write CDIC 30320a 0005 1 1 1
    CDIC Read RAM 320a 0005
    DMA Read CH:0 ADDR:00 DATA:8000 LDS:0 UDS:1
    DMA Write CH:0 ADDR:00 DATA:ffff LDS:0 UDS:1
    DMA Write CH:0 ADDR:06 DATA:00df LDS:1 UDS:1
    DMA Write CH:0 ADDR:07 DATA:9d50 LDS:1 UDS:1
    DMA Write CH:0 ADDR:05 DATA:0480 LDS:1 UDS:1
    DMA Write CH:0 ADDR:02 DATA:1212 LDS:1 UDS:0
    DMA Write CH:0 ADDR:03 DATA:8080 LDS:1 UDS:0
    Write CDIC 303ff8 f20c 1 1 1
    CDIC Write DMA Control Register 1ffc f20c
    DMA Read CH:0 ADDR:00 DATA:8000 LDS:0 UDS:1
    DMA Read CH:0 ADDR:00 DATA:8000 LDS:1 UDS:0
    DMA Read CH:0 ADDR:00 DATA:8000 LDS:0 UDS:1
    DMA Read CH:0 ADDR:06 DATA:00df LDS:1 UDS:1
    DMA Read CH:0 ADDR:07 DATA:a650 LDS:1 UDS:1
    Write CDIC 303ffa 2800 1 1 1
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 2800
    Start Decoder at 2800
    Reset audio filters
    DETECT_CODING2 ff
    Write SLAVE 02 8383 1 0 1
    DAC Right 0   0
    ...
    Written video_1554.png

Why is 0x3200 selected as buffer?
Before the error occurs, the playback of coding 05 is just aborted. But why?

    cat log |  grep -e png -e SM -e "Audio Control Registe" -e Decoder -e CODING > barf

    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00800001 00000320 00000000 00000000 00000000  00d05f64 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 2800
    Written video_1514.png
    Written video_1515.png
    Written video_1516.png
    Written video_1517.png
    Written video_1518.png
    Start Decoder at 2800
    DETECT_CODING2 05
    CDIC Read Z Buffer Register / Audio Control Register 1ffd 2800
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 2800
    Written video_1519.png
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Read Z Buffer Register / Audio Control Register 1ffd 0000
    Written video_1520.png
    Written video_1521.png
    Written video_1522.png
    Written video_1523.png

    cat log |  grep -e png -e SM -e "Audio Control Registe" -e Decoder -e CODING -e Syscall > barf

    Syscall @ 27b28c 8e I$SetStt 00000007 00000123 00000018 0000003b 00000008 0000002e 00007b30 00000000  002310f0 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt MA_Pause
    Return from Syscall 0001  cdi_cc 0027b290  00000007 000000cb 00000018 0000003b 00000008 0000002e 00007b30 00000000  002310f0 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd430 0001
    Syscall @ 277832 8e I$SetStt 00000008 00000033 00000018 0000003b 00000008 0000002e 00007b30 00000000  002310f0 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_Pause
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Read Z Buffer Register / Audio Control Register 1ffd 0000

There it is. SS_Pause is breaking audiomap playback

    cat log |  grep -e png -e SM \
        -e "Audio Control Register" \
        -e "CDIC Write Command Register" \
        -e "CDIC Write Data Buffer Register" \
        -e Decoder -e CODING -e Syscall > barf


    Syscall @ 277832 8e I$SetStt 00000008 00000033 00000018 0000003b 00000008 0000002e 00007b30 00000000  002310f0 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_Pause
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Read Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Write Command Register 1e00 0024
    CDIC Write Data Buffer Register 1fff c000
    ...
    Syscall @ 277832 8e I$SetStt 00000008 00000037 ffffffc0 0000003b 00000008 00000080 00000028 00000080  00000004 00d064b2 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_Cont
    CDIC Write Command Register 1e00 002a
    CDIC Write Data Buffer Register 1fff c000
    ...
    Syscall @ 276754 8e I$SetStt 00000004 0080003b ffff0001 00000001 00000000 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 2800
    Start Decoder at 2800
    DETECT_CODING2 ff

I've measured on real hardware that writing 0 to AUDCTL doesn't stop the playback.
The currently played sector still continues to the end.

Maybe the next audio map is written to 3200 because it is still assumed that playback is going on.
That can be checked by measuring Level C time vs frames.

    cat log |  grep -e png -e SM -e CODING > barf


    DETECT_CODING2 05
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00000002 00000320 00000000 40041320 00000000  00d05f64 00d06490 00000000 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1212.png
    Written video_1213.png
    Written video_1214.png
    Written video_1215.png
    Written video_1216.png
    DETECT_CODING2 05
    Written video_1217.png
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 67800001 00000320 00000000 00000000 00000000  00d05f64 00d06490 00276eb0 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1218.png
    Written video_1219.png
    Written video_1220.png
    Written video_1221.png
    DETECT_CODING2 05
    Written video_1222.png
    Written video_1223.png
    Written video_1224.png
    Written video_1225.png
    Written video_1226.png
    Written video_1227.png
    DETECT_CODING2 ff
    Written video_1228.png

Just 6 frames...

I've also found this

    Written video_1453.png
    Written video_1454.png
    Syscall @ 276754 8e I$SetStt 00000004 0080003b ffff0001 00000001 00000000 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    DETECT_CODING2 ff
    DETECT_CODING2 05
    Syscall @ 276754 8e I$SetStt 00000004 0000003b 00000001 00000002 00000320 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    Written video_1455.png
    Written video_1456.png
    Written video_1457.png

In this case, a single sm_out has seemed to have refilled the 2800 buffer

Close inspection

    cat log |  grep -e png -e SM \
        -e "Audio Control Register" \
        -e "CDIC Write Command Register" \
        -e "CDIC Write Data Buffer Register" \
        -e Decoder -e CODING -e Syscall > barf

    Syscall @ 276754 8e I$SetStt 00000004 0080003b ffff0001 00000001 00000000 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 0800
    Start Decoder at 2800
    DETECT_CODING2 ff
    CDIC Read Z Buffer Register / Audio Control Register 1ffd 0001
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Read Z Buffer Register / Audio Control Register 1ffd 0000
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 2800
    Start Decoder at 2800
    DETECT_CODING2 05

What is the difference to the failing case?

    Syscall @ 276754 8e I$SetStt 00000004 0080003b ffff0001 00000001 00000000 0000002e 00007b30 00000000  00d05f64 00d01d66 0027675e 00d0151a 00d0649e 00d07af4 00d08000 00dfd428 SetStt SS_SM
    CDIC Write Z Buffer Register / Audio Control Register 1ffd 2800
    Start Decoder at 2800
    DETECT_CODING2 ff

The path is very different. AUDCTL is never set to 0 before.
It should be noted that this is also happening on the sm_out() afterwards during normal playback.
!!! We have to assume that cdapdriv thinks that playback is still going on. !!!

    cat log |  grep -e png -e SM \
        -e "Audio Control Register" \
        -e "Audio Buffer Register" \
        -e "CDIC Write Command Register" \
        -e "CDIC Write Data Buffer Register" \
        -e Decoder -e CODING -e SS_Cont -e SS_Pause > barf


It seems that my implementation was wrong here.
The audio buffer register should have bit 15 set after playback has been finished, even so
audio control was set to 0.
Also, playback cannot be stopped on real hardware.
