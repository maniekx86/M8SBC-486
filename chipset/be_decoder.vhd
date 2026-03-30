----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    22:02:19 09/20/2025
-- Design Name:
-- Module Name:    be_decoder - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: A0 and A1 decoder from the BE0-3 signals
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
USE IEEE.NUMERIC_STD.ALL;

-- Refer to page 102 of 486DX Datasheet (Oct92)

ENTITY be_decoder IS
	PORT (
		BE0		: IN	STD_LOGIC;
		BE1		: IN	STD_LOGIC;
		BE2		: IN	STD_LOGIC;
		BE3		: IN	STD_LOGIC;

		A1		: OUT	STD_LOGIC;
		A0_BLE	: OUT	STD_LOGIC;
		BHE		: OUT	STD_LOGIC
	);
END be_decoder;

ARCHITECTURE Behavioral OF be_decoder IS
BEGIN

	A1 <= BE0 AND BE1;

	BHE <= BE1 AND BE3;

	A0_BLE <= (BE0 AND BE2) OR (BE0 AND (NOT BE1));

END Behavioral;
