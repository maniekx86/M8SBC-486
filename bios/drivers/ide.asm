; Compact IDE HDD driver (poll-mode)
;
; TODO: implement LBA writes and fix CF cards access
;

%define IDE_HDD_READ		0x20
%define IDE_HDD_WRITE		0x30

%define IDE_STATUS_DRQ		0x08

%define IDE_PORT_DATA		0x1F0
%define IDE_PORT_COUNT		0x1F2
%define IDE_PORT_SECTOR		0x1F3
%define IDE_PORT_CYL_LOW	0x1F4
%define IDE_PORT_CYL_HIGH	0x1F5
%define IDE_PORT_HEAD_DRV_LBA	0x1F6
%define IDE_PORT_CMD		0x1F7
%define IDE_PORT_STATUS		0x1F7
%define IDE_PORT_ALT_STATUS	0x3F6

; ide_send_chs
; Sends number of sectors, drive number and CHS to IDE HDD
; In:
;   AL - number of sectors
;   CH - cylinder
;   CL - sector
;   DH - head
;   DL - drive number
ide_send_chs:
	push ax
	push cx
	push dx

	; set up stack frame
    push bp
    mov bp, sp
    sub sp, 6   ; stack frame size

	mov word [bp-2], cx ; packed cylinder/sector
    mov word [bp-4], dx ; h - head, l - drive
    mov word [bp-6], ax ; h - XX  , l - sector count

	; send 0xA0 to 0x1F6 ORed with head number to indicate master
	mov dx, IDE_PORT_HEAD_DRV_LBA
    mov ax, [bp-4] ; dx = drive/head - ah (dh) - head
    ; swap ah and al
    xchg ah, al ; al = head
    and al, 0x0F ; mask to 4 bits
    or al, 0xA0 ; CHS, Master
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

	; set sector count
	mov ax, [bp-6] ; l is sector count
    mov dx, IDE_PORT_COUNT
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

	; set sector number
    mov ax, [bp-2] ; packed cylinder/sector
	; sectors num is packed in bits 5-0 of original CL (al)
    and al, 0b00111111
    mov dx, IDE_PORT_SECTOR
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

	; set cylinder low byte
    mov ax, [bp-2]
    mov cx, ax ; copy to cx for high byte extraction
    ; cylinder low byte is in original CH (ah)
    xchg ah, al ; now al has cylinder low byte
    mov dx, IDE_PORT_CYL_LOW
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

	mov al, cl
    shr al, 6
    mov dx, IDE_PORT_CYL_HIGH
    out dx, al


	; ; 0x1F2 - number of sectors
	; mov dx, IDE_PORT_COUNT
	; out dx, al

	; ; 0x1F3 - sector
	; mov al, cl
	; and al, 0x3F
	; mov dx, IDE_PORT_SECTOR
	; out dx, al

	; ; 0x1F4 - cylinder low
	; mov al, ch
	; mov dx, IDE_PORT_CYL_LOW
	; out dx, al

	; ; 0x1F5 - cylinder high
	; mov al, cl
	; mov cl, 6
	; shr al, cl
	; mov dx, IDE_PORT_CYL_HIGH
	; out dx, al

	; pop dx
	
	; ; 0x1F6 - drive (0x10) / lba (0x40) / head (0x0F)
	; shl dl, 1
	; shl dl, 1
	; shl dl, 1
	; shl dl, 1
	; or dl, dh
	; and dl, 0x1F
	; mov al, dl
	; mov dx, IDE_PORT_HEAD_DRV_LBA
	; out dx, al

	add sp, 6
    pop bp

	pop dx
	pop cx
	pop ax	
	ret


; ide_wait (16-bit)
; Waits until the device has PIO data to transfer, or is ready to accept PIO data
; In:
;   none
; Out:
;   CF = 0 - ok
; ide_wait:
; 	push ax
; 	push cx
; 	push dx
; 	mov cx, 65535
; 	mov dx, IDE_PORT_STATUS
; ide_wait_loop:
; 	in al, dx
; 	test al, IDE_STATUS_DRQ
; 	jnz ide_wait_ok
; 	loop ide_wait_loop
; 	stc
; 	jmp ide_wait_done
; ide_wait_ok:
; 	clc
; ide_wait_done:
; 	pop dx
; 	pop cx
; 	pop ax
; 	ret
;
; ide wait (32 bit)
ide_wait:
    push ax
    push ecx
    push dx
    mov ecx, 2000000
    mov dx, IDE_PORT_STATUS
ide_wait_loop:
    in al, dx
    test al, IDE_STATUS_DRQ
    jnz ide_wait_ok
    dec ecx
    jnz ide_wait_loop
    stc
    jmp ide_wait_done
ide_wait_ok:
    clc
ide_wait_done:
    pop dx
    pop ecx
    pop ax
    ret


ide_check_lba: ; Get Extended Drive Parameters
    ; DL - drive (0x80)
    ; BX = 55AAh
    ; check dl is 0x80
    cmp dl, 0x80
    jne .not_supported

	; Check if LBA support reporting is enabled (bit 1 of CMOS 0x40)
	push ax 
	pushf
	in al, 0x70
	mov ah, al ; old index to AH
	mov al, 0x40
	out 0x70, al
	in al, 0x71
	test al, 0b00000010
	jz .not_supported_cmos_res ; jump if zero
	mov al, ah
	out 0x70, al
	popf
	pop ax


    mov bx, 0xAA55
    mov ah, 0x20 ; success
    mov cx, 1 ; int 13,42h supported
    clc
    ret

.not_supported_cmos_res:
	mov al, ah
	out 0x70, al
	popf
	pop ax
.not_supported:
	stc
	ret


; ide_read_lba - Extended Read Sectors From Drive (LBA)
; DL - drive (0x80)
; DS:SI - pointer to packet structure
; Packet structure:
; Offset Size Description
; 0      1    Size of packet (10h)
; 1      1    Reserved (must be 0)
; 2      2    Number of blocks to transfer
; 4      2    Buffer offset
; 6      2    Buffer segment
; 8      8    Starting LBA (QWORD). We will only use lower DWORD for now (offset 8)
ide_read_lba: 
	pusha
    pushf
    push es

	mov ax, [ds:si]
    cmp al, 0x10
    jne .packet_error

    ; wait for drive ready (BSY[7]=0, RDY[6]=1)
.wait_ready42:
    mov dx, IDE_PORT_STATUS
    in al, dx
    and al, 0xC0
    cmp al, 0x40
    jne .wait_ready42

    mov al, [ds:si + 11]  ; Read LBA bits 24-27
    and al, 0x0F          
    or  al, 0xE0          ; LBA, Master drive (TO DO: add support for slave)
    mov dx, IDE_PORT_HEAD_DRV_LBA
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

    ; set sector count (number of sectors to read)
    mov dx, IDE_PORT_COUNT
    mov al, [ds:si + 2] ; number of blocks to transfer
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

    ; We will only send 24 bits of LBA
    mov dx, IDE_PORT_SECTOR
    mov al, [ds:si + 8]     ; LBA bits 0-7
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

    mov dx, IDE_PORT_CYL_LOW
    mov al, [ds:si + 9]     ; LBA bits 8-15
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx

    mov dx, IDE_PORT_CYL_HIGH
    mov al, [ds:si + 10]    ; LBA bits 16-23
    out dx, al

	mov dx, 0x80 ; io wait
	in al, dx


    ; issue read command (0x20)
    mov al, 0x20
    mov dx, IDE_PORT_CMD
    out dx, al

	xor cx, cx
    mov cl, [ds:si + 2] ; number of blocks to transfer
    mov dx, 0x1F0 ; data port
    ; get buffer segment:offset
    mov bx, [ds:si + 4] ; offset
    mov es, [ds:si + 6] ; segment

.read_loop42:
	; wait for DRQ=1 (bit 3)

.wait_drq42:
	mov dx, 0x80 ; io wait
	in al, dx
	mov dx, IDE_PORT_STATUS
    in al, dx
	and al, 0b00001000
	cmp al, 0b00001000
	jne .wait_drq42
	
	mov dx, IDE_PORT_DATA

    push cx         ; use cx as block counter, but save it as we use cx for word count too
    push di
    
    mov di, bx      ; rep insw uses es:di, so point DI to BX offset
    mov cx, 256     ; 256 words
    cld             ; direction forward
    rep insw        ; read
    
    mov bx, di      ; update bx for next sector
    
    pop di         
    pop cx          ; restore block counter and decrement
    
    dec cx          ; block count
    jnz .read_loop42

	pop es
    popf
    popa

    clc
    mov ah, 0 ; success
    ret

.packet_error:
    pop es
    popf
    popa
	mov ah, 0x01 ; invalid parameter
    ret





; ide_read - Classic read (CHS)
; IDE HDD read
; In:
;   AL - number of sectors to read
;   CH - cylinder
;   CL - sector
;   DH - head
;   DL - drive number
;   ES:BX - buffer
ide_read:
	push ax

	call ide_send_chs

	; send read command
	mov al, IDE_HDD_READ
	mov dx, IDE_PORT_CMD
	out dx, al
	
	mov dx, 0x80 ; io wait
	in al, dx
	in al, dx
	in al, dx
	in al, dx

	pop ax

.ide_read_loop:
	or al, al
	jz .ide_read_done
	call ide_wait
	jc .ide_read_timeout
	mov cx, 256
	mov dx, IDE_PORT_DATA
.ide_read_data:
    push di      
    mov di, bx      ; di = buffer offset
    cld             ; direction
    rep insw        ; read 256 words (cx)
    mov bx, di      ; update bx for next sector
    pop di 
	sub al, 1
	jmp .ide_read_loop
.ide_read_done:
	clc
	ret
.ide_read_timeout:
	ret

; ide_write
; IDE HDD write
; In:
;   AL - number of sectors to write
;   CH - cylinder
;   CL - sector
;   DH - head
;   DL - drive number
;   ES:BX - buffer
ide_write:
	push ax

	call ide_send_chs

	; send write command
	mov al, IDE_HDD_WRITE
	mov dx, IDE_PORT_CMD
	out dx, al
	
	mov dx, 0x80 ; io wait
	in al, dx
	in al, dx
	in al, dx
	in al, dx

	pop ax

.ide_write_loop:
	or al, al
	jz .ide_write_done
	call ide_wait
	jc .ide_write_timeout
	mov cx, 256
	mov dx, IDE_PORT_DATA
	push ax
.ide_write_data:
    push ds         ; data index
    push si         ; source index
    mov ax, es  
    mov ds, ax      ; es = ax
    mov si, bx      ; si = bx. ds:si is es:bx now
    
    cld             ; direction
    rep outsw
    
    mov bx, si      ; update bx for next sector
    
    pop si
    pop ds
	pop ax
	sub al, 1
	jmp .ide_write_loop
.ide_write_done:
	clc
	ret
.ide_write_timeout:
	ret
