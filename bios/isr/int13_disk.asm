; Disk BIOS (INT 13h)
; Supports master (DL=80h) and slave (DL=81h) hard drives
; Functions: 00-04, 08, 10, 15, 41-43
%include "drivers/ide.asm"

; swap_dl - Translate DL between 0x80 and 0x81 if Slave is first boot drive
; In/Out: DL (swapped in-place if CMOS bit 3 is set and DL is 0x80 or 0x81)
; Preserves all other registers
swap_dl:
	cmp dl, 0x80
	jb .no_swap
	cmp dl, 0x81
	ja .no_swap
	push ax
	mov al, 0x40
	out 0x70, al
	in al, 0x71
	test al, 0b00001000
	pop ax
	jz .no_swap
	xor dl, 1
.no_swap:
	ret

int13:
	; Set interrupt flag in caller's saved flags so IRET
	; re-enables interrupts (INT instruction clears IF)
	push bp
	mov bp, sp
	or word [bp+6], 0x0200
	pop bp
	cld
	call swap_dl        ; swap logical to physical drive at entry
	; Functions that handle drive validation internally
	; (floppy support, custom checks, etc.)
	cmp ah, 0x01
	je int13_get_last_error
	cmp ah, 0x08
	je int13_get_params
	cmp ah, 0x15
	je int13_get_type
	cmp ah, 0x41
	je int13_func41
	; All remaining functions require DL = 0x80 or 0x81
	cmp dl, 0x80
	jb int13_not_ready
	cmp dl, 0x81
	ja int13_not_ready
	cmp ah, 0x00
	je int13_reset
	cmp ah, 0x02
	je int13_read
	cmp ah, 0x03
	je int13_write
	cmp ah, 0x04
	je int13_reset		; verify = success
	cmp ah, 0x10
	je int13_reset		; ready = success
	cmp ah, 0x42
	je int13_func42
	cmp ah, 0x43
	je int13_func43
	jmp int13_no_command
;----------------------------------------------------------------------
; Status/result helpers
; All paths converge to int13_return which updates BDA and exits
;----------------------------------------------------------------------
; Common return: set disk_error in BDA, set CF based on AH
; In: AH = error code (0 = success)
; Preserves all other registers
int13_return:
	push ds
	push bx
	mov bx, 0x40
	mov ds, bx
	mov [disk_error], ah
	pop bx
	pop ds
	call swap_dl        ; unswap physical back to logical drive
	or ah, ah
	jnz .error
	clc
	jmp iret_carry
.error:
	stc
	jmp iret_carry

int13_exit_carry:
	pushf
	call swap_dl        ; unswap physical back to logical drive
	popf
	jmp iret_carry

int13_success:
	mov ah, 0
	jmp int13_return
int13_not_ready:
	mov ah, 0xAA
	jmp int13_return
int13_no_command:
	mov ah, 0x01
	jmp int13_return
int13_no_drive:
	mov ah, 15
	jmp int13_return
int13_rw_error:
	mov ah, 0x04		; sector not found / read error
	jmp int13_return
;----------------------------------------------------------------------
; AH=00h - Reset disk system
;----------------------------------------------------------------------
int13_reset:
	jmp int13_success
;----------------------------------------------------------------------
; AH=01h - Get status of last operation
; Out: AH = last error code, CF = clear
;----------------------------------------------------------------------
int13_get_last_error:
	push ds
	push ax
	mov ax, 0x40
	mov ds, ax
	pop ax
	mov ah, [disk_error]
	pop ds
	clc
	jmp int13_exit_carry
;----------------------------------------------------------------------
; AH=02h - Read sectors (CHS)
; In: AL=count, CH=cyl, CL=sect, DH=head, DL=drive, ES:BX=buffer
;----------------------------------------------------------------------
int13_read:
	cmp al, 0
	jne .check_done
	mov al, 1
.check_done:
	push ax
	push bx
	push cx
	push dx
	call ide_read
	pop dx
	pop cx
	pop bx
	pop ax
	jc int13_rw_error
	jmp int13_success
;----------------------------------------------------------------------
; AH=03h - Write sectors (CHS)
; In: AL=count, CH=cyl, CL=sect, DH=head, DL=drive, ES:BX=buffer
;----------------------------------------------------------------------
int13_write:
	cmp al, 0
	jne .check_done
	mov al, 1
.check_done:
	push ax
	push bx
	push cx
	push dx
	call ide_write
	pop dx
	pop cx
	pop bx
	pop ax
	jc int13_rw_error
	jmp int13_success
;----------------------------------------------------------------------
; AH=04h - Verify sectors (no-op, always succeeds)
;----------------------------------------------------------------------
;----------------------------------------------------------------------
; AH=08h - Get drive parameters
;----------------------------------------------------------------------
int13_get_params:
	cmp dl, 0
	je int13_08_floppy
	cmp dl, 0x80
	jb int13_no_drive
	cmp dl, 0x81
	ja int13_no_drive
	push ds
	push si
	mov ax, 0x40
	mov ds, ax
	mov al, dl
	and al, 1
	xor ah, ah
	mov si, ax
	add si, si
	mov ax, [0xC5 + si] ; logical cyls
	test ax, ax
	jz .no_drive_pop
	dec ax              ; max cyls (0-based)
	mov ch, al          ; CH = low 8 bits of cyl
	mov cl, ah          ; CL = high 8 bits
	shl cl, 6           ; CL = high bits in 7:6
	shr si, 1           ; si = drive index (0 or 1)
	mov dh, [0xC9 + si] ; dh = logical heads
	dec dh              ; max head
	or cl, [0xCB + si]  ; CL |= logical sectors
	mov dl, [num_hdd]
	mov bl, 0           ; drive type
	pop si
	pop ds
	jmp int13_success
.no_drive_pop:
	pop si
	pop ds
	jmp int13_no_drive
int13_08_floppy:
	mov ax, cs
	mov es, ax
	mov di, dbt_floppy
	xor ax, ax
	mov bx, 4
	mov dl, 1
	mov dh, 1
	mov ch, 79
	mov cl, 18
	jmp int13_success
dbt_floppy:
	db 1, 1, 1, 2, 18, 1, 2, 1, 0xff, 1, 1
;----------------------------------------------------------------------
; AH=15h - Get drive type
; Out: AH=type (1=floppy, 3=fixed), CX:DX=sector count (fixed only)
;----------------------------------------------------------------------
int13_get_type:
	cmp dl, 0
	je .floppy
	cmp dl, 0x80
	jb int13_no_drive
	cmp dl, 0x81
	ja int13_no_drive
	push bx
	push ds
	push si
	mov ax, 0x40
	mov ds, ax
	mov al, dl
	and al, 1
	xor ah, ah
	mov si, ax
	add si, si
	mov ax, [0xC5 + si]   ; cyls
	shr si, 1
	mov bl, [0xC9 + si]   ; heads
	xor bh, bh
	mul bx
	mov bl, [0xCB + si]   ; sectors
	mul bx                ; dx:ax = total sectors
	mov cx, dx
	mov dx, ax
	pop si
	pop ds
	pop bx
	mov ah, 3		; fixed disk
	clc
	jmp int13_exit_carry
.floppy:
	mov ah, 1		; floppy without change detection
	clc
	jmp int13_exit_carry
;----------------------------------------------------------------------
; AH=41h - Check INT 13h Extensions present
; Out: AH=21h (version), BX=AA55h, CX=1 (packet access), CF=0
;----------------------------------------------------------------------
int13_func41:
	call ide_check_lba
	jc int13_not_ready
	; AH=21h, BX=AA55h, CX=1 already set by ide_check_lba
	clc
	jmp int13_exit_carry
;----------------------------------------------------------------------
; AH=42h - Extended Read Sectors (LBA)
; In: DL=drive, DS:SI=DAP
;----------------------------------------------------------------------
int13_func42:
	call ide_read_lba
	jc int13_rw_error
	jmp int13_success
;----------------------------------------------------------------------
; AH=43h - Extended Write Sectors (LBA)
; In: DL=drive, DS:SI=DAP
;----------------------------------------------------------------------
int13_func43:
	call ide_write_lba
	jc int13_rw_error
	jmp int13_success

