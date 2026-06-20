# M8SBC-486

All the sources (Schematics, PCB, VHDL, BIOS sources) for the M8SBC-486. 

This project is a 486 Homebrew computer, with some efforts to make it kinda PC compatible. See [my page about it](https://maniek86.xyz/projects/m8sbc_486.php).

<img title="" src="photos/IMG_20251019_031401_g.jpeg" alt="soldered board">

## Specs:

- 150*150mm 4 layer PCB
- PGA-168 socket for 5V 486 CPUs.
- Xilinx Spartan II XC2S100 FPGA as "chipset". Codename "Hamster 1"
- 4MB SRAM, (8*HM628512)
- 256KB of ROM (W29C020 or 39SF020A) (224 KB accessible)
- 8254 Programmable Interval Timer
- 8259 Programmable Interrupt Controller
- Two 16-bit ISA slots
- 8042 compatible PS/2 keyboard controller. Implemented in the FPGA
- Simple CMOS RTC and CMOS storage. Implemented in the FPGA too
- ATMega128 as reset circuit handler, nonvolatile CMOS storage and bitstream loader.

The FSB frequency is currently set to a fixed 24 MHz (DX2 CPUs run then at 48 MHz), but this can be changed by uncommenting/commenting lines in the FPGA source.

Secondary PIC and DMA are missing, so the compatibility is not full. The missing DMA especially breaks support for sound cards.

## Current progress:

The hardware and FPGA are mostly done. BIOS is capable of booting DOS. There are a few issues & bugs, but they are being slowly fixed.

Among the most impressive things the board (as time of writing: 20/06/2026) is capable of:

- Running Linux 2.2.26 ([using custom bootloader](https://github.com/maniekx86/linux_m8sbc_boot)) and Linux 4.4.302 (documentation is coming soon)

- Running MS-DOS and FreeDOS: The software compatibility is mixed. Some software hangs the system, throws exceptions, but some run fine. Most notable are: Second Reality demo (no sound), Prince of Persia, Wolfenstein 3D, Fasttracker II (PC speaker works in one mode, LPT DAC works okay), 3DBench 1.0c, CACHECHK. For more software checks and detailed information, see the compatibility table on the [project's website](https://maniek86.xyz/projects/m8sbc_486.php).

- Running DOOM ([FastDOOM](https://github.com/viti95/FastDoom) running on FreeDOS 1.4)

## Hardware diagram

<img src="photos/hw_diagram.png" alt="Hardware diagram">

<hr>

## Special thanks to [PCBWay](https://www.pcbway.com)!

[<img title="" src="photos/pcbway.png" alt="" width="400">](https://www.pcbway.com)

Special thanks to PCBWay for sponsoring PCBs for this project! Their sponsorship was a huge help and enabled me to make progress with this project. PCBWay is a well-known PCB prototyping and manufacturing service, providing high-quality boards and excellent customer support. I have worked with their boards in the past and can say that they are of great quality. I easily placed an order for PCBs on their platform for this project without any problems. The sponsorship also included a free quick delivery option. If you’re looking for reliable PCB prototyping and manufacturing services, I highly recommend [checking them](https://www.pcbway.com).

# Folders

## pcb/

Schematic and PCB design for this homebrew computer. Board is 150mm*150mm with 4 layers. (Placement of the screw holes is not compliant with any standard)

## chipset/

Sources for the "Hamster 1" chipset. FPGA used is XC2S100 (Xilinx Spartan II). Compile with Xilinx ISE 10.1

## avr/

Sources for AVR ATMega128:

Small AVR firmware that configures the FPGA from on-chip flash at power-up and manages system reset for the M8SBC-486 project

## bios/

M8SBC-486 SeaPig BIOS

Based on this project: [b-dmitry1/BIOS](https://github.com/b-dmitry1/BIOS)

## Disclaimer

This project is essentially my hobby, as I like retro, electronics, digital circuits and low-level programming. I never expected this computer to run DOS in the first place. I consider it pretty much experimental and made to research the workings of older x86 chips. I am pretty sure that this work could be used to build something more robust and stable or even to develop fully custom-made boards for other x86 CPUs. It took me a lot of time, but I don't regret it. There are still many issues, but it's heartwarming that I can get so much existing software to work. And, thanks to everyone for support!

## Acknowledgements

Special thanks to: TheRetroWeb community, [b-dmitry1](https://github.com/b-dmitry1) and [PCBWay](https://pcbway.com/)

## More images

<img alt="PCB bottom" src="photos/IMG_20251002_235903_preview.jpeg">
<img width="600" alt="3d render back" src="photos/render_back.jpg" />
<img width="600" alt="pcb view" src="photos/pcb_view.jpg" />
