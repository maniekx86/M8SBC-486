; BIOS parameter block

bios_data:
	dw 0x3F8, 0x2F8, 0x3E8, 0x2E8	; 0x00 - COM port numbers
	dw 0x378, 0x278, 0		; 0x08 - LPT1-LPT3
	dw 0x0000		; 0x0E - EBDA segment (none)

bios_equip:
	dw 0x082D		; 0x10 - equipment

	db 0			; 0x12 - OEM codes
lowram_size:
	dw 640			; 0x13 - lower RAM size (KB)
	dw 0			; 0x15 - not used

; Keyboard
keyboard_flags:
	dw 0			; 0x17 - keyboard flags
	db 0			; 0x19 - Alt+charcode buffer
keybuf_head:
	dw 0x1E			; 0x1A - keyboard buffer head (offset into seg 0x40)
keybuf_tail:
	dw 0x1E			; 0x1C - keyboard buffer tail (offset into seg 0x40)
keybuf:
	times 16 dw 0		; 0x1E - keyboard buffer

; Disk
disk_calib_status:
	db 0			; 0x3E - disk calibration status, bits 5:4 - selected disk
motor_run:
	db 0			; 0x3F - floppy motor on flags (0 - A, 1 - B)
motor:
	db 0			; 0x40 - motor off timer
disk_error:
	db 0			; 0x41 - floppy error
	times 7 db 0		; 0x42 - floppy status

; Video data
video_mode:
	db 3			; 0x49 - current video mode
chars_per_line:
	dw 40			; 0x4A - characters per line
video_regen_size:
	dw 0x4000		; 0x4C - screen size
	dw 0			; 0x4E - screen shift
cursor_pos:
	times 8 dw 0		; 0x50 - cursor position in 8 pages
cursor_lines:
	dw 0x0607		; 0x60 - cursor scanlines
video_page:
	db 0			; 0x62 - current video page
	dw 0x3d4		; 0x63 - base IO-port of video controller
	db 0x0A			; 0x65 - mode register of 6845:
				;        bit 5 - enable blinking
				;        bit 4 - mode 6
				;        bit 3 - enable video output
				;        bit 2 - monochrome
				;        bit 1 - graphics mode
				;        bit 0 - text mode
	db 0			; 0x66 - CGA palette:
				;        bit 5 - CGA blue palette
				;        bit 4 - CGA bright palette
				;        bit 3:0 - border / back color

pmode_exit_ip:
	dw 0			; 0x67 - exit from protected mode IP value
pmode_exit_cs:
	dw 0			; 0x69 - and CS value

	db 0			; 0x6B - IRQ 0-7 flags

; Timer
ticks_low:
	dw 0			; 0x6C - tick count (low)
ticks_high:
	dw 0			; 0x6E - tick count (high)
new_day:
	db 0			; 0x70 - new day flag

; System flags
ctrl_break:
	db 0			; 0x71 - Ctrl+Break pressed
warm_boot:
	dw 0x1234		; 0x72 - warm boot 0x1234, cold boot otherwise

; HDD
hdd_last_status:
	db 0			; 0x74 - last hdd status
num_hdd:
	db 1			; 0x75 - HDD number
hdd_control:
	db 8			; 0x76 - HDD control register (bit 3 - more than 8 heads)
	db 0			; 0x77 - HDD port for IBM XT

; Timeouts
lpt_timeouts:
	times 4 db 0		; 0x78 - LPT timeouts
com_timeouts:
	times 4 db 0		; 0x7C - COM timeouts

; Keyboard buffer
keyb_buffer_start:
	dw 0x1E			; 0x80
keyb_buffer_end:
	dw 0x3E			; 0x82


; Video
video_rows:
	db 24			; 0x84 - video lines minus 1
char_scan_lines:
	dw 8			; 0x85 - scan lines per char
video_options:
	db 0x38			; 0x87 - video controller options:
				;        bit 7 - do not clear screen when changing mode
				;        bit 6:4 - VRAM size (64/128/192/256/512/1024+)
				;        bit 3 - video active
				;        bit 1 - monochrome
				;        bit 0 - cursor emulation
video_type:
	db 0x09			; 0x88 - video controller type: hires enhanced
video_flags1:
	db 0x59			; 0x89 - video controller flags:
				;        bit 7,4 - num scan lines (350, 400, 200)
				;        bit 6 - display switch
				;        bit 3 - default palette
				;        bit 2 - monochrome
				;        bit 1 - grayscale
				;        bit 0 - VGA active
video_flags2:
	db 0x00			; 0x8A - video controller flags 2 (unknown)

	db 0			; 0x8B - floppy config
	db 0			; 0x8C - HDD status
	db 0			; 0x8D - HDD error
	db 0			; 0x8E - HDD done
	db 0			; 0x8F - FDD info
	db 0			; 0x90 - FDD 0 type
	db 0			; 0x91 - FDD 1 type
	db 0			; 0x92 - FDD 0 state
	db 0			; 0x93 - FDD 1 state
	db 0			; 0x94 - FDD 0 cyl
	db 0			; 0x95 - FDD 1 cyl
key_flags3:
	db 0			; 0x96 - keyboard flags 3
key_flags4:
	db 0			; 0x97 - keyboard flags 4

	dw 0, 0			; 0x98 - wait flag address
	dd 0			; 0x9C - wait counter

	db 0			; 0xA0 - wait flag

	times 7 db 0		; 0xA1

; This label used by parameter block size control
check_size:

	dw 0, 0			; 0xA8 - Display Combination Code table address

; Our parameters
reserved:
	db 0			; Reserved
sd_block:
	db 0			; SD block mode indicator
hid_keyb_state:
	db 0			; USB keyboard exchange state
hid_keyb_errors:
	db 0			; USB keyboard num errors
hid_keys:
	db 0, 0, 0, 0		; USB keypress buffer (3 keys + shift)
hid_report:
	db 0, 0, 0, 0, 0, 0	; Shift, 0, key 1, key 2, key 3, 0
hid_lastkey:
	db 0			; Last key code for auto-repeat
hid_repeat:
	db 0
hid_mouse_state:
	db 0			; USB mouse exchange state
hid_mouse_errors:
	db 0			; USB mouse num errors
video_attr:
	db 7

bios_temp:
	dw 0, 0			; temporary data buffer

; Dynamic HDD Parameters (filled by C code)
hdd_lba_supported:
	db 0, 0			; 1 byte per drive (0=Master, 1=Slave)
hdd_logical_cyls:
	dw 0, 0			; 2 bytes per drive
hdd_logical_heads:
	db 0, 0			; 1 byte per drive
hdd_logical_sectors:
	db 0, 0			; 1 byte per drive
fdpt_0:
	times 16 db 0		; INT 41h points here
fdpt_1:
	times 16 db 0		; INT 46h points here

bios_data_end:
