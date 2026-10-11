#include "cmos.h"

static uint8_t cmos_data[32];

#define CMOS_BASE 0x40

uint8_t cmos_read() {
    uint8_t cmos_checksum = 0;
    for(int i=0; i<31; i++) {
        outb(0x70, CMOS_BASE + i);
        cmos_data[i] = inb(0x71);
        cmos_checksum += cmos_data[i]; // cmos_checksum skips 0x1F
    }
    outb(0x70, CMOS_BASE + 0x1F);
    cmos_data[31] = inb(0x71);

    if(cmos_checksum != cmos_data[31]) {
        memset(cmos_data, 0, 32);
        cmos_save();
        return 0;
    }
    
    return 1;
}

void cmos_save() {
    uint8_t cmos_checksum = 0;

    for(int i=0; i<31; i++) {
        outb(0x70, CMOS_BASE + i);
        outb(0x71, cmos_data[i]);
        cmos_checksum += cmos_data[i];
    }
    outb(0x70, CMOS_BASE + 0x1F);
    outb(0x71, cmos_checksum);
}


uint8_t cmos_get(enum CMOS_SETTINGS setting) {
    switch(setting) {

        case CMOS_QUICK_MEMTEST:
            if((cmos_data[0] & 0b00000001) > 0) return 1;
            return 0;

        case CMOS_LBA_SUPPORT:
            if((cmos_data[0] & 0b00000010) > 0) return 1;
            return 0;

        case CMOS_LOCK_CMOS:
            if((cmos_data[0] & 0b00000100) > 0) return 1;
            return 0;

        case CMOS_FIRST_BOOT_DRIVE:
            if((cmos_data[0] & 0b00001000) > 0) return 1;
            return 0;

        case CMOS_LBA_TRANSLATION:
            if((cmos_data[0] & 0b00010000) > 0) return 1;
            return 0;
            
        case CMOS_HDD_MASTER_DISABLE:
            if((cmos_data[0] & 0b00100000) > 0) return 1;
            return 0;
            
        case CMOS_HDD_SLAVE_DISABLE:
            if((cmos_data[0] & 0b01000000) > 0) return 1;
            return 0;

        default:
            return 0;
    }
}

void cmos_set(enum CMOS_SETTINGS setting, uint8_t value) {
    switch(setting) {

        case CMOS_QUICK_MEMTEST:
            if(value > 0) {
                cmos_data[0] |=  0b00000001;
            } else {
                cmos_data[0] &= ~0b00000001;
            }
            break;
        
        case CMOS_LBA_SUPPORT:
            if(value > 0) {
                cmos_data[0] |=  0b00000010;
            } else {
                cmos_data[0] &= ~0b00000010;
            }
            break;

        case CMOS_LOCK_CMOS:
            if(value > 0) {
                cmos_data[0] |=  0b00000100;
            } else {
                cmos_data[0] &= ~0b00000100;
            }
            break;

        case CMOS_FIRST_BOOT_DRIVE:
            if(value > 0) {
                cmos_data[0] |=  0b00001000;
            } else {
                cmos_data[0] &= ~0b00001000;
            }
            break;

        case CMOS_LBA_TRANSLATION:
            if(value > 0) {
                cmos_data[0] |=  0b00010000;
            } else {
                cmos_data[0] &= ~0b00010000;
            }
            break;
            
        case CMOS_HDD_MASTER_DISABLE:
            if(value > 0) {
                cmos_data[0] |=  0b00100000;
            } else {
                cmos_data[0] &= ~0b00100000;
            }
            break;
        
        case CMOS_HDD_SLAVE_DISABLE:
            if(value > 0) {
                cmos_data[0] |=  0b01000000;
            } else {
                cmos_data[0] &= ~0b01000000;
            }
            break;

        default:
            break;
    }
}

void cmos_lock() {
    outb(0x70, 0xFF);
    outb(0x71, 0x17);
}


uint8_t cmos_is_m8sbc() {
    uint8_t b1, b2;
    
    outb(0x70, 0xFC);
    b1 = inb(0x71);
    outb(0x70, 0xFD);
    b2 = inb(0x71);

    if(b1 == 0x48 && b2 == 0x86) return 1;
    return 0;
}

uint16_t cmos_chp_version() {
    uint8_t b1, b2;

    outb(0x70, 0xFE);
    b1 = inb(0x71);
    outb(0x70, 0xFF);
    b2 = inb(0x71);

    return (uint16_t)((b1<<8) | (b2 & 0xFF));
}
