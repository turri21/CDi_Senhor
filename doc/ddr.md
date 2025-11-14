# DE10-nano DDR3

A total of 1GB of DDR3 memory is available.
The usage of this memory is not very well documented

    0x00000000 First 512MB are for Linux
    0x20000000 MiSTer Scaler (2048*3*1024 size)
    0x22000000 MiSTer fb?
    0x22001000 MiSTer fb?
    0x24000000 arcade_video rotation module (3x8MB)
    0x30000000 Used by N64, so it is free for the core. Considered safe
