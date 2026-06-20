;
; Based on work by b-dmitry1
; Copyright (c) 2025 b-dmitry1
; Licensed under the MIT License.
;
;
; TODO: 
; - update POST codes
; - fix IDE driver
;

cpu 486

%include "config.inc"


	org 0 ; Real 0xF000:0x0000

[BITS 16]
image_start:

; BIOS parameter block
; Do not move!
%include "data/biosdata.asm"

	align 8

times 0xFA - $ + image_start db 0xFF

; 0xF000:0x00FA - INT15 jmp (F000:F859 jumps to 00FA)
jmp near int15 ; 3 bytes
; 0xF000:0x00FD - VBIOS jmp (F000:F065 jumps to 00FD)
jmp near int10

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Entry point - 0xF000:0x0100
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
start:
	; For real 286+ CS register is normalized here
	; So address will be 0x000F0000 instead of 0xFFFF0000
	nop

	cli
	cld

	mov al, 0x01 ; POST 01 - BIOS execution start
	out 0x80, al

	mov al, 0x00 ; IO port clear
    out 0x61, al

	mov ax, 0x40 ; Setup segments
	mov ds, ax

	; EDX contains CPUID, we should save it somewhere
	; Lets save it at SP - saving it to memory will overwrite it, 
	; and stack cant be used right now as memory is untested
	; We will save it to 0x5F0 after mem test
	mov sp, dx
	

	; Check if this restart is just an exit from protected mode
	; and we need to resume execution of user program
	; mov ax, [pmode_exit_cs]
	; or ax, [pmode_exit_ip]
	; jz normal_restart

	; Zero values or the system will not restart properly
	; mov word [pmode_exit_cs], 0
	; mov word [pmode_exit_ip], 0

	; SKIP PMODE EXIT CHECKS - reset is implemented incorrectly in the M8SBC
	jmp normal_restart

; ======== unused ========
	; Check NVRAM for a protected mode exit flag
	mov al, 0x0F
	out 0x70, al
	jmp $+2
	in al, 0x71
	cmp al, 0x5
	je pmode_exit
	cmp al, 0xA
	jne normal_restart

pmode_exit:
	; Resume execution in real mode	
	push word [pmode_exit_cs]
	push word [pmode_exit_ip]
	retf
; ========================

normal_restart:

	mov al, 0x02 ; POST 02 - Initial PIC setup
	out 0x80, al

	; Set interrupt controller (PICs 8259) registers
%include "drivers/pic.asm"

    ; Warm boot check <- probably currently broken TODO: fix
    mov ax, 0x40
	mov ds, ax
	cmp word [0x0072], 0x1234
	je skip_base_mem_test
	
	mov al, 0x03 ; POST 03 - Base 64K memory test
	out 0x80, al

	; base 64K memory test
	xor ax, ax ; es = 0
	mov es, ax 
    mov ds, ax
%include "drivers/base_memtest.asm"
	mov ax, 0x40 ; Setup segments back
	mov ds, ax

skip_base_mem_test: ; ds is 0x40 in case of skip
	mov dx, sp ; CPUID was stored temporary in SP
	mov ds:[0x1F0], dx ; save CPUID to 0x5F0

	; Setup stack
	xor ax, ax
	mov ss, ax
	mov sp, 0x1000
    
    ; Clear KB controller
    in al, 0x60
    in al, 0x60
    in al, 0x60
    in al, 0x60

	mov al, 0x04 ; POST 04 - BIOS data setup (IVT, BDA)
	out 0x80, al


	; Create an empty interrupt table
	xor ax, ax
	mov ds, ax
	mov es, ax
	xor di, di
	mov cx, 192
erase_ints2:
	mov ax, empty_int
	stosw
	mov ax, cs
	stosw
	loop erase_ints2

	; Fill used vectors
	mov [0x00 * 4], word int00
	mov [0x01 * 4], word int01
	mov [0x02 * 4], word int02
	mov [0x03 * 4], word int03
	mov [0x04 * 4], word int04
	mov [0x05 * 4], word int05
	mov [0x06 * 4], word int06
	mov [0x07 * 4], word int07
	mov [0x08 * 4], word int08
	mov [0x09 * 4], word int09
	mov [0x0A * 4], word empty_hw_int
	mov [0x0B * 4], word empty_hw_int
	mov [0x0C * 4], word int0c
	mov [0x0D * 4], word empty_hw_int
	mov [0x0E * 4], word empty_hw_int
	mov [0x0F * 4], word empty_hw_int
	mov [0x10 * 4], word int10
	mov [0x11 * 4], word int11
	mov [0x12 * 4], word int12
	mov [0x13 * 4], word int13
	mov [0x14 * 4], word int14
	mov [0x15 * 4], word int15
	mov [0x16 * 4], word int16
	mov [0x17 * 4], word int17
	mov [0x19 * 4], word int19
	mov [0x1A * 4], word int1a
	mov [0x1D * 4], word video_init_table
	mov [0x1E * 4], word int1e
	mov [0x41 * 4], word int41

	; Set CGA glyph table address
	mov [0x43 * 4 + 2], word 0xF000
	mov [0x43 * 4], word 0xFA6E

	; Copy BIOS data
	mov ax, 0x0000
	mov es, ax
	mov di, 0x400
	mov ax, cs
	mov ds, ax
	mov si, bios_data
	mov cx, 0x100 + bios_data_end - bios_data + 1
	rep movsb
	
	mov al, 0x05 ; POST 05 - Option ROM detection and execution
	out 0x80, al

	; Check if we have additional BIOS chips
	mov ax, 0x40
	mov ds, ax
	mov word [bios_temp + 2], 0xC000
	mov word [bios_temp], 3
scan_roms:
	mov ax, [bios_temp + 2]
	mov es, ax
	cmp [es:0], word 0xAA55
	jnz no_rom
	call far [bios_temp]
no_rom:
	mov ax, 0x40
	mov ds, ax
	mov ax, 0x1000
	add [bios_temp + 2], ax
	cmp word [bios_temp + 2], 0xF000
	jnz scan_roms

	; int 42h needs to point to int 10h, not F000:F065
	; Handled by vgavector.asm jumping to F000:00FD which jumps to BIOS int 10h
	;xor ax, ax
	;mov ds, ax
	;mov [0x42 * 4], word int10 ; int 42h EGA/VGA/PS - Relocated (by EGA) Video Handler (original INT 10h)
	;mov [0x42 * 4 + 2], word 0xF000

	mov al, 0x06 ; POST 06 - VGA init
	out 0x80, al

	; Set the text mode normal way	
	mov ax, 3
	int 0x10

	; Hide cursor using real mode interface
	mov ah, 01h ; function: Set Cursor Shape
	mov ch, 20h ; Bit 5 set (makes cursor invisible)
	mov cl, 00h
	int 10h

	mov al, 0x07 ; POST 07 - L1 Cache enable
	out 0x80, al

	; Memory test OK, so now we can enable CPU's cache
	call cache_enable

	mov al, 0x08 ; POST 08 - C entry
	out 0x80, al

	; C entry
    ; - switch to protected mode
    ; - init C
    ; - execute main()
    ; - restore real mode and return here
	call 0xF000:0x2000 
    
    mov al, 0x09 ; POST 09 - C execution done, Real mode PIT init
    out 0x80, al

    ; Restore cursor using real mode interface
	mov ah, 0x01    ; Function: Set Cursor Shape
	mov ch, 0x0E    ; Start Scan Line 
	mov cl, 0x0F    ; End Scan 
	int 0x10
    ; Move cursor to 0,6
    mov ah, 0x02
    mov bh, 0x00
    mov dl, 0
    mov dh, 6
    int 0x10

	; Timer 1: 15 us / 0x12
	; We don't need old-style timer DRAM regeneration so will use default value
	mov al, 0x54
	out 0x43, al
	mov al, 0x12
	out 0x41, al
	mov al, 0x00
	out 0x41, al
	mov al, 0x40
	out 0x43, al

	; Timer 2: 1 ms / 0x4A9
	; Can be programmed to 2 or 4 KHz to produce loud beeps
	mov al, 0xB6
	out 0x43, al
	mov al, 0xA9
	out 0x42, al
	mov al, 0x04
	out 0x42, al
	mov al, 0x40
	out 0x43, al

	; Timer 0: 55 ms / 0xFFFF
	; System timer connected to IRQ0
	mov al, 0x36
	out 0x43, al
	mov al, 0
	out 0x40, al
	out 0x40, al
    
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    mov al, 0x0A ; POST 0A - Read boot sector
	out 0x80, al

	mov ax, 0x0000
	mov es, ax

	; If we reached this point -> we have disk and can boot now
	mov si, msg_bootsector
	call putsv

	; Load a very first sector from default boot drive
    ; Note: maybe this should be moved to C code and from there checked if the drive is bootable(?)
	xor ax, ax
	mov es, ax
	mov bx, 0x7C00
	mov ax, 0x201
	mov dx, 0x80 ; boot drive
	mov cx, 1
	int 0x13
    
	xor ax, ax
	mov es, ax
	mov ds, ax

	; Display on screen first bytes and boot signature of the received data
	; If all ok you will see something like FA33C08E...55AA on screen
	; and in the debug console
	mov si, 0x7C00
	lodsb

	call print_hexv
	lodsb
	call print_hexv
	lodsb
	call print_hexv
	lodsb
	call print_hexv
	mov al, '.'
	call putchv
	mov al, '.'
	call putchv
	mov al, '.'
	call putchv
	mov si, 0x7DFE
	lodsb
	call print_hexv
	lodsb
	call print_hexv

	mov si, msg_crlf
	call putsv
    
    mov al, 0x0B ; POST 0B - Enable interrupts leaving
	out 0x80, al

	; Enable interrupts
	mov al, 0x20
	out 0x20, al
	sti
    
    mov al, 0x0B ; POST 0C - Start OS
	out 0x80, al


	; Set general register default values
	xor ax, ax
	xor bx, bx
	xor cx, cx
	mov dx, 0x80	; Boot drive code should be in DL
	xor si, si
	xor di, di
	xor bp, bp

	; Start OS
	jmp (0x0000):0x7C00




; Interrupt return with Z or C flag set/reset
iret_carry_on:
	stc
iret_carry:
	push bp
	mov bp, sp
	jnc iret_carry_off1
	or word [bp+6], 1
	pop bp
	iret
iret_carry_off1:
	and word [bp+6], 0xFFFE
	pop bp
	iret
iret_carry_off:
	clc
	jmp iret_carry

iret_zero:
	push bp
	mov bp, sp
	jnz iret_zero_off1
	or word [bp+6], 0x40
	pop bp
	iret
iret_zero_off1:
	and word [bp+6], 0xFFBF
	pop bp
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

empty_hw_int:
	push ax
	mov al, 0x20
	out 0x20, al
	pop ax
	iret

empty_int:
	iret

%include "isr/traps.asm"

%include "isr/int08_timer.asm"
%include "isr/int09_keyboard.asm"
%include "isr/int0c_comm.asm"
%include "isr/int10_video.asm"
%include "isr/int11.asm"
%include "isr/int12.asm"
%include "isr/int13_disk.asm"
%include "isr/int14_comm.asm"
%include "isr/int15_at.asm"
%include "isr/int16_keyboard.asm"
%include "isr/int17.asm"
%include "isr/int19.asm"
%include "isr/int1a_rtc.asm"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Extra
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "console.asm"
%include "drivers/pcspk.asm"
%include "drivers/cache.asm"

; BIOS messages
msg_reset:
	db "x86 embedded BIOS R3", 13, 10, "github.com/b-dmitry1/BIOS", 13, 10, 0

msg_ok:
	db "OK", 13, 10, 0

msg_crlf:
	db 13, 10, 0

msg_bootsector:
	db "Boot sector: ", 0

msg_failed:
	db 'failed', 0

; Tables
int1e:
	db 0xDF ; Step rate 2ms, head unload time 240ms
	db 0x02 ; Head load time 4 ms, non-DMA mode 0
	db 0x25 ; Byte delay until motor turned off
	db 0x02 ; 512 bytes per sector
floppy_sectors_per_track:
	db 18	; 18 sectors per track (1.44MB)
	db 0x1B ; Gap between sectors for 3.5" floppy
	db 0xFF ; Data length (ignored)
	db 0x54 ; Gap length when formatting
	db 0xF6 ; Format filler byte
	db 0x0F ; Head settle time (1 ms)
	db 0x08 ; Motor start time in 1/8 seconds


video_static_table:
	; https://dos4gw.org/VGA_Static_Functionality_Table
	db 0x7f ; bits 0 .. 7 = modes 00h .. 07h supported
	db 0xff ; bits 0 .. 7 = modes 08h .. 0fh supported
	db 0x0f ; bits 0 .. 3 = modes 10h .. 13h supported
	dd 0 	; IBM reserved
	db 0x07 ; scan lines suppported: bit 0 = 200, 1 = 350, 2 = 400
	db 0x08 ; font blocks available in text mode (4 = EGA, 8 = VGA)
	db 0x02 ; maximum active font blocks in text mode (2 = EGA VGA)
	db 0xfd ; misc support flags
	db 0x08	; misc capabilities (DCC support)
	dw 0x00 ; reserved
	db 0x3C	; save pointer function flags
	db 0x00 ; reserved 

video_init_table:
	; https://dos4gw.org/Video_Initialization_Table
abRegs40x25:
	db 0x39, 0x28, 0x2d, 0x10, 0x1f, 0x06, 0x19, 0x1c, 0x02, 0x07, 0x66, 0x07, 0x00, 0x00, 0x00, 0x00
abRegs80x25:
	db 0x72, 0x50, 0x5a, 0x10, 0x1f, 0x06, 0x19, 0x1c, 0x02, 0x07, 0x66, 0x07, 0x00, 0x00, 0x00, 0x00
abRegsGfx:
	db 0x39, 0x28, 0x2d, 0x10, 0x7f, 0x06, 0x64, 0x70, 0x02, 0x07, 0x06, 0x07, 0x00, 0x00, 0x00, 0x00
abRegsMono:
	db 0x72, 0x50, 0x5a, 0x10, 0x1f, 0x06, 0x19, 0x1c, 0x02, 0x07, 0x06, 0x07, 0x00, 0x00, 0x00, 0x00
	; wSize40x25
	dw 0x3E8
	; wSize80x25
	dw 0x7d0
	; wSizeLoRes
	dw 0x3e80
	; wSizeHiRes
	dw 0x3e80
	; abClmCnts (Text columns in each mode)
	db 0x28, 0x28, 0x50, 0x50, 0x28, 0x28, 0x50, 0x00
	; abModeCodes (port 3d8 values for each mode)
	db 0x0c, 0x08, 0x02, 0x09, 0x0a, 0x0e, 0x1a, 0x00 



; CGA 8x8 font
; Do not move! Need to be placed in 0x1A6E
	times 0x1A6E - $ + image_start db 0x90
	%include "data/cgafont.asm"


int41:
	; Hard disk parameter table
	; Hard-coded to save space
	; 203 * 16 * 63 * 512 = 104767488 bytes = 99.9 MB
hdd_cyls:
	dw HDD_CYLINDERS - 1	; Number of cyls minus 1
hdd_heads:
	db HDD_HEADS - 1	; Number of heads minus 1
	dw 0                    ; Starting reduced-write current cylinder
	dw 0                    ; Starting write precompensation cylinder
	db 0                    ; Maximum ECC data burst length
	db 0xC0                 ; Disable retries (bit 7), Disable ECC (bit 6)
	db 0                    ; Standard timeout value
	db 0                    ; Timeout value for format drive
	db 0                    ; Timeout value for check drive
	dw 0                    ; Reserved
hdd_sectors:
	db HDD_SECTORS		; Sectors per track
	db 0

	; Check BIOS parameter block alignment
%if ((check_size - bios_data) != 0xA8)
%error BIOS parameter block data offset detected!
%endif

; moved to startvector.asm
; 	; Fill unused area with NOPs
; 	times 8192 - 16 - $ + image_start db 0x90

; bootentry:
; 	jmp (0F000h):start
; 	db	"08/29/87"
; 	db	0x00
; 	db	0xFC		; Machine type (XT)
; 	db	0x55		; Checksum
