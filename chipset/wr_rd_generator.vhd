----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    18:49:22 09/21/2025
-- Design Name:
-- Module Name:    wr_rd_generator - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: Intel bus style control signals generator with waitstate support
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

ENTITY wr_rd_generator IS
	PORT (
		CLK				: IN	STD_LOGIC;
		RESET			: IN	STD_LOGIC;
		ADS				: IN	STD_LOGIC;
		RW				: IN	STD_LOGIC;
		MIO				: IN	STD_LOGIC;
		EN_WRRD			: IN  STD_LOGIC; -- negated
		WAITSTATE_CNT	: IN  INTEGER RANGE 0 to 127;

		RDY				: OUT	STD_LOGIC;
		MEM_WR			: OUT	STD_LOGIC;
		MEM_RD			: OUT	STD_LOGIC;
		IO_WR			: OUT	STD_LOGIC;
		IO_RD			: OUT	STD_LOGIC
	);
END wr_rd_generator;

ARCHITECTURE Behavioral OF wr_rd_generator IS
	SIGNAL SET_WAITSTATES				: INTEGER RANGE 0 to 127;

	TYPE drv_state_type IS (st1_wait_for_ads, st2_wait_state);
	SIGNAL drv_state, drv_next_state	: drv_state_type;

	SIGNAL RDY_I						: STD_LOGIC;

	SIGNAL WS_COUNT						: INTEGER RANGE 0 to 127 := 0;

	SIGNAL LAST_CS						: STD_LOGIC := '1';
	SIGNAL EXTRA_WS						: STD_LOGIC := '0';
	CONSTANT NCOUNT						: INTEGER := 2;
	CONSTANT NACTIVE					: STD_LOGIC := '1';

BEGIN

	--SET_WAITSTATES <= WAITSTATE_CNT;
	SYNC_PROC: PROCESS (CLK)
	BEGIN
		IF(RISING_EDGE(CLK)) THEN
			IF (RESET = '1') THEN
				drv_state <= st1_wait_for_ads;
				-- reset output
				WS_COUNT <= 0;
				SET_WAITSTATES <= 0;
				RDY_I <= '0'; -- flip flop

				EXTRA_WS <= '0';
				LAST_CS <= '1';
			ELSE
				IF drv_state = st1_wait_for_ads THEN
					IF drv_next_state = st2_wait_state THEN -- on toggle from s1 to s2

						IF (LAST_CS /= EN_WRRD) AND (NACTIVE = '1') THEN
							SET_WAITSTATES <= WAITSTATE_CNT + NCOUNT;
							EXTRA_WS <= '1'; -- to check
						ELSE
							SET_WAITSTATES <= WAITSTATE_CNT;
							EXTRA_WS <= '0';
						END IF;

						IF SET_WAITSTATES > 0 THEN -- go instantly high to indicate wait
							RDY_I <= '1';
						ELSE
							RDY_I <= '0';
						END IF;

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

				LAST_CS <= EN_WRRD;
			END IF;
		END IF;
	END PROCESS;

	OUTPUT_DECODE: PROCESS (drv_state, RW, MIO, WS_COUNT, EXTRA_WS) -- RW: 0 - read, 1 - write
		VARIABLE RD				: STD_LOGIC;
		VARIABLE WR				: STD_LOGIC;
		VARIABLE allow_drive	: STD_LOGIC;
	BEGIN
		--insert statements to decode internal output signals
		RD := '1';
		WR := '1';
		MEM_WR <= '1';
		MEM_RD <= '1';
		IO_WR <= '1';
		IO_RD <= '1';

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
			IF RW = '1' THEN -- write
				WR := '0';
			ELSE -- read
				RD := '0';
			END IF;

			-- 0 = IO, 1 = MEM
			IF MIO = '1' THEN
				MEM_WR <= WR;
				MEM_RD <= RD;
			ELSE
				IO_WR <= WR;
				IO_RD <= RD;
			END IF;

		ELSE -- not S2
			MEM_WR <= '1';
			MEM_RD <= '1';
			IO_WR <= '1';
			IO_RD <= '1';
		END IF;
	END PROCESS;

	NEXT_STATE_DECODE: PROCESS(drv_state, ADS, EN_WRRD, WS_COUNT, SET_WAITSTATES)
	BEGIN
		--declare default state for next_state to avoid latches
		drv_next_state <= drv_state; -- default is to stay in current state

		CASE (drv_state) IS
			WHEN st1_wait_for_ads => -- When ADS is 0 and RAMCS and 0 we activate
				IF (ADS = '0') AND (EN_WRRD = '0') THEN
					drv_next_state <= st2_wait_state;
				END IF;
			WHEN st2_wait_state =>
				IF ((ADS = '1') AND (WS_COUNT >= SET_WAITSTATES)) OR (EN_WRRD = '1') THEN -- End of cycle or EN for some reason deaserted)
					drv_next_state <= st1_wait_for_ads;
				END IF;

			WHEN OTHERS =>
				drv_next_state <= st1_wait_for_ads;
		END CASE;
	END PROCESS;

	RDY <= RDY_I;

END Behavioral;
