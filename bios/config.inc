
; Continuous 1KB blocks after 1MB
; In case of M8SBC-486 - it's 3072 (0x100000-0x400000)
%define EXT_RAM_SIZE_CONT 3072

; Where in binary is C code entry located
%define C_CODE_ENTRY 0x4000
