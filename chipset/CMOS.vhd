----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
-- 
-- Create Date:    19:21:33 11/27/2025 
-- Design Name: 
-- Module Name:    CMOS - Behavioral 
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions: 
-- Description: Simple CMOS RTC (non volatile) implementation
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

ENTITY CMOS IS
	PORT (
		CLK_IN	: IN	STD_LOGIC;
		DATA_IN	: IN	STD_LOGIC_VECTOR(7 downto 0);
		DATA_OUT	: OUT	STD_LOGIC_VECTOR(7 downto 0);
		CMOS_CS	: IN	STD_LOGIC;
		WR			: IN	STD_LOGIC;
		RD			: IN	STD_LOGIC;
		A0			: IN	STD_LOGIC;
		
		CLK_PIT	: IN	STD_LOGIC;
		
		AVR_CLK	: IN	STD_LOGIC;
		AVR_IO	: INOUT STD_LOGIC;
		
		FPGA_VER	: IN	STD_LOGIC_VECTOR(31 downto 0);
		RESET		: IN	STD_LOGIC
	);
END CMOS;

ARCHITECTURE Behavioral OF CMOS IS
	-- Clock divider counter
	SIGNAL PIT_DIVIDER	: INTEGER RANGE 0 TO 1193182 := 0;
	SIGNAL TICK_1HZ		: STD_LOGIC := '0';
	
    -- Time Registers
	SIGNAL SECONDS	: INTEGER RANGE 0 TO 60 := 0;
	SIGNAL MINUTES	: INTEGER RANGE 0 TO 60 := 0;
	SIGNAL HOURS	: INTEGER RANGE 0 TO 24 := 0;
	SIGNAL WEEKDAY	: INTEGER RANGE 0 TO 8 := 7; -- 1-7 (Sun-Sat)
	SIGNAL DAY		: INTEGER RANGE 0 TO 32 := 1;
	SIGNAL MONTH	: INTEGER RANGE 0 to 13 := 11;
	SIGNAL YEAR		: INTEGER RANGE 0 TO 100 := 25;
	SIGNAL CENTURY	: INTEGER RANGE 0 TO 99 := 20;
	
	-- Helper signal for calendar logic
	SIGNAL MAX_DAYS_IN_MONTH : INTEGER RANGE 28 TO 31;
	SIGNAL IS_LEAP_YEAR      : BOOLEAN;
	
	SIGNAL CURRENT_REGISTER		: STD_LOGIC_VECTOR(7 downto 0) := x"00";
	TYPE CMOS_REGISTERS_TYPE IS ARRAY (0 TO 31 ) OF std_logic_vector (7 DOWNTO 0);
	SIGNAL CMOS_REGISTERS: CMOS_REGISTERS_TYPE :=(
		x"00",x"00",x"00",x"00",-- 0x00
		x"00",x"00",x"00",x"00",-- 0x04
		x"00",x"00",x"00",x"00",-- 0x08
		x"00",x"00",x"00",x"00",-- 0x0C
		x"00",x"00",x"00",x"00",-- 0x10
		x"00",x"00",x"00",x"00",-- 0x14
		x"00",x"00",x"00",x"00",-- 0x18
		x"00",x"00",x"00",x"00"-- 0x1C
	);
	
	SIGNAL CMOS_WRITE_PROTECT : STD_LOGIC := '0';
	
	SIGNAL TRANSFER_CONFIG	: STD_LOGIC := '1'; -- Init
	SIGNAL TRANSFER_CONFIG_NEXT_END : STD_LOGIC := '0';
	
	SIGNAL RECEIVED_CONFIG	: STD_LOGIC := '0';
	SIGNAL RECEIVED_PREAM	: STD_LOGIC := '0';
	SIGNAL PREAM_COUNT		: INTEGER RANGE 0 TO 7 := 0;
	SIGNAL S1_AVR_CLK			: STD_LOGIC := '0';
	SIGNAL S1_AVR_DIN			: STD_LOGIC := '0';
	SIGNAL S2_AVR_CLK			: STD_LOGIC := '0';
	SIGNAL S2_AVR_DIN			: STD_LOGIC := '0';
	SIGNAL LAST_AVR_CLK		: STD_LOGIC := '0';
	
	SIGNAL CONFIG_COUNT		: INTEGER RANGE 0 TO 31 := 0;
	SIGNAL CONFIG_C_BIT		: INTEGER RANGE 0 TO 7 := 0;
	SIGNAL CONFIG_TEMP		: STD_LOGIC_VECTOR(7 downto 0) := x"00";
	
	SIGNAL AVR_OUT				: STD_LOGIC := '0';
	
	SIGNAL RAM_WRITE_EN, BUS_WRITER_EN  : STD_LOGIC;
	SIGNAL CFG_WRITER_EN 	: STD_LOGIC := '0';
	SIGNAL CFG_WRITER_ADDR	: INTEGER RANGE 0 to 31 := 0;
	SIGNAL RAM_WRITE_VAL, CFG_WRITER_VAL, RAM_OUT : STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL BUS_WRITER_VAL : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	SIGNAL RAM_WRITE_ADDR, BUS_WRITER_ADDR : INTEGER RANGE 0 to 31; 
	
	CONSTANT CYCLES_WAIT_TO_TRANSFER : INTEGER := 100000; -- How many CPU cycles to wait before attempting to store data
	
	

	SIGNAL TRANSFER_TIMER			: INTEGER RANGE 0 to CYCLES_WAIT_TO_TRANSFER+1 := 0;
	SIGNAL CONFIG_DATA_DIRTY		: STD_LOGIC := '0';
	SIGNAL LAST_CONFIG_DATA_DIRTY	: STD_LOGIC := '0';
	SIGNAL CONFIG_DO_WRITE			: STD_LOGIC := '0';
	SIGNAL TRANSFER_DIRTY			: STD_LOGIC := '0';
	SIGNAL CONFIG_WRITE_PHASE		: INTEGER RANGE 0 to 2 := 0;
	SIGNAL CFG_SKIP_CLK				: STD_LOGIC := '0';
	
	SIGNAL BUS_ACCESS			: STD_LOGIC;
	SIGNAL CMOS_IN_RANGE		: STD_LOGIC;
	
BEGIN
	
	-- AVR communication process
	-- On bitstream load, the FPGA awaits for 33 bytes sent serially on two IO reusable FPGA config lines from ATMega
	-- Protocol: DIN - CLK source, INIT - Data. CLK is always driven by AVR which after initial config awaits for DIN to get pulled low
	-- Clocked on raising clock
	-- Restore: (FPGA in, AVR out)
	-- 11110101 [byte 0] [byte 1] [byte 2] ... [byte 31]
	--
	-- Store: (FPGA out, AVR in)
	-- 11110101 [byte 0] [byte 1] [byte 2] ... [byte 31] 10101010
	PROCESS(CLK_IN)
		VARIABLE AVR_OUT_TMP			: STD_LOGIC;
		VARIABLE CONFIG_TEMP_VAR	: STD_LOGIC_VECTOR (7 downto 0);
	BEGIN
		IF FALLING_EDGE(CLK_IN) THEN
			S1_AVR_CLK <= AVR_CLK; -- 2-FF sync
			S1_AVR_DIN <= AVR_IO;
			S2_AVR_CLK <= S1_AVR_CLK;
			S2_AVR_DIN <= S1_AVR_DIN;
			
			
			IF WR = '0' AND A0 = '1' AND CMOS_CS = '0' AND CMOS_IN_RANGE = '1' AND CMOS_WRITE_PROTECT = '0' THEN -- write oqcuired
				TRANSFER_TIMER <= 0;
				CONFIG_DATA_DIRTY <= '1';
			ELSE
			
				IF RECEIVED_CONFIG = '1' AND CONFIG_DO_WRITE = '0' THEN -- When config is received and we are not in write
					IF TRANSFER_TIMER >= CYCLES_WAIT_TO_TRANSFER THEN -- Timer time out
						IF CONFIG_DATA_DIRTY = '1' OR TRANSFER_DIRTY = '1' THEN
							-- Initialize write
							CONFIG_COUNT <= 0;
							CONFIG_C_BIT <= 0;
							CONFIG_DO_WRITE <= '1';
							TRANSFER_DIRTY <= '0';
							TRANSFER_CONFIG <= '1';
							TRANSFER_CONFIG_NEXT_END <= '0';
							CONFIG_WRITE_PHASE <= 0;
							CFG_WRITER_EN <= '0';
							CONFIG_DATA_DIRTY <= '0';
							
							CFG_SKIP_CLK <= '1';
						END IF;
					ELSE 
						IF CONFIG_DATA_DIRTY /= LAST_CONFIG_DATA_DIRTY THEN
							TRANSFER_TIMER <= 0;
						ELSE
							TRANSFER_TIMER <= TRANSFER_TIMER + 1;
						END IF;
					END IF;
				END IF;
			END IF;
			
			
			LAST_CONFIG_DATA_DIRTY <= CONFIG_DATA_DIRTY;
			
			CFG_WRITER_ADDR <= CONFIG_COUNT;
			
			-- if RD or WR became 0, transfer is dirty!!!
			
			IF LAST_AVR_CLK /= S2_AVR_CLK AND S2_AVR_CLK = '1' THEN
				-- happens on rising edge
				IF RECEIVED_CONFIG = '0' THEN
					
					CONFIG_TEMP(7 downto 0) <= CONFIG_TEMP(6 downto 0) & S2_AVR_DIN;

					IF RECEIVED_PREAM = '1' THEN
				
						IF CONFIG_C_BIT = 7 THEN
							CONFIG_C_BIT <= 0;
							CFG_WRITER_EN <= '1';
							CFG_WRITER_VAL <= CONFIG_TEMP;
							
							IF CONFIG_COUNT = 31 THEN
								-- Finished
								TRANSFER_CONFIG_NEXT_END <= '1';
							ELSE
								CONFIG_COUNT <= CONFIG_COUNT + 1;
							END IF;
						ELSE
							CFG_WRITER_EN <= '0';
							CONFIG_C_BIT <= CONFIG_C_BIT + 1;
							IF TRANSFER_CONFIG_NEXT_END = '1' THEN
								TRANSFER_CONFIG <= '0';
								RECEIVED_CONFIG <= '1';
							END IF;
						END IF;
					ELSE 
						-- wait for 11110101
						IF CONFIG_TEMP = X"F5" THEN
							RECEIVED_PREAM <= '1';
						ELSE
							IF PREAM_COUNT = 7 THEN
								PREAM_COUNT <= 0;
							ELSE
								PREAM_COUNT <= PREAM_COUNT + 1;
							END IF;
						END IF;
						
					END IF;
					
				ELSE --RECEIVED_CONFIG = '1'
					-- write data loop if write is in progress
					-- if BUS_ACCESS becomes '1' during write then discard data
					IF CFG_SKIP_CLK = '1' THEN
						CFG_SKIP_CLK <= '0'; -- To not start in middle of clk
					ELSE 
						IF CONFIG_DO_WRITE = '1' THEN
							IF BUS_ACCESS = '0' THEN -- Bus access to cfg writer
								--IF TRANSFER_DIRTY = '1' THEN -- Cancel access but continue clocking
									-- Even if write occurs while phase 0, config_count should be 0 anyway
									-- We need to clock till the end to not begin another transfer
									-- while AVR is still probing for data
									
								--ELSE -- Write loop (normal state)
									CASE CONFIG_WRITE_PHASE IS
										WHEN 0 =>
											CONFIG_TEMP_VAR := X"F5";
										WHEN 1 =>
											CONFIG_TEMP_VAR := RAM_OUT;
										WHEN 2 =>
											CONFIG_TEMP_VAR := X"AA";
									END CASE;
									
									AVR_OUT_TMP := CONFIG_TEMP_VAR(7 - CONFIG_C_BIT); -- Send MSB first
									
									IF TRANSFER_DIRTY = '1' THEN
										AVR_OUT <= '0'; -- cancel
									ELSE 
										IF AVR_OUT_TMP = '1' THEN
											AVR_OUT <= 'Z'; -- replace with Z later
										ELSE
											AVR_OUT <= '0';
										END IF;
									END IF;
									
									IF CONFIG_C_BIT = 7 THEN
										CONFIG_C_BIT <= 0;
										CASE CONFIG_WRITE_PHASE IS
											WHEN 0 =>
												CONFIG_WRITE_PHASE <= 1;
											WHEN 1 =>
												IF CONFIG_COUNT = 31 THEN
													CONFIG_WRITE_PHASE <= 2;
												ELSE 
													CONFIG_COUNT <= CONFIG_COUNT + 1;
												END IF;
											WHEN 2 =>
												-- Finish
												TRANSFER_CONFIG <= '0';
												CONFIG_DO_WRITE <= '0';
										END CASE;
									ELSE
										CONFIG_C_BIT <= CONFIG_C_BIT + 1;
									END IF;
									
								--END IF; -- transfer_dirty
							ELSE -- If BUS access becomes 1 (bus access to CPU)
								TRANSFER_DIRTY <= '1';
								AVR_OUT <= '0';
							END IF;
						END IF; -- CONFIG_DO_WRITE
					END IF; -- CFG_SKIP_CLK
					
				END IF; -- RECEIVED_CONFIG
			END IF; -- CLK CHECK
			
			LAST_AVR_CLK <= S2_AVR_CLK;
		END IF;
	END PROCESS;
	
	AVR_IO <= 'Z' WHEN RECEIVED_CONFIG = '0' ELSE AVR_OUT;
	
	RAM_WRITE_VAL <= CFG_WRITER_VAL WHEN TRANSFER_CONFIG = '1' AND BUS_ACCESS = '0' ELSE BUS_WRITER_VAL;
	RAM_WRITE_ADDR <= CFG_WRITER_ADDR WHEN TRANSFER_CONFIG = '1' AND BUS_ACCESS = '0' ELSE BUS_WRITER_ADDR;
	RAM_WRITE_EN <= CFG_WRITER_EN WHEN TRANSFER_CONFIG = '1' AND BUS_ACCESS = '0' ELSE BUS_WRITER_EN;
	
	PROCESS(CURRENT_REGISTER) -- cmos_in_range
		VARIABLE ADDR_INT				: UNSIGNED(7 DOWNTO 0);
	BEGIN
		ADDR_INT := UNSIGNED(CURRENT_REGISTER);
		IF ADDR_INT >= 64 AND ADDR_INT < 96 THEN -- 0x40 - 0x5F 
			CMOS_IN_RANGE <= '1';
		ELSE
			CMOS_IN_RANGE <= '0';
		END IF;
	END PROCESS;
	
	PROCESS(CLK_IN) -- CMOS RAM process
	BEGIN
		IF FALLING_EDGE(CLK_IN) THEN
			IF RAM_WRITE_EN = '1' THEN
				CMOS_REGISTERS(RAM_WRITE_ADDR) <= RAM_WRITE_VAL;
			END IF;
			RAM_OUT <= CMOS_REGISTERS(RAM_WRITE_ADDR); -- (sync)
		END IF;
	END PROCESS;
	--RAM_OUT <= CMOS_REGISTERS(RAM_WRITE_ADDR); -- also read_addr (async)


	PROCESS(CLK_IN, CURRENT_REGISTER, RESET, CMOS_CS, WR, RECEIVED_CONFIG, A0, CMOS_WRITE_PROTECT, RD, SECONDS, MINUTES, HOURS, DAY, MONTH, YEAR, CENTURY, FPGA_VER, RAM_OUT, WEEKDAY, CMOS_IN_RANGE)
		VARIABLE DATA_OUT_FINAL		: STD_LOGIC_VECTOR(7 downto 0);
	BEGIN
		DATA_OUT_FINAL := x"00";
		
		BUS_WRITER_ADDR <= to_integer(unsigned(CURRENT_REGISTER(4 downto 0))); -- for base dividable by 0x20 
		--BUS_WRITER_ADDR <= to_integer(unsigned(CURRENT_REGISTER(5 downto 0)) - 16); -- for base dividable by 0x10 
		
		IF RESET = '1' THEN
			CMOS_WRITE_PROTECT <= '0';
		END IF;

		IF CMOS_CS = '0' AND RESET = '0' THEN
			IF WR = '0' THEN -- Write
				
				IF CMOS_IN_RANGE = '1' AND RECEIVED_CONFIG = '1' AND A0 = '1' AND CMOS_WRITE_PROTECT = '0' THEN -- range (0x20 - 0x40), check A1 as bus access is only at port 71
					BUS_WRITER_EN <= '1';
					BUS_ACCESS <= '1';
				ELSE 
					BUS_WRITER_EN <= '0';
					BUS_ACCESS <= '0';
				END IF;
				
				IF FALLING_EDGE(CLK_IN) THEN
					IF (A0 = '0') THEN -- 0x70
						-- Cmos register
						CURRENT_REGISTER <= DATA_IN;
					ELSE -- 0x71

						CASE CURRENT_REGISTER IS						
							WHEN x"FF" => -- Chipset command register
								
								IF DATA_IN = x"17" THEN -- 0x17 - lock CMOS until reset
									CMOS_WRITE_PROTECT <= '1';
								END IF;
								
							WHEN OTHERS =>
								BUS_WRITER_VAL <= DATA_IN;
						END CASE;
						
					END IF;
					
				END IF;
				
			ELSIF RD = '0' THEN -- Read
				IF CMOS_IN_RANGE = '1' AND RECEIVED_CONFIG = '1' AND A0 = '1' THEN
					BUS_ACCESS <= '1';
				ELSE 
					BUS_ACCESS <= '0';
				END IF;
				BUS_WRITER_EN <= '0';
				
				IF (A0 = '0') THEN -- 0x70
					DATA_OUT_FINAL := CURRENT_REGISTER;
				END IF;
				IF (A0 = '1') THEN -- 0x71
					CASE CURRENT_REGISTER IS
						WHEN x"00" => -- Seconds
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(SECONDS, 8));
						WHEN x"02" => -- Minutes
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(MINUTES, 8));
						WHEN x"04" => -- Hours
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(HOURS, 8));
						WHEN x"06" => -- Weekday
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(WEEKDAY, 8));
						WHEN x"07" => -- Day of month
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(DAY, 8));
						WHEN x"08" => -- Month
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(MONTH, 8));
						WHEN x"09" => -- Year
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(YEAR, 8));
						WHEN x"32" => -- Century
							DATA_OUT_FINAL := std_logic_vector(to_unsigned(CENTURY, 8));
						WHEN x"0A" => -- Status register A
							-- STATUS REGISTER A (Offset 0x0A)
							-- Bit 7 (UIP): '0' -> Update NOT in progress (Always safe to read)
							-- Bits 6-4 (Div): '010' -> 32.768kHz reference (Standard)
							-- Bits 3-0 (Rate): '0110' -> 1kHz interrupt rate (Standard)
							-- Result: 00100110
							DATA_OUT_FINAL := "00100110";
						WHEN x"0B" => -- Status register B
							-- Bit 7 (SET): '0' -> Running normal
							-- Bit 2 (DM):  '1' -> BINARY MODE (Crucial! because we output std_logic_vector of integer)
							-- Bit 1 (24/12): '1' -> 24 Hour Format
							-- Result: 00000110 
							DATA_OUT_FINAL := "00000110";
						
						WHEN x"FC" =>
							DATA_OUT_FINAL := FPGA_VER(31 downto 24);
						WHEN x"FD" =>
							DATA_OUT_FINAL := FPGA_VER(23 downto 16);
						WHEN x"FE" =>
							DATA_OUT_FINAL := FPGA_VER(15 downto 8);
						WHEN x"FF" =>
							DATA_OUT_FINAL := FPGA_VER(7 downto 0);
							
						WHEN OTHERS =>
							IF CMOS_IN_RANGE = '1' THEN
								IF RECEIVED_CONFIG = '1' THEN
									DATA_OUT_FINAL := RAM_OUT;
								ELSE
									DATA_OUT_FINAL := x"FF";
								END IF;
							ELSE
								DATA_OUT_FINAL := x"00";
							END IF;
					END CASE;
					
				END IF;
			ELSE
				BUS_ACCESS <= '0';
				BUS_WRITER_EN <= '0';
				DATA_OUT_FINAL := x"00";
			END IF;
		ELSE 
			BUS_ACCESS <= '0';
			BUS_WRITER_EN <= '0';
		END IF; -- CMOS CS check
		
		
		DATA_OUT <= DATA_OUT_FINAL; -- def
		
	END PROCESS;

	-- 1. Frequency Divider Process
	-- Assumes CLK_PIT is approx 1.1931818 MHz. 
	-- Generates a single cycle pulse (TICK_1HZ) every second.
	PROCESS(CLK_PIT)
	BEGIN
		IF rising_edge(CLK_PIT) THEN
			IF PIT_DIVIDER >= 1193181 THEN 
				PIT_DIVIDER <= 0;
				TICK_1HZ <= '1';
			ELSE
				PIT_DIVIDER <= PIT_DIVIDER + 1;
				TICK_1HZ <= '0';
			END IF;
		END IF;
	END PROCESS;

	-- 2. Leap Year Calculation
	-- A year is leap if divisible by 4.
	-- (Simplified logic: Since YEAR is 0-99, checking last 2 bits = 00 covers mod 4)
	IS_LEAP_YEAR <= (YEAR rem 4 = 0);

	-- 3. Max Days in Month Logic
	PROCESS(MONTH, IS_LEAP_YEAR)
	BEGIN
		CASE MONTH IS
			WHEN 4 | 6 | 9 | 11 => -- April, June, Sept, Nov
				MAX_DAYS_IN_MONTH <= 30;
			WHEN 2 =>              -- February
				IF IS_LEAP_YEAR THEN
					MAX_DAYS_IN_MONTH <= 29;
				ELSE
				MAX_DAYS_IN_MONTH <= 28;
				END IF;
			WHEN OTHERS =>         -- Jan, Mar, May, Jul, Aug, Oct, Dec
				MAX_DAYS_IN_MONTH <= 31;
		END CASE;
	END PROCESS;

	-- 4. Main Time-Keeping Process
	PROCESS(CLK_PIT)
	BEGIN
		IF rising_edge(CLK_PIT) THEN
			IF TICK_1HZ = '1' THEN
				-- Increment Seconds
				IF SECONDS >= 59 THEN
					SECONDS <= 0;

					-- Increment Minutes
					IF MINUTES >= 59 THEN
						MINUTES <= 0;

						-- Increment Hours
						IF HOURS >= 23 THEN
							HOURS <= 0;

							-- Increment Weekday (1-7)
							IF WEEKDAY >= 7 THEN
								WEEKDAY <= 1;
							ELSE
								WEEKDAY <= WEEKDAY + 1;
							END IF;

							-- Increment Day/Month/Year
							IF DAY >= MAX_DAYS_IN_MONTH THEN
								DAY <= 1;

								-- Increment Month
								IF MONTH >= 12 THEN
									MONTH <= 1;

									-- Increment Year
									IF YEAR >= 99 THEN
										YEAR <= 0;
										CENTURY <= CENTURY + 1;
									ELSE
										YEAR <= YEAR + 1;
									END IF;
								ELSE
									MONTH <= MONTH + 1;
								END IF;
							ELSE
								DAY <= DAY + 1;
							END IF; -- End Day check

						ELSE
							HOURS <= HOURS + 1;
						END IF; -- End Hours check
					ELSE
						MINUTES <= MINUTES + 1;
					END IF; -- End Minutes check
				ELSE
					SECONDS <= SECONDS + 1;
				END IF; -- End Seconds check
			END IF; -- End Tick check
		END IF;
	END PROCESS;

END BEHAVIORAL;

