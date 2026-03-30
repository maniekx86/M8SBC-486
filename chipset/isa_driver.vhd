----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    23:21:17 10/14/2025
-- Design Name:
-- Module Name:    isa_driver - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: 8 and 16-bit ISA driver
--
-- Dependencies:
--
-- Revision:
-- Revision 0.02 - Rewrite to sync
-- Revision 0.01 - File Created
-- Additional Comments: ISA specs for 0.02 rewrite based on EISA System Architecture Second Edition by MINDSHARE, INC. TOM SHANLEY DON ANDERSON (1995)
--
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY isa_driver IS
	PORT (
		CLK				: IN	STD_LOGIC;
		RESET			: IN	STD_LOGIC;
		ADS				: IN	STD_LOGIC;
		RW				: IN	STD_LOGIC;
		MIO				: IN	STD_LOGIC;
		EN_ISA			: IN	STD_LOGIC; -- negated

		ISA_CLK_HIGH_CYCLES : IN INTEGER RANGE 1 TO 15;
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

		CPU_16BTR		: IN	STD_LOGIC; -- Do not do 16-bit transfer if CPU does 8-bit one!
		ISA_SBHE		: OUT	STD_LOGIC
	);
END ISA_DRIVER;

ARCHITECTURE behavioral OF isa_driver IS
	TYPE drv_state_type IS (st1_wait_for_ads, st2_ts_wait_for_rise, st3_ts_wait_for_fall, st4_tc1_wait_for_rise, st5_tc1_wait_for_fall, st6_waitstates_wait);
	SIGNAL drv_state, drv_next_state			: drv_state_type;

	SIGNAL DIV_COUNT		: INTEGER RANGE 0 TO 15 := 0;
	SIGNAL ISA_CLK_STATE	: STD_LOGIC := '0';

	SIGNAL RDY_I			: STD_LOGIC;
	SIGNAL ISA_DO_16B		: STD_LOGIC := '0';

	SIGNAL WS_COUNT			: INTEGER RANGE 0 TO 127 := 0;
BEGIN

	-- Standard 8-bit ISA cycle consists of 1 starting cycle + 4 ws cycles
	-- To sync clocks, we take CPU clock and divide it by x amount
	-- Each cycle happens on rising edge of divided clock

	-- Clock divider
	PROCESS (CLK)
	BEGIN
		IF RISING_EDGE(CLK) THEN
			IF ISA_CLK_STATE = '1' THEN
				-- Counting the HIGH duration
				IF DIV_COUNT >= (ISA_CLK_HIGH_CYCLES - 1) THEN
					ISA_CLK_STATE <= '0'; -- Toggle to Low
					DIV_COUNT <= 0;
				ELSE
					DIV_COUNT <= DIV_COUNT + 1;
				END IF;
			ELSE
				-- Counting the LOW duration
				IF DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1) THEN
					ISA_CLK_STATE <= '1'; -- Toggle to High
					DIV_COUNT <= 0;
				ELSE
					DIV_COUNT <= DIV_COUNT + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	ISA_CLK <= ISA_CLK_STATE;

	SYNC_PROC: PROCESS (CLK) -- clk synced
	BEGIN
		IF RISING_EDGE(CLK) THEN
			IF RESET = '1' THEN
				WS_COUNT <= 0;
				ISA_DO_16B <= '0';
			ELSE

				IF drv_state = st1_wait_for_ads THEN
					WS_COUNT <= 0; -- reset
					ISA_DO_16B <= '0';
				END IF;

				IF drv_state = st2_ts_wait_for_rise THEN
				END IF;

				IF drv_state = st4_tc1_wait_for_rise AND drv_next_state = st5_tc1_wait_for_fall THEN
					-- check CS16 signals
					IF MIO = '1' THEN -- MEM
						IF ISA_MEMCS16 = '0' THEN
							ISA_DO_16B <= '1';
						END IF;
					ELSE -- I/O
						IF ISA_IOCS16 = '0' THEN
							ISA_DO_16B <= '1';
						END IF;
					END IF;
				END IF;

				IF drv_state = st6_waitstates_wait THEN -- We need to count 5 rising edges before ending transaction
					IF ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1) THEN -- rise
						IF WS_COUNT < 5 THEN
							WS_COUNT <= WS_COUNT + 1;
						END IF;
					END IF;
				END IF;

				drv_state <= drv_next_state;

				IF drv_state /= st1_wait_for_ads THEN
				END IF;

			END IF;
		END IF;
	END PROCESS;

	OUTPUT_DECODE: PROCESS (drv_state, drv_next_state, RW, MIO, WS_COUNT, ISA_DO_16B) -- out | RW: 0 - read, 1 - write
		VARIABLE RD				: STD_LOGIC;
		VARIABLE WR				: STD_LOGIC;
		VARIABLE allow_drive	: STD_LOGIC;
	BEGIN
		--insert statements to decode internal output signals
		-- "BS16 / BS8 must be driven active before the first RDY or BRDY is driven active"
		-- so we should be able to indicate 8/16 bit transfer even after ADS

		BS8_O <= '1';
		BS16_O <= '1';
		ISA_MEM_WR <= '1';
		ISA_MEM_RD <= '1';
		ISA_IO_WR <= '1';
		ISA_IO_RD <= '1';

		RDY_I <= '0'; -- ready

		IF drv_state /= st1_wait_for_ads THEN -- Hold CPU if we are in transfer
			RDY_I <= '1';
		END IF;

	  IF drv_state = st4_tc1_wait_for_rise THEN
			-- We should active BALE (pulse high) here but we dont have BALE!
		END IF;

		IF drv_state = st5_tc1_wait_for_fall OR drv_state = st6_waitstates_wait THEN
			IF ISA_DO_16B = '1' THEN
				BS16_O <= '0';
			ELSE
				BS8_O <= '0';
			END IF;
		END IF;

		IF drv_state = st6_waitstates_wait OR (drv_state = st5_tc1_wait_for_fall AND ISA_DO_16B = '1') THEN -- If device is 16-bit capable, assert control lines instantly
			-- Activate RW signals
			WR := '1';
			RD := '1';

			IF RW = '1' THEN -- write
				WR := '0';
			ELSE -- read
				RD := '0';
			END IF;

			IF MIO = '1' THEN -- MEM
				ISA_MEM_WR <= WR;
				ISA_MEM_RD <= RD;
			ELSE -- I/O
				ISA_IO_WR <= WR;
				ISA_IO_RD <= RD;
			END IF;

		END IF;

	END PROCESS;

	NEXT_STATE_DECODE: PROCESS(drv_state, ADS, EN_ISA, WS_COUNT, ISA_CLK_STATE, ISA_CLK_LOW_CYCLES, ISA_IO_READY, ISA_DO_16B, DIV_COUNT) -- in
	BEGIN
		--declare default state for next_state to avoid latches
		drv_next_state <= drv_state; -- default is to stay in current state

		CASE (drv_state) IS
			-- st1
			WHEN st1_wait_for_ads => -- Transfer begin, When ADS is 0 and EN_ISA and 0 we activate
				IF (ADS = '0') AND (EN_ISA = '0') THEN
					drv_next_state <= st2_ts_wait_for_rise;
				END IF;

			-- st2
			WHEN st2_ts_wait_for_rise => -- Wait for sync to ISA clock - rising edge
				IF EN_ISA = '1' THEN
					drv_next_state <= st1_wait_for_ads; -- ISA CS for some reason deasserted
				ELSE
					IF ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1) THEN -- rise
						drv_next_state <= st3_ts_wait_for_fall;
					END IF;
				END IF;

			-- st3
			WHEN st3_ts_wait_for_fall =>
				IF EN_ISA = '1' THEN
					drv_next_state <= st1_wait_for_ads;
				ELSE
					IF ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1) THEN -- fall
						drv_next_state <= st4_tc1_wait_for_rise;
					END IF;
				END IF;

			-- st4
			WHEN st4_tc1_wait_for_rise =>
				IF EN_ISA = '1' THEN
					drv_next_state <= st1_wait_for_ads;
				ELSE
					IF ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1) THEN -- rise
						drv_next_state <= st5_tc1_wait_for_fall;
					END IF;
				END IF;

			-- st5
			WHEN st5_tc1_wait_for_fall =>
				IF EN_ISA = '1' THEN
					drv_next_state <= st1_wait_for_ads;
				ELSE
					IF ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1) THEN -- fall
						drv_next_state <= st6_waitstates_wait;
					END IF;
				END IF;

			-- st6
			WHEN st6_waitstates_wait =>
				IF EN_ISA = '1' THEN
					drv_next_state <= st1_wait_for_ads;
				ELSE
					IF ISA_DO_16B = '1' THEN -- 16b : 1 ws
						IF (ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1)) AND WS_COUNT >= 1 AND ISA_IO_READY = '1' THEN -- WS count ended and device is ready (ISA_IO_READY [CHRDY] = 1)
							drv_next_state <= st1_wait_for_ads;
						END IF;
					ELSE  -- 8b : 4 ws
						IF (ISA_CLK_STATE = '0' AND DIV_COUNT >= (ISA_CLK_LOW_CYCLES - 1)) AND WS_COUNT >= (5-1) AND ISA_IO_READY = '1' THEN -- WS count ended and device is ready (ISA_IO_READY [CHRDY] = 1)
							drv_next_state <= st1_wait_for_ads;
						END IF;
					END IF;
				END IF;

			WHEN OTHERS =>
				drv_next_state <= st1_wait_for_ads;
		END CASE;
	END PROCESS;

	-- ISA_RDY - output from driver
	-- ISA_IO_READY - input from ISA
	-- RDY: 1 = wait, 0 = ready
	ISA_RDY <= RDY_I;
	ISA_SBHE <= CPU_16BTR;

END BEHAVIORAL;
