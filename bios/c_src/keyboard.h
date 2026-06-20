#ifndef KEYBOARD_H
#define KEYBOARD_H

#include <stdint.h>
#include "interrupts.h"
#include "x86io.h"

#ifndef NULL
#define NULL 0
#endif

#define KB_BUF_SIZE 8

void kb_init();

void kb_interrupt_handle();

int kb_is_available();
uint8_t kb_get_scancode();
void kb_clear_buffer();

typedef void (*kb_callback_ptr)(void);
void kb_set_callback(kb_callback_ptr func);

#endif
