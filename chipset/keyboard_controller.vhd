----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    13:50:01 09/22/2025
-- Design Name:
-- Module Name:    keyboard_controller - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: PC style keyboard controller implementation
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

ENTITY keyboard_controller IS
	PORT (
		CLK			: IN	STD_LOGIC; -- for timeout
		PS2_CLK		: IN	STD_LOGIC;
		PS2_DATA	: IN	STD_LOGIC;
		RESET		: IN	STD_LOGIC;

		D_OUT		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0); -- data port 0x60
		DS_OUT		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0); -- status port 0x64
		CLK_CPU		: IN	STD_LOGIC; -- to clear flag
		RD_CLEAR	: IN	STD_LOGIC; -- to clear flag
		CLEAR_BUF	: IN	STD_LOGIC;
		INT_OUT		: OUT	STD_LOGIC
	);
END keyboard_controller;

ARCHITECTURE Behavioral OF keyboard_controller IS

	TYPE rom_type IS ARRAY (0 TO 255) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

	CONSTANT SET2_TO_SET1 : rom_type := ( -- NON EXT
		16#1C# => X"1E", -- A
		16#32# => X"30", -- B
		16#21# => X"2E", -- C
		16#23# => X"20", -- D
		16#24# => X"12", -- E
		16#2B# => X"21", -- F
		16#34# => X"22", -- G
		16#33# => X"23", -- H
		16#43# => X"17", -- I
		16#3B# => X"24", -- J
		16#42# => X"25", -- K
		16#4B# => X"26", -- L
		16#3A# => X"32", -- M
		16#31# => X"31", -- N
		16#44# => X"18", -- O
		16#4D# => X"19", -- P
		16#15# => X"10", -- Q
		16#2D# => X"13", -- R
		16#1B# => X"1F", -- S
		16#2C# => X"14", -- T
		16#3C# => X"16", -- U
		16#2A# => X"2F", -- V
		16#1D# => X"11", -- W
		16#22# => X"2D", -- X
		16#35# => X"15", -- Y
		16#1A# => X"2C", -- Z
		16#45# => X"0B", -- 0
		16#16# => X"02", -- 1
		16#1E# => X"03", -- 2
		16#26# => X"04", -- 3
		16#25# => X"05", -- 4
		16#2E# => X"06", -- 5
		16#36# => X"07", -- 6
		16#3D# => X"08", -- 7
		16#3E# => X"09", -- 8
		16#46# => X"0A", -- 9
		16#0E# => X"29", -- `
		16#4E# => X"0C", -- -
		16#55# => X"0D", -- =
		16#5D# => X"2B", -- \
		16#66# => X"0E", -- BKSP
		16#29# => X"39", -- SPACE
		16#0D# => X"0F", -- TAB
		16#58# => X"3A", -- CAPS
		16#12# => X"2A", -- L SHFT
		16#14# => X"1D", -- L CTRL
		16#11# => X"38", -- L ALT
		16#59# => X"36", -- R SHFT
		16#5A# => X"1C", -- ENTER
		16#76# => X"01", -- ESC
		16#05# => X"3B", -- F1
		16#06# => X"3C", -- F2
		16#04# => X"3D", -- F3
		16#0C# => X"3E", -- F4
		16#03# => X"3F", -- F5
		16#0B# => X"40", -- F6
		16#83# => X"41", -- F7
		16#0A# => X"42", -- F8
		16#01# => X"43", -- F9
		16#09# => X"44", -- F10
		16#78# => X"57", -- F11
		16#07# => X"58", -- F12
		16#7E# => X"46", -- SCROLL
		16#54# => X"1A", -- [
		16#77# => X"45", -- NUM
		16#7C# => X"37", -- KP *
		16#7B# => X"4A", -- KP -
		16#79# => X"4E", -- KP +
		16#71# => X"53", -- KP .
		16#70# => X"52", -- KP 0
		16#69# => X"4F", -- KP 1
		16#72# => X"50", -- KP 2
		16#7A# => X"51", -- KP 3
		16#6B# => X"4B", -- KP 4
		16#73# => X"4C", -- KP 5
		16#74# => X"4D", -- KP 6
		16#6C# => X"47", -- KP 7
		16#75# => X"09", -- KP 8
		16#7D# => X"49", -- KP 9
		16#5B# => X"1B", -- ]
		16#4C# => X"27", -- ;
		16#52# => X"28", -- '
		16#41# => X"33", -- ,
		16#49# => X"34", -- .
		16#4A# => X"35", -- /

		OTHERS => X"00" -- Default/Error
	);

	CONSTANT SET2_TO_SET1_EXT : rom_type := ( -- 0xE0 ext codes
		16#1F# => X"5B", -- L WIN
		16#14# => X"1D", -- R CTRL
		16#27# => X"5C", -- R WIN
		16#11# => X"58", -- R ALT
		16#2F# => X"5D", -- APPS
		16#70# => X"52", -- INSERT
		16#6C# => X"47", -- HOME
		16#7D# => X"49", -- PG UP
		16#71# => X"53", -- DELETE
		16#69# => X"4F", -- END
		16#7A# => X"51", -- PG DN
		16#75# => X"48", -- UP ARROW
		16#6B# => X"4B", -- L ARROW
		16#72# => X"50", -- DOWN ARROW
		16#74# => X"4D", -- R ARROW
		16#4A# => X"35", -- KP /
		16#5A# => X"1C", -- KP EN

		OTHERS => X"00" -- Default/Error
	);

	CONSTANT int_pulse_dur	: INTEGER := 7; -- 7 * 838 = about 5866 ns
	CONSTANT timeout_limit	: INTEGER := 100000; -- 200 for tests, 100000 for final (100000 is about 83 ms)

	TYPE kb_state_type IS (st1_wait, st2_fetch);
	SIGNAL kb_state, kb_next_state		: kb_state_type := st1_wait;

	SIGNAL timeout			: INTEGER RANGE 0 TO timeout_limit := 0;
	SIGNAL REC_TIMEOUT		: STD_LOGIC := '0';

	SIGNAL kb_data			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL kb_bit			: INTEGER RANGE 0 TO 9 := 0;
	SIGNAL kb_data_read		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL kb_parity		: STD_LOGIC := '0';

	SIGNAL pulse_int		: STD_LOGIC := '0';
	SIGNAL int_hold			: INTEGER RANGE 0 TO int_pulse_dur := int_pulse_dur;

	SIGNAL dflag			: STD_LOGIC := '0';
	SIGNAL last_RD_CLEAR	: STD_LOGIC := '0';

	SIGNAL scancode_ext		: STD_LOGIC := '0';
	SIGNAL scancode_release	: STD_LOGIC := '0';
BEGIN

	PROCESS (CLK, RESET, REC_TIMEOUT, pulse_int, kb_bit)
	BEGIN
		IF FALLING_EDGE(CLK) THEN
			IF RESET = '1' THEN
				kb_state <= st1_wait;
				timeout <= 0;
				REC_TIMEOUT <= '0';
				int_hold <= 0;
			ELSE
				IF kb_state = st1_wait THEN
					timeout <= 0;
				ELSE
					IF timeout >= timeout_limit THEN
						REC_TIMEOUT <= '1';
					ELSE
						timeout <= timeout + 1;
					END IF;
				END IF;

				IF REC_TIMEOUT = '1' AND kb_bit = 0 THEN -- reset was ACK
					kb_state <= st1_wait;
					REC_TIMEOUT <= '0';
				ELSE
					kb_state <= kb_next_state;
				END IF;

				-- interrupt
				IF pulse_int = '1' THEN -- solution to hold pulse for few clock cycles
					IF int_hold < int_pulse_dur THEN
						int_hold <= int_hold + 1;
					END IF;
				ELSE
					int_hold <= 0;
				END IF;

			END IF;

		END IF;
	END PROCESS;

	PROCESS (PS2_CLK, PS2_DATA, RESET, REC_TIMEOUT, CLEAR_BUF)
		VARIABLE data_parity		: STD_LOGIC;
		VARIABLE result_scancode	: STD_LOGIC_VECTOR(7 DOWNTO 0);
	BEGIN
		IF RESET = '1' OR REC_TIMEOUT = '1' THEN
			kb_data <= X"00";
			IF RESET = '1' THEN -- reset output only on full reset
				kb_data_read <= X"00";
			END IF;
			kb_bit <= 0;
			kb_next_state <= st1_wait;
			kb_parity <= '0';
			pulse_int <= '0';

			scancode_ext <= '0';
			scancode_release <= '0';
		ELSE
--			IF clear_int >= int_pulse_dur THEN
--				pulse_int <= '0';
--			END IF;
			IF CLEAR_BUF = '1' THEN
				kb_data_read <= X"00";
			ELSE
				IF FALLING_EDGE(PS2_CLK) THEN

					IF kb_state = st1_wait AND PS2_DATA = '0' THEN -- start bit
						kb_next_state <= st2_fetch; -- CLK (~1 MHz) is way faster than PS2_CLK (16 KHz max), so state should change in time
						pulse_int <= '0';
						kb_bit <= 0;
						kb_data <= X"00";
					END IF;

					IF kb_state = st2_fetch THEN
						IF kb_bit = 9 THEN -- stop bit
							kb_next_state <= st1_wait;
							data_parity := NOT (kb_data(7) XOR kb_data(6) XOR kb_data(5) XOR kb_data(4) XOR kb_data(3) XOR kb_data(2) XOR kb_data(1) XOR kb_data(0));
							IF kb_parity = data_parity THEN
								-- proper data received

								-- Translation from scan code 2 to 1
								-- kb data order: [E0] [F0] DATA
								-- E0 - extended, F0 - release, DATA - data
								IF kb_data = X"E0" THEN
									scancode_ext <= '1';

									kb_data_read <= kb_data; -- Extended scan codes apply to the same keys in sets 1 and 2 so send E0
									pulse_int <= '1';

								ELSIF kb_data = X"F0" THEN
									scancode_release <= '1';
								ELSE
									-- scancode
									IF scancode_ext = '1' THEN
										-- extended
										result_scancode := SET2_TO_SET1_EXT(to_integer(unsigned(kb_data)));
									ELSE
										-- normal
										result_scancode := SET2_TO_SET1(to_integer(unsigned(kb_data)));
									END IF;
									IF scancode_release = '1' THEN -- key release
										result_scancode(7) := '1'; -- OR 0x80
									END IF;

									kb_data_read <= result_scancode;
									pulse_int <= '1';

									scancode_ext <= '0';
									scancode_release <= '0';
								END IF;


								-- generate interrupt -- old
								--kb_data_read <= kb_data;
								--pulse_int <= '1';
							ELSE
								kb_data_read <= X"00";
							END IF;
						ELSE
							IF kb_bit = 8 THEN -- parity bit
								kb_parity <= PS2_DATA;
							ELSE
								kb_data <= PS2_DATA & kb_data(7 DOWNTO 1); -- data bit
							END IF;
						END IF;
						kb_bit <= kb_bit + 1;
					END IF;

				END IF; -- if falling

			END IF; -- if not clear_buf

		END IF; -- if not reset
	END PROCESS;

	PROCESS (CLK_CPU, int_hold, RESET)
	BEGIN
		IF RESET = '1' THEN
			dflag <= '0';
			last_RD_CLEAR <= '1';
		ELSE
			IF int_hold = 1 THEN
				dflag <= '1';
			ELSE
				IF FALLING_EDGE(CLK_CPU) THEN
					IF last_RD_CLEAR = '0' AND RD_CLEAR = '1' THEN -- RISING edge
						dflag <= '0';
					END IF;

					last_RD_CLEAR <= RD_CLEAR;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	D_OUT <= kb_data_read;
	DS_OUT <= "0001010" & dflag;
	INT_OUT <= '1' WHEN (int_hold < int_pulse_dur AND int_hold > 0) ELSE '0';

END Behavioral;
