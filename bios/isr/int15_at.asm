	; Partial implementation of PC/AT int 15h
	; Designed for use with FPGA / emulator and
	; Intel 386EX / Texas Instruments 486 / Cyrix 486 CPUs

%include "drivers/a20.asm"

int15:
	cmp ah, 0x24
	je int15_a20
	cmp ah, 0x88
	je int15_memsize_0x88
	cmp ah, 0xC0
	je int15_getconfig
	cmp ax, 0xE820
	je int15_memmap
	cmp ax, 0xE801
	je int15_memsize_0xE801
	cmp ah, 0x8A
	je int15_memsize_0x8A

	mov ah, 0x86
	jmp iret_carry_on

int15_a20:
	cmp al, 0
	je int15_a20_disable
	cmp al, 1
	je int15_a20_enable
	cmp al, 2
	je int15_a20_get
	cmp al, 3
	je int15_a20_get_support
	mov ah, 0x86
	stc
	jmp iret_carry

int15_a20_disable:
	push ax
	call a20_disable
	pop ax

	xor ah, ah
	clc
	jmp iret_carry

int15_a20_enable:
	push ax
	call a20_enable
	pop ax

	xor ah, ah
	clc
	jmp iret_carry

int15_a20_get:
	call a20_get

	xor ah, ah
	clc
	jmp iret_carry

int15_a20_get_support:
	xor ah, ah
	mov bx, 0
	clc
	jmp iret_carry

int15_memsize_0x88:
	mov ax, EXT_RAM_SIZE_CONT
	clc
	jmp iret_carry

int15_memsize_0xE801:
	mov ax, EXT_RAM_SIZE_CONT
	mov cx, ax
	xor bx, bx
	mov dx, bx
	clc
	jmp iret_carry

int15_memsize_0x8A:
	mov ax, EXT_RAM_SIZE_CONT
	xor dx, dx
	clc
	jmp iret_carry

int15_getconfig:
	mov bx, 0xF000
	mov es, bx
	mov bx, int15_system_config
	mov ah, 0
	clc
	jmp iret_carry
	
int15_memmap:
	mov eax, 0x534D4150 ; signature
	; ES:DI	Buffer Pointer

	cmp ebx, 0
	je .copy_0

	cmp ebx, 1
	je .copy_1

	cmp ebx, 2
	je .copy_2

	cmp ebx, 3
	je .copy_3

	cmp ebx, 4
	je .copy_4

	jmp iret_carry_on

.copy_0:
	mov ecx, int15_memmap_0
	mov ebx, 1
	jmp .copy
.copy_1:
	mov ecx, int15_memmap_1
	mov ebx, 2
	jmp .copy
.copy_2:
	mov ecx, int15_memmap_2
	mov ebx, 3
	jmp .copy
.copy_3:
	mov ecx, int15_memmap_3
	mov ebx, 4
	jmp .copy
.copy_4:
	mov ecx, int15_memmap_4
	mov ebx, 0
	jmp .copy

.copy:
	push si
	push ds
	push di

	push cs ; DS = CS
	pop ds
	mov si, cx

	mov ecx, 20
    cld
    rep movsb           ; DS:SI -> ES:DI

	pop di
	pop ds
	pop si

	mov ecx, 20

	cmp ebx, 0
	je .finished

	jmp iret_carry

.finished:
	xor ebx, ebx
	jmp iret_carry_on


int15_memmap_0: ; 0x0000000 - 0x009FFFF: available
	dq 0x00000000 
	dq 0x000A0000
	dd 1
; 0xA0000 - 0xC8000 ISA space
int15_memmap_1: ; 0x00A0000 - 0x0100000: reserved: ISA, VGA RAM, ROMs
	dq 0x0000A0000
	dq 0x000060000
	dd 2
int15_memmap_2: ; 0x0100000 - 0x0400000: available
	dq 0x000100000
	dq 0x000300000
	dd 1
int15_memmap_3: ; 0x0400000 - 0x04A0000: reserved (repeat)
	dq 0x000400000
	dq 0x0000A0000
	dd 2
int15_memmap_4: ; 0x04A0000 - 0x0500000: available
	dq 0x0004A0000
	dq 0x000060000
	dd 1


int15_system_config:
	dw 8		; Size
	db 0xF8		; 386 or higher CPU
	db 0x00		; Model
	db 0x01		; BIOS revision
	db 0x20		; Feature information, no second PIC
	db 0x00     ; Feature 2
	db 0
	db 0
	db 0

