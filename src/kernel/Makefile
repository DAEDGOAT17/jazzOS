# src/kernel/Makefile

all: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/kernel.elf
	objcopy -O binary $< $@

$(BUILD_DIR)/kernel.elf: $(BUILD_DIR)/entry.o $(BUILD_DIR)/main.o
	# Explicitly set output format to elf32-i386
	ld -m elf_i386 -T linker.ld -o $@ $^

$(BUILD_DIR)/entry.o: entry.asm
	nasm -f elf32 $< -o $@

$(BUILD_DIR)/main.o: main.c
	gcc -m32 -ffreestanding -fno-stack-protector -fno-pic -O0 -nostdlib -c $< -o $@

clean:
	rm -f $(BUILD_DIR)/entry.o $(BUILD_DIR)/main.o $(BUILD_DIR)/kernel.elf $(BUILD_DIR)/kernel.bin