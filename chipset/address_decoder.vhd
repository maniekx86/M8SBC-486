----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:    01:03:23 09/21/2025
-- Design Name:
-- Module Name:    address_decoder - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: Address decoder for the M8SBC-486
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

ENTITY address_decoder IS
	PORT (
		ADDR_IN			: IN	STD_LOGIC_VECTOR(23 DOWNTO 2);
		ADDR_31			: IN	STD_LOGIC;
		ADDR_A0			: IN	STD_LOGIC;
		ADDR_A1			: IN	STD_LOGIC;
		CPU_MIO			: IN	STD_LOGIC; -- 0 = IO, 1 = MEM
		CPU_WR			: IN	STD_LOGIC; -- 0 = read

		RAM_CACHEABLE	: IN	STD_LOGIC;
		ROM_CACHEABLE	: IN	STD_LOGIC;

		INT_ACK			: IN	STD_LOGIC; -- Override address decoder while interrupt ack is in progress

		RAM_CS			: OUT	STD_LOGIC;
		ROM_CS			: OUT	STD_LOGIC; -- ROM_CS is connected just to OE. Allow it only at READ
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
END address_decoder;

ARCHITECTURE Behavioral OF address_decoder IS
	SIGNAL ADDR_INT			: UNSIGNED(23 DOWNTO 0);

	SIGNAL ROM_CS_I			: STD_LOGIC;
	SIGNAL PIC_CS_I			: STD_LOGIC;
	SIGNAL PIT_CS_I			: STD_LOGIC;
	SIGNAL PS2_CS_I			: STD_LOGIC;
	SIGNAL O61_CS_I			: STD_LOGIC;
	SIGNAL ISA_CS_I			: STD_LOGIC;
	SIGNAL CMOS_CS_I		: STD_LOGIC;

	SIGNAL RAM_CACHE		: STD_LOGIC; -- negated
	SIGNAL ROM_CACHE		: STD_LOGIC; -- negated

BEGIN

	ADDR_INT <= UNSIGNED(ADDR_IN & ADDR_A1 & ADDR_A0);

	-- RAM CS: MEM, 0x000000 to 0x09FFFF, 0x100000 to 0x3FFFFF and 0x4A0000 to 0x4FFFFF (wrap to access 384KB memory hole)
	PROCESS(ADDR_INT, ADDR_31, CPU_MIO, RAM_CACHEABLE)
	BEGIN
		RAM_CS <= '1'; -- inactive
		RAM_CACHE <= '1';
		IF NOT ((ADDR_31 = '1') OR (CPU_MIO = '0')) THEN -- inactive if addr>2GB or IO
			-- decode
			IF (ADDR_INT < x"0A0000") OR (ADDR_INT >= x"100000" AND ADDR_INT < x"400000") OR (ADDR_INT >= x"4A0000" AND ADDR_INT < x"500000") THEN
				RAM_CS <= '0';
				IF RAM_CACHEABLE = '1' THEN
					RAM_CACHE <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- ROM MEM CS: MEM, 0x0C8000 to 0x100000 and 2GB to the end (224KB in lower area. ROM IS 256KB, lower 32KB is accessible after 2GB)
	PROCESS(ADDR_INT, ADDR_31, CPU_MIO, ROM_CACHEABLE)
	BEGIN
		ROM_CS_I <= '1'; -- inactive
		ROM_CACHE <= '1';
		IF NOT (CPU_MIO = '0') THEN -- inactive if addr>2GB or IO
			-- decode
			IF ADDR_31 = '1' THEN -- If 2GB>
				ROM_CS_I <= '0';
				IF ROM_CACHEABLE = '1' THEN
					ROM_CACHE <= '0';
				END IF;
			ELSE
				IF (ADDR_INT >= x"0C8000") AND (ADDR_INT < x"100000") THEN -- If in range 0C8000 to 100000
					ROM_CS_I <= '0';
					IF ROM_CACHEABLE = '1' THEN
						ROM_CACHE <= '0';
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	ROM_CS <= ROM_CS_I WHEN (CPU_WR = '0') ELSE '1'; -- Allow only at reads

	-- IO devices mapping
	-- x86 IO has only 65536 ports, so for less complexity we can just check first 16 bits (or less if range is like x0h to x3h)

	-- PIC: IO, 20h to 21h
	PROCESS(ADDR_INT, CPU_MIO)
	BEGIN
		PIC_CS_I <= '1';
		IF (CPU_MIO = '0') THEN --		 xxXXxxXX76543210
			IF (ADDR_INT(15 DOWNTO 1)) = "000000000010000" THEN
				PIC_CS_I <= '0';
			END IF;
		END IF;
	END PROCESS;

	PIC_CS <= PIC_CS_I;

	-- PIT: IO, 40h to 43h
	PROCESS(ADDR_INT, CPU_MIO)
	BEGIN
		PIT_CS_I <= '1';
		IF (CPU_MIO = '0') THEN --		 xxXXxxXX76543210
			IF (ADDR_INT(15 DOWNTO 2)) = "00000000010000" THEN
				PIT_CS_I <= '0';
			END IF;
		END IF;
	END PROCESS;

	PIT_CS <= PIT_CS_I;

	-- KB: IO, 60h and 64h
	PROCESS(ADDR_INT, CPU_MIO)
	BEGIN
		PS2_CS_I <= '1';
		IF (CPU_MIO = '0') THEN --		 xxXXxxXX76543210
			IF (ADDR_INT(15 DOWNTO 0)) = "0000000001100000" OR (ADDR_INT(15 DOWNTO 0)) = "0000000001100100" THEN
				PS2_CS_I <= '0';
			END IF;
		END IF;
	END PROCESS;

	PS2_CS <= PS2_CS_I;

	-- OUTPUT 61h LATCH: IO, 61h
	PROCESS(ADDR_INT, CPU_MIO)
	BEGIN
		O61_CS_I <= '1';
		IF (CPU_MIO = '0') THEN --		 xxXXxxXX76543210
			IF (ADDR_INT(15 DOWNTO 0)) = "0000000001100001" THEN
				O61_CS_I <= '0';
			END IF;
		END IF;
	END PROCESS;

	O61_CS <= O61_CS_I;

	-- CMOS: IO, 70h to 71h
	PROCESS(ADDR_INT, CPU_MIO)
	BEGIN
		CMOS_CS_I <= '1';
		IF (CPU_MIO = '0') THEN --		 xxXXxxXX76543210
			IF (ADDR_INT(15 DOWNTO 1)) = "000000000111000" THEN
				CMOS_CS_I <= '0';
			END IF;
		END IF;
	END PROCESS;

	CMOS_CS <= CMOS_CS_I;

	-- Special - IO and MEM both decoding
	-- ISA CS: MEM, 0x0A0000 to 0x0C8000 (160KB window) and rest of IO
	PROCESS(ADDR_INT, ADDR_31, CPU_MIO, PIC_CS_I, PIT_CS_I, PS2_CS_I, O61_CS_I, CMOS_CS_I, INT_ACK)
	BEGIN
		IF INT_ACK = '1' THEN -- ISA can be active if no interrupt is in progress
			ISA_CS_I <= '1'; -- inactive
			IF NOT ((ADDR_31 = '1') OR (CPU_MIO = '0')) THEN -- inactive if addr>2GB or IO
				-- decode
				IF (ADDR_INT >= x"0A0000") AND (ADDR_INT < x"0C8000") THEN
					ISA_CS_I <= '0';
				END IF;
			ELSE
				-- All other IO accesses
				IF (CPU_MIO = '0') AND (NOT ((PIC_CS_I = '0') OR (PIT_CS_I = '0') OR (PS2_CS_I = '0') OR (O61_CS_I = '0') OR (CMOS_CS_I = '0'))) THEN
					ISA_CS_I <= '0';
				END IF;
			END IF;
		ELSE
			ISA_CS_I <= '1';
		END IF;
	END PROCESS;

	ISA_CS <= ISA_CS_I;

	-- BS8/16 DECODER
	PROCESS(CPU_MIO, ROM_CS_I, PIC_CS_I, PIT_CS_I, PS2_CS_I, O61_CS_I, ISA_CS_I, CMOS_CS_I)
	BEGIN
	-- RAM_CS
	-- ROM_CS
	--
	-- PIC_CS
	-- PIT_CS
	-- PS2_CS
	-- O61_CS
	-- ISA_CS
	--	CPU_MIO

		OUT_BS8 <= '1';
		OUT_BS16 <= '1';

		-- RAM is 32 bit, don't use BS8/16

		-- Assume that code above is safe and never more than 1 device will pull its CS
		-- 8 bit MEM devices
		IF ROM_CS_I = '0' THEN
			OUT_BS8 <= '0';
		END IF;

		-- IO devices
		IF (PIC_CS_I = '0') OR (PIT_CS_I = '0') OR (PS2_CS_I = '0') OR (O61_CS_I = '0') OR (CMOS_CS_I = '0') THEN
			-- No need to check is CPU_MIO is pointing to IO because all of the signals above check it before
			OUT_BS8 <= '0';
		END IF;

		-- ISA (special). ISA BS might be overwriten by ISA transfer circuity, however keep it as 8-bit as default
		IF (ISA_CS_I = '0') THEN
			OUT_BS8 <= '0';
		END IF;

		-- Duh, nothing is 16 bit here
		-- ISA later on will play with 16 bit

	END PROCESS;

	-- Cacheable
	OUT_KEN <= '0' WHEN ((ROM_CACHE = '0') OR (RAM_CACHE = '0')) ELSE '1';

END Behavioral;
