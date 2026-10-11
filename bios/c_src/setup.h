#ifndef SETUP_H
#define SETUP_H

#include <stdint.h>
#include "x86io.h"
#include "utils.h"
#include "cpudetect.h"
#include "vga.h"
#include "interrupts.h"
#include "ide.h"
#include "cmos.h"
#include "about.h"

void setup_display(uint16_t cpuid, int is_cyrix, int mem_total, int fpu_present, char *ide_master_name, char *ide_slave_name, int ide_detected);

#endif
