# --- Configuration ---
CC = i686-linux-gnu-gcc
LD = i686-linux-gnu-ld
ASM = nasm
PYTHON3 = python3

C_SOURCES = main.c interrupts.c vga.c utils.c cpudetect.c keyboard.c about.c ide.c cmos.c setup.c
ASM_SOURCES = entry.asm

VERSION ?= "?.??"

BOOTLOGO_DIR = bootlogo
BOOTLOGO_SRC = logo.png
BOOTLOGO = fontdata.h
BOOTLOGO_TARGET = $(BOOTLOGO_DIR)/$(BOOTLOGO)

OUT_DIR = out

# --- Internal Variables ---
# Convert .c -> out/xxx.o
C_OBJECTS = $(patsubst %.c, $(OUT_DIR)/%.o, $(C_SOURCES))
# Convert .asm -> out/xxx.o
ASM_OBJECTS = $(patsubst %.asm, $(OUT_DIR)/%.o, $(ASM_SOURCES))
# All objects combined
ALL_OBJECTS = $(ASM_OBJECTS) $(C_OBJECTS)

# Flags
CFLAGS = -m32 -march=i486 -ffreestanding -Os -Wall -Wextra \
         -fno-pic -fno-stack-protector -fomit-frame-pointer -I. \
		 -fno-asynchronous-unwind-tables -fno-unwind-tables \
		 -DVERSION=\"$(VERSION)\"

LDFLAGS = -T linkerc.ld -nostdlib

# --- Rules ---

# Default Target
all: $(OUT_DIR)/bios_c_blob.bin

$(BOOTLOGO_TARGET): $(BOOTLOGO_DIR)/$(BOOTLOGO_SRC)
	cd $(BOOTLOGO_DIR) && $(PYTHON3) gen_logo.py $(BOOTLOGO_SRC)

# Ensure output directory exists
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Compile C files
$(OUT_DIR)/%.o: %.c | $(OUT_DIR) $(BOOTLOGO_TARGET)
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble ASM files
$(OUT_DIR)/%.o: %.asm | $(OUT_DIR)
	$(ASM) -f elf32 $< -o $@

# Link everything together
$(OUT_DIR)/bios_c_blob.bin: $(ALL_OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $(ALL_OBJECTS) --print-map > $(OUT_DIR)/map.txt


# Clean up
clean:
	rm -rf $(OUT_DIR)
	rm -f $(BOOTLOGO_DIR)/$(BOOTLOGO)
	rm -f $(BOOTLOGO_DIR)/preview.bin
