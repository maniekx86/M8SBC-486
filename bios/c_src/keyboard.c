#include "keyboard.h"

static uint8_t kb_buffer[KB_BUF_SIZE];
static uint8_t kb_buffer_read = 0;
static uint8_t kb_buffer_write = 0;
static kb_callback_ptr kb_stored_callback = 0;

// TODO: 
// - Capslock, Numlock and Scrolllock support in this protected mode blob
// - Keyboard LEDs (to do during implementing above)
// - Translation
// - Actually testing the controller and interface

void kb_init() { // 8042 initialization
    kb_clear_buffer();
    
    // Set config
    while(inb(0x64) & 0x01) {
        inb(0x60);
    }
    outb(0x64, 0x60); // Configuration byte
    while(inb(0x64) & 0x01) { 
        asm volatile ("nop"); 
    }
    outb(0x60, 0b01000101); // hex: 0x45: Interrupt on, system flag on and translation on
    
    while(inb(0x64) & 0x01) {
        inb(0x60);
    }
    outb(0x60, 0xFF); // Reset keyboard
    
    pic_enable_irq(1); // keyboard
}

void kb_interrupt_handle() {
    // Fill our buffer
    while(inb(0x64) & 0x01) { // While bit 0 is 1 (data available)
        // Future TODO - translation instead of doing raw key handling in functions
        uint8_t scancode = inb(0x60);
        // KB specific responses (non scancodes) 0xFA, 0xFE, 0xFA might mess up something. handling TODO
        
        kb_buffer[kb_buffer_write] = scancode;
        kb_buffer_write = (kb_buffer_write + 1) % KB_BUF_SIZE;
    }
    
    if (kb_stored_callback != NULL) {
        kb_stored_callback();
    }
}


void kb_set_callback(kb_callback_ptr func) {
    kb_stored_callback = func;
}


int kb_is_available() {
    if(kb_buffer_read!=kb_buffer_write) return 1;
    return 0;
}

uint8_t kb_get_scancode() {
    if(kb_buffer_read==kb_buffer_write) return 0;
    uint8_t s = kb_buffer[kb_buffer_read];
    kb_buffer_read = (kb_buffer_read + 1) % KB_BUF_SIZE;
    return s;
}

void kb_clear_buffer() {
    kb_buffer_read = 0;
    kb_buffer_write = 0;

    while(inb(0x64) & 0x01) {
        inb(0x60);
    }
}
