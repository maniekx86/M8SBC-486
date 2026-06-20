; Disk BIOS
; TO DO: Slave disk support and floppy?

%include "drivers/ide.asm"


int13:
	; Set interrupt flag to make MS-DOS work
	push bp
	mov bp, sp
	or word [bp+6], 0x0200
	pop bp

	cld

	cmp ah, 0
	je int13_reset
	cmp ah, 1
	;je int13_get_last_error
	cmp ah, 2
	je int13_read
	cmp ah, 3
	je int13_write

	cmp ah, 4
	; je int13_verify
	cmp ah, 8
	je int13_get_params
	cmp ah, 0x10
	; je int13_10
	cmp ah, 0x15
	; je int13_get_type

	; AH = 41h - Get Extended Drive Parameters
    cmp ah, 0x41
    je int13_func41
    ; AH = 42h - Extended Read Sectors From Drive (LBA)
    cmp ah, 0x42
    je int13_func42

	jmp int13_no_command

int13_success:
	push ax
	push ds
	mov ax, 0x40
	mov ds, ax
	mov [disk_error], byte 0
	pop ds
	pop ax
	mov ah, 0
	clc
	jmp iret_carry

int13_not_ready:
	push ax
	push ds
	mov ax, 0x40
	mov ds, ax
	mov [disk_error], byte 0xAA
	pop ds
	pop ax
	mov ah, 0xAA
	stc
	jmp iret_carry

int13_no_command:
	push ax
	push ds
	mov ax, 0x40
	mov ds, ax
	mov [disk_error], byte 1
	pop ds
	pop ax
	mov ah, 0x01
	stc
	jmp iret_carry

int13_no_drive:
	push ax
	push ds
	mov ax, 0x40
	mov ds, ax
	mov [disk_error], byte 15
	pop ds
	pop ax
	mov ah, 15
	stc
	jmp iret_carry
	
int13_rw_error:
	push ax
	push ds
	mov ax, 0x40
	mov ds, ax
	mov [disk_error], byte 0x04  ; 0x04 = Read/Write Error
	pop ds
	pop ax
	mov ah, 0x04
	stc
	jmp iret_carry

int13_reset:
	; Reset the drive
	cmp dl, 0x80
	jne int13_not_ready
	jmp int13_success

int13_get_last_error:
	; Get last error
	push bx
	push ax
	push ds
	mov ax, 0x40
	mov ds, ax
	mov bl, [disk_error]
	pop ds
	pop ax
	mov ah, bl
	pop bx
	iret

; int13_02
; Disk read
; In:
;   AL - number of sectors to read
;   CH - cylinder
;   CL - sector
;   DH - head
;   DL - drive number
;   ES:BX - buffer
int13_read:
	cmp dl, 0x80
	jne int13_not_ready

	cmp al, 0
	jne int13_read_check_al_done
	mov al, 1
int13_read_check_al_done:

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

	jmp int13_not_ready


; int13_03
; Disk write
; In:
;   AL - number of sectors to write
;   CH - cylinder
;   CL - sector
;   DH - head
;   DL - drive number
;   ES:BX - buffer
int13_write:
	cmp dl, 0x80
	jne int13_not_ready

	cmp al, 0
	jne int13_write_check_al_done
	mov al, 1
int13_write_check_al_done:

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

	jmp int13_not_ready

; int13_04
; Verify sectors
; In:
;   DL - drive number
int13_verify:
	cmp dl, 0x80
	jne int13_not_ready
	jmp int13_success

; int13_08
; Get drive parameters
; In:
;   DL - drive number
int13_get_params:
	cmp dl, 0
	je int13_08_floppy
	cmp dl, 0x80
	jne int13_no_drive
	mov bl, 41
	mov dl, 1
	mov dh, 15
	mov ch, 255	; cyl
	mov cl, 255	; sect
	jmp int13_success

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

dbt_hdd:
	db 1, 1, 1, 2, 63, 1, 2, 1, 0xff, 1, 1

dbt_floppy:
	db 1, 1, 1, 2, 18, 1, 2, 1, 0xff, 1, 1

; int13_10
; Check if device is ready
; In:
;   DL - drive number
int13_10:
	cmp dl, 0x80
	jne int13_not_ready
	jmp int13_success

; int13_get_type
; Get drive type
; In:
;   DL - drive number
int13_get_type:
	cmp dl, 0
	je int13_15_floppy
	cmp dl, 0x80
	jne int13_no_drive
	mov ah, 3
	mov cx, 0x000F ; 504 MB
	mov dx, 0xC000
	jmp int13_success

int13_15_floppy:
	mov ah, 1
	jmp int13_success


int13_func41:

	call ide_check_lba
	jc int13_not_ready      ; unsure if correct in case of missing lba support
	jmp int13_success

int13_func42:
    cmp dl, 0x80
	jne int13_not_ready
	
	call ide_read_lba
	
	jc int13_rw_error
	jmp int13_success

; int13_calc_lba
; Convert CHS to LBA
; In:
;   AL - number of sectors to read
;   CH - cylinder
;   CL - sector
;   DH - head
;   DL - drive number
int13_calc_lba:
	; lba = (cyl * num_heads + head) * num_sects + sect - 1
	; lba = (CH * 16 + DH) * 63 + CL
	; temp = cx;
	; CX = CH;
	; CX <<= 4;
	; DX = DH;
	; CX += DX;
	; AX = CX * 63;
	; CX = temp;
	; CH = 0;
	; AX += CX;

	push cx		; temp = CX;
	xchg cl, ch	; CX = CH;

	shr ch, 1
	shr ch, 1
	shr ch, 1
	shr ch, 1
	shr ch, 1
	shr ch, 1

	and cx, 0x3FF
	shl cx, 1	; CX <<= 4;
	shl cx, 1
	shl cx, 1
	shl cx, 1
	mov dl, dh      ; DX = DH;
	xor dh, dh
	add cx, dx      ; CX += DX;
	mov ax, 63	
	mul cx          ; DX:AX = CX * 63;
	pop cx
	and cx, 0x3F
	dec cx
	add ax, cx	; AX += CL;
	adc dx, 0       ; DX:AX = lba32

	ret
