; Shift / special key status codes
%define KEYB_FLAGS_INS_DN	0x8000
%define KEYB_FLAGS_CAPS_DN	0x4000
%define KEYB_FLAGS_NUM_DN	0x2000
%define KEYB_FLAGS_SCRL_DN	0x1000
%define KEYB_FLAGS_PAUSE_DN	0x0800
%define KEYB_FLAGS_SYSRQ_DN	0x0400
%define KEYB_FLAGS_LEFT_ALT_DN	0x0200
%define KEYB_FLAGS_RIGHT_ALT_DN	0x0100
%define KEYB_FLAGS_INS		0x0080
%define KEYB_FLAGS_CAPS		0x0040
%define KEYB_FLAGS_NUM		0x0020
%define KEYB_FLAGS_SCRL		0x0010
%define KEYB_FLAGS_ALT		0x0008
%define KEYB_FLAGS_CTRL		0x0004
%define KEYB_FLAGS_LEFT_SHIFT	0x0002
%define KEYB_FLAGS_RIGHT_SHIFT	0x0001

	; Keyboard

int09:
	push ax
	push bx 
	push cx
	push si
	push ds

	mov ax, 0x40
	mov ds, ax

	; Get XT char code
	; FPGA keyboard controller must convert PS/2 or USB code to XT code
	in al, 0x60
	mov ah, al

	; Tell keyboard controller that we are ready for the next one
	in al, 0x61
	or al, 0x80
	out 0x61, al
	and al, 0x7F
	out 0x61, al

	mov al, ah

	; Extended code
	cmp ah, 0xE0
	jne .check_e0_state
	mov byte [0x0096], 1       ; Save extended code flag in BDA (0x0496)
	jmp int09_done

.check_e0_state:
	mov cl, [0x0096]           ; Load the E0 flag into CL
	mov byte [0x0096], 0       ; and clear it from memory
    
    ; Test for modifier keys
	cmp ah, 0x2A
	je int09_lshift
	cmp ah, 0x36
	je int09_rshift
	cmp ah, 0x1D
	je int09_ctrl
	cmp ah, 0x38
    
    ; Test for modifier keys releases
	je int09_alt
	cmp ah, 0xAA
	je int09_lshift_up
	cmp ah, 0xB6
	je int09_rshift_up
	cmp ah, 0x9D
	je int09_ctrl_up
	cmp ah, 0xB8
	je int09_alt_up
    
    ; Test for toggle keys (Capslock, Numlock, Scrolllock)
	cmp ah, 0x3A
	je int09_caps
	cmp ah, 0x45
	je int09_num
	cmp ah, 0x46
	je int09_scroll

	; Test for general release
	test al, 0x80
	jnz int09_done
    
    

	mov si, ax
	and si, 0x7F
    
    ; -- CTRL+ALT+DEL check and reset
    cmp ah, 0x53               ; Is scancode DEL?
	jne .not_ctrlaltdel
	mov bl, [keyboard_flags]
	and bl, 0x0C               ; Mask CTRL (0x04) and ALT (0x08)
	cmp bl, 0x0C               ; Are both active?
	jne .not_ctrlaltdel
    ; Warm boot
    mov word [0x72], 0x1234    ; Set BDA warm boot flag at 0x0472
.wait_kbd: ; Reset by pulsing reset
    in al, 0x60                ; Clear junk if theres any in the KBC (OBF might block IBF)
	in al, 0x64
	test al, 0x02              ; Wait for IBF to be clear
	jnz .wait_kbd
	mov al, 0xFE               ; Command: pulse line (reset)
	out 0x64, al
    cli
	hlt
    jmp $
	
.not_ctrlaltdel:

	; -- Convert to ASCII
	mov al, [keyboard_flags]
	test al, 0x08           ; Check alt
	jnz int09_use_alt
	
	test al, 0x04           ; Check ctrl
	jnz int09_use_ctrl
	
	test al, 0x03           ; Check shift (left or right)
	jnz int09_use_shift

	add si, ascii_normal ; -- Normal table lookup
do_xlat:                
	mov al, [cs:si]
	
	; -- Numpad logic (check before caps so it can override ASCII if needed)
	cmp ah, 0x47
	jb .check_caps
	cmp ah, 0x53
	ja .check_caps
    
    test cl, 1                 ; was there prefix 0xE0? (dedicated nav key)
	jnz .force_nav             ; if yes, skip numlock and force that nav key
	
	mov bl, [keyboard_flags]
	test bl, KEYB_FLAGS_NUM    ; Numlock on?
	jnz .check_caps            ; If yes, keep ASCII and proceed
    
.force_nav:
	xor al, al                 ; If not, these are navigation keys, wipe ASCII to 0
	jmp int09_ok               ; Skip capslock check for Numpad keys

.check_caps:
	; -- Capslock logic
	mov bl, [keyboard_flags]
	test bl, KEYB_FLAGS_CAPS
	jz int09_ok                ; skip toggle, capslock off
	
	; Check if character is a letter
	cmp al, 'A'
	jb int09_ok
	cmp al, 'z'
	ja int09_ok
	cmp al, 'Z'
	jbe .toggle_case
	cmp al, 'a'
	jb int09_ok
    ; note: above checks must fall into toggle_case as the key is a letter here
.toggle_case:
	xor al, 0x20            ; flip the 6th bit to swap upper/lower case
	jmp int09_ok


int09_use_alt:
    xor al, al              ; skip lookup, alt keys return 0
    jmp int09_ok

int09_use_ctrl:
	add si, ascii_ctrl
	jmp do_xlat

int09_use_shift:
	add si, ascii_shift
	jmp do_xlat


ascii_normal:
	db 0, 27, "1234567890-=", 8, 9
	db "qwertyuiop[]", 13, 0, "as"
	db "dfghjkl;'`", 0, "\zxcv"         ; A2.02: ` swapped with ~ for standard layout
	db "bnm,./", 0, "*", 0, " "
	db 0                                ; 0x3A Capslock
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0     ; 0x3B-0x44 F1-F10
	db 0, 0                             ; 0x45-0x46 Numlock/Scrolllock
	db "789-456+1230."                  ; 0x47-0x53 Numpad keys
	times 128 - ($ - ascii_normal) db 0 

ascii_shift:
	db 0, 27, "!@#$%^&*()_+", 8, 9
	db "QWERTYUIOP{}", 13, 0, "AS"
	db "DFGHJKL:", 34, "~", 0, "|ZXCV"
	db "BNM<>?", 0, "*", 0, " "
	db 0                                ; Capslock
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0     ; F1-F10
	db 0, 0                             ; Numlock/Scrolllock
	db "789-456+1230."                  ; Shift usually forces numbers on numpad(?)
	times 128 - ($ - ascii_shift) db 0
    

ascii_ctrl:
	;   0  Esc  1  2  3  4  5  6  7  8  9  0  -  =  BS Tab
	db  0, 27,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 0
	;   q   w   e   r   t   y   u   i   o   p   [   ]  CR
	db  17, 23, 5,  18, 20, 25, 21, 9,  15, 16, 27, 29, 10, 0
	;   a   s   d   f   g   h   j   k   l   ;   '   `
	db  1,  19, 4,  6,  7,  8,  10, 11, 12, 0,  0,  0,  0
	;   \   z   x   c   v   b   n   m   ,   .   /
	db  28, 26, 24, 3,  22, 2,  14, 13, 0,  0,  0,  0,  0
	;   *       Spc
	db  0,  0,  32, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0
	db  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
    times 128 - ($ - ascii_ctrl) db 0


int09_ok:
	; Write char to keyboard buffer
	mov si, [keybuf_tail]
	mov [si + 0x1E], ax
	inc si
	inc si
	and si, 0x1E
	mov [keybuf_tail], si

	cmp [keybuf_head], si
	jne int09_done

	; Buffer overflow -> remove 1 char
	mov si, [keybuf_head]
	inc si
	inc si
	and si, 0x1E
	mov [keybuf_head], si

	; TODO: add beep here

int09_done:
	; End of interrupt
	mov al, 0x20
	out 0x20, al

	pop ds
	pop si
	pop cx
	pop bx
	pop ax
	iret

	; Shift keys pressed / released
int09_lshift:
	mov si, [keyboard_flags]
	or si, KEYB_FLAGS_LEFT_SHIFT ; 0x0001
	mov [keyboard_flags], si
	jmp int09_done
int09_rshift:
	mov si, [keyboard_flags]
	or si, KEYB_FLAGS_RIGHT_SHIFT ; 0x0002
	mov [keyboard_flags], si
	jmp int09_done
int09_ctrl:
	mov si, [keyboard_flags]
	or si, KEYB_FLAGS_CTRL ; 0x0004
	mov [keyboard_flags], si
	jmp int09_done
int09_alt:
	mov si, [keyboard_flags]
	or si, KEYB_FLAGS_ALT ; 0x0008
	mov [keyboard_flags], si
	jmp int09_done
int09_lshift_up:
	mov si, [keyboard_flags]
	and si, ~KEYB_FLAGS_LEFT_SHIFT ; 0xFFFE
	mov [keyboard_flags], si
	jmp int09_done
int09_rshift_up:
	mov si, [keyboard_flags]
	and si, ~KEYB_FLAGS_RIGHT_SHIFT ; 0xFFFD
	mov [keyboard_flags], si
	jmp int09_done
int09_ctrl_up:
	mov si, [keyboard_flags]
	and si, ~KEYB_FLAGS_CTRL ; 0xFFFB
	mov [keyboard_flags], si
	jmp int09_done
int09_alt_up:
	mov si, [keyboard_flags]
	and si, ~KEYB_FLAGS_ALT ; 0xFFF7
	mov [keyboard_flags], si
	jmp int09_done
    
    
    
    
    
    
    
    ; Toggle key handlers and LEDs
    
int09_caps:
	test al, 0x80            ; Ignore release code
	jnz int09_done
	mov si, [keyboard_flags]
	xor si, KEYB_FLAGS_CAPS  ; Toggle bit
	mov [keyboard_flags], si
	call update_leds
	jmp int09_done

int09_num:
	test al, 0x80
	jnz int09_done
	mov si, [keyboard_flags]
	xor si, KEYB_FLAGS_NUM
	mov [keyboard_flags], si
	call update_leds
	jmp int09_done

int09_scroll:
	test al, 0x80
	jnz int09_done
	mov si, [keyboard_flags]
	xor si, KEYB_FLAGS_SCRL
	mov [keyboard_flags], si
	call update_leds
	jmp int09_done
    
    ; LEDs
update_leds:
	; Keyboard status byte is mapped perfectly for a bit shift
	; CAPS=Bit 6, NUM=Bit 5, SCRL=Bit 4 and
    ; 8042 expects: CAPS=Bit 2, NUM=Bit 1, SCRL=Bit 0.
	mov ax, [keyboard_flags]
	mov cl, 4
	shr al, cl
	and al, 0x07             ; AL now contains the exact byte needed for port 60h

	push ax                  ; Save LED byte

	; Wait for keyboard controller input buffer to empty
.wait1:
	in al, 0x64
	test al, 0x02
	jnz .wait1

	mov al, 0xED             ; LED CMD
	out 0x60, al

.wait2:
	in al, 0x64
	test al, 0x02
	jnz .wait2

	pop ax                   ; Restore LED byte
	out 0x60, al             ; Send states
	
	ret
