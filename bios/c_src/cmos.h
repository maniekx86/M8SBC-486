#ifndef CMOS_H
#define CMOS_H

#include <stdint.h>
#include "x86io.h"
#include "utils.h"

enum CMOS_SETTINGS {
	CMOS_QUICK_MEMTEST,
	CMOS_LBA_ENABLED,
	CMOS_LOCK_CMOS
};

uint8_t cmos_read(); // returns 0 if checksum was invalid
void cmos_save();

uint8_t cmos_get(enum CMOS_SETTINGS setting);
void cmos_set(enum CMOS_SETTINGS setting, uint8_t value);

void cmos_lock();

uint8_t cmos_is_m8sbc();
uint16_t cmos_chp_version();


#endif
