#include <stdint.h>
#include "x86io.h"          // IN(), OUT(), INW(), OUTW()
#include "interrupts.h"     // IDT, PIC, IRQ ISRs
#include "utils.h"          // C utility functions (strings, memory)
#include "keyboard.h"       // Onboard compatible 8042 PS/2 controller functions
#include "vga.h"            // VGA print, VGA text mode logo
#include "cpudetect.h"      // CPUID parse, Cyrix check, FPU check
#include "ide.h"            // IDE functions and detection
#include "cmos.h"           // CMOS settings read, write, restore, save

#include "about.h"
#include "setup.h"

#ifndef VERSION
#define VERSION "?.??"
#endif

#define POST(x) outb(0x80, x)

volatile uint32_t *cpuid_edx = (uint32_t*)0x5F0;  // DX from reset is stored to 0x5F0 by ASM
// volatile uint16_t *bda_warm_boot = (uint16_t*)0x472; // Warm boot flag. If set to 0x1234, skip some checks. Needs fixes in real mode asm, so TODO

// Global variables
uint16_t cpuid;
int cyrix_cpu = 0;
char cpu_model[48];
int fpu_present = 0;

int mem_total = 64;             // base 64K already tested
int ide_detected = 0;
char ide_name[48];
int skip_memory_test = 0;
uint8_t cmos_status;

// Memory test regions:
// 0x0010000 - 0x009FFFF: start: 0x0010000, 9 blocks
// 0x0100000 - 0x03FFFFF: start: 0x0100000, 48 blocks
// 0x04A0000 - 0x04FFFFF: start: 0x04A0000, 6 blocks
// block is 64K in size
//
// Base 64K was already tested before and it should 
// be working if we already hit this point

#define MEMTEST_REGIONS_TOTAL 3
struct memtest_regions_struct {
    uint32_t offset;
    uint8_t blocks_64k;
} memtest_regions[MEMTEST_REGIONS_TOTAL] = {
    {0x0010000, 9},
    {0x0100000, 48},
    {0x04A0000, 6}
};

void memory_error(uint32_t read, uint32_t expected, uint32_t location, int x_pos) { // TO UPDATE/IMPROVE
    char buf[16];
    
    POST(0xE1); // E1 - Extended memory test failed
    
    skip_memory_test = 0; // Clear if already selected
    
    location = location * 4;
    
    // FAIL: [address] - [read]: [value] [expected]: [value]
    // example: FAIL: DEADBEEF - R: 12121212 E: 55AA55AA
    vga_print_string("FAIL: ", x_pos, 10, 0x0C);
    itoapad(location, buf, 16, 8);
    vga_print_string(buf, x_pos + 6, 10, 0x0C); // x 14
    vga_print_string("- R:", x_pos + 15, 10, 0x0C); // x 20
    itoapad(read, buf, 16, 8);
    vga_print_string(buf, x_pos + 20, 10, 0x0C); // x 28
    vga_print_string("E: ", x_pos + 29, 10, 0x0C); // x 32
    itoapad(expected, buf, 16, 8);
    vga_print_string(buf, x_pos + 32, 10, 0x0C); 
    vga_print_string("Press ESC to ignore", x_pos, 11, 0x0C);
    
    while(skip_memory_test==0) asm("nop");
}

__attribute__ ((optimize(2))) void memory_test(int quick) {
    volatile uint32_t *memory = (volatile uint32_t *)0x00000000;
    
    // At this point cache is already ON but we gonna invalidate it after writes

    mem_total = 64; // base 64k already tested
    char print_buf[20];
    int inc_amount;
    int print_len = 0;

    if(quick) {
        inc_amount = 32; 
    } else {
        inc_amount = 1;
    }

    for(int region=0; region < MEMTEST_REGIONS_TOTAL; region++) {
        // 0x0010000
        uint32_t mem_offset = memtest_regions[region].offset / 4;
        uint8_t blocks = memtest_regions[region].blocks_64k;

        for(int block=0; block < blocks; block++) {

            uint32_t ticks_next = irq0_ticks + 5; // Slow down

            for(uint32_t wpos = 0; wpos < (0x10000/4); wpos+=inc_amount) { // uint32_t align is 4 so 1 offset = 4 bytes
                volatile uint32_t *current_ptr = memory + mem_offset + wpos;
                *current_ptr = 0x55AA55AA;
            }
            asm volatile("wbinvd");
            for(uint32_t rpos = 0; rpos < (0x10000/4); rpos+=inc_amount) {
                volatile uint32_t *current_ptr = memory + mem_offset + rpos;
                if(*current_ptr != 0x55AA55AA) {
                    // ERROR
                    memory_error(*current_ptr, 0x55AA55AA, mem_offset + rpos, 20 + print_len + 1);
                    return;
                }
            }
            // Swap bits
            for(uint32_t wpos = 0; wpos < (0x10000/4); wpos+=inc_amount) {
                volatile uint32_t *current_ptr = memory + mem_offset + wpos;
                *current_ptr = 0xAA55AA55;
            }
            asm volatile("wbinvd");
            for(uint32_t rpos = 0; rpos < (0x10000/4); rpos+=inc_amount) {
                volatile uint32_t *current_ptr = memory + mem_offset + rpos;
                if(*current_ptr != 0xAA55AA55) {
                    // ERROR
                    memory_error(*current_ptr, 0xAA55AA55, mem_offset + rpos, 20 + print_len + 1);
                    return;
                }
            }
            // if mem test goes too fast, slow down by counting ticks
            while(ticks_next > irq0_ticks) { asm("nop"); }

            mem_total += 64;
            mem_offset = mem_offset + 0x4000; // 0x10000 / 4
            //vga_print_itoa(tested_memory_k, 20, 10, 0x0F, 10, 0);

            if(skip_memory_test==1) {
                mem_total = 4096;
            }
            
            itoa(mem_total, print_buf, 10);
            if(quick) {
                strcat(print_buf, " KB (q)");
            } else {
                strcat(print_buf, " KB");
            }
            vga_print_string(print_buf, 20, 10, 0x0F);
            print_len = strlen(print_buf);
            
            if(skip_memory_test==1) break;
            
        }
        
    }

}

enum POST_action_enum {
    POST_NORMAL,
    POST_SETTINGS,
    POST_SYSTEM_TEST,
    POST_ABOUT
} POST_action;

void POST_kb_handle() {
    // kb buffer should be always not empty when this routine is executed
    // Future TODO - work on translated keys instead of working with raw keys
    uint8_t scancode = kb_get_scancode();

    switch (scancode) {

        case 0x01: // ESC
            skip_memory_test = 1;
            break;
        
        default:
            break;
    }

    if(POST_action == POST_NORMAL) {
        switch (scancode) {

            case 0x3B: // F1
                POST_action = POST_SETTINGS;
                for(int x=0; x<80; x++) {
                    vga_print_char(' ', x, 24, 0x07);
                }
                vga_print_string("Selected: SETTINGS", 1, 24, 0x0F);
                break;

            case 0x3C: // F2
                break; // to do in future
                POST_action = POST_SYSTEM_TEST;
                for(int x=0; x<80; x++) {
                    vga_print_char(' ', x, 24, 0x07);
                }
                vga_print_string("Selected: SYSTEM TEST", 1, 24, 0x0F);
                break;
        
            case 0x3D: // F3
                POST_action = POST_ABOUT;
                for(int x=0; x<80; x++) {
                    vga_print_char(' ', x, 24, 0x07);
                }
                vga_print_string("Selected: ABOUT", 1, 24, 0x0F);
                break;

            default:
                break;
        }
    }
}

void main() {
    // Interrupts are disabled
    POST(0x80); // 80 - C main() running. IDT init
    
    idt_init(); // Remaps and masks all IRQ internally ( pic_remap(0x20); pic_set_mask(0xFF); )
    
    POST(0x81); // 81 - CMOS read

    cmos_status = cmos_read();
    
    POST(0x82); // 82 - CPU identification
    fpu_present = is_fpu_present();
    cyrix_cpu = is_cyrix_cpu();

    cpuid = (uint16_t)(*cpuid_edx & 0xFFFF);
    detect_486_model(cpuid, cyrix_cpu, cpu_model, 0);

    POST(0x83); // 83 - PIT setup and test
    
    // 100 Hz and enable PIT IRQ
    pit_set_int_freq(100);
    pic_enable_irq(0);
    
    sti();
    while(1) { // Verify that interrupts work
        if(irq0_ticks>3) break;
        asm volatile("nop");
        // If this loop never exits, verify PIT and PIC, TODO: timeout and error message
    }
    
    POST(0x84); // 84 - Keyboard initialization and test
    
    kb_init();

    POST_action = POST_NORMAL;
    kb_set_callback(POST_kb_handle);

    cli();

    // Draw BIOS
    
    POST(0x85); // 85 - BIOS POST display init

    vga_load_logo(); 
    vga_draw_logo(60, 1);
    vga_draw_extra_logo(1,1);
    vga_draw_extra_logo(1,2);
    
    POST(0x86); // 86 - BIOS POST display

    vga_print_string("SeaPig 486 Single Board Computer BIOS " VERSION , 4, 1, 0x07);
    vga_print_string("Copyright (C) 2024-2026, maniek86.xyz", 4, 2, 0x07);
    vga_print_string("M8SBC-486 REV 1.0 BIOS (DEV)", 1, 4, 0x07);

    vga_print_string("Main Processor :", 3, 7, 0x07);
    vga_print_string("FPU Present :", 6, 8, 0x07);
    vga_print_string("Memory Test :", 6, 10, 0x07);

    vga_print_string("---- Built " __DATE__ " " __TIME__ " / CHP V1 / Derived from BIOS by b-dmitry1 ----", 1, 23, 0x07);

    /*
    vga_print_string("[ESC SKIP MEMORY TEST]  [F1 SETTINGS]  [F2 SYSTEM TEST]  [F3 ABOUT]", 7, 24, 0x0A);
    // highlight ESC, F1, F2, F3
    vga_set_char_attr(0x0F, 7+1, 24);
    vga_set_char_attr(0x0F, 7+2, 24);
    vga_set_char_attr(0x0F, 7+3, 24);
    
    vga_set_char_attr(0x0F, 7+25, 24);
    vga_set_char_attr(0x0F, 7+26, 24);
    vga_set_char_attr(0x0F, 7+40, 24);
    vga_set_char_attr(0x0F, 7+41, 24);
    vga_set_char_attr(0x0F, 7+58, 24);
    vga_set_char_attr(0x0F, 7+59, 24);
    */

    vga_print_string("[ESC SKIP MEMORY TEST]  [F1 SETTINGS]  [F3 ABOUT]", 15, 24, 0x0A);
    // highlight ESC, F1, F3
    vga_set_char_attr(0x0F, 15+1, 24);
    vga_set_char_attr(0x0F, 15+2, 24);
    vga_set_char_attr(0x0F, 15+3, 24);
    
    vga_set_char_attr(0x0F, 15+25, 24);
    vga_set_char_attr(0x0F, 15+26, 24);
    vga_set_char_attr(0x0F, 15+40, 24);
    vga_set_char_attr(0x0F, 15+41, 24);

    vga_print_string(cpu_model, 20, 7, 0x0F);

    if(fpu_present) {
        vga_print_string("Yes", 20, 8, 0x0F);
    } else {
        vga_print_string("No", 20, 8, 0x0F);
    }

    if(cmos_status==0) { // cmos was invalid
        vga_print_string("CMOS checksum was invalid! Cleared", 23, 22, 0x04);
    }
    
    sti();
    
    POST(0x87); // 87 - Extended memory test
    
    // if(bda_warm_boot==0x1234) { // Warm boot. needs fixes in real mode asm, so TODO
    //   skip_memory_test = 1;
    // }

    memory_test(cmos_get(CMOS_QUICK_MEMTEST));
    
    POST(0x88); // 88 - Primary IDE detection

    vga_print_string("Primary IDE : detecting...", 6, 12, 0x07);

    IDE_reset();

    if(IDE_wait_busy(500) && IDE_detect(ide_name)) { // wait 5 seconds
        ide_name[42] = 0;
        ide_detected = 1;
        vga_print_string("              ", 20, 12, 0x0F);
        vga_print_string(ide_name, 20, 12, 0x0F);
    } else {
        vga_print_string("None          ", 20, 12, 0x0F);
        strcpy(ide_name, "None");
        ide_detected = 0;
    }
    
    POST(0x89); // 89 - POST display wait

    kb_set_callback(NULL);

    uint32_t boot_delay;

    if(ide_detected == 0) {
        POST_action = POST_SETTINGS;
    }

    switch(POST_action) {
        case POST_ABOUT:
            boot_delay = irq0_ticks + 10;
            POST(0xA0); // A0 - About display
            about_display();
            break;

        case POST_SETTINGS:
            POST(0xA1); // A1 - BIOS setup
            boot_delay = irq0_ticks + 10;
            setup_display(cpuid, cyrix_cpu, mem_total, fpu_present, ide_name, ide_detected);
            break;

        default:
            boot_delay = irq0_ticks + 100;
            break;
    }


    while(1) {
        if(irq0_ticks>boot_delay) {
            break;
        }
        asm volatile("nop");
    }


    if(cmos_get(CMOS_LOCK_CMOS)) cmos_lock();
    
    POST(0x8A); // 8A - Restore PIC
    
    cli(); // Reset PIC to default
    pic_remap(8); 
    pic_set_mask(0x00); 
    idt_restore_real_mode();
    
    POST(0x8B); // 8B - Restore VGA and print summary

    vga_restore_font();
    vga_clear(0x07);
    
    for(int x=0; x<80; x++) {
        vga_print_char('=', x, 0, 0x07);
        vga_print_char('=', x, 4, 0x07);
    }
    vga_print_string(" SeaPig BIOS ", 32, 0, 0x07);
    
    vga_print_string("Processor", 1, 1, 0x07);
    vga_print_char(':', 13, 1, 0x07); 
    vga_print_string("Memory", 1, 2, 0x07);
    vga_print_char(':', 13, 2, 0x07);
    vga_print_string("Primary IDE", 1, 3, 0x07);
    vga_print_char(':', 13, 3, 0x07);
    
    vga_print_string(cpu_model, 15, 1, 0x07);
    int mem_str_len = vga_print_itoa(mem_total, 15, 2, 0x07, 10, 0);
    vga_print_string("KB", 16+mem_str_len, 2, 0x07);
    vga_print_string(ide_name, 15, 3, 0x07);
    
    // OS text should be printed at Y=6
    
    
    // Cursor gets moved by real mode section

    return;
}
