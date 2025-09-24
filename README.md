# M8SBC-486
All the sources (Schematics, PCB, VHDL, BIOS sources) for the M8SBC-486. 

This project is a 486 Homebrew computer, with some efforts to make it kinda PC compatible

<img width="600" alt="3d render top" src="https://github.com/user-attachments/assets/c3660d31-5cec-41c4-a888-bc9a218be1a0" />

# Folders
## pcb/
Schematic and PCB design for this homebrew computer. Board is 150mm*150mm with 4 layers. (Placement of the screw holes is not compliant with any standard)

### Specs:
- 4MB SRAM, (8*HM628512)
- 256KB of ROM (W29C020)
- Two 16-bit ISA slots
- 8254 Programmable Interval Timer
- 8259 Programmable Interrupt controller
- PS/2 Keyboard
- Xilinx Spartan II XC2S100 FPGA as "chipset"
- ATMega128 as reset circuit handler and bitstream loader
  
<hr>

### Special thanks to [PCBWay](https://www.pcbway.com)!
[<img src="https://github.com/user-attachments/assets/9c270085-e667-4e85-bc4e-80821a971aca" width="400">](https://www.pcbway.com)

Special thanks to PCBWay for sponsoring PCBs for this project! Their sponsorship was a huge help and enabled me to make progress with this project. PCBWay is a well-known PCB prototyping and manufacturing service, providing high-quality boards and excellent customer support. I have worked with their boards in the past and can say that they are of great quality. I easily placed an order for PCBs on their platform for this project without any problems. The sponsorship also included a free quick delivery option. If you’re looking for reliable PCB prototyping and manufacturing services, I highly recommend [checking them](https://www.pcbway.com).

## xilinx/
FPGA sources [to do]

[rest to do]

## Images
<img width="600" alt="3d render back" src="https://github.com/user-attachments/assets/ad219e94-d9bd-4d1b-94ef-2878d594568b" />
<img width="600" alt="pcb view" src="https://github.com/user-attachments/assets/de7f4183-888d-4929-84c8-d80f1c8443ea" />
