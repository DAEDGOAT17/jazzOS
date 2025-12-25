ASM = nasm
CC = gcc
SRC_DIR = src
BUILD_DIR = $(abspath build)

.PHONY: all clean run always bootloader kernel

all: $(BUILD_DIR)/main_floppy.img
# ... (rest of your variables) ...

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	@echo "--- Building Floppy Image ---"
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "PANKAJOS" $(BUILD_DIR)/main_floppy.img
	# Install Stage 1 to the Boot Sector
	dd if=$(BUILD_DIR)/stage1.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	# Combine Stage 2 and Kernel into one file
	cat $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel.bin > $(BUILD_DIR)/full_stage2.bin
	# Copy to floppy with the filename Stage 1 expects (UPPERCASE)
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/full_stage2.bin "::STAGE2.BIN"

bootloader: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=$(BUILD_DIR)
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=$(BUILD_DIR)

kernel: always
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(BUILD_DIR)

always:
	mkdir -p $(BUILD_DIR)

clean:
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=$(BUILD_DIR) clean
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=$(BUILD_DIR) clean
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(BUILD_DIR) clean
	rm -rf $(BUILD_DIR)/*

run: all
	qemu-system-i386 -fda $(BUILD_DIR)/main_floppy.img -boot a