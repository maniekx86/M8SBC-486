; entry.asm
bits 16

section .text.entry

; Linker calculation out
global pm_entry
global protected_mode_start
global real_mode_restored
global gdt_descriptor
global preparing_for_real_mode

extern main
extern _data_load_addr
extern _data_start
extern _data_end
extern _bss_start
extern _bss_end

; Linker calculation in
extern _off_gdt_desc
extern _off_pm_start
extern _off_rm_restore
extern _off_prep_rm

; Ints
global isr_irq0
global isr_irq1

extern c_isr_irq0
extern c_isr_irq1

; we have to save old SP somewhere
%define SAVE_SP_ADDR 0x0600

pm_entry:
    pushf
    pusha
    cli

    xor ax, ax
    mov ds, ax ; ds = 0
    mov [SAVE_SP_ADDR], sp


    ; 1. Load GDT using the calculated 16-bit offset
    ; The linker sees this as just a number (e.g., 0x2040)
    lgdt [cs:_off_gdt_desc]

    ; 2. Switch to Protected Mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; 3. Jump to PM using the calculated offset
    ; We force a 32-bit jump using the 16-bit offset we got from LD
    jmp dword 0x08:(_off_pm_start + 0xF0000)

; ---------------------------------------------
bits 32
protected_mode_start:
    ; 4. Set Segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0xB00 ; ASM stack is at 0x1000

    ; 5. Copy Data (ROM -> RAM)
    mov esi, _data_load_addr
    mov edi, _data_start
    mov ecx, _data_end
    sub ecx, _data_start
    rep movsb

    ; 6. Clear BSS
    mov edi, _bss_start
    mov ecx, _bss_end
    sub ecx, _bss_start
    xor eax, eax
    rep stosb

    ; 7. Call C
    call main

    ; 8. Return to Real Mode
    jmp 0x18:_off_prep_rm

bits 16
preparing_for_real_mode:
    mov ax, 0x20 
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov eax, cr0
    and al, ~1
    mov cr0, eax

    ; 9. Jump back to Real Mode CS (0xF000)
    ; Use the calculated offset again
    jmp 0xF000:_off_rm_restore

real_mode_restored:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov sp, [SAVE_SP_ADDR]
    
    popa
    popf
    retf

; End of execution
; ---------------------------------------------


align 4
gdt_start:
    dq 0 ; Null
    
    ; 0x08: Code 32-bit (Base=0, Limit=4GB)
    db 0xFF, 0xFF, 0, 0, 0, 0x9A, 0xCF, 0 
    ; 0x10: Data 32-bit (Base=0, Limit=4GB)
    db 0xFF, 0xFF, 0, 0, 0, 0x92, 0xCF, 0 

    ; 0x18: Code 16-bit (Base=0xF0000, Limit=64KB)
    ; BaseLow=0000, BaseMid=0F, BaseHi=00 -> 0x000F0000
    db 0xFF, 0xFF, 0x00, 0x00, 0x0F, 0x9A, 0x00, 0 
    ; 0x20: Data 16-bit (Base=0xF0000, Limit=64KB)
    ; BaseLow=0000, BaseMid=0F, BaseHi=00 -> 0x000F0000
    db 0xFF, 0xFF, 0x00, 0x00, 0x0F, 0x92, 0x00, 0 

gdt_descriptor:
    dw $ - gdt_start - 1
    dd gdt_start



; ---------------------------------------------
; Extra: C helpers
bits 32
isr_irq0:
    pusha
    pushf

    call c_isr_irq0

    mov al, 0x20 ; int ACK
    out 0x20, al

    popf
    popa
    iretd

isr_irq1:
    pusha
    pushf

    call c_isr_irq1

    mov al, 0x20 ; int ACK
    out 0x20, al

    popf
    popa
    iretd
