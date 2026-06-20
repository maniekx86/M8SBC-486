#ifndef INTERRUPTS_H
#define INTERRUPTS_H

#include <stdint.h>
#include "keyboard.h"
#include "x86io.h"

// Initialize the IDT and load it
void idt_init(void);

void pic_remap(int offset1);

void idt_restore_real_mode(void);

static inline void sti() {
	asm volatile ("sti");
}
static inline void cli() {
	asm volatile ("cli");
}

void pic_set_mask(uint8_t mask);
void pic_enable_irq(uint8_t irq);
void pic_enable_irq(uint8_t irq);

//static inline void pic_set_mask(uint8_t mask) { // old
//    outb(0x21, mask);
//}

void pit_set_int_freq(uint32_t freq);

void c_isr_irq0();
void c_isr_irq1();


extern uint32_t irq0_ticks;

#endif
