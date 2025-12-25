# Fallback: If BUILD_DIR isn't provided by the root Makefile, 
# it assumes the build folder is two levels up.
BUILD_DIR ?= $(abspath ../../../build)
ASM = nasm

TARGET = $(BUILD_DIR)/stage1.bin

all: $(TARGET)

$(TARGET): bootloader.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) $< -f bin -o $@

clean:
	rm -f $(TARGET)