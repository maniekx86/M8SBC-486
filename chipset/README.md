# M8SBC-486 FPGA sources

Codename: "Hamster 1" chipset

Experimental "chipset" made for M8SBC-486. 

- 24 MHz max FSB (At current time of writing, might be possible to go further)
- Can address up to a maximum of 4MB of SRAM
- No support for burst data transfers
- Integrated [8042 compatible keyboard controller](https://github.com/maniekx86/kbc_8042_vhdl)
- Integrated simple RTC/CMOS (CMOS volatile)

Full documentation: TO DO. At this time some information available is [here](https://maniek86.xyz/projects/m8sbc_486_hw_chp.php).

## Importing & building

To properly import and build VHDL sources to an FPGA bitstream, you have to:

1. Install Xilinx ISE 10.1. Downloads are still available on the [AMD website](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive-ise.html). I've used "ISE Design Suite - 10.1  Full Product Installation"

2. Launch Project navigator and create new project (File -> New Project)

3. Choose Project name, Project location. For "Top-level source type" choose HDL. Click next

4. Configure Device Properties:
   
   - Product Category: All
   - Family: Spartan2
   - Device: XC2S100
   - Package: TQ144
   - Speed: Choose depending on your part, if unsure -6 should work for all
   - Synthesis Tool: XST (VHDL/Verilog)
   - Simulator: Leave as is
   - Preferred Language: VHDL
   - Enable enhanced Design Summary:  Yes
   - Enable Message Filtering: No
   - Enable Incremental Messages: No
   
   Click next

5. In "Create New Source" dialog, do not do anything. Click Next

6. In the "Add Existing Sources" dialog, click Add Source, navigate to the directory where you downloaded the VHDL sources and select all (including the .ucf file). Leave "Copy to Project" checked. Click Next and then Finish

7. You will see the "Adding Source Files" dialog box. Each source should have a green check mark. Do not change anything here; click OK. If everything went right, you should see in the Sources window (left top) all the sources with the m8sbc_main.vhd being at top.

8. In Processes window (below the Sources window), double click on the "Generate Programming File". If the process finishes successfully then the .bit file should be located in the project's directory.

### Issues with ISE 10.1

I successfully got the ISE 10.1 to work pretty nicely on the Windows 10 x64, however, it is possible you will run into problems during install or compilation. Below are potential issues:

#### During compilation there is error "Failed to link the design"

See: [Error in VHDL (Xilinx): failed to link the design - Stack Overflow](https://stackoverflow.com/questions/23033297/error-in-vhdl-xilinx-failed-to-link-the-design)

## What's next

To "flash" the bitstream to the M8SBC-486, copy the .bit file to the AVR sources directory and compile it. The bitstream will be embedded into ATMega128, and will be loaded on every power up by it. You can alternatively load up the bitstream temporarily to the FPGA using the onboard JTAG connector.
