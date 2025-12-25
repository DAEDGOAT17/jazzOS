BUILD_DIR ?= $(abspath ../../../build)
ASM = nasm

TARGET = $(BUILD_DIR)/stage2.bin

all: $(TARGET)

$(TARGET): kernel.asm
	@mkdir -p $(BUILD_DIR)
	$(ASM) $< -f bin -o $@

clean:
	rm -f $(TARGET)