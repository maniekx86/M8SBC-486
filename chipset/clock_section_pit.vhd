----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    13:21:07 09/22/2025
-- Design Name:
-- Module Name:    clock_section_pit - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: Clock divider for PIT
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
LIBRARY UNISIM;
USE UNISIM.VCOMPONENTS.ALL;

ENTITY clock_section_pit IS
	PORT (
		CLK_INPUT	: IN  STD_LOGIc;  -- 14.318 MHz in
		CLK_OUT		: OUT STD_LOGIC	  -- 1.193 MHz out
	);
END clock_section_pit;

ARCHITECTURE Behavioral OF clock_section_pit IS
	SIGNAL CLKDV_raw  : STD_LOGIC;
	SIGNAL CLK0_raw	  : STD_LOGIC;
	SIGNAL CLKFB	  : STD_LOGIC;
	SIGNAL LOCKED_int : STD_LOGIC;
BEGIN

	CLKDLL_inst : CLKDLL
	GENERIC MAP (
		CLKDV_DIVIDE => 12.0, -- "invalid" but works?!
		  -- We can divide by: 1.5,2.0,2.5,3.0,4.0,5.0,8.0 or 16.0
		DUTY_CYCLE_CORRECTION => TRUE,
		STARTUP_WAIT => TRUE
	)
	PORT MAP (
		CLKIN	=> CLK_INPUT,	-- from input buffer (AT MAIN)
		CLKFB	=> CLKFB,		-- feedback from BUFG
		RST		=> '0',			-- no reset
		CLKDV	=> CLKDV_raw,	-- divided clock
		CLK0	=> CLK0_raw,	-- 0° output for feedback
		CLK90	=> OPEN,
		CLK180	=> OPEN,
		CLK270	=> OPEN,
		CLK2X	=> OPEN,
		LOCKED	=> LOCKED_int
	);

	BUFG_FB : BUFG
	PORT MAP (
		I => CLK0_raw,
		O => CLKFB
	);

	BUFG_CLKDV : BUFG
	PORT MAP (
		I => CLKDV_raw,
		O => CLK_OUT
	);

END Behavioral;
