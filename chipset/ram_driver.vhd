----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    21:24:19 09/19/2025
-- Design Name:
-- Module Name:    ram_driver - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: Driver for 4MB SRAM organised as 8 x 512KB
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- 13/01/2026:
-- RAM read performance improvement: If a read occurs after a read, keep RAM CS/OE active and skip waitstate
-- This driver design waits for ADS signal in order to begin transfer. RAM CS/OE are inactive during first clock cycle when ADS asserts
-- which already takes one cycle. RAM is doing nothing! Next cycle asserts CS/OE and that begins the RAM access time count.
-- But what if we see that CPU is constantly accessing the memory? We can keep the CS/OE active and skip one wait state
-- Improvement: At 24 MHz FSB, 486DX2, 70ns RAM, 1 waitstate and 0 burst waitstate we went up from 17.5 MB/s to 26.8 MB/s (DOS/CACHECHK)
-- This could be also implemented for writes? TODO
--
--
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ram_driver IS
	PORT (
		CLK				: IN		STD_LOGIC;
		RESET			: IN		STD_LOGIC;
		BE				: IN		STD_LOGIC_VECTOR(3 downto 0);
		ADS				: IN		STD_LOGIC; -- Active LOW
		CPU_RW			: IN		STD_LOGIC; -- Inverted in x86! 0 - read, 1 - write
		RAMCS			: IN		STD_LOGIC; -- Active LOW
		ADDR21			: IN		STD_LOGIC; -- switches between first and second bank (2MB)

		CS0				: OUT		STD_LOGIC;
		CS1				: OUT		STD_LOGIC;
		RDY				: OUT		STD_LOGIC;
		WE				: OUT		STD_LOGIC_VECTOR(3 downto 0); -- For each bytes
		OE				: OUT		STD_LOGIC_VECTOR(3 downto 0);

		RAM_WAITSTATES			: IN INTEGER RANGE 0 to 127;
		RAM_BURST_WAITSTATES	: IN INTEGER RANGE 0 to 15

	);
END ram_driver;

ARCHITECTURE Behavioral OF ram_driver IS
	--CONSTANT ram_waitstates : INTEGER	:= 0;

	--Use descriptive names for the states, like st1_reset, st2_search

	TYPE drv_state_type IS (st1_wait_for_ads, st2_wait_state);
	SIGNAL drv_state, drv_next_state			: drv_state_type;

	--Declare internal signals for all outputs of the state-machine
	--SIGNAL	 <output>_i : std_logic;  -- example output signal
	SIGNAL RDY_I		: STD_LOGIC;

	SIGNAL WS_COUNT		: INTEGER RANGE 0 to 127 := 0;
	SIGNAL WS_TO_WAIT	: INTEGER RANGE 0 to 127 := 0;

	SIGNAL LAST_CS		: STD_LOGIC := '1';
	SIGNAL EXTRA_WS		: STD_LOGIC := '0';
	CONSTANT NCOUNT		: INTEGER := 16;
	CONSTANT NACTIVE	: STD_LOGIC := '0';

	-- WR is held till the end of entire transaction

	SIGNAL LAST_CS0		: STD_LOGIC := '1';
	SIGNAL LAST_CS1		: STD_LOGIC := '1';
	SIGNAL KEEP_READ	: STD_LOGIC := '0';
	SIGNAL d_cs0		: STD_LOGIC;
	SIGNAL d_cs1		: STD_LOGIC;

BEGIN
	CSDEC: PROCESS(ADDR21)
	BEGIN
		IF ADDR21 = '1' THEN
			d_cs1 <= '0';
			d_cs0 <= '1';
		ELSE
			d_cs0 <= '0';
			d_cs1 <= '1';
		END IF;
	END PROCESS;

	CS0 <= d_cs0;
	CS1 <= d_cs1;

	SYNC_PROC: PROCESS (CLK)
		VARIABLE ram_waitstates_total	: INTEGER;
		VARIABLE d_cs0					: STD_LOGIC;
		VARIABLE d_cs1					: STD_LOGIC;
	BEGIN
		IF(RISING_EDGE(CLK)) THEN
			IF (RESET = '1') THEN
				drv_state <= st1_wait_for_ads;
				-- reset outputs

				WS_COUNT <= 0;
				EXTRA_WS <= '0';
				WS_TO_WAIT <= 0;
				RDY_I <= '0'; -- flip flop
				KEEP_READ <= '0';
				LAST_CS0 <= '0';
				LAST_CS1 <= '0';
			ELSE

				IF (LAST_CS /= RAMCS) AND (NACTIVE = '1') THEN -- extend when previous address was pointing to other device
					ram_waitstates_total := RAM_WAITSTATES + NCOUNT;
				ELSE
					ram_waitstates_total := RAM_WAITSTATES;
				END IF;

				IF RAMCS = '1' OR CPU_RW = '1' THEN -- reset on switch to different device or on switch to write
					KEEP_READ <= '0';
					LAST_CS0 <= '0';
					LAST_CS1 <= '0';
				END IF;

				IF drv_state = st1_wait_for_ads THEN
					IF drv_next_state = st2_wait_state AND RAMCS = '0' THEN -- on toggle from s1 to s2 (ADS)

						IF LAST_CS0 = d_cs0 AND LAST_CS1 = d_cs1 AND CPU_RW = '0' THEN
							-- eligible for quick read
							KEEP_READ <= '1';
							ram_waitstates_total := RAM_BURST_WAITSTATES;
						END IF;

						IF ram_waitstates_total > 0 THEN -- go instantly high to indicate wait
							RDY_I <= '1';
						ELSE
							RDY_I <= '0';
						END IF;

						WS_TO_WAIT <= ram_waitstates_total;

						IF (LAST_CS /= RAMCS) AND (NACTIVE = '1') THEN
							EXTRA_WS <= '1';
						ELSE
							EXTRA_WS <= '0';
						END IF;

						LAST_CS0 <= d_cs0;
						LAST_CS1 <= d_cs1;

					ELSE -- default low
						RDY_I <= '0';
					END IF;
				ELSE
					IF drv_next_state = st1_wait_for_ads THEN
						RDY_I <= '0'; -- toggle back on switch
					END IF;
				END IF;

				drv_state <= drv_next_state;

				IF drv_state = st2_wait_state THEN
					WS_COUNT <= WS_COUNT + 1;
				ELSE
					WS_COUNT <= 0;
				END IF;
				-- <output> <= <output>_i;
				-- assign other outputs to internal signals

				LAST_CS <= RAMCS;

			END IF;
		END IF;
	END PROCESS;

	OUTPUT_DECODE: PROCESS (drv_state, CPU_RW, BE, ADDR21, EXTRA_WS, WS_COUNT, KEEP_READ) -- RW: 0 - read, 1 - write
		VARIABLE allow_drive : STD_LOGIC;
	BEGIN
		--insert statements to decode internal output signals
		IF EXTRA_WS = '1' THEN
			IF WS_COUNT >= NCOUNT THEN
				allow_drive := '1';
			ELSE
				allow_drive := '0';
			END IF;
		ELSE
			allow_drive := '1';
		END IF;

		IF (drv_state = st2_wait_state) AND (allow_drive = '1') THEN
			IF CPU_RW = '1' THEN -- write
				OE <= "1111";
				WE <= BE; -- BE is valid during entire cycle
			ELSE -- read
				WE <= "1111";
				-- OE <= BE;
				OE <= "0000"; -- This fixes L1 cache! BE should be ignored during cache fills, but we can ignore it all time during reads anyway
			END IF;

		ELSE -- not S2
			IF KEEP_READ = '1' THEN
				OE <= "0000";
			ELSE
				OE <= "1111";
			END IF;
			WE <= "1111";
		END IF;
	END PROCESS;

	NEXT_STATE_DECODE: PROCESS(drv_state, ADS, RAMCS, WS_COUNT, WS_TO_WAIT)
	BEGIN
		--declare default state for next_state to avoid latches
		drv_next_state <= drv_state; -- default is to stay in current state

		CASE (drv_state) IS
			WHEN st1_wait_for_ads => -- When ADS is 0 and RAMCS and 0 we activate
				IF (ADS = '0') AND (RAMCS = '0') THEN
					drv_next_state <= st2_wait_state;
				END IF;
			WHEN st2_wait_state =>
				IF (ADS = '1') AND (WS_COUNT >= WS_TO_WAIT) THEN
					drv_next_state <= st1_wait_for_ads;
				END IF;
			WHEN OTHERS =>
				drv_next_state <= st1_wait_for_ads;
		END CASE;
	END PROCESS;

	RDY <= RDY_I;

END Behavioral;
