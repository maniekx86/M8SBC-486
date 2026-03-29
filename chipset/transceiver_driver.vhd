----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:	   19:41:48 09/20/2025
-- Design Name:
-- Module Name:	   transceiver_driver - Behavioral
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
	PORT (
		BE				: IN	STD_LOGIC_VECTOR(3 DOWNTO 0);
		BS8				: IN	STD_LOGIC;
		BS16			: IN	STD_LOGIC;

		TR_8B			: OUT	STD_LOGIC_VECTOR(3 DOWNTO 0);
		TR_16B_LOW		: OUT	STD_LOGIC;
		TR_16B_HIGH		: OUT	STD_LOGIC
	);
END transceiver_driver;

ARCHITECTURE Behavioral OF transceiver_driver IS

BEGIN

	PROCESS (BE, BS8, BS16)
		VARIABLE bs_comb	: STD_LOGIC_VECTOR(1 DOWNTO 0);
	BEGIN
		bs_comb := BS8 & BS16;
		CASE bs_comb IS
			WHEN "01" =>
				-- BS8 active

				TR_8B <= "1111";
				TR_16B_LOW <= '1';
				TR_16B_HIGH <= '1';

				IF BE(0) = '0' THEN
					TR_8B(0) <= '0';
				ELSE
					IF BE(1) = '0' THEN
						TR_8B(1) <= '0';
					ELSE
						IF BE(2) = '0' THEN
							TR_8B(2) <= '0';
						ELSE
							IF BE(3) = '0' THEN
								TR_8B(3) <= '0';
							END IF;
						END IF;
					END IF;
				END IF;

			WHEN "10" =>
				-- BS16 active

				TR_8B <= "1111";
				TR_16B_LOW <= '1';	-- Higher 8 bits to 8-15
				TR_16B_HIGH <= '1'; -- Higher 8 bits to 24-31

				IF BE(0) = '0' THEN -- start 0
					TR_8B(0) <= '0'; -- 8b (0)
					IF BE(1) = '0' THEN -- 16b if 0-15
						TR_16B_LOW <= '0';
					END IF;
				ELSE
					IF BE(1) = '0' THEN -- start 8
						TR_16B_LOW <= '0'; -- only 8b possible
					ELSE
						IF BE(2) = '0' THEN -- start 16
							TR_8B(2) <= '0'; -- 8b (2)
							IF BE(3) = '0' THEN -- 16b if 16-31
								TR_16B_HIGH <= '0';
							END IF;
						ELSE
							IF BE(3) = '0' THEN -- start 24
								TR_16B_HIGH <= '0'; -- only 8b possible
							END IF;
						END IF;
					END IF;
				END IF;

			WHEN OTHERS =>
				TR_8B <= "1111";
				TR_16B_LOW <= '1';
				TR_16B_HIGH <= '1';
		END CASE;
	END PROCESS;

END Behavioral;
