#include "interrupts.h"

static uint8_t pic_mask;

/* --- Structures --- */
struct idt_entry_t {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t  zero;
    uint8_t  type_attr;
    uint16_t offset_high;
} __attribute__((packed));

struct idtr_t {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

// idt
struct idt_entry_t idt[64];
static struct idtr_t idtr;
static struct idtr_t real_mode_idtr;

// wrappers from entry.asm
extern void isr_irq0(void);
extern void isr_irq1(void);

void set_idt_gate(int n, uint32_t handler) {
    idt[n].offset_low = handler & 0xFFFF;
    idt[n].selector = 0x08; // Code Segment
    idt[n].zero = 0;
    idt[n].type_attr = 0x8E; // 32-bit Interrupt Gate
    idt[n].offset_high = (handler >> 16) & 0xFFFF;
}

void idt_init(void) {
    // remap PIC
    pic_remap(0x20);

    // set idt
    set_idt_gate(0x20, (uint32_t)isr_irq0);
    set_idt_gate(0x21, (uint32_t)isr_irq1);

    // IDT load
    idtr.limit = sizeof(idt) - 1;
    idtr.base  = (uint32_t)&idt;

    // "memory" constraint tells compiler we are reading from idtr memory
    __asm__ volatile("lidt %0" : : "m"(idtr));
}

void pic_remap(int offset1) {
    
    outb(0x20, 0x11); io_wait();
    outb(0x21, offset1); io_wait();
    outb(0x21, 0); io_wait(); // no slave
    outb(0x21, 0x01); io_wait();
    outb(0x21, 0xFF); // all IRQ masked
    pic_mask = 0xFF;

    outb(0x20, 0x20); // clear
}

void idt_restore_real_mode(void) {
    // restore IDT for real mode 
        
    real_mode_idtr.base = 0x00000000;
    real_mode_idtr.limit = 0x3FF;

    __asm__ volatile("lidt %0" : : "m"(real_mode_idtr));
}

void pit_set_int_freq(uint32_t freq) {
    // Configure PIT
    uint32_t divisor = 1193180 / freq;
    outb(0x43, 0x36); // Command port
    outb(0x40, divisor & 0xFF); // Low byte
    outb(0x40, (divisor >> 8) & 0xFF); // High byte
}

void pic_set_mask(uint8_t mask) {
    pic_mask = mask;
    outb(0x21, mask);
}
void pic_enable_irq(uint8_t irq) { // Mask must be set prior to calling these two funcs
    pic_mask &= ~(0x1 << irq);
    outb(0x21, pic_mask);
}
void pic_disable_irq(uint8_t irq) {
    pic_mask |= (0x1 << irq);
    outb(0x21, pic_mask);
}



////// interrupt handlers

uint32_t irq0_ticks = 0;


void c_isr_irq0() { // Timer tick
    irq0_ticks++;
}


void c_isr_irq1() { // Keyboard input
    kb_interrupt_handle();
}


