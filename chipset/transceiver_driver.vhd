----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
-- 
-- Create Date:    19:41:48 09/20/2025 
-- Design Name: 
-- Module Name:    transceiver_driver - Behavioral 
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions: 
-- Description: Driver for byte swapping transceivers
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


ENTITY transceiver_driver IS
	port (
		BE			 		: IN		STD_LOGIC_VECTOR(3 downto 0);
		BS8				: IN		STD_LOGIC;
		BS16				: IN		STD_LOGIC;
		
		TR_8B				: OUT		STD_LOGIC_VECTOR( 3 downto  0);
		TR_16B_LOW		: OUT		STD_LOGIC;	
		TR_16B_HIGH		: OUT		STD_LOGIC
    );
END transceiver_driver;

ARCHITECTURE Behavioral OF transceiver_driver IS
	SIGNAL s_8bit  : STD_LOGIC;
	SIGNAL s_16bit : STD_LOGIC;
BEGIN

    -- Decode bus state internally
    s_8bit  <= '1' WHEN (BS8 = '0' AND BS16 = '1') ELSE '0';
    s_16bit <= '1' WHEN (BS8 = '1' AND BS16 = '0') ELSE '0';

    -- TR_8B(0): Active in either mode if BE(0) is active
    TR_8B(0) <= '0' WHEN ((s_8bit = '1' OR s_16bit = '1') AND BE(0) = '0') ELSE '1';

    -- TR_8B(1): Active only in 8-bit mode if BE(0) is inactive and BE(1) is active
    TR_8B(1) <= '0' WHEN (s_8bit = '1' AND BE(0) = '1' AND BE(1) = '0') ELSE '1';

    -- TR_8B(2): Active in either mode if BE(0..1) are inactive and BE(2) is active
    TR_8B(2) <= '0' WHEN ((s_8bit = '1' OR s_16bit = '1') AND BE(0) = '1' AND BE(1) = '1' AND BE(2) = '0') ELSE '1';

    -- TR_8B(3): Active only in 8-bit mode if BE(0..2) are inactive and BE(3) is active
    TR_8B(3) <= '0' WHEN (s_8bit = '1' AND BE(0) = '1' AND BE(1) = '1' AND BE(2) = '1' AND BE(3) = '0') ELSE '1';

    -- TR_16B_LOW: Active only in 16-bit mode if BE(1) is active
    TR_16B_LOW <= '0' WHEN (s_16bit = '1' AND BE(1) = '0') ELSE '1';

    -- TR_16B_HIGH: Active only in 16-bit mode if BE(0..1) are inactive and BE(3) is active
    TR_16B_HIGH <= '0' WHEN (s_16bit = '1' AND BE(0) = '1' AND BE(1) = '1' AND BE(3) = '0') ELSE '1';
	
END Behavioral;

