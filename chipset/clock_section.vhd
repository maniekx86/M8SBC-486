----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
--
-- Create Date:	   13:21:07 09/22/2025
-- Design Name:
-- Module Name:	   clock_section - Behavioral
-- Project Name: Hamster 1 chipset
-- Target Devices: M8SBC-486 REV 1.0
-- Tool versions:
-- Description: Main clock divider
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

LIBRARY UNISIM;
USE UNISIM.vcomponents.ALL;

ENTITY clock_section IS
	GENERIC (
		DIVIDE_BY : INTEGER := 2 -- set to 2 or 3, see CLKDV_DIVIDE below too. Also see m8sbc_main.vhd to update timings & waitstates
	);
	PORT (
		CLK_INPUT	: IN  STD_LOGIC; -- 48 MHz input clock (on GCK pin)
		CPU_CLK_OUT : OUT STD_LOGIC -- divided clock for CPU & FPGA
	);
END ENTITY;

ARCHITECTURE Behavioral OF clock_section IS

	-- Internal signals
	SIGNAL CLKIN_buf  : STD_LOGIC;
	SIGNAL CLK0_raw	  : STD_LOGIC;
	SIGNAL CLKFB	  : STD_LOGIC;
	SIGNAL LOCKED_int : STD_LOGIC;

	SIGNAL CLK_SYS	  : STD_LOGIC; -- 48 MHz internal clock from DLL
	SIGNAL cpu_clk	  : STD_LOGIC := '0';

	-- Divider counter
	SIGNAL cnt		  : unsigned(1 DOWNTO 0) := (OTHERS => '0'); -- 2 bits are enough for /2 or /3
BEGIN

	----------------------------------------------------------------
	-- Input buffer for 48 MHz source
	----------------------------------------------------------------
	CLKIN_IBUFG : IBUFG
	PORT MAP (
		I => CLK_INPUT,
		O => CLKIN_buf
	);

	----------------------------------------------------------------
	-- DLL used only to deskew 48 MHz clock (ignore CLKDV)
	----------------------------------------------------------------
	CLKDLL_inst : CLKDLL
	GENERIC MAP (
		CLKDV_DIVIDE		 => 4.0,  -- used if DIVIDE_BY isn't 2 or 3. For some reason some values make the DLL not lock/wake (including 2 and 3)
		DUTY_CYCLE_CORRECTION => TRUE,
		STARTUP_WAIT		  => TRUE
	)
	PORT MAP (
		CLKIN	=> CLKIN_buf,
		CLKFB	=> CLKFB,
		RST		=> '0',
		CLKDV	=> OPEN,	  -- not used
		CLK0	=> CLK0_raw,  -- 0° output for feedback and system clock
		CLK90	=> OPEN,
		CLK180	=> OPEN,
		CLK270	=> OPEN,
		CLK2X	=> OPEN,
		LOCKED	=> LOCKED_int
	);

	----------------------------------------------------------------
	-- Feedback BUFG for DLL (keeps CLK0 and CLKIN phase-aligned)
	----------------------------------------------------------------
	BUFG_FB : BUFG
	PORT MAP (
		I => CLK0_raw,
		O => CLKFB
	);

	----------------------------------------------------------------
	-- Global buffer for system clock (48 MHz)
	----------------------------------------------------------------
	BUFG_SYS : BUFG
	PORT MAP (
		I => CLK0_raw,
		O => CLK_SYS
	);

	----------------------------------------------------------------
	-- Simple synchronous divider on CLK_SYS
	----------------------------------------------------------------
	PROCESS (CLK_SYS)
	BEGIN
		IF RISING_EDGE(CLK_SYS) THEN
			IF LOCKED_int = '1' THEN -- only run when DLL is locked
				IF DIVIDE_BY = 2 THEN
					-- /2: toggle output each cycle
					cpu_clk <= NOT cpu_clk;
				ELSIF DIVIDE_BY = 3 THEN
					-- /3: count 0,1,2 and toggle on terminal count
					IF cnt = 2 THEN
						cnt		<= (OTHERS => '0');
						cpu_clk <= NOT cpu_clk;
					ELSE
						cnt <= cnt + 1;
					END IF;
				ELSE
					-- Fallback: no division, just pass through (optional)
					cpu_clk <= CLK_SYS;
				END IF;
			ELSE
				-- Optionally hold low until lock
				cpu_clk <= '0';
			END IF;
		END IF;
	END PROCESS;

	CPU_CLK_OUT <= cpu_clk;

END Behavioral;

----------------------------------------------------------------------------------
--
--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;
--library UNISIM;
--use UNISIM.vcomponents.all;
--
--entity clock_section is
--    port (
--        CLK_INPUT   : in  std_logic;  -- 48 MHz input clock (on GCK pin)
--        CPU_CLK_OUT : out std_logic   -- 12 MHz clock for CPU
--    );
--end entity;
--
--architecture Behavioral of clock_section is
--
--    -- Internal signals
--    signal CLKIN_buf  : std_logic;
--    signal CLKDV_raw  : std_logic;
--    signal CLK0_raw   : std_logic;
--    signal CLKFB      : std_logic;
--    signal LOCKED_int : std_logic;
--
--begin
--
--    ----------------------------------------------------------------
--    -- Input buffer for 48 MHz source
--    ----------------------------------------------------------------
--    CLKIN_IBUFG : IBUFG
--    port map (
--        I => CLK_INPUT,
--        O => CLKIN_buf
--    );
--
--    ----------------------------------------------------------------
--    -- Single DLL: divide 48 MHz -> 12 MHz (CLKDV output)
--    ----------------------------------------------------------------
--    CLKDLL_inst : CLKDLL
--    generic map (
--        CLKDV_DIVIDE => 1.5,  
--		  -- We can divide by: 1.5,2.0,2.5,3.0,4.0,5.0,8.0 or 16.0
--		  -- 4.0: 12.0 MHz
--		  -- 3.0: 16.0 MHz
--		  -- 2.5: 19.2 MHz
--		  -- 2.0: 24.0 MHz
--		  -- 1.5: 32.0 MHz
--        DUTY_CYCLE_CORRECTION => TRUE,
--        STARTUP_WAIT => TRUE
--    )
--    port map (
--        CLKIN   => CLKIN_buf, -- from input buffer
--        CLKFB   => CLKFB,     -- feedback from BUFG
--        RST     => '0',       -- no reset
--        CLKDV   => CLKDV_raw, -- divided clock
--        CLK0    => CLK0_raw,  -- 0° output for feedback
--        CLK90   => open,
--        CLK180  => open,
--        CLK270  => open,
--        CLK2X   => open,
--        LOCKED  => LOCKED_int
--    );
--
--    ----------------------------------------------------------------
--    -- Feedback BUFG for DLL (keeps CLK0 and CLKIN phase-aligned)
--    ----------------------------------------------------------------
--    BUFG_FB : BUFG
--    port map (
--        I => CLK0_raw,
--        O => CLKFB
--    );
--
--    ----------------------------------------------------------------
--    -- Global buffer for divided clock (drives CPU and FPGA logic)
--    ----------------------------------------------------------------
--    BUFG_CLKDV : BUFG
--    port map (
--        I => CLKDV_raw,
--        O => CPU_CLK_OUT
--    );
--
--
--end Behavioral;
