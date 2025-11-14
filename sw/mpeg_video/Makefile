FIRMWARE_OBJS = start.o main.o
FIRMWARE2_OBJS = start.o main2.o

TOOLCHAIN_PREFIX = /opt/riscv/bin/riscv32-unknown-elf-
COMPRESSED_ISA = C
CFLAGS = -O3 -mabi=ilp32 -march=rv32im$(subst C,c,$(COMPRESSED_ISA)) \
	-ffreestanding -fdata-sections -ffunction-sections --std=c99 -nostartfiles

all: firmware.mem firmware.lst firmware2.mem firmware2.lst

analyze: firmware.elf
	nm  --print-size --numeric-sort firmware.elf 

firmware.mem: firmware.bin
	objcopy -I binary -O binary --reverse-bytes=4 firmware.bin firmware_swap.bin
	xxd -p -c4 firmware_swap.bin firmware.mem
	wc firmware.mem
	cp firmware.mem ../../rtl/mpeg/fmv/firmware.mem

firmware2.mem: firmware2.bin
	objcopy -I binary -O binary --reverse-bytes=4 firmware2.bin firmware2_swap.bin
	xxd -p -c4 firmware2_swap.bin firmware2.mem
	wc firmware2.mem
	cp firmware2.mem ../../rtl/mpeg/fmv/firmware2.mem

firmware.bin: firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware2.bin: firmware2.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@


firmware.elf: $(FIRMWARE_OBJS) sections_decoder.lds
	$(TOOLCHAIN_PREFIX)gcc $(CFLAGS) -o $@ \
		-Wl,--gc-sections,--build-id=none,-Bstatic,-T,sections_decoder.lds,-Map,firmware1.map,--strip-debug \
		$(FIRMWARE_OBJS) $(TEST_OBJS) -lgcc

firmware2.elf: $(FIRMWARE2_OBJS) sections_worker.lds
	$(TOOLCHAIN_PREFIX)gcc $(CFLAGS) -o $@ \
		-Wl,--gc-sections,--build-id=none,-Bstatic,-T,sections_worker.lds,-Map,firmware2.map,--strip-debug \
		$(FIRMWARE2_OBJS) $(TEST_OBJS) -lgcc


firmware.lst: firmware.elf
	$(TOOLCHAIN_PREFIX)objdump --disassemble-all firmware.elf > firmware.lst

firmware2.lst: firmware2.elf
	$(TOOLCHAIN_PREFIX)objdump --disassemble-all firmware2.elf > firmware2.lst

start.o: start.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o $@ $<

main.o: main.c *.h
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o main.o main.c

main2.o: main2.c *.h
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o main2.o main2.c


clean:
	rm -f *.o *.mem *.bin *.map *.elf *.lst
