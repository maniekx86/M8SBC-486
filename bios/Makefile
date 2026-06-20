# Makefile for BIOS build
# Requirements: nasm, dd, make

VERSION := "A2.02"

# Tools
NASM := nasm
DD := dd
CP := cp


# Directories
OUT_DIR := out
C_SRC_DIR := c_src
EMPTY_DIR := empty


# Source files
BIOS_ASM := bios.asm
STARTVECTOR_ASM := startvector.asm
# TODO: make the fixed BIOS addresses be set up in a way other than creating a ASM source for each vector?
VGAVECTOR_ASM := vgavector.asm
INT15VECTOR_ASM := int15vector.asm

# Recompile BIOS_ASM on file update from drivers, data and isr directories
INCLUDES = $(wildcard drivers/*.asm data/*.asm isr/*.asm)

# Output files
BIOS_BIN := $(OUT_DIR)/bios.bin

STARTVECTOR_BIN := $(OUT_DIR)/startvector.bin
VGAVECTOR_BIN := $(OUT_DIR)/vgavector.bin
INT15VECTOR_BIN := $(OUT_DIR)/int15vector.bin

BIOS_C_BLOB := $(C_SRC_DIR)/out/bios_c_blob.bin
IMAGE_64K := $(OUT_DIR)/image64k.bin

# Ready to flash image
M8SBC_FLASH := $(OUT_DIR)/m8sbc_flash.bin


# Empty images
EMPTY_64K := $(EMPTY_DIR)/empty64k.bin
EMPTY_256K := $(EMPTY_DIR)/empty256k.bin



# Default target
.PHONY: all
all: $(IMAGE_64K) $(M8SBC_FLASH)

# Create output directory
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Build C sources
.PHONY: c_sources
c_sources:
	$(MAKE) -C $(C_SRC_DIR) VERSION=$(VERSION)

$(BIOS_C_BLOB): c_sources
	@:

# Assemble NASM files
$(BIOS_BIN): $(BIOS_ASM) $(INCLUDES) | $(OUT_DIR)
	$(NASM) $< -f bin -o $@

$(STARTVECTOR_BIN): $(STARTVECTOR_ASM) | $(OUT_DIR)
	$(NASM) $< -f bin -o $@

$(VGAVECTOR_BIN): $(VGAVECTOR_ASM) | $(OUT_DIR)
	$(NASM) $< -f bin -o $@
	
$(INT15VECTOR_BIN): $(INT15VECTOR_ASM) | $(OUT_DIR)
	$(NASM) $< -f bin -o $@

# Build 64K image
$(IMAGE_64K): $(BIOS_BIN) $(STARTVECTOR_BIN) $(VGAVECTOR_BIN) $(INT15VECTOR_BIN) $(BIOS_C_BLOB) $(EMPTY_64K) | $(OUT_DIR)
	$(CP) $(EMPTY_64K) $@
	$(DD) if=$(BIOS_BIN) of=$@ bs=1 seek=0 conv=notrunc
# startvector.bin, 0xFFF0
	$(DD) if=$(STARTVECTOR_BIN) of=$@ bs=1 seek=65520 conv=notrunc 
# vgavector.bin 0xF065
	$(DD) if=$(VGAVECTOR_BIN) of=$@ bs=1 seek=61541 conv=notrunc
# int15vector.bin 0xF859
	$(DD) if=$(INT15VECTOR_BIN) of=$@ bs=1 seek=63577 conv=notrunc
# bios_c_blob.bin, 0x2000
	$(DD) if=$(BIOS_C_BLOB) of=$@ bs=1 seek=8192 conv=notrunc

# Build M8SBC flash image
$(M8SBC_FLASH): $(IMAGE_64K) $(EMPTY_256K) | $(OUT_DIR)
	$(CP) $(EMPTY_256K) $@
	$(DD) if=$< of=$@ bs=1 seek=196608 conv=notrunc

# Clean build artifacts
.PHONY: clean
clean:
	rm -rf $(OUT_DIR)
	$(MAKE) -C $(C_SRC_DIR) clean


