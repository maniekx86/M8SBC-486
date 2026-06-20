# M8SBC-486 SeaPig BIOS

Minimal BIOS for M8SBC-486 that is capable of booting various operating systems such as MS-DOS, FreeDOS or Linux. 

Current version: A2.02

See docs/ for more technical information and release history.

## Building

Requirements: `make`, `nasm`, `dd`, `i686-linux-gnu-gcc`, `python3` (with Pillow installed, required for boot logo)

To build, clone repository and run `make` in this directory. Ready to flash image will be at `out/m8sbc_flash.bin`

## Improvements

- Fancy POST screen
- LBA support (read)
- Hard drive detection
- BIOS setup
- Extended memory test
- Compatibility fixes
- POST codes (see docs/)
- More complete keyboard implementation

## Issues / TODOs

- No LBA write support
- Compact flash cards get randomly corrupted (unsure if it's a hardware or BIOS issue).

## Original README

### x86 embedded BIOS R3

Very compact (less than 8KB of ROM space) x86 BIOS for embedded systems, FPGA, and emulators.

### Implemented functions and features

* Minimal initialization
* Minimal functionality ISRs 10h-1Ah
* Lower memory test with continuous mode to help debugging FPGA SDRAM controller
* Very compact Video BIOS
* Minimal SVGA functionality enough to run hi-res games like "Heroes Of Might and Magic" and "Transport Tycoon"
* Supports add-on ROM chips (see config.inc)
* BIOS disk hypercall for emulators
* SPI mode SD-card support on FPGA boards
* Very simplified USB HID device support for FPGA boards
* Good for a systems without video adapter
* Customizable SPI/USB drivers
* A20 line and PLL control (frequency multiplier for 486)

### Known issues

* No hardware detection / BIOS setup (to save ROM space)
* No extended memory test
* Int 13h (BIOS disk) supports only reset/read/write functions
* Internal video BIOS doesn't support printing text in graphic mode
* Video adapter initialization incomplete so will not work properly with a real VGA chips without OEM BIOS
