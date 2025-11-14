FIRMWARE_OBJS = start.o main.o
TOOLCHAIN_PREFIX = /opt/riscv/bin/riscv32-unknown-elf-
COMPRESSED_ISA = C
CFLAGS = -Os -mabi=ilp32 -march=rv32im$(subst C,c,$(COMPRESSED_ISA)) \
	-ffreestanding -fdata-sections -ffunction-sections --std=c99 -nostartfiles

all: firmware.mem firmware.lst

analyze: firmware.elf
	nm  --print-size --size-sort  firmware.elf 

firmware.mem: firmware.bin
	xxd -p -c4 firmware.bin firmware.mem
	wc firmware.mem
	cp firmware.mem ../../rtl/mpeg/fma/firmware.mem

firmware.bin: firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware.elf: $(FIRMWARE_OBJS) sections.lds
	$(TOOLCHAIN_PREFIX)gcc $(CFLAGS) -o $@ \
		-Wl,--gc-sections,--build-id=none,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) $(TEST_OBJS) -lgcc

firmware.lst: firmware.elf
	$(TOOLCHAIN_PREFIX)objdump --disassemble-all firmware.elf > firmware.lst

start.o: start.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o $@ $<

main.o: main.c pl_mpeg.h
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o main.o main.c

clean:
	rm -f *.o *.mem *.bin *.map *.elf *.lst
