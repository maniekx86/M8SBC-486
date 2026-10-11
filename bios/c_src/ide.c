#include "ide.h"
#include "cmos.h"

static uint16_t disk_data[256];

void IDE_reset() {
    // Hardware RESET signal has already initialized the drives
    // Issuing a software reset (SRST) here can cause mismatched drives 
    // to hang indefinitely waiting for the PDIAG- handshake
    // Instead, we just wait for BSY to clear during the detection phase
}

int IDE_wait_busy(int timeout) {
    uint32_t start_ticks = irq0_ticks;
    while(1) {
        if(irq0_ticks > start_ticks+timeout) return 0;
        uint8_t status = inb(IDE_STATUS);
        if(status == 0xFF) return 0; // Floating bus, drive absent
        if(!(status & 0x80)) break;
        asm volatile("nop");
        io_wait();
    }
    return 1;
}


void IDE_set_drive_bda(int drive, uint16_t cyls, uint8_t heads, uint8_t sectors, uint8_t lba_support, uint32_t lba_cap) {
    uint16_t log_cyls = cyls;
    uint8_t log_heads = heads;
    uint8_t log_sectors = sectors;

    // Check if LBA is enabled
    if (!cmos_get(CMOS_LBA_SUPPORT)) {
        lba_support = 0;
    }

    // Translation logic for >504MB (1032192 sectors / 528482304 bytes)
    if (lba_support && lba_cap > 1032192 && cmos_get(CMOS_LBA_TRANSLATION)) {
        log_sectors = 63;
        log_heads = 255;
        uint32_t c = lba_cap / (255 * 63);
        if (c > 1024) c = 1024;
        log_cyls = c;
    }
    
    // if not using translation, cap physical cylinders at 1024 for int 13h compatibility
    // (though OSes using native LBA might want the full cylinder count, int 13h CHS limits it)
    if (!(lba_support && lba_cap > 1032192 && cmos_get(CMOS_LBA_TRANSLATION))) {
        if (log_cyls > 1024) log_cyls = 1024;
    }

    // BDA
    volatile uint8_t *lba_ptr = (uint8_t*)(0x4C3 + drive);
    volatile uint16_t *cyls_ptr = (uint16_t*)(0x4C5 + drive * 2);
    volatile uint8_t *heads_ptr = (uint8_t*)(0x4C9 + drive);
    volatile uint8_t *secs_ptr = (uint8_t*)(0x4CB + drive);
    volatile uint8_t *fdpt = (uint8_t*)(0x4CD + drive * 16);

    *lba_ptr = lba_support;
    *cyls_ptr = log_cyls;
    *heads_ptr = log_heads;
    *secs_ptr = log_sectors;

    // FDPT
    fdpt[0] = (log_cyls - 1) & 0xFF;
    fdpt[1] = ((log_cyls - 1) >> 8) & 0xFF;
    fdpt[2] = log_heads > 0 ? log_heads - 1 : 0;
    fdpt[3] = 0;
    fdpt[4] = 0;
    fdpt[5] = 0;
    fdpt[6] = 0;
    fdpt[7] = 0;
    fdpt[8] = 0xC0; // retries/ECC off
    fdpt[9] = 0;
    fdpt[10] = 0;
    fdpt[11] = 0;
    fdpt[12] = 0;
    fdpt[13] = 0;
    fdpt[14] = log_sectors;
    fdpt[15] = 0;
}


int IDE_detect(int drive_index, char *drive_name, uint16_t *cyls, uint8_t *heads, uint8_t *sectors, uint8_t *lba_support, uint32_t *lba_capacity) {
    if (drive_index == 0) outb(IDE_NUM3, 0xA0); // select master drive
    else outb(IDE_NUM3, 0xB0); // select slave drive
    io_wait();
    outb(IDE_COMMAND, 0xEC); // IDENTIFY command
    io_wait();

    memset(drive_name, 0, 41);

    uint32_t irq0_start = irq0_ticks;

    while(1) {
        io_wait();
        uint8_t status = inb(IDE_STATUS);

        uint32_t elapsed = irq0_ticks - irq0_start;
        if(elapsed > 550) return 0; // 5.5 seconds
        // TODO: add skip key?

        static uint32_t last_ticks = 0;
        if(last_ticks != irq0_ticks) { // to not redraw every few cpu cycles
            vga_print_itoa(elapsed / 100, 20+13, 12 + drive_index, 0x07, 10, 0);
            last_ticks = irq0_ticks;
        }

        if(!(status & 0x80) && (status & 8)) {
            break;
        }
    }

    for(int i=0;i<256;i++) {
        disk_data[i] = inw(IDE_DATA);
        io_wait();
    }

    // Check sanity of the data
    int check = 1;
    
    // Floating or empty bus
    if(disk_data[0] == 0x0000 || disk_data[0] == 0xFFFF) check = 0;
    
    if((disk_data[0] & 0x8000) != 0) { // ATA bit 15
        if (disk_data[0] != 0x848A) { // CF ident
            check = 0; // it's likely ATAPI (CD-ROM) or garbage, not an ATA HDD/CF
        }
    }

    for(int i=0;i<20;i++) {
        // Swap name bytes
        drive_name[i*2] = (disk_data[27 + i] >> 8) & 0xFF;
        drive_name[i*2 + 1] = disk_data[27 + i] & 0xFF;
    }
    // Check if name is in ASCII printable range
    for(int i=0;i<40;i++) {
        if( !(( (uint8_t)drive_name[i] >= 32 && (uint8_t)drive_name[i] <= 127 ) || (uint8_t)drive_name[i] == 0) ) check = 0;
    }
    // Check if all data is not the same
    uint16_t f = disk_data[0];
    int fc = 0;
    for(int i=0;i<256;i++) {
        if(disk_data[i]==f) fc++;
    }
    if(fc>=255) check = 0;

    // Return info, TODO: move to struct?
    if (check) {
        if (cyls) *cyls = disk_data[1];
        if (heads) *heads = disk_data[3];
        if (sectors) *sectors = disk_data[6];
        if (lba_support) *lba_support = (disk_data[49] & (1 << 9)) ? 1 : 0;
        if (lba_capacity) {
            *lba_capacity = ((uint32_t)disk_data[61] << 16) | disk_data[60];
        }
    }

    return check;
}
