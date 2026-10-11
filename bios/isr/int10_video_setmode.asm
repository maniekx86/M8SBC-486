
%include "data/video_init.asm"

; TODO: Add Bochs's specific values to replace their own VGA BIOS

; write_regs
; Writes default values to a graphic registers
; In:
;   DX = index register port
;   CS:SI = table address
;   CX = number of bytes
;   AL = start reg
write_regs:
	mov ah, [cs:si]
	out dx, ax
	inc al
	add si, VIDEO_TABLE_COLS
	loop write_regs
	ret

; calc_video_table_column
; Calculates the column number of init tables
; In:
;   AL = video mode
; Out:
;   BX = table column
calc_video_table_column:
	xor bh, bh
	mov bl, al
	cmp al, 6
	jle calc_video_table_column_done
	mov bl, 7
	cmp al, 0x0D
	je calc_video_table_column_done
	inc bl
	cmp al, 0x0E
	je calc_video_table_column_done
	inc bl
	cmp al, 0x10
	je calc_video_table_column_done
	inc bl
	cmp al, 0x12
	je calc_video_table_column_done
	inc bl	

calc_video_table_column_done:
	ret

load_font:
	mov dx, 0x3c4
	mov ax, 0x0100 ; SQ00: reset
	out dx, ax
	mov ax, 0x0402 ; SQ02: plane 2
	out dx, ax
	mov ax, 0x0704 ; SQ04: disable chain-4
	out dx, ax
	mov ax, 0x0300 ; SQ00: end reset
	out dx, ax

	mov dx, 0x3ce
	mov ax, 0x0204 ; GC04: plane 2
	out dx, ax
	mov ax, 0x0005 ; GC05: disable odd/even
	out dx, ax
	mov ax, 0x0006 ; GC06: 0xA0000
	out dx, ax

	push es
	push ds
	mov ax, 0xA000
	mov es, ax
	xor di, di
	mov ax, cs
	mov ds, ax
	mov si, cga_font
	mov cx, 128
load_font_loop:
	push cx
	mov cx, 8
load_font_loop1:
	lodsb
	stosb
	stosb	   ; Convert 8x8 to 8x16
	loop load_font_loop1
	mov cx, 16
	xor al, al
	rep stosb  ; Zero next 16 bytes
	pop cx
	loop load_font_loop
	pop ds
	pop es

	mov dx, 0x3c4
	mov ax, 0x0100 ; SQ00: reset
	out dx, ax
	mov ax, 0x0302 ; SQ02: planes 0 and 1
	out dx, ax
	mov ax, 0x0304 ; SQ04: restore odd/even
	out dx, ax
	mov ax, 0x0300 ; SQ00: end reset
	out dx, ax

	mov dx, 0x3ce
	mov ax, 0x0004 ; GC04: plane 0
	out dx, ax
	mov ax, 0x1005 ; GC05: restore odd/even
	out dx, ax
	mov ax, 0x0E06 ; GC06: 0xB8000
	out dx, ax

	ret

; write_regs
; Writes default values from mode tables
; In:
;   BX = init table column
init_vga_regs:
	; Misc output
	mov dx, 0x3c2
	mov al, 0x63
	out dx, al

	; Sequence controller
	mov si, bx
	add si, seq_table
	mov dx, 0x3c4
	mov cx, 5
	xor al, al
	call write_regs

	; CRT registers
	mov dx, 0x3d4
	mov al, 0x11
	out dx, al
	inc dx
	xor al, al
	out dx, al	; Remove write protection
	dec dx
	mov si, bx
	add si, crt_table
	mov cx, 25
	xor al, al
	call write_regs
	
	; Graphic controller
	mov si, bx
	add si, gc_table
	mov dx, 0x3ce
	mov cx, 9
	xor al, al
	call write_regs

	; Attribute controller	
	; Switch port 0x3C0 to address mode
	mov dx, 0x3DA
	in al, dx

	mov si, bx
	add si, ac_table
	mov cx, 21
	mov dx, 0x3c0
	xor al, al
init_vga_regs_ac:
	; Index
	out dx, al
	mov ah, [cs:si]
	add si, VIDEO_TABLE_COLS
	xchg al, ah
	; Value
	out dx, al
	xchg al, ah
	inc al
	loop init_vga_regs_ac

	cmp byte [video_mode], 3
	jg done_load_font
	call load_font
done_load_font:

	; Enable video, 80x25
	mov dx, 0x3d8
	mov al, 9
	out dx, al
	
	; CGA palette
	mov dx, 0x3d9
	mov al, 7
	out dx, al

	; Switch port 0x3C0 to address mode
	mov dx, 0x3DA
	in al, dx

	; Lock 16-color palette
	mov dx, 0x3c0
	mov al, 0x20
	out dx, al

	; Enable blink, video, hi-res
	mov dx, 0x3b8
	mov al, 0x29
	out dx, al

	ret

clear_framebuffer:
	mov al, [video_mode]
	test al, 0x80
	jnz clear_framebuffer_done
	mov ax, 0xA000
	mov es, ax
	xor di, di
	mov cx, 32768
	xor ax, ax
	rep stosw
	mov ax, 0xB000
	mov es, ax
	xor di, di
	mov cx, 32768
	mov ax, 0x720
	cmp byte [video_mode], 3
	jle fill_7
	xor ax, ax
fill_7:
	rep stosw
clear_framebuffer_done:
	ret

colors:
	db 0, 0, 0
	db 0, 0, 42
	db 0, 42, 0
	db 0, 42, 42
	db 42, 0, 0
	db 42, 0, 42
	db 42, 21, 0
	db 42, 42, 42
	db 21, 21, 21
	db 21, 21, 63
	db 21, 63, 21
	db 21, 63, 63
	db 63, 21, 21
	db 63, 21, 63
	db 63, 63, 21
	db 63, 63, 63

set_video_mode:
	push ax
	push bx
	push cx
	push dx

	mov [video_mode], al
	and al, 0x7F


	call calc_video_table_column

	; Configure graphics controller
	call init_vga_regs

	; Write default BIOS values
	mov byte [video_attr], 7
	mov [video_page], byte 0
	mov [cursor_pos], word 0
	mov [cursor_pos + 2], word 0
	mov [cursor_pos + 4], word 0
	mov [cursor_pos + 6], word 0
	mov [cursor_pos + 8], word 0
	mov [cursor_pos + 10], word 0
	mov [cursor_pos + 12], word 0
	mov [cursor_pos + 14], word 0
	mov [cursor_lines], byte 6
	mov [cursor_lines + 1], byte 7
	mov [video_rows], byte 24
	mov [video_regen_size], word 0x4000

	; Get Chars per line
	mov si, bx
	add si, video_cols
	mov al, [cs:si]
	xor ah, ah
	mov [chars_per_line], ax

	; Set default palette
	mov dx, 0x3c6
	mov al, 0xFF
	out dx, al
	mov dx, 0x3c8
	xor al, al
	out dx, al
	inc dx
	mov cx, 48
	mov si, colors
defaultpalette:
	mov al, [cs:si]
	inc si
	out dx, al
	loop defaultpalette

	call clear_framebuffer

	mov al, [video_mode]
	and al, 0x7F
	mov [video_mode], al

	pop dx
	pop cx
	pop bx
	pop ax	

	jmp int10_done
