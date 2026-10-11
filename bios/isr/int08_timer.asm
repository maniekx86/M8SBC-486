	; Timer interrupt
int08:
	push ax
	push ds

	mov ax, 0x40
	mov ds, ax

	; Update system time
	add word [ticks_low], 1
	adc word [ticks_high], 0

	; Check for midnight
	cmp word [ticks_high], 0x18
	jnz int08_not_midnight
	cmp word [ticks_low], 0xB0
	jnz int08_not_midnight

	xor ax, ax
	mov [ticks_low], ax
	mov [ticks_high], ax
	mov byte [new_day], 1

int08_not_midnight:

	; Stop floppy motor
	; To make Civilization game launch
	cmp byte [motor], 0
	je int08_no_motor
	dec byte [motor]
int08_no_motor:
	and byte [motor_run], 0xF0

	pop ds
	pop ax

	; Call user interrupt 0x1C
	; DOS games need it
	int 0x1C

	; End of interrupt
	push ax
	mov al, 0x20
	out 0x20, al
	pop ax

	iret
