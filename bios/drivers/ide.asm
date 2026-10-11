; no IRQ / no DMA (polling) IDE HDD driver
;
; supports master (DL=80h) and slave (DL=81h) drives
;

%define IDE_HDD_READ		0x20
%define IDE_HDD_WRITE		0x30

%define IDE_STATUS_BSY		0x80
%define IDE_STATUS_DRDY		0x40
%define IDE_STATUS_DRQ		0x08
%define IDE_STATUS_ERR		0x01

%define IDE_PORT_DATA		0x1F0
%define IDE_PORT_COUNT		0x1F2
%define IDE_PORT_SECTOR		0x1F3
%define IDE_PORT_CYL_LOW	0x1F4
%define IDE_PORT_CYL_HIGH	0x1F5
%define IDE_PORT_HEAD_DRV_LBA	0x1F6
%define IDE_PORT_CMD		0x1F7
%define IDE_PORT_STATUS		0x1F7
%define IDE_PORT_ALT_STATUS	0x3F6

%define IDE_TIMEOUT_CYCLES  200000


; ide_wait_ready - Wait for BSY=0, DRDY=1, check ERR
; Out: CF=0 ready, CF=1 timeout/error
ide_wait_ready:
	push ax
	push ecx
	push dx
	mov ecx, IDE_TIMEOUT_CYCLES
	mov dx, IDE_PORT_ALT_STATUS
.loop:
	in al, dx
	test al, IDE_STATUS_BSY
	jnz .busy
	test al, IDE_STATUS_DRDY
	jnz .check_err
.busy:
	dec ecx
	jnz .loop
	stc
	jmp .done
.check_err:
	test al, IDE_STATUS_ERR
	jz .ok
	stc
	jmp .done
.ok:
	clc
.done:
	pop dx
	pop ecx
	pop ax
	ret


; ide_wait - Wait for BSY=0, DRQ=1 (data transfer ready)
; Out: CF=0 ready, CF=1 timeout/error
ide_wait:
	push ax
	push ecx
	push dx
	mov ecx, IDE_TIMEOUT_CYCLES
	mov dx, IDE_PORT_ALT_STATUS
.loop:
	in al, dx
	test al, IDE_STATUS_BSY
	jnz .busy
	test al, IDE_STATUS_ERR
	jnz .error
	test al, IDE_STATUS_DRQ
	jnz .ok
.busy:
	dec ecx
	jnz .loop
.error:
	stc
	jmp .done
.ok:
	clc
.done:
	pop dx
	pop ecx
	pop ax
	ret


; ide_io_wait - I/O wait macro, clobbers AL!
%macro IO_WAIT 0
	in al, 0x80
%endmacro


; ide_send_chs - Send CHS parameters to IDE controller
; In: AL=count, CH=cyl_lo, CL=sect|(cyl_hi<<6), DH=head, DL=drive
; Preserves all registers
ide_send_chs:
	push ax
	push bx
	push cx
	push dx

	push bp
	mov bp, sp
	sub sp, 6
	mov word [bp-2], cx
	mov word [bp-4], dx
	mov word [bp-6], ax

	; Check LBA support in BDA
	push ds
	push si
	mov ax, 0x40
	mov ds, ax
	mov ax, [bp-4]
	and al, 1
	xor ah, ah
	mov si, ax
	mov al, [0xC3 + si]
	test al, al
	jnz .do_lba
	pop si
	pop ds

	; ---------------- PHYSICAL CHS ----------------
	call ide_wait_ready

	; Head/Drive: 1|0|1|DRV|HEAD[3:0]
	mov dx, IDE_PORT_HEAD_DRV_LBA
	mov ax, [bp-4]
	xchg ah, al
	and al, 0x0F
	or al, 0xA0
	test ah, 0x01
	jz .m
	or al, 0x10
.m:	out dx, al
	IO_WAIT

	; Sector count
	mov ax, [bp-6]
	mov dx, IDE_PORT_COUNT
	out dx, al
	IO_WAIT

	; Sector number
	mov ax, [bp-2]
	and al, 0b00111111
	mov dx, IDE_PORT_SECTOR
	out dx, al
	IO_WAIT

	; Cylinder low
	mov ax, [bp-2]
	mov cx, ax
	xchg ah, al
	mov dx, IDE_PORT_CYL_LOW
	out dx, al
	IO_WAIT

	; Cylinder high
	mov al, cl
	shr al, 6
	mov dx, IDE_PORT_CYL_HIGH
	out dx, al
	jmp .done_send

.do_lba:
	; ---------------- LBA TRANSLATION ----------------
	; LBA = ( (cyl * heads) + head ) * sectors + (sector - 1)
	
	xor eax, eax
	mov ax, [bp-2]
	xchg ah, al
	shr ah, 6
	and ax, 0x03FF              ; EAX = cyl (0..1023)

	xor ebx, ebx
	mov bl, [0xC9 + si]         ; EBX = logical heads
	mul ebx                     ; EAX = cyl * heads
	
	xor ebx, ebx
	mov dx, [bp-4]
	mov bl, dh                  ; EBX = head
	add eax, ebx                ; EAX = (cyl*heads) + head
	
	xor ebx, ebx
	mov bl, [0xCB + si]         ; EBX = logical sectors
	mul ebx                     ; EAX = ((cyl*heads) + head) * sectors
	
	xor ecx, ecx
	mov cx, [bp-2]
	and cx, 0x3F                ; CX = sector (1..63)
	dec cx
	add eax, ecx                ; EAX = LBA
	
	mov [bp-2], ax      ; LBA low
	shr eax, 16
	mov [bp-4], ax      ; LBA high
	
	pop si
	pop ds
	
	call ide_wait_ready
	
	mov ax, [bp-4]
	mov al, ah
	and al, 0x0F
	or al, 0xE0
	mov cx, [bp+2]      ; original DX
	test cl, 1
	jz .m2
	or al, 0x10
.m2:
	mov dx, IDE_PORT_HEAD_DRV_LBA
	out dx, al
	IO_WAIT
	
	mov dx, IDE_PORT_COUNT
	mov ax, [bp-6]
	out dx, al
	IO_WAIT
	
	mov dx, IDE_PORT_SECTOR
	mov ax, [bp-2]
	out dx, al
	IO_WAIT
	
	mov dx, IDE_PORT_CYL_LOW
	mov al, ah
	out dx, al
	IO_WAIT
	
	mov dx, IDE_PORT_CYL_HIGH
	mov ax, [bp-4]
	out dx, al

.done_send:
	add sp, 6
	pop bp
	pop dx
	pop cx
	pop bx
	pop ax
	ret


; ide_cmd_delay - Issue ATA command and wait 400ns
; In: AL=command
; Clobbers: DX, AL
ide_cmd_delay:
	mov dx, IDE_PORT_CMD
	out dx, al
	mov dx, IDE_PORT_ALT_STATUS
	in al, dx
	in al, dx
	in al, dx
	in al, dx
	ret


; ide_read - Read sectors (CHS, PIO)
; In: AL=count, CHS in CH/CL/DH, DL=drive, ES:BX=buffer
; Out: CF=0 ok, CF=1 error
ide_read:
	push ax
	call ide_send_chs
	mov al, IDE_HDD_READ
	call ide_cmd_delay
	pop ax

.loop:
	or al, al
	jz .done
	call ide_wait
	jc .err
	push ax
	push cx
	push di
	pushf
	cli
	mov di, bx
	mov cx, 256
	mov dx, IDE_PORT_DATA
	cld
	rep insw
	popf
	mov bx, di
	pop di
	pop cx
	pop ax
	sub al, 1
	jmp .loop
.done:
	call ide_wait_ready
	jc .err
	clc
	ret
.err:
	stc
	ret


; ide_write - Write sectors (CHS)
; In: AL=count, CHS in CH/CL/DH, DL=drive, ES:BX=buffer
; Out: CF=0 ok, CF=1 error
ide_write:
	push ax
	call ide_send_chs
	mov al, IDE_HDD_WRITE
	call ide_cmd_delay
	pop ax

.loop:
	or al, al
	jz .done
	call ide_wait
	jc .err
	push ax
	push cx
	push ds
	push si
	pushf
	cli
	mov ax, es
	mov ds, ax
	mov si, bx
	mov cx, 256
	mov dx, IDE_PORT_DATA
	cld
	rep outsw
	popf
	mov bx, si
	pop si
	pop ds
	pop cx
	pop ax
	sub al, 1
	jmp .loop
.done:
	call ide_wait_ready
	jc .err
	clc
	ret
.err:
	stc
	ret


; ide_check_lba - check LBA extensions support (AH=41h)
; In: DL=drive
; Out: CF=0 supported (AH=21h, BX=AA55h, CX=1), CF=1 not
ide_check_lba:
	cmp dl, 0x80
	je .chk
	cmp dl, 0x81
	je .chk
	jmp .no
.chk:
	push ax
	pushf
	in al, 0x70
	mov ah, al
	mov al, 0x40
	out 0x70, al
	in al, 0x71
	test al, 0b00000010
	jz .no_cmos
	mov al, ah
	out 0x70, al
	popf
	pop ax
	mov bx, 0xAA55
	mov ah, 0x21
	mov cx, 1
	clc
	ret
.no_cmos:
	mov al, ah
	out 0x70, al
	popf
	pop ax
.no:
	stc
	ret


; ide_setup_lba - Common LBA register setup for read/write
; In: DL=drive, DS:SI=DAP
; Out: CX=sector count, BX=buf offset, ES=buf segment
;      CF=0 ok, CF=1 error (packet/timeout)
;      If CF=1, stack is NOT modified (caller handles cleanup)
; Clobbers: AX, DX
ide_setup_lba:
	; Validate packet
	mov al, [ds:si]
	cmp al, 0x10
	jb .pkt_err

	call ide_wait_ready
	jc .err

	; Drive/LBA[27:24]
	mov al, [ds:si + 11]
	and al, 0x0F
	or al, 0xE0
	test dl, 0x01
	jz .m
	or al, 0x10
.m:	mov dx, IDE_PORT_HEAD_DRV_LBA
	out dx, al
	IO_WAIT

	; Count
	mov dx, IDE_PORT_COUNT
	mov al, [ds:si + 2]
	out dx, al
	IO_WAIT

	; LBA[7:0]
	mov dx, IDE_PORT_SECTOR
	mov al, [ds:si + 8]
	out dx, al
	IO_WAIT

	; LBA[15:8]
	mov dx, IDE_PORT_CYL_LOW
	mov al, [ds:si + 9]
	out dx, al
	IO_WAIT

	; LBA[23:16]
	mov dx, IDE_PORT_CYL_HIGH
	mov al, [ds:si + 10]
	out dx, al

	; Prepare return values
	xor cx, cx
	mov cl, [ds:si + 2]
	mov bx, [ds:si + 4]
	mov es, [ds:si + 6]
	clc
	ret
.pkt_err:
.err:
	stc
	ret


; ide_read_lba - Extended Read (LBA, AH=42h)
; In: DL=drive, DS:SI=DAP
; Out: CF=0 ok (AH=0), CF=1 error (AH=error code)
ide_read_lba:
	pusha
	pushf
	push es

	call ide_setup_lba
	jc .err

	mov al, IDE_HDD_READ
	call ide_cmd_delay

.loop:
	call ide_wait
	jc .err

	push cx
	push di
	pushf
	cli
	mov di, bx
	mov cx, 256
	mov dx, IDE_PORT_DATA
	cld
	rep insw
	popf
	mov bx, di
	pop di
	pop cx
	dec cx
	jnz .loop

	call ide_wait_ready
	jc .err

	pop es
	popf
	popa
	mov ah, 0
	clc
	ret

.err:
	pop es
	popf
	popa
	mov ah, 0xBB
	stc
	ret


; ide_write_lba - Extended Write (LBA, AH=43h)
; In: DL=drive, DS:SI=DAP
; Out: CF=0 ok (AH=0), CF=1 error (AH=error code)
ide_write_lba:
	pusha
	pushf
	push es

	call ide_setup_lba
	jc .err

	mov al, IDE_HDD_WRITE
	call ide_cmd_delay

.loop:
	call ide_wait
	jc .err

	push cx
	push ds
	push si
	pushf
	cli
	mov ax, es
	mov ds, ax
	mov si, bx
	mov cx, 256
	mov dx, IDE_PORT_DATA
	cld
	rep outsw
	popf
	mov bx, si
	pop si
	pop ds
	pop cx
	dec cx
	jnz .loop

	call ide_wait_ready
	jc .err

	pop es
	popf
	popa
	mov ah, 0
	clc
	ret

.err:
	pop es
	popf
	popa
	mov ah, 0xBB
	stc
	ret
