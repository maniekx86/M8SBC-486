----------------------------------------------------------------------------------
-- Company: maniek86.xyz
-- Engineer: Piotr Grzesik
-- 
-- Create Date:    16:13:25 06/13/2026 
-- Design Name: 
-- Module Name:    KBC_8042 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: "Enough" 8042 recreation
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: PC PS/2 keyboard controller implementation (no mouse)
--
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY KBC_8042 IS
	PORT (
		CLK			: IN		STD_LOGIC; -- min freq 8 MHz
		CLK_1_1931M	: IN		STD_LOGIC; -- fixed freq (14.318 MHz / 12)
		RST_n			: IN		STD_LOGIC;
		
		CS_n			: IN		STD_LOGIC;
		RD_n			: IN		STD_LOGIC;
		WR_n			: IN		STD_LOGIC;
		A2				: IN		STD_LOGIC;
		DATA_IN		: IN		STD_LOGIC_VECTOR(7 DOWNTO 0);
		DATA_OUT		: OUT 	STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		PS2_CLK_IN	: IN		STD_LOGIC;
		PS2_CLK_OUT	: OUT		STD_LOGIC; -- 1 / 0 - in external logic 1 should be converted to Z and pulled up to vcc
		PS2_DAT_IN	: IN		STD_LOGIC;
		PS2_DAT_OUT	: OUT		STD_LOGIC; -- 1 / 0 - same as above
		
		IRQ1			: OUT		STD_LOGIC;
		A20_GATE		: OUT		STD_LOGIC;
		CPU_RESET_n	: OUT		STD_LOGIC
	);
END KBC_8042;


ARCHITECTURE Behavioral OF KBC_8042 IS


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
		16#75# => X"48", -- KP 8
		16#7D# => X"49", -- KP 9
		16#5B# => X"1B", -- ]
		16#4C# => X"27", -- ;
		16#52# => X"28", -- '
		16#41# => X"33", -- ,
		16#49# => X"34", -- .
		16#4A# => X"35", -- /
		
		-- ps/2 control bytes (simple pass fix)
		16#FA# => X"FA", -- ACK
		16#FE# => X"FE", -- Resend
		16#AA# => X"AA", -- BAT Passed
		16#EE# => X"EE", -- Echo
		16#00# => X"00", -- Error/Overrun
		16#FF# => X"FF", -- Error/Overrun
		16#FC# => X"FC", -- BAT Failed
		16#FD# => X"FD", -- BAT Failed
		
		-- Device ID Byte 1 (Byte 2 is 0x83, which naturally translates to 0x41)
		16#AB# => X"AB",

		OTHERS => X"00"  -- Default/Error
	);
	
	CONSTANT SET2_TO_SET1_EXT : rom_type := ( -- 0xE0 ext codes
		16#1F# => X"5B", -- L WIN
		16#14# => X"1D", -- R CTRL
		16#27# => X"5C", -- R WIN
		16#11# => X"38", -- R ALT
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
		
		16#12# => X"2A", -- Fake L SHIFT (Used in Arrow/Numpad clusters)
		16#59# => X"36", -- Fake R SHIFT (Used in Arrow/Numpad clusters)
		16#7C# => X"37", -- PRINT SCREEN (Translates to KP *)
	
		OTHERS => X"00"  -- Default/Error
	);
	
	CONSTANT cmd_read_configuration_byte	: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"20";
	CONSTANT cmd_write_configuration_byte	: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"60";
	CONSTANT cmd_test_controller				: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"AA";
	CONSTANT cmd_test_ps2_port					: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"AB";
	CONSTANT cmd_disable_ps2_port				: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"AD";
	CONSTANT cmd_enable_ps2_port				: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"AE";
	CONSTANT cmd_read_controller_o_port		: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"D0";
	CONSTANT cmd_write_controller_o_port	: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"D1";
	CONSTANT cmd_pulse_reset					: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"FE";
	
	CONSTANT ps2_receive_timeout				: INTEGER := 5000; -- 5000 is about 4-5 ms
	CONSTANT ps2_reset_pulse_duration		: INTEGER := 6000; -- 5-6 ms
	CONSTANT ps2_send_clk_waiting_duration	: INTEGER := 120;  -- about 100 uS
	CONSTANT ps2_send_clk_waiting_dat_rel	: INTEGER := 60;   -- DAT release timing (must be lower than above)
	
	-- these readed from PS/2 ctrl probably need to be 2ff synced ...
	SIGNAL status_obf								: STD_LOGIC := '0'; -- Output buffer status (0 = empty, 1 = full)
	SIGNAL status_ibf								: STD_LOGIC := '0'; -- Input buffer status (0 = empty, 1 = full)
	SIGNAL status_sysf							: STD_LOGIC := '0'; -- Meant to be cleared on reset and set by firmware
	SIGNAL status_cd								: STD_LOGIC := '0'; -- Command/data 0 = input buffer to PS/2, 1 = input buffer to controller
	SIGNAL status_terr							: STD_LOGIC := '0'; -- Time-out error
	SIGNAL status_perr							: STD_LOGIC := '0'; -- Parity error
	
	SIGNAL status_sysf_f1						: STD_LOGIC := '0'; -- 2ff from ps/2 block
	SIGNAL status_sysf_f2						: STD_LOGIC := '0';
	SIGNAL interrupt_en  						: STD_LOGIC := '0'; -- host logic interrupt
	SIGNAL interrupt_en_f1						: STD_LOGIC := '0';
	SIGNAL interrupt_en_f2						: STD_LOGIC := '0';
	
	
	SIGNAL host_read_buf							: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00";
	SIGNAL last_rd									: STD_LOGIC := '0';
	SIGNAL last_rd_clear_ok						: STD_LOGIC := '0';
	
	SIGNAL pass_to_ps2_cmd						: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00"; -- CPU interface to PS/2 CTRL
	SIGNAL pass_to_host_data					: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00"; -- PS/2 CTRL to CPU interface
	SIGNAL pass_to_host_perr					: STD_LOGIC := '0';
	SIGNAL pass_to_host_terr					: STD_LOGIC := '0';
	
	-- crossing domain flags
	SIGNAL pass_to_ps2_cmd_av					: STD_LOGIC := '0'; -- Available byte in host to ctrl buffer
	SIGNAL pass_to_ps2_cmd_av_1				: STD_LOGIC := '0';
	SIGNAL pass_to_ps2_cmd_av_2				: STD_LOGIC := '0';
	
	SIGNAL pass_to_ps2_cmd_cl					: STD_LOGIC := '0'; -- Clear available flag in host to ctrl buffer
	SIGNAL pass_to_ps2_cmd_cl_1				: STD_LOGIC := '0';
	SIGNAL pass_to_ps2_cmd_cl_2				: STD_LOGIC := '0';
	
	SIGNAL pass_to_ps2_cmd_av_rdy				: STD_LOGIC := '0'; -- Equal to pass_to_ps2_cmd_av_3, info that it's clear
	SIGNAL pass_to_ps2_cmd_av_rdy_1			: STD_LOGIC := '0';
	SIGNAL pass_to_ps2_cmd_av_rdy_2			: STD_LOGIC := '0';
	
	SIGNAL pass_to_host_data_av				: STD_LOGIC := '0'; -- Data for the CPU (0x60) is available signal
	SIGNAL pass_to_host_data_av_1				: STD_LOGIC := '0';
	SIGNAL pass_to_host_data_av_2				: STD_LOGIC := '0';
	SIGNAL pass_to_host_data_av_3				: STD_LOGIC := '0';
	
	SIGNAL pass_to_host_data_cl				: STD_LOGIC := '0'; -- Clear flag above signal
	SIGNAL pass_to_host_data_cl_1				: STD_LOGIC := '0';
	SIGNAL pass_to_host_data_cl_2				: STD_LOGIC := '0';	
	
	SIGNAL pass_to_host_data_cl_ack			: STD_LOGIC := '0'; -- Ack above signal from slower domain
	SIGNAL pass_to_host_data_cl_ack_1		: STD_LOGIC := '0';	
	SIGNAL pass_to_host_data_cl_ack_2		: STD_LOGIC := '0';	
	
	
	-- PS/2 interface
	SIGNAL PS2_CLK_IN_1							: STD_LOGIC := '0';
	SIGNAL PS2_CLK_IN_2							: STD_LOGIC := '0';
	SIGNAL PS2_CLK_IN_3							: STD_LOGIC := '0';
	SIGNAL PS2_DAT_IN_1							: STD_LOGIC := '0';
	SIGNAL PS2_DAT_IN_2							: STD_LOGIC := '0';
	
	SIGNAL PS2_CLK_OUT_buf						: STD_LOGIC := '1';
	SIGNAL PS2_DAT_OUT_buf						: STD_LOGIC := '1';
	
	SIGNAL ps2_bit_count							: INTEGER RANGE 0 TO 11 := 0;
	SIGNAL ps2_receive_data						: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00";
	SIGNAL ps2_parity_bit						: STD_LOGIC := '0';
	--SIGNAL ps2_stop_bit							: STD_LOGIC := '0';
	SIGNAL ps2_timeout_cnt						: INTEGER RANGE 0 TO ps2_receive_timeout;
	
	-- PS/2 ctrl block specific signals
	SIGNAL ps2_cmd_buf							: STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00";
	TYPE PS2_DATA_TARGET_STATE IS (WRITE_PS2, WRITE_CFG, WRITE_OPORT);
	SIGNAL PS2_DATA_TARGET : PS2_DATA_TARGET_STATE;
	
	-- Configuration byte
	SIGNAL ps2_cfg_interrupt					: STD_LOGIC := '1'; -- b0
	SIGNAL ps2_cfg_sysf							: STD_LOGIC := '0'; -- b2
	SIGNAL ps2_cfg_port_clock					: STD_LOGIC := '0'; -- b4 (PS/2 disable/enable - 0 enabled, 1 disabled)
	SIGNAL ps2_cfg_translation					: STD_LOGIC := '0'; -- b6
	
	-- Output port
	SIGNAL ps2_output_port						: STD_LOGIC_VECTOR(7 DOWNTO 0) := "11000001"; -- CPU not in reset and release CLK
	
	-- Reset pulse
	SIGNAL ps2_reset_pulse_count				: INTEGER RANGE 0 TO ps2_reset_pulse_duration := 0;
	SIGNAL ps2_reset_pulse_active				: STD_LOGIC := '0';
	SIGNAL ps2_reset_pulse						: STD_LOGIC := '0';
	SIGNAL ps2_reset_trigger					: STD_LOGIC := '0';
	SIGNAL ps2_reset_trigger_last				: STD_LOGIC := '0';
	
	-- Translation
	SIGNAL ps2_translation_ext					: STD_LOGIC := '0';
	SIGNAL ps2_translation_break				: STD_LOGIC := '0';
	
	-- Host to device
	SIGNAL ps2_send_clk_waiting				: STD_LOGIC := '0';
	SIGNAL ps2_send_clk_waiting_count		: INTEGER RANGE 0 TO ps2_send_clk_waiting_duration := 0;
	
	
	TYPE PS2_FM_STATE IS (ST_IDLE, ST_CMD_REC, ST_DATA_REC, ST_WAIT_CMD_CLEAR, ST_PS2_REC, ST_PS2_SEND, ST_WAIT_OBF_ACK); 
   SIGNAL PS2_STATE : PS2_FM_STATE; 

BEGIN
	
	-- CPU interface
	SYNC_CPU_INTERFACE: PROCESS(RD_n, WR_n, CS_n, A2, DATA_IN, RST_n, CLK)
		VARIABLE data_parity_tmp : STD_LOGIC;
	BEGIN
		
		IF RST_n = '0' THEN
			-- RESET
			status_obf <= '0';
			status_ibf <= '0';
			status_sysf <= '0';
			status_cd <= '0';
			status_terr <= '0';
			status_perr <= '0';
			--PS2 status_sysf_f1 <= '0';
			status_sysf_f2 <= '0';
			interrupt_en <= '0';
			--PS2 interrupt_en_f1 <= '0';
			interrupt_en_f2 <= '0';
			host_read_buf <= X"00";
			last_rd <= '0';
			last_rd_clear_ok <= '0';
			pass_to_ps2_cmd <= X"00";
			pass_to_ps2_cmd_av <= '0';
			--PS2 pass_to_ps2_cmd_cl <= '0';
			pass_to_ps2_cmd_cl_1 <= '0';
			pass_to_ps2_cmd_cl_2 <= '0';
			--PS2 pass_to_ps2_cmd_av_rdy <= '0';
			pass_to_ps2_cmd_av_rdy_1 <= '0';
			pass_to_ps2_cmd_av_rdy_2 <= '0';
			--PS2 pass_to_host_data_av <= '0';
			pass_to_host_data_av_1 <= '0';
			pass_to_host_data_av_2 <= '0';
			pass_to_host_data_av_3 <= '0';
			pass_to_host_data_cl <= '0';
			--PS2 pass_to_host_data_cl_ack <= '0';
			pass_to_host_data_cl_ack_1 <= '0';
			pass_to_host_data_cl_ack_2 <= '0';
			
		ELSE
			IF RISING_EDGE(CLK) THEN
				-- Synchronizers
				pass_to_ps2_cmd_cl_1 <= pass_to_ps2_cmd_cl;
				pass_to_ps2_cmd_cl_2 <= pass_to_ps2_cmd_cl_1;
				
				pass_to_ps2_cmd_av_rdy_1 <= pass_to_ps2_cmd_av_rdy;
				pass_to_ps2_cmd_av_rdy_2 <= pass_to_ps2_cmd_av_rdy_1;
				
				pass_to_host_data_cl_ack_1 <= pass_to_host_data_cl_ack;
				pass_to_host_data_cl_ack_2 <= pass_to_host_data_cl_ack_1;
				
				status_sysf_f2 <= status_sysf_f1;
				status_sysf <= status_sysf_f2;
				interrupt_en_f2 <= interrupt_en_f1;
				interrupt_en <= interrupt_en_f2;
				
				IF pass_to_ps2_cmd_cl_2 = '1' AND pass_to_ps2_cmd_av = '1' THEN -- pass_to_ps2_cmd_cl_2 prevents from 2 drivers
					pass_to_ps2_cmd_av <= '0';
				END IF;
				
				IF pass_to_ps2_cmd_av = '1' OR pass_to_ps2_cmd_av_rdy_2 = '1' OR pass_to_ps2_cmd_cl_2 = '1' THEN
					status_ibf <= '1';
				ELSE
					IF status_ibf = '1' AND pass_to_host_data_cl_ack_2 = '0' THEN
						status_ibf <= '0';
					END IF;
				END IF;
			
				-- Writing
				IF CS_n = '0' AND WR_n = '0' THEN
				
					IF A2 = '0' THEN -- CPU WRITE 0x60 (Data write)
						
						--IF pass_to_ps2_cmd_av = '0' THEN -- don't allow overwrite. 
						IF status_ibf = '0' THEN
							-- We dont need to check av_rdy because it should be cleared before av gets to the PS2 block via synchroniser
							pass_to_ps2_cmd 		<= DATA_IN;
							pass_to_ps2_cmd_av 	<= '1';
							status_cd <= '0'; -- data
						END IF;
						
					ELSE -- CPU WRITE 0x64 (Command)
						
						--IF pass_to_ps2_cmd_av = '0' THEN -- don't allow overwrite. 
						IF status_ibf = '0' THEN
							pass_to_ps2_cmd 		<= DATA_IN;
							pass_to_ps2_cmd_av 	<= '1';
							status_cd <= '1'; -- cmd
						END IF;
							

					END IF; -- A2
					
				END IF; -- WR,CS = '0'
			END IF; -- RISING_EDGE(CLK)
			
			
			
			-- Reading (SYNC)
			
			IF RISING_EDGE(CLK) THEN -- Block to receive byte from ctrl for CPU read
			
				pass_to_host_data_av_1 <= pass_to_host_data_av;
				pass_to_host_data_av_2 <= pass_to_host_data_av_1;
				pass_to_host_data_av_3 <= pass_to_host_data_av_2;
				
				IF pass_to_host_data_av_2 = '1' AND pass_to_host_data_av_3 = '0' THEN -- data received from ctrl via 2ff
					host_read_buf <= pass_to_host_data;
					
					status_terr <= pass_to_host_terr;
					status_perr <= pass_to_host_perr;
					
					status_obf <= '1';
					pass_to_host_data_cl <= '1';
				ELSIF CS_n = '0' AND RD_n = '0' AND A2 = '0' AND status_obf = '1' THEN -- last case: do not trigger last_rd if there's no data in buffer
					last_rd <= '1';
				ELSE
					IF last_rd = '1' THEN -- clear when read ended
						last_rd <= '0';
						status_obf <= '0';
						host_read_buf <= X"00";
						last_rd_clear_ok <= '1';
					END IF;
					IF last_rd_clear_ok = '1' AND last_rd = '0' THEN
						IF pass_to_host_data_cl_ack_2 = '1' THEN
							pass_to_host_data_cl <= '0';
							last_rd_clear_ok <= '0';
						END IF;
					END IF;
				END IF;
			END IF;
			
		END IF; -- RST_n = '0'
		
	END PROCESS;
	
	-- Reading (ASYNC)
	HOST_ASYNC_READ: PROCESS(RST_n, CS_n, RD_n, WR_n, A2, status_obf, host_read_buf, status_perr, status_terr, status_cd , status_sysf, status_ibf)
		VARIABLE DATA_OUT_v : STD_LOGIC_VECTOR(7 DOWNTO 0);
	BEGIN
		DATA_OUT_v := X"00";
		IF RST_n = '1' THEN -- reset not asserted
			IF CS_n = '0' AND RD_n = '0' AND WR_n = '1' THEN
				IF A2 = '0' THEN -- CPU READ 0x60 (Data read)
					IF status_obf = '1' THEN
						DATA_OUT_v := host_read_buf;
					ELSE
						DATA_OUT_v := X"00";
					END IF;
				ELSE -- CPU READ 0x64 (Status)
					DATA_OUT_v := status_perr & status_terr & "01" & status_cd & status_sysf & status_ibf & status_obf; -- bit 4 = 1 (Keyboard lock, 1 means unlocked)
				END IF;
			END IF; -- CS,RD,WR = '0'
		END IF;
		
		DATA_OUT <= DATA_OUT_v;
	END PROCESS;
	
	--status_ibf <= pass_to_ps2_cmd_av OR pass_to_ps2_cmd_av_rdy_2 OR pass_to_ps2_cmd_cl_2 OR pass_to_host_data_cl_ack; -- ensure that 2ffs are clear before CPU tries to write again
	
	IRQ1 <= status_obf AND interrupt_en; -- host domain
	A20_GATE <= ps2_output_port(1); -- ps2 domain
	CPU_RESET_n <= ps2_output_port(0) AND (NOT ps2_reset_pulse); -- ps2 domain
	
	PS2_CLK_OUT <= PS2_CLK_OUT_buf;
	PS2_DAT_OUT <= PS2_DAT_OUT_buf;
	
	PS2_RESET_PROC: PROCESS (CLK_1_1931M)
	BEGIN
		IF RISING_EDGE(CLK_1_1931M) THEN
			IF ps2_reset_trigger /= ps2_reset_trigger_last THEN
				ps2_reset_trigger_last <= ps2_reset_trigger;
				ps2_reset_pulse_active <= '1';
				ps2_reset_pulse_count <= 0;
				ps2_reset_pulse <= '1';
			ELSE
				IF ps2_reset_pulse_count >= ps2_reset_pulse_duration THEN
					ps2_reset_pulse <= '0';
					ps2_reset_pulse_active <= '0';
				ELSE
					IF ps2_reset_pulse_active = '1' THEN
						ps2_reset_pulse_count <= ps2_reset_pulse_count + 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PS2_SYNC_PROC: PROCESS (RST_n, CLK_1_1931M)
		VARIABLE data_parity_tmp : STD_LOGIC;
		VARIABLE translated_data_v : STD_LOGIC_VECTOR(7 DOWNTO 0);
   BEGIN
			
		if RST_n = '0' THEN
			PS2_STATE <= ST_IDLE;
			PS2_DATA_TARGET <= WRITE_PS2;
			PS2_CLK_OUT_buf <= '0'; -- PS/2 communication inhibit
			PS2_DAT_OUT_buf <= '1'; -- Default "hi-z"
			
			pass_to_host_data <= X"00";
			pass_to_host_perr <= '0';
			pass_to_host_terr <= '0';
			pass_to_ps2_cmd_av_1 <= '0';
			pass_to_ps2_cmd_av_2 <= '0';
			pass_to_ps2_cmd_cl <= '0';
			pass_to_ps2_cmd_av_rdy <= '0';
			pass_to_host_data_av <= '0';
			pass_to_host_data_cl_1 <= '0';
			pass_to_host_data_cl_2 <= '0';
			pass_to_host_data_cl_ack <= '0';
			
			PS2_CLK_IN_1 <= '0'; 
			PS2_CLK_IN_2 <= '0';
			PS2_CLK_IN_3 <= '0';
			PS2_DAT_IN_1 <= '0';
			PS2_DAT_IN_2 <= '0';
			
			ps2_bit_count <= 0;
			ps2_receive_data <= X"00";
			ps2_parity_bit <= '0';
			--ps2_stop_bit <= '0';
			ps2_timeout_cnt <= 0;
			
			ps2_cmd_buf <= X"00";
			ps2_cfg_interrupt <= '1';
			ps2_cfg_sysf <= '0';
			ps2_cfg_port_clock <= '0';
			ps2_cfg_translation <= '0';
			-- output port and reset pulse kept after reset
			
			ps2_translation_ext <= '0';
			ps2_translation_break <= '0';
			ps2_send_clk_waiting <= '0';
			ps2_send_clk_waiting_count <= 0;
			
		ELSE
			IF RISING_EDGE(CLK_1_1931M) THEN
			
				PS2_CLK_IN_1 <= PS2_CLK_IN;
				IF ps2_output_port(6) = '1' THEN
					PS2_CLK_IN_2 <= PS2_CLK_IN_1; -- PS/2 host read (dev->host) occurs on falling edge
				ELSE -- output port (bit 6 KBD CLK) bypass
					PS2_CLK_IN_2 <= '0';
				END IF;
				PS2_CLK_IN_3 <= PS2_CLK_IN_2; -- PS/2 host write (host->dev) data change should occur after falling edge as device reads on falling edge too
				
				PS2_DAT_IN_1 <= PS2_DAT_IN;
				IF ps2_output_port(7) = '1' THEN
					PS2_DAT_IN_2 <= PS2_DAT_IN_1;
				ELSE  -- output port (bit 7 KBD DAT) bypass
					PS2_DAT_IN_2 <= '0';
				END IF;
			
				pass_to_host_data_cl_1 <= pass_to_host_data_cl; -- asserted
				pass_to_host_data_cl_2 <= pass_to_host_data_cl_1;
				
				pass_to_host_data_cl_ack <= pass_to_host_data_cl_2;
				
				IF pass_to_host_data_cl_2 = '1' THEN
					pass_to_host_data_av <= '0';
				END IF;
			
				pass_to_ps2_cmd_av_1 <= pass_to_ps2_cmd_av;
				pass_to_ps2_cmd_av_2 <= pass_to_ps2_cmd_av_1;
				
				pass_to_ps2_cmd_av_rdy <= pass_to_ps2_cmd_av_2; -- back
				
				CASE PS2_STATE IS
					WHEN ST_IDLE => -- Read only in IDLE
					  -- check if we have a command and no data is in obf
					  IF pass_to_ps2_cmd_av_2 = '1' AND pass_to_host_data_cl_2 = '0' THEN
							PS2_CLK_OUT_buf <= '0'; -- don't allow communication - we are busy!
							
							ps2_cmd_buf <= pass_to_ps2_cmd; -- also holds data
							pass_to_ps2_cmd_cl <= '1'; -- ACK: clear IBF in the host domain
							
							IF status_cd = '0' THEN
								 PS2_STATE <= ST_DATA_REC;
							ELSE
								 PS2_STATE <= ST_CMD_REC;
							END IF;
							
					  ELSE
							-- No command is here or we are blocked by OBF
							-- by keeping cl at 0, we refuse to acknowledge the byte
							-- IBF stays locked at 1 so the CPU is forced to wait
							pass_to_ps2_cmd_cl <= '0';
							
							--   PS/2 receive block in idle
							IF pass_to_host_data_cl_2 = '0' THEN -- no data in obf
							
								IF ps2_cfg_port_clock = '0' THEN --  (1 = disabled, 0 = enabled)
									PS2_CLK_OUT_buf <= '1'; -- allow communication when interface is enabled
								ELSE
									PS2_CLK_OUT_buf <= '0';
								END IF;
								
								IF PS2_CLK_IN_2 = '0' AND PS2_CLK_IN_3 = '1' AND ps2_cfg_port_clock = '0' THEN 
								-- falling edge 
								-- and only when we are enabled (to not react to disabling/enabling interface, IN and OUT are connected together externally)
								
									IF PS2_DAT_IN_2 = '0' THEN -- start bit is 0
										-- Receive start
										PS2_STATE <= ST_PS2_REC;
										ps2_bit_count <= 0;
										ps2_timeout_cnt <= 0;
										
									END IF;
								END IF;
								
							ELSE
								PS2_CLK_OUT_buf <= '0'; -- don't allow communication
							END IF; -- else pass_to_host_data_cl_2 = '0'
							
					  END IF;
					  
					  PS2_DAT_OUT_buf <= '1'; -- normal state of dat out ("float")
									
						
					WHEN ST_CMD_REC => -- 0x64
					
						CASE ps2_cmd_buf IS
							WHEN cmd_read_configuration_byte => -- 0x20
							
								pass_to_host_data <= "0" & ps2_cfg_translation & "0" & ps2_cfg_port_clock & "0" & ps2_cfg_sysf & "0" & ps2_cfg_interrupt;
								pass_to_host_perr <= '0';
								pass_to_host_terr <= '0';
								pass_to_host_data_av <= '1';
								
							WHEN cmd_write_configuration_byte => -- 0x60
								PS2_DATA_TARGET <= WRITE_CFG;
								
							WHEN cmd_test_controller => -- 0xAA
								pass_to_host_data <= X"55"; -- test passed
								pass_to_host_perr <= '0';
								pass_to_host_terr <= '0';
								pass_to_host_data_av <= '1';
								-- Test command disables keyboard
								ps2_cfg_port_clock <= '1';
								
							WHEN cmd_test_ps2_port => -- 0xAB
								-- TODO: do actual test
								pass_to_host_data <= X"00"; -- no faults
								pass_to_host_perr <= '0';
								pass_to_host_terr <= '0';
								pass_to_host_data_av <= '1';
								
							WHEN cmd_disable_ps2_port => -- Disable Keyboard, set bit 4 of cfg reg
								ps2_cfg_port_clock <= '1';
								
							WHEN cmd_enable_ps2_port => -- Enable Keyboard, clear bit 4 of cfg reg
								-- PS/2 interface can be enabled by sending a byte to the keyboard (WRITE_PS2) (undocumented behavior)
								ps2_cfg_port_clock <= '0';
							
							WHEN cmd_read_controller_o_port => -- 0xD0
							
								pass_to_host_data <= ps2_output_port;
								pass_to_host_perr <= '0';
								pass_to_host_terr <= '0';
								pass_to_host_data_av <= '1';
							
							WHEN cmd_write_controller_o_port => -- 0xD1
								PS2_DATA_TARGET <= WRITE_OPORT;
							
							WHEN cmd_pulse_reset => -- 0xFE
								ps2_reset_trigger <= NOT ps2_reset_trigger;
								
							WHEN OTHERS =>
							
						END CASE;
 
						ps2_cmd_buf <= X"00";
						PS2_STATE <= ST_WAIT_CMD_CLEAR;

					WHEN ST_DATA_REC => -- 0x60
					
						CASE PS2_DATA_TARGET IS
						
							WHEN WRITE_PS2 => -- BEGIN TRANSMISSION TO PS/2
								
								PS2_CLK_OUT_buf <= '0'; -- pull clock low
								PS2_DAT_OUT_buf <= '1'; -- data high
								ps2_send_clk_waiting	<= '1'; -- We are waiting 100 uS
								ps2_send_clk_waiting_count <= 0; -- ps2_send_clk_waiting_duration
								
								ps2_timeout_cnt <= 0; -- timeout
								ps2_bit_count <= 0;
								
								PS2_STATE <= ST_PS2_SEND;
								
							WHEN WRITE_CFG =>
								ps2_cfg_translation <= ps2_cmd_buf(6);
								ps2_cfg_port_clock <= ps2_cmd_buf(4);
								ps2_cfg_sysf <= ps2_cmd_buf(2);
								status_sysf_f1 <= ps2_cmd_buf(2); -- pass to cpu interface 0x64 
								ps2_cfg_interrupt <= ps2_cmd_buf(0);
								interrupt_en_f1 <= ps2_cmd_buf(0); -- CPU manages OBF that is tied to interrupt
								
								PS2_DATA_TARGET <= WRITE_PS2;
								PS2_STATE <= ST_WAIT_CMD_CLEAR;
								
							WHEN WRITE_OPORT =>
								ps2_output_port <= ps2_cmd_buf;
								
								PS2_DATA_TARGET <= WRITE_PS2;
								PS2_STATE <= ST_WAIT_CMD_CLEAR;
							
							WHEN OTHERS =>
								
								PS2_DATA_TARGET <= WRITE_PS2;
								PS2_STATE <= ST_WAIT_CMD_CLEAR;
								
						END CASE;
					
						
						
					WHEN ST_WAIT_CMD_CLEAR =>
						-- wait until we are ready to get next command by cmd clear signal be fully cleared 
						IF pass_to_ps2_cmd_av_2 = '0' THEN
							PS2_STATE <= ST_IDLE;
						END IF;
					  
					WHEN ST_PS2_REC =>
						IF ps2_timeout_cnt >= ps2_receive_timeout THEN
							-- Receive timeout occured
							pass_to_host_data <= X"FF";
							pass_to_host_perr <= '0';
							pass_to_host_terr <= '1';
							pass_to_host_data_av <= '1';
							PS2_STATE <= ST_WAIT_OBF_ACK;
						ELSE
					
							IF PS2_CLK_IN_2 = '0' AND PS2_CLK_IN_3 = '1' THEN -- falling edge
								-- Bit receive
								IF ps2_bit_count < 8 THEN
									ps2_receive_data <= PS2_DAT_IN_2 & ps2_receive_data(7 downto 1);
								ELSIF ps2_bit_count = 8 THEN
									ps2_parity_bit <= PS2_DAT_IN_2;
								ELSIF ps2_bit_count >= 9 THEN
									-- ps2_stop_bit <= PS2_DAT_IN_2; -- extra check?
									
									data_parity_tmp := NOT (ps2_receive_data(7) XOR ps2_receive_data(6) XOR ps2_receive_data(5) XOR ps2_receive_data(4) XOR 
																	ps2_receive_data(3) XOR ps2_receive_data(2) XOR ps2_receive_data(1) XOR ps2_receive_data(0)); -- Parity
									
									IF data_parity_tmp = ps2_parity_bit THEN
									
										-- TODO: PAUSE/BREAK and PRINT SCR translation
										-- Control bytes like ACK pass through thanks to translation rom passing them 1 to 1
										IF ps2_cfg_translation = '1' THEN
										
											IF ps2_receive_data = X"E0" THEN -- Extended. In translation it's passed
												ps2_translation_ext <= '1';
												
												pass_to_host_data <= ps2_receive_data;
												pass_to_host_perr <= '0';
												pass_to_host_terr <= '0';
												pass_to_host_data_av <= '1';
												
												PS2_STATE <= ST_WAIT_OBF_ACK;
												
											ELSIF ps2_receive_data = X"F0" THEN -- Break. Not passed. Go to idle and wait for next byte to OR 0x80
											
												ps2_translation_break <= '1';
												PS2_STATE <= ST_IDLE;
												
											ELSE
												
												IF ps2_translation_ext = '1' THEN -- Ext or normal
													translated_data_v := SET2_TO_SET1_EXT(to_integer(unsigned(ps2_receive_data)));
												ELSE
													translated_data_v := SET2_TO_SET1(to_integer(unsigned(ps2_receive_data)));
												END IF;
												
												IF ps2_translation_break = '1' THEN -- Release
													translated_data_v(7) := '1'; -- OR with 0x80
												END IF;
												
												pass_to_host_data <= translated_data_v;
												pass_to_host_perr <= '0';
												pass_to_host_terr <= '0';
												pass_to_host_data_av <= '1';
												PS2_STATE <= ST_WAIT_OBF_ACK;
												
												ps2_translation_ext <= '0'; -- Reset flags
												ps2_translation_break <= '0';
											END IF; -- ps2_receive_data = xxx
											
										ELSE -- ps2_cfg_translation = '1'
											
											-- No translation
											
											pass_to_host_data <= ps2_receive_data;
											pass_to_host_perr <= '0';
											pass_to_host_terr <= '0';
											pass_to_host_data_av <= '1';
											PS2_STATE <= ST_WAIT_OBF_ACK;
										END IF; -- ps2_cfg_translation = '0'
										
									ELSE
										-- Parity error
										pass_to_host_data <= X"FF";
										pass_to_host_perr <= '1';
										pass_to_host_terr <= '0';
										pass_to_host_data_av <= '1';
										PS2_STATE <= ST_WAIT_OBF_ACK;
									END IF; -- data_parity_tmp = ps2_parity_bit
											
								END IF; -- ps2_bit_count = 9
								
								ps2_bit_count <= ps2_bit_count + 1;
								ps2_timeout_cnt <= ps2_timeout_cnt + 1;
							ELSE
								ps2_timeout_cnt <= 0; -- reset timeout on pulse
							END IF; -- falling edge PS2_CLK_IN_2 = '0' AND PS2_CLK_IN_3 = '1'
							
							
						END IF; -- ps2_timeout_cnt >= ps2_receive_timeout
						
					WHEN ST_PS2_SEND =>
						-- ps2_cmd_buf contains byte to send
						
						IF ps2_timeout_cnt >= ps2_receive_timeout THEN
							-- timeout
							PS2_CLK_OUT_buf <= '1';
							PS2_DAT_OUT_buf <= '1';

							pass_to_host_data <= X"FF";
							pass_to_host_perr <= '0';
							pass_to_host_terr <= '1';
							pass_to_host_data_av <= '1';
							PS2_STATE <= ST_WAIT_OBF_ACK;
						ELSE
							IF ps2_send_clk_waiting = '1' THEN -- transmit init
								-- CLK OUT is 0
								-- DAT OUT is 1
								IF ps2_send_clk_waiting_count >= ps2_send_clk_waiting_duration THEN
									ps2_send_clk_waiting <= '0';
									PS2_CLK_OUT_buf <= '1'; -- release CLK (L->H)! D0 next
								ELSE
									IF ps2_send_clk_waiting_count = ps2_send_clk_waiting_dat_rel THEN -- make DAT low before CLK release (start bit)
										PS2_DAT_OUT_buf <= '0';
									END IF;
									ps2_send_clk_waiting_count <= ps2_send_clk_waiting_count + 1;
								END IF;
								
							ELSE -- ps2_send_clk_waiting = '1'
								-- actual data transfer
								IF PS2_CLK_IN_2 = '0' AND PS2_CLK_IN_3 = '1' THEN -- falling edge
									IF ps2_bit_count < 8 THEN
										
										PS2_DAT_OUT_buf <= ps2_cmd_buf(ps2_bit_count); -- D0 first so we can cast this directly
										
									ELSIF ps2_bit_count = 8 THEN
										-- parity
										PS2_DAT_OUT_buf <= NOT (ps2_cmd_buf(7) XOR ps2_cmd_buf(6) XOR ps2_cmd_buf(5) XOR ps2_cmd_buf(4) XOR 
																 ps2_cmd_buf(3) XOR ps2_cmd_buf(2) XOR ps2_cmd_buf(1) XOR ps2_cmd_buf(0));
									ELSIF ps2_bit_count = 9 THEN
										PS2_DAT_OUT_buf <= '1'; -- Stop bit. On next rising edge 
									ELSIF ps2_bit_count = 10 THEN
										-- Read ack
										IF PS2_DAT_IN_2 = '0' THEN
											-- Transmit ok
											PS2_STATE <= ST_IDLE;
										ELSE
											-- Error, lets raise timeout
											pass_to_host_data <= X"FF";
											pass_to_host_perr <= '0';
											pass_to_host_terr <= '1';
											pass_to_host_data_av <= '1';
											PS2_STATE <= ST_WAIT_OBF_ACK;
										END IF;
									END IF; -- ps2_bit_count = xxx
										
									
									ps2_bit_count <= ps2_bit_count + 1;
									ps2_timeout_cnt <= 0; -- reset timeout on pulse
								ELSE
									ps2_timeout_cnt <= ps2_timeout_cnt + 1;
								END IF; -- falling edge clk in
							END IF; -- ps2_send_clk_waiting = '0'
							
						END IF; -- ps2_timeout_cnt >= ps2_receive_timeout
					
						
					WHEN ST_WAIT_OBF_ACK =>
						 -- we just sent data to the CPU domain
						 -- we CANNOT go idle because pass_to_host_data_cl_2 is 0 and idle block could execute another command if IBF isn't empty
						 IF pass_to_host_data_cl_2 = '1' THEN
							  -- synchronizers have caught up, ready to go back to idle
							  PS2_STATE <= ST_IDLE;
						 END IF;

					WHEN OTHERS =>
				END CASE;

				
         END IF; -- RISING EDGE
      END IF; -- RESET
		
   END PROCESS;
	
	
 
	

END Behavioral;

