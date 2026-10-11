/* linker.ld */
OUTPUT_FORMAT("binary")
ENTRY(pm_entry)

SECTIONS
{
    /* Code lives at 0xF4000 */
    . = 0xF4000;

    .text : {
        *(.text.entry) /* Put assembly entry first */
        *(.text)
        *(.text.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Variables live in RAM at 0x1000 */
    .data 0x1000 : AT(ADDR(.rodata) + SIZEOF(.rodata)) {
        _data_start = .;
        *(.data)
        _data_end = .;
    }

    .bss : {
        _bss_start = .;
        *(.bss)
        *(COMMON)
        _bss_end = .;
    }

    _data_load_addr = LOADADDR(.data);

    /* --- THE FIX: Calculate 16-bit Offsets --- */
    /* We subtract the segment base (0xF0000) from the linear symbols */
    
    _off_gdt_desc = gdt_descriptor - 0xF0000;
    _off_pm_start = protected_mode_start - 0xF0000;
    _off_rm_restore = real_mode_restored - 0xF0000;
    _off_prep_rm    = preparing_for_real_mode - 0xF0000;
}
