----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    22:47:54 09/17/2025
-- Design Name:
-- Module Name:    m8sbc_main - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: Main file connecting everything together
--
-- Dependencies:
--
-- Revision:
-- Revision 0.02 - isa_driver rewrite
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
LIBRARY IEEE;
LIBRARY UNISIM;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE UNISIM.VCOMPONENTS.ALL;

ENTITY m8sbc_main IS
	PORT (
	-- Clocks (in)
		CLK_IN_MAIN			: IN		STD_LOGIC;
		CLK_IN_14_318		: IN		STD_LOGIC;
	-- Clocks (out)
		CLK_OUT_CPU			: OUT		STD_LOGIC;
		CLK_OUT_ISA			: OUT		STD_LOGIC;
		CLK_OUT_PIT			: OUT		STD_LOGIC;

	-- CPU Input pins
		CPU_IN_ADDR			: IN		STD_LOGIC_VECTOR(23 DOWNTO 2);
		CPU_IN_ADDR_31		: IN		STD_LOGIC;
		CPU_IN_WR			: IN		STD_LOGIC; -- 0 = read, 1 = write
		CPU_IN_ADS			: IN		STD_LOGIC;
		CPU_IN_MIO			: IN		STD_LOGIC; -- 0 = IO, 1 = MEM
		CPU_IN_DC			: IN		STD_LOGIC;
		CPU_IN_BE			: IN		STD_LOGIC_VECTOR( 3 DOWNTO 0);
	-- CPU Output pins
		CPU_OUT_RDY			: OUT		STD_LOGIC;
		CPU_OUT_BS8			: OUT		STD_LOGIC;
		CPU_OUT_BS16		: OUT		STD_LOGIC;
		CPU_OUT_KEN			: OUT		STD_LOGIC;
		CPU_OUT_NMI			: OUT		STD_LOGIC;
	-- CPU InOut pins
		CPU_DATA			: INOUT		STD_LOGIC_VECTOR( 7 DOWNTO 0);

	-- Generated address lines
		ADDR_A0				: OUT		STD_LOGIC;
		ADDR_A1				: OUT		STD_LOGIC;

	-- Reset
		RESET_SYS_IN		: IN		STD_LOGIC;
		RESET_REQ_OUT		: OUT		STD_LOGIC;

	-- Config pins
		RAM_CACHE_EN		: IN		STD_LOGIC;
		ROM_CACHE_EN		: IN		STD_LOGIC;

	-- RAM control lines
		RAM_CS0				: OUT		STD_LOGIC;
		RAM_CS1				: OUT		STD_LOGIC;
		RAM_WE_B			: OUT		STD_LOGIC_VECTOR( 3 DOWNTO 0);
		RAM_OE_B			: OUT		STD_LOGIC_VECTOR( 3 DOWNTO 0);

	-- ROM
		ROM_CS				: OUT		STD_LOGIC;

	-- Bus width transcievers control pins
		TR_8B				: OUT		STD_LOGIC_VECTOR( 3 DOWNTO 0);
		TR_16B_LOW			: OUT		STD_LOGIC;
		TR_16B_HIGH			: OUT		STD_LOGIC;

	-- Generic control lines
		MEM_WR				: OUT		STD_LOGIC;
		MEM_RD				: OUT		STD_LOGIC;
		IO_WR				: OUT		STD_LOGIC;
		IO_RD				: OUT		STD_LOGIC;

	-- ISA bus
		ISA_MEM_WR			: OUT		STD_LOGIC;
		ISA_MEM_RD			: OUT		STD_LOGIC;
		ISA_SBHE			: OUT		STD_LOGIC;
		ISA_MEMCS16			: IN		STD_LOGIC;
		ISA_IOCS16			: IN		STD_LOGIC;
		ISA_IO_READY		: IN		STD_LOGIC;

	-- PIC (interrupt controller, IO 0x20-0x21)
		PIC_CS				: OUT		STD_LOGIC;
		PIC_INTA			: OUT		STD_LOGIC;

	-- PIT (timer, IO 0x40-0x43)
		PIT_CS				: OUT		STD_LOGIC;
		PIT_LATCH_LE		: OUT		STD_LOGIC;

	-- Keyboard controller (IO 0x60)
		PS2_CLK				: IN		STD_LOGIC;
		PS2_DATA			: IN		STD_LOGIC;
		PS2_INTERUPT		: OUT		STD_LOGIC;

	-- CMOS NVRAM AVR interface
		AVR_CLK				: IN		STD_LOGIC;
		AVR_IO				: INOUT		STD_LOGIC
	);
END m8sbc_main;

ARCHITECTURE Behavioral OF m8sbc_main IS

	-- CONSTANTS
	-- Update Divider in CLKGEN!

	CONSTANT FPGA_VER					: STD_LOGIC_VECTOR(31 DOWNTO 0) := x"48860002"; -- first 2 bytes - chipset ident, last 2 bytes - version

	CONSTANT REVERSE_CLOCK				: STD_LOGIC	:= '0'; -- Use 1 for 12 MHz, for 16> use 0

--	-- DIV = 4.0 - 12 MHz
--	CONSTANT RAM_WAITSTATES				: INTEGER RANGE 0 TO 127 := 0;
-- CONSTANT RAM_BURST_WAITSTATES		: INTEGER RANGE 0 TO 15  := 0; -- Read bursts
--	CONSTANT ROM_WAITSTATES				: INTEGER RANGE 0 TO 127 := 1;
--
--	CONSTANT ONBOARD_IO_WAITSTATES		: INTEGER RANGE 0 TO 127 := 12;
--	CONSTANT PIC_INT_ACK_WAITSTATES		: INTEGER RANGE 0 TO 127 := 12;
--
--	CONSTANT ISA_CLK_LOW_CYCLES			: INTEGER RANGE 1 TO 15 := 1; -- 6 MHz
--	CONSTANT ISA_CLK_HIGH_CYCLES		: INTEGER RANGE 1 TO 15 := 1;
--

	-- DIV = 2.5 - 19.2 MHz
--	CONSTANT RAM_WAITSTATES				: INTEGER RANGE 0 TO 127 := 1;
-- CONSTANT RAM_BURST_WAITSTATES		: INTEGER RANGE 0 TO 15  := 0;
--	CONSTANT ROM_WAITSTATES				: INTEGER RANGE 0 TO 127 := 1;
--
--	CONSTANT ONBOARD_IO_WAITSTATES		: INTEGER RANGE 0 TO 127 := 19;
--	CONSTANT PIC_INT_ACK_WAITSTATES		: INTEGER RANGE 0 TO 127 := 19;
--
--	CONSTANT ISA_CLK_LOW_CYCLES			: INTEGER RANGE 1 TO 15 := 2; -- 6.4 MHz
--	CONSTANT ISA_CLK_HIGH_CYCLES		: INTEGER RANGE 1 TO 15 := 1;

	-- DIV = 2.0 - 24 MHz
	CONSTANT RAM_WAITSTATES				: INTEGER RANGE 0 TO 127 := 1;
	CONSTANT RAM_BURST_WAITSTATES		: INTEGER RANGE 0 TO 15  := 0;
	CONSTANT ROM_WAITSTATES				: INTEGER RANGE 0 TO 127 := 2;

	CONSTANT ONBOARD_IO_WAITSTATES		: INTEGER RANGE 0 TO 127 := 23;
	CONSTANT PIC_INT_ACK_WAITSTATES		: INTEGER RANGE 0 TO 127 := 23;

	CONSTANT ISA_CLK_LOW_CYCLES			: INTEGER RANGE 1 TO 15 := 2; -- 8 MHz
	CONSTANT ISA_CLK_HIGH_CYCLES		: INTEGER RANGE 1 TO 15 := 1;

	-- COMPONENTS
	COMPONENT clock_section IS
		PORT (
			CLK_INPUT	: IN	STD_LOGIC; -- 48 MHz
			CPU_CLK_OUT : OUT	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT clock_section_pit IS
		PORT (
			CLK_INPUT	: IN	STD_LOGIC; -- 14.318 MHz in
			CLK_OUT		: OUT	STD_LOGIC  -- 1.193 MHz out
		);
	END COMPONENT;

	COMPONENT ram_driver IS
		PORT (
			CLK				: IN		STD_LOGIC;
			RESET			: IN		STD_LOGIC;
			BE				: IN		STD_LOGIC_VECTOR(3 DOWNTO 0);
			ADS				: IN		STD_LOGIC; -- Active LOW
			CPU_RW			: IN		STD_LOGIC; -- Inverted in x86! 0 - read, 1 - write
			RAMCS			: IN		STD_LOGIC; -- Active LOW
			ADDR21			: IN		STD_LOGIC; -- switches between first and second bank (2MB)

			CS0				: OUT		STD_LOGIC;
			CS1				: OUT		STD_LOGIC;
			RDY				: OUT		STD_LOGIC;
			WE				: OUT		STD_LOGIC_VECTOR(3 DOWNTO 0); -- For each bytes
			OE				: OUT		STD_LOGIC_VECTOR(3 DOWNTO 0);

			RAM_WAITSTATES	: IN		INTEGER RANGE 0 TO 127;
			RAM_BURST_WAITSTATES : IN	INTEGER RANGE 0 TO 15
		);
	END COMPONENT;

	COMPONENT transceiver_driver IS
	PORT (
		BE					: IN		STD_LOGIC_VECTOR(3 DOWNTO 0);
		BS8					: IN		STD_LOGIC;
		BS16				: IN		STD_LOGIC;

		TR_8B				: OUT		STD_LOGIC_VECTOR( 3 DOWNTO 0);
		TR_16B_LOW			: OUT		STD_LOGIC;
		TR_16B_HIGH			: OUT		STD_LOGIC
	);
	END COMPONENT;

	COMPONENT be_decoder IS
	PORT (
		BE0		: IN	STD_LOGIC;
		BE1		: IN	STD_LOGIC;
		BE2		: IN	STD_LOGIC;
		BE3		: IN	STD_LOGIC;

		A1		: OUT	STD_LOGIC;
		A0_BLE	: OUT	STD_LOGIC;
		BHE		: OUT	STD_LOGIC
	);
	END COMPONENT;

	COMPONENT address_decoder IS
	PORT (
			ADDR_IN			: IN	STD_LOGIC_VECTOR(23 DOWNTO 2);
			ADDR_31			: IN	STD_LOGIC;
			ADDR_A0			: IN	STD_LOGIC;
			ADDR_A1			: IN	STD_LOGIC;
			CPU_MIO			: IN	STD_LOGIC; -- 0 = IO, 1 = MEM
			CPU_WR			: IN	STD_LOGIC; -- 0 = read

			RAM_CACHEABLE	: IN	STD_LOGIC;
			ROM_CACHEABLE	: IN	STD_LOGIC;

			INT_ACK			: IN	STD_LOGIC;

			RAM_CS			: OUT	STD_LOGIC;
			ROM_CS			: OUT	STD_LOGIC; -- ROM_CS, will activate only on READ
			PIC_CS			: OUT	STD_LOGIC;
			PIT_CS			: OUT	STD_LOGIC;
			PS2_CS			: OUT	STD_LOGIC;
			O61_CS			: OUT	STD_LOGIC; -- Write only 61h output port (latch used)
			ISA_CS			: OUT	STD_LOGIC;
			CMOS_CS			: OUT	STD_LOGIC;

			OUT_KEN			: OUT	STD_LOGIC;
			OUT_BS16		: OUT	STD_LOGIC;
			OUT_BS8			: OUT	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT wr_rd_generator IS
		PORT (
			CLK				: IN	STD_LOGIC;
			RESET			: IN	STD_LOGIC;
			ADS				: IN	STD_LOGIC;
			RW				: IN	STD_LOGIC;
			MIO				: IN	STD_LOGIC;
			EN_WRRD			: IN	STD_LOGIC;
			WAITSTATE_CNT	: IN	INTEGER RANGE 0 TO 127;

			RDY				: OUT	STD_LOGIC;
			MEM_WR			: OUT	STD_LOGIC;
			MEM_RD			: OUT	STD_LOGIC;
			IO_WR			: OUT	STD_LOGIC;
			IO_RD			: OUT	STD_LOGIC

		);
	END COMPONENT;

	COMPONENT isa_driver IS
		PORT (
			CLK				: IN	STD_LOGIC;
			RESET			: IN	STD_LOGIC;
			ADS				: IN	STD_LOGIC;
			RW				: IN	STD_LOGIC;
			MIO				: IN	STD_LOGIC;
			EN_ISA			: IN	STD_LOGIC; -- negated

			ISA_CLK_HIGH_CYCLES : IN INTEGER RANGE 1 TO 15; -- ISA clock divisor from main clock
			ISA_CLK_LOW_CYCLES	: IN INTEGER RANGE 1 TO 15;
			WAITSTATE_16C	: IN	INTEGER RANGE 0 TO 15; -- From ADS to check 16B signals
			WAITSTATE_END	: IN	INTEGER RANGE 0 TO 127; -- From check to end of transfer

			ISA_MEMCS16		: IN	STD_LOGIC;
			ISA_IOCS16		: IN	STD_LOGIC;
			ISA_IO_READY	: IN	STD_LOGIC; -- Input from ISA

			ISA_RDY			: OUT	STD_LOGIC; -- Output from driver
			ISA_MEM_WR		: OUT	STD_LOGIC;
			ISA_MEM_RD		: OUT	STD_LOGIC;
			ISA_IO_WR		: OUT	STD_LOGIC;
			ISA_IO_RD		: OUT	STD_LOGIC;
			ISA_CLK			: OUT	STD_LOGIC;

			BS8_O			: OUT	STD_LOGIC;
			BS16_O			: OUT	STD_LOGIC;

			CPU_16BTR		: IN	STD_LOGIC;
			ISA_SBHE		: OUT	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT keyboard_controller IS
		PORT (
			CLK			: IN	STD_LOGIC; -- for timeout
			PS2_CLK		: IN	STD_LOGIC;
			PS2_DATA	: IN	STD_LOGIC;
			RESET		: IN	STD_LOGIC;

			D_OUT		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			DS_OUT		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			CLK_CPU		: IN	STD_LOGIC;
			RD_CLEAR	: IN	STD_LOGIC;
			CLEAR_BUF	: IN	STD_LOGIC;
			INT_OUT		: OUT	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT CMOS IS
		PORT (
			CLK_IN		: IN	STD_LOGIC;
			DATA_IN		: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			DATA_OUT	: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			CMOS_CS		: IN	STD_LOGIC;
			WR			: IN	STD_LOGIC;
			RD			: IN	STD_LOGIC;
			A0			: IN	STD_LOGIC;

			CLK_PIT		: IN	STD_LOGIC;

			AVR_CLK		: IN	STD_LOGIC;
			AVR_IO		: INOUT STD_LOGIC;

			FPGA_VER	: IN	STD_LOGIC_VECTOR(31 DOWNTO 0);
			RESET		: IN	STD_LOGIC
		);
	END COMPONENT;

	-- SIGNALS
	SIGNAL	CLK_CPU			: STD_LOGIC; -- 12 MHz (def)
	SIGNAL	CLK_14M_BUF		: STD_LOGIC;
	SIGNAL	CLK_PIT			: STD_LOGIC; -- 1.183 MHz
	SIGNAL	CLK_ISA			: STD_LOGIC;

	SIGNAL	O_BS8			: STD_LOGIC; --
	SIGNAL	O_BS16			: STD_LOGIC; -- equal to ADDRDEC_BS8 or ISA_BS8 depending on CS
	SIGNAL	ADDRDEC_BS8		: STD_LOGIC;
	SIGNAL	ADDRDEC_BS16	: STD_LOGIC;
	SIGNAL	ISA_BS8			: STD_LOGIC;
	SIGNAL	ISA_BS16		: STD_LOGIC;

	SIGNAL	I_CS_RAM		: STD_LOGIC;

	SIGNAL	O_IO_RD			: STD_LOGIC;
	SIGNAL	O_IO_WR			: STD_LOGIC;

	SIGNAL	O_RDY_RAM		: STD_LOGIC;
	SIGNAL	O_RDY_WRRD		: STD_LOGIC;
	SIGNAL	O_RDY_ISA		: STD_LOGIC;

	SIGNAL	O_A0_BLE		: STD_LOGIC;
	SIGNAL	O_A1			: STD_LOGIC;
	SIGNAL	O_BHE			: STD_LOGIC;

	SIGNAL	I_CS_ROM		: STD_LOGIC;
	SIGNAL	I_CS_PIC		: STD_LOGIC;
	SIGNAL	I_CS_PIT		: STD_LOGIC;
	SIGNAL	I_CS_PS2		: STD_LOGIC;
	SIGNAL	I_CS_O61		: STD_LOGIC;
	SIGNAL	I_CS_ISA		: STD_LOGIC;
	SIGNAL	I_CS_CMOS		: STD_LOGIC;

	SIGNAL	S_EN				: STD_LOGIC;
	SIGNAL	S_ISA_EN			: STD_LOGIC;
	SIGNAL	S_WAITSTATES		: INTEGER RANGE 0 TO 127;
	SIGNAL	S_WAITSTATES_ISA16	: INTEGER RANGE 0 TO 127;

	SIGNAL	MUX_MEM_WR		: STD_LOGIC; -- to remove later
	SIGNAL	MUX_MEM_RD		: STD_LOGIC;

	SIGNAL	MUX_ISA_IO_WR	: STD_LOGIC;
	SIGNAL	MUX_ISA_IO_RD	: STD_LOGIC;

	SIGNAL	IO_RD_P			: STD_LOGIC;
	SIGNAL	IO_WR_P			: STD_LOGIC;
	SIGNAL	ISA_MEM_WR_P	: STD_LOGIC;
	SIGNAL	ISA_MEM_RD_P	: STD_LOGIC;

	SIGNAL	O_CPU_DATA		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	O_CPU_DATA_P_O	: STD_LOGIC; -- PS2 or O61
	SIGNAL	O61_DATA_L		: STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00";

	SIGNAL	O_PS2_DATA		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	O_PS2_STATUS	: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	O_PS2_INT		: STD_LOGIC;
	SIGNAL	PS2_RD_CLEAR	: STD_LOGIC;

	SIGNAL	O_CMOS_DATA_OUT	: STD_LOGIC_VECTOR(7 DOWNTO 0);

	SIGNAL	I_INT_ACK		: STD_LOGIC;

	SIGNAL	EXTRA_BS8		: STD_LOGIC;
	SIGNAL	EXTRA_BS16		: STD_LOGIC;

	SIGNAL	CPU_O_KEN		: STD_LOGIC;

	SIGNAL	O_CPU_16BTR		: STD_LOGIC;

BEGIN
	-----------------------------------------
	---- BEGIN							 ----
	-----------------------------------------

	CLKGEN: clock_section PORT MAP(
		CLK_INPUT		=> CLK_IN_MAIN, -- Input 48 MHz
		CPU_CLK_OUT		=> CLK_CPU
	);

	-- BUF for both PIT & ISA
	CLKIN_IBUFG : IBUFG PORT MAP(
		I => CLK_IN_14_318,
		O => CLK_14M_BUF
	);

	CLKGEN_PIT: clock_section_pit PORT MAP(
		CLK_INPUT		=> CLK_14M_BUF,
		CLK_OUT			=> CLK_PIT
	);

	RAMDRV: ram_driver PORT MAP(
		CLK		=> CLK_CPU,
		RESET	=> RESET_SYS_IN,
		BE		=> CPU_IN_BE,
		ADS		=> CPU_IN_ADS,
		CPU_RW	=> CPU_IN_WR,
		RAMCS	=> I_CS_RAM, -- coming from ADRDECODER
		ADDR21	=> CPU_IN_ADDR(21),
		-- Outputs
		CS0		=> RAM_CS0,
		CS1		=>	RAM_CS1,
		RDY		=> O_RDY_RAM,
		WE		=> RAM_WE_B,
		OE		=> RAM_OE_B,

		RAM_WAITSTATES => RAM_WAITSTATES,
		RAM_BURST_WAITSTATES => RAM_BURST_WAITSTATES -- read "bursts" are currently only implemented
	);

	TRANSCIEVERDRV: transceiver_driver PORT MAP(
		BE			=> CPU_IN_BE,
		BS8			=>	O_BS8, -- input
		BS16		=> O_BS16, -- input

		TR_8B		=> TR_8B,
		TR_16B_LOW	=> TR_16B_LOW,
		TR_16B_HIGH	=> TR_16B_HIGH
	);

	BEDECODER: be_decoder PORT MAP(
		BE0		=> CPU_IN_BE(0),
		BE1		=> CPU_IN_BE(1),
		BE2		=> CPU_IN_BE(2),
		BE3		=> CPU_IN_BE(3),

		A1		=> O_A1,
		A0_BLE	=> O_A0_BLE,
		BHE		=> O_BHE
	);

	ADRDECODER: address_decoder PORT MAP(
		ADDR_IN			=> CPU_IN_ADDR,
		ADDR_31			=> CPU_IN_ADDR_31,
		ADDR_A0			=> O_A0_BLE,
		ADDR_A1			=> O_A1,
		CPU_MIO			=> CPU_IN_MIO,
		CPU_WR			=> CPU_IN_WR,

		RAM_CACHEABLE	=> RAM_CACHE_EN,
		ROM_CACHEABLE	=> ROM_CACHE_EN,

		INT_ACK			=> I_INT_ACK,

		-- outputs
		RAM_CS			=> I_CS_RAM, -- to ADRDECODER
		ROM_CS			=> I_CS_ROM, -- direct out
		PIC_CS			=> I_CS_PIC, -- out
		PIT_CS			=> I_CS_PIT, -- out
		PS2_CS			=> I_CS_PS2, -- to KBCTRL
		O61_CS			=> I_CS_O61, -- to LE
		CMOS_CS			=> I_CS_CMOS,
		ISA_CS			=> I_CS_ISA, -- to ISA logic

		OUT_KEN			=> CPU_O_KEN, -- direct out
		OUT_BS16		=> ADDRDEC_BS16,
		OUT_BS8			=> ADDRDEC_BS8
	);

	WRRDGEN: wr_rd_generator PORT MAP(
		CLK				=> CLK_CPU,
		RESET			=>	RESET_SYS_IN,
		ADS				=> CPU_IN_ADS,
		RW				=> CPU_IN_WR,
		MIO				=> CPU_IN_MIO,
		EN_WRRD			=> S_EN,
		WAITSTATE_CNT	=> S_WAITSTATES,

		RDY				=> O_RDY_WRRD,
		MEM_WR			=> MUX_MEM_WR,
		MEM_RD			=> MUX_MEM_RD,
		IO_WR			=> O_IO_WR,
		IO_RD			=> O_IO_RD
	);

	ISA_DRV: isa_driver PORT MAP(
		CLK				=> CLK_CPU,
		RESET			=> RESET_SYS_IN,
		ADS				=> CPU_IN_ADS,
		RW				=> CPU_IN_WR,
		MIO				=> CPU_IN_MIO,
		EN_ISA			=> S_ISA_EN, -- from ADDR decoder

		ISA_CLK_HIGH_CYCLES => ISA_CLK_HIGH_CYCLES,
		ISA_CLK_LOW_CYCLES	=> ISA_CLK_LOW_CYCLES,
		WAITSTATE_16C	=> S_WAITSTATES_ISA16,
		WAITSTATE_END	=> S_WAITSTATES,

		ISA_MEMCS16		=> ISA_MEMCS16,
		ISA_IOCS16		=> ISA_IOCS16,
		ISA_IO_READY	=> ISA_IO_READY, -- Input from ISA

		ISA_RDY			=> O_RDY_ISA, -- Output from driver
		ISA_MEM_WR		=> ISA_MEM_WR_P,
		ISA_MEM_RD		=> ISA_MEM_RD_P,
		ISA_IO_WR		=> MUX_ISA_IO_WR,
		ISA_IO_RD		=> MUX_ISA_IO_RD,
		ISA_CLK			=> CLK_ISA,

		BS8_O			=> ISA_BS8,
		BS16_O			=> ISA_BS16,

		CPU_16BTR		=> O_CPU_16BTR,
		ISA_SBHE		=> ISA_SBHE
	);

	KBCTRL: keyboard_controller PORT MAP(
		CLK			=> CLK_PIT, -- 1.1 MHz, used for transfer timeout
		PS2_CLK		=> PS2_CLK,
		PS2_DATA	=> PS2_DATA,
		RESET		=> RESET_SYS_IN,

		CLEAR_BUF	=> '0',

		D_OUT		=> O_PS2_DATA,
		DS_OUT		=> O_PS2_STATUS,
		CLK_CPU		=> CLK_CPU,
		RD_CLEAR	=> PS2_RD_CLEAR,
		INT_OUT		=> O_PS2_INT
	);

	cmos_rtc: CMOS PORT MAP(
		CLK_IN			=> CLK_CPU,
		DATA_IN			=> CPU_DATA,
		DATA_OUT		=> O_CMOS_DATA_OUT,
		CMOS_CS			=> I_CS_CMOS,
		WR				=> O_IO_WR,
		RD				=> O_IO_RD,
		A0				=> O_A0_BLE,

		CLK_PIT			=> CLK_PIT,

		AVR_CLK			=> AVR_CLK,
		AVR_IO			=> AVR_IO,

		FPGA_VER		=> FPGA_VER,
		RESET			=> RESET_SYS_IN
	);

	O_CPU_16BTR <= O_BHE;

	I_INT_ACK <= '0' WHEN (CPU_IN_DC = '0' AND CPU_IN_MIO = '0') ELSE '1';

	-- ISA MEM WR/RD driven by isa_driver

	-- If ISA active, forward outputs to ISA drv
	IO_RD_P				<= O_IO_RD WHEN I_CS_ISA = '1' ELSE MUX_ISA_IO_RD;
	IO_WR_P				<= O_IO_WR WHEN I_CS_ISA = '1' ELSE MUX_ISA_IO_WR;

	IO_RD <= IO_RD_P WHEN TRUE ELSE '1';
	IO_WR <= IO_WR_P WHEN TRUE ELSE '1';
	MEM_WR		<= MUX_MEM_WR WHEN TRUE ELSE '1';
	MEM_RD		<= MUX_MEM_RD WHEN TRUE ELSE '1';
	ISA_MEM_WR <= ISA_MEM_WR_P WHEN TRUE ELSE '1';
	ISA_MEM_RD <= ISA_MEM_RD_P WHEN TRUE ELSE '1';

	EXTRA_BS8			<= ADDRDEC_BS8 WHEN I_CS_ISA = '1' ELSE ISA_BS8;
	EXTRA_BS16			<= ADDRDEC_BS16 WHEN I_CS_ISA = '1' ELSE ISA_BS16;

	O_BS8  <= '0' WHEN I_INT_ACK = '0' ELSE EXTRA_BS8; -- BS8 on INT ACK
	O_BS16 <= '1' WHEN I_INT_ACK = '0' ELSE EXTRA_BS16;

	-- WR/RD gen activator and WAITSTATE selector
	PROCESS(I_CS_ROM, I_CS_PIC, I_CS_PIT, I_CS_O61, I_CS_ISA, I_INT_ACK)
		VARIABLE SEL_BUS	: STD_LOGIC_VECTOR(3 DOWNTO 0);
	BEGIN

		-- INTA cycle is basically:
		-- Activating I_INT_ACK by setting CPU_DC, CPU_MIO, CPU_WR to 0
		-- CPU do 2 IO reads when I_INT_ACK is 0
		-- A2-A31 is set to 0
		-- PIC ignores CS on INT_ACK
		-- We send two INTA pulses to PIC (override IO_RD)

		SEL_BUS := I_CS_ROM & (I_CS_PIC AND I_CS_PIT AND I_CS_O61 AND I_CS_PS2 AND I_CS_CMOS) & I_CS_ISA & I_INT_ACK;

		S_EN <= '1';
		S_ISA_EN <= '1';
		S_WAITSTATES_ISA16 <= 0;
		S_WAITSTATES <= 0;

		CASE SEL_BUS IS

			WHEN "0111" => -- ROM active
				S_EN <= '0';
				S_WAITSTATES <= ROM_WAITSTATES;

			WHEN "1011" => -- Onboard IO device active (PIT, FPGA)
				S_EN <= '0';
				S_WAITSTATES <= ONBOARD_IO_WAITSTATES;

			WHEN "1101" => -- ISA active

				S_EN <= '1'; -- activate isa
				S_ISA_EN <= '0';

			WHEN "1110" => -- PIC INTA (because I_CS_ISA will be low on INTA addr)
				S_EN <= '0';
				S_WAITSTATES <= PIC_INT_ACK_WAITSTATES;

			WHEN OTHERS =>
				S_WAITSTATES <= 0; -- def no waitstates
				S_EN <= '1'; -- inactive (negated)
				S_ISA_EN <= '1';
				S_WAITSTATES_ISA16 <= 0;
		END CASE;
	END PROCESS;

	PIC_CS <= I_CS_PIC;
	PIT_CS <= I_CS_PIT;

	-- Output from the FPGA to the CPU data bus driver
	PROCESS(O_IO_RD, CPU_IN_WR, I_CS_PS2, I_CS_O61, I_CS_CMOS, CPU_IN_ADDR, O_PS2_STATUS, O_PS2_DATA, O61_DATA_L, O_CMOS_DATA_OUT)
	BEGIN
		O_CPU_DATA <= "ZZZZZZZZ";
		O_CPU_DATA_P_O <= '0';

		PS2_RD_CLEAR <= '1';
		IF (CPU_IN_WR = '0') THEN -- only allow bus drive on reads
			IF (O_IO_RD = '0') THEN

				IF (I_CS_PS2 = '0') THEN -- PS2 read

					IF CPU_IN_ADDR(2) = '1' THEN -- 0x64
						O_CPU_DATA <= O_PS2_STATUS;
					ELSE -- 0x60
						O_CPU_DATA <= O_PS2_DATA;
						PS2_RD_CLEAR <= '0'; -- send clear signal to the PS2
					END IF;

					O_CPU_DATA_P_O <= '1';

				ELSIF (I_CS_O61 = '0') THEN -- O61 read
					O_CPU_DATA <= O61_DATA_L;
					O_CPU_DATA_P_O <= '1';

				ELSIF (I_CS_CMOS = '0') THEN -- CMOS read
					O_CPU_DATA <= O_CMOS_DATA_OUT;
					O_CPU_DATA_P_O <= '1';
				END IF;
			END IF;
		END IF;
	END PROCESS;

	CPU_DATA <= O_CPU_DATA WHEN (O_CPU_DATA_P_O = '1') ELSE "ZZZZZZZZ";

	-- PORT O61 read fix
	-- As output port 61h is a latch, we cant read from it. However we can simulate that using this chipset
	-- So capture data when write occurs to 61h and send it back if something tries to read from it

	-- PIT latch Output port LE.
	-- Inverted. 74573 latch latches on 0, pass tho is on 1
	PIT_LATCH_LE	<= (NOT O_IO_WR) WHEN (I_CS_O61 = '0') ELSE '0'; -- Activate when WR and O61_CS

	PROCESS(CLK_CPU, RESET_SYS_IN) -- O61 write to temp buf
	BEGIN
		IF RESET_SYS_IN = '1' THEN
			O61_DATA_L <= x"00";
		ELSE

			IF FALLING_EDGE(CLK_CPU) THEN -- decoders update on rising edge
				IF (I_CS_O61 = '0') AND (O_IO_WR = '0') THEN
					O61_DATA_L <= CPU_DATA;
				END IF;
			END IF;

		END IF;
	END PROCESS;

	CLK_OUT_CPU		<= NOT CLK_CPU WHEN REVERSE_CLOCK = '1' ELSE CLK_CPU; -- For some timings? reason, running below 16 MHz requires inverting clock
	CLK_OUT_PIT		<= CLK_PIT;
	CLK_OUT_ISA		<= CLK_ISA;
	CPU_OUT_BS8		<= O_BS8; -- TEMP
	CPU_OUT_BS16	<= O_BS16; -- TEMP
	ADDR_A0			<= O_A0_BLE;
	ADDR_A1			<= O_A1;

	PS2_INTERUPT	<= NOT O_PS2_INT;

	ROM_CS			<= I_CS_ROM;

	-- For some reason I inverted RDY behaviour on the generators before. 1 - is WAIT, 0 is READY !!!!!!
	-- ISA_IO_READY is 0 = wait
	CPU_OUT_RDY		<= O_RDY_ISA OR O_RDY_RAM OR O_RDY_WRRD;


	RESET_REQ_OUT	<= '1'; -- active LOW
	CPU_OUT_NMI		<= '0';
	PIC_INTA		<= O_IO_RD WHEN I_INT_ACK = '0' ELSE '1'; -- Int ack for 8259 is like RD. 486 holds INTA state both reads so we need to use IO_RD feature

	CPU_OUT_KEN		<= CPU_O_KEN; -- To fix: doesn't work on ROM

END Behavioral;
