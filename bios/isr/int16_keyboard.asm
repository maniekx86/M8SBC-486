	; Keyboard

int16:
	push di
	push ds
	mov di, 0x40
	mov ds, di

	cmp ah, 0
	je keyb_get
	cmp ah, 1
	je keyb_peek
	cmp ah, 2
	je keyb_shift

	cmp ah, 0x10
	je keyb_get
	cmp ah, 0x11
	je keyb_peek
	cmp ah, 0x12
	je keyb_shift

	mov ah, 0x86
	xor al, al
	jmp keyb_done

keyb_get:                   ; INT 16 AH=00 is blocking
    sti
.wait_for_key:
    mov ax, [keybuf_tail]
	cmp ax, [keybuf_head]
	jne .read_key           ; there's key in buffer, read it
    hlt                     ; we can halt cpu until we wait for the KB interrupt (interrupt will wake anyway CPU)
    jmp .wait_for_key
    
.read_key:
    cli                     ; ensure buffer isn't accesed while read
	mov ax, [keybuf_tail]
	xor ax, [keybuf_head]
	and ax, 0x1E
	jz keyb_done

	mov di, [keybuf_head]
	mov ax, [di + 0x1E]
	inc di
	inc di
	and di, 0x1E
	mov [keybuf_head], di

	xor di, di
	add di, 1
	jmp keyb_done

keyb_peek:
    cli                     ; ensure buffer isn't accesed while read
	mov ax, [keybuf_tail]
	xor ax, [keybuf_head]
	and ax, 0x1E
	jz keyb_done

	mov di, [keybuf_head]
	mov ax, [di + 0x1E]

	xor di, di
	add di, 1
	jmp keyb_done

keyb_shift:
	mov ax, [keyboard_flags]
	jmp keyb_done

keyb_done:
	pop ds
	pop di
	jmp iret_zero
