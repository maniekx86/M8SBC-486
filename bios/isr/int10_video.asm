; Compact video BIOS
;

int10:
	push ds
	push es
	push si
	push di

	cld

	push dx
	mov dx, 0x40
	mov ds, dx
	pop dx

	; SVGA functions
	cmp ah, 0x4F
	je int10_svga

	; Graphics / video functions
	cmp ah, 0x1B
	je int10_get_state_info


	cmp ax, 0x1000
	je int10_ega_set_palette
	cmp ax, 0x1002
	je int10_ega_set_all_palette
	cmp ax, 0x1012
	je int10_vga_set_all_palette

	push dx
	mov dx, 0xB800
	mov es, dx
	pop dx

	cmp ah, 0
	je set_video_mode
	cmp ah, 0x0B
	je cga_palette
	cmp ah, 0x0F
	je get_video_mode
	cmp ah, 0x12
	je int10_ega_12
	cmp ah, 0x1A
	je int10_video_combination

	cmp ah, 1
	je set_cursor_type
	cmp ah, 2
	je set_cursor_pos
	cmp ah, 3
	je get_cursor_pos
	cmp ah, 5
	je set_video_page

	cmp ah, 0x0E
	je putch_tty

	cmp byte [video_mode], 3
	jg int10_done_no_update

	; Text mode only functions
	cmp ah, 6
	je int10_scroll_up
	cmp ah, 7
	je int10_scroll_down
	cmp ah, 8
	je readch
	cmp ah, 9
	je putcha
	cmp ah, 0x0A
	je putch

	jmp int10_done_no_update

int10_done:
	push ax
	push bx
	push dx
	mov dx, 0x40
	mov ds, dx

	mov al, [cursor_pos + 1]
	mov ah, [chars_per_line]
	mul ah
	mov dl, [cursor_pos]
	xor dh, dh
	add ax, dx
	mov bx, ax

	mov dx, 0x3D4
	mov al, 0x0E
	out dx, al
	inc dx
	mov al, bh
	out dx, al
	dec dx
	mov al, 0x0F
	out dx, al
	inc dx
	mov al, bl
	out dx, al
	pop dx
	pop bx
	pop ax

int10_done_no_update:
	pop di
	pop si
	pop es
	pop ds
	iret

%include "isr/int10_video_setmode.asm"

%include "isr/int10_video_text.asm"

int10_ega_12:
	cmp bl, 0x10
	je int10_ega_12_getinfo

	jmp int10_done_no_update

int10_ega_12_getinfo:
	mov bx, 3
	mov cx, 0
	jmp int10_done_no_update

int10_ega_set_palette:
	push ax
	push dx
	mov dx, 0x3DA
	in al, dx
	xor ax, ax
	mov dx, 0x3C0
	mov al, bl
	out dx, al
	mov al, bh
	out dx, al
int10_ega_set_palette_done:
	pop dx
	pop ax
	jmp int10_done_no_update

; ES:DX = palette + border color
int10_ega_set_all_palette:
	push ax
	push cx
	push dx
	push si
	mov si, dx
	mov dx, 0x3DA
	in al, dx
	xor al, al
	mov dx, 0x3C0
	xor ax, ax
	mov cx, 17
int10_ega_set_all_palette_1:
	mov al, ah
	out dx, al
	inc ah
	mov al, [es:si]
	out dx, al
	inc si
	loop int10_ega_set_all_palette_1
	pop si
	pop dx
	pop cx
	pop ax
	jmp int10_done_no_update

; bx = first reg
; cx = num regs
; es:dx = table address
int10_vga_set_all_palette:
	push bx
	push cx
	push dx
	push si
	mov si, dx
	mov dx, 0x3C8
	mov al, bl
	out dx, al
	inc dx
int10_vga_set_all_palette_loop:
	mov al, [es:si]
	out dx, al
	inc si
	mov al, [es:si]
	out dx, al
	inc si
	mov al, [es:si]
	out dx, al
	inc si
	loop int10_vga_set_all_palette_loop
	pop si
	pop dx
	pop cx
	pop ax
	jmp int10_done_no_update


readch:
	cmp byte [video_mode], 3
	jg readch_graphic
	push dx
	push di

	mov al, [cursor_pos + 1]
	mov ah, [chars_per_line]
	mul ah
	mov dl, [cursor_pos]
	xor dh, dh
	add ax, dx
	shl ax, 1
	mov di, ax
	mov ax, [es:di]
	pop di
	pop dx
	mov bh, [video_page]
	jmp int10_done_no_update

readch_graphic:
	jmp int10_done_no_update

get_video_mode:
	mov ah, [chars_per_line]
	mov al, [video_mode]
	and al, 0x7F
	mov bh, [video_page]
	jmp int10_done

set_cursor_type:
	mov [cursor_lines], cx
	jmp int10_done_no_update

set_cursor_pos:
	mov [video_page], bh		; Page
	mov [cursor_pos], dl		; Cursor pos
	mov [cursor_pos + 1], dh
	jmp int10_done

get_cursor_pos:
	mov bh, [video_page]
	mov cl, [cursor_lines]
	mov ch, [cursor_lines + 1]
	mov dl, [cursor_pos]
	mov dh, [cursor_pos + 1]
	jmp int10_done_no_update

set_video_page:
	mov [video_page], al
	jmp int10_done

cga_palette:
	push ax
	push bx
	push dx
	cmp bh, 1
	jne cga_palette_done

	and bl, 0x01
	shl bl, 1
	shl bl, 1
	shl bl, 1
	shl bl, 1
	shl bl, 1
	mov al, bl
	mov dx, 0x3D9
	out dx, al

	; VGA translates CGA palette to 256-color table
	inc dx
	in al, dx       ; switch AC to index
	mov dl, 0xc0
	or bl, bl
	jz cga_palette_0
	mov al, 1       ; cyan-magenta-white
	out dx, al
	mov al, 3
	out dx, al
	mov al, 2
	out dx, al
	mov al, 5
	out dx, al
	mov al, 3
	out dx, al
	mov al, 7
	out dx, al
	jmp cga_palette_done
cga_palette_0:
	mov al, 1       ; green-red-yellow
	out dx, al
	mov al, 10
	out dx, al
	mov al, 2
	out dx, al
	mov al, 12
	out dx, al
	mov al, 3
	out dx, al
	mov al, 14
	out dx, al
cga_palette_done:
	mov al, 0x20
	out dx, al
	pop dx
	pop bx
	pop ax
	jmp int10_done

int10_video_combination:
	cmp al, 0
	jne int10_video_combination_done
	
	; AL = 0: Get Video Combination	
	mov bl, 0x08	; VGA analog color display
	mov bh, 0	; No inactive display
	mov al, 0x1a	; Status "OK"
	
int10_video_combination_done:
	jmp int10_done_no_update


; int10_get_state_info
; In:
;   ES, DI = address of buffer for VGADynamicState
;   BX = 0
; Out:
;   AL = 0x1B
int10_get_state_info:
	push ax
	push cx
	push di
	push si
	push ds

	mov ax, 0x40
	mov ds, ax

	; Clear 64 bytes of data
	push di
	mov cx, 32
	xor ax, ax
	rep stosw
	pop di

	; 0 - address 
	mov word [es:di], video_static_table
	mov word [es:di + 2], 0xf000

	; Copy 30 bytes from bios data area
	push di
	add di, 4
	mov si, video_mode
	mov cx, 30
	rep movsb
	pop di

	mov al, [video_rows]
	mov byte [es:di + 34], al
	mov word [es:di + 35], 8	; Font 8 dots
	mov byte [es:di + 37], 0x08	; Display combination code (VGA analog color)
	;mov byte [es:di + 38], 0x00	; Display combination code inactive display code
	mov word [es:di + 39], 256	; Number of colors in active video mode

	mov byte [es:di + 41], 8	; Number of pages in active video mode

	mov byte [es:di + 42], 0	; Number of scan lines: 0 = 200, 1 = 350, 2 = 400, 3 = 480
	mov byte [es:di + 45], 0x01	; Bit 0 - all modes on all active displays active, 1 - grayscale, 2 - mono,
					; 3 - no default palette, 4 - cursor emulation enabled,
					; 5 - cursor blinking
	;mov byte [es:di + 46], 0x00	; Reserved
	;mov byte [es:di + 47], 0x00	; Reserved
	;mov byte [es:di + 48], 0x00	; Reserved
	mov byte [es:di + 49], 0x03	; Video RAM: 3 - 256KB
	mov byte [es:di + 50], 0x1C	; Text font override, graphic font override, palette override
	
	pop ds
	pop si
	pop di
	pop cx
	pop ax
	mov al, 0x1b
	jmp int10_done_no_update

%include "isr/int10_video_svga.asm"
