#ifndef IDE_H
#define IDE_H

#include <stdint.h>
#include "x86io.h"
#include "utils.h"
#include "vga.h"
#include "interrupts.h"

#define IDE_DATA 0x1F0
#define IDE_SEC_COUNT 0x1F2
#define IDE_NUM0 0x1F3
#define IDE_NUM1 0x1F4
#define IDE_NUM2 0x1F5
#define IDE_NUM3 0x1F6
#define IDE_COMMAND 0x1F7
#define IDE_STATUS 0x1F7

#define IDE_DEV_CONTROL 0x3F6

void IDE_reset();
int IDE_wait_busy(int timeout);
int IDE_detect(int drive_index, char *drive_name, uint16_t *cyls, uint8_t *heads, uint8_t *sectors, uint8_t *lba_support, uint32_t *lba_capacity);
void IDE_set_drive_bda(int drive, uint16_t cyls, uint8_t heads, uint8_t sectors, uint8_t lba_support, uint32_t lba_cap);

#endif
