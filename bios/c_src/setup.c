#include "setup.h"

enum bios_settings_setting {
	OPTION_EMPTY,
	OPTION_QUICK_MEMTEST,
	OPTION_LBA_REPORTING,
	OPTION_LOCK_CMOS,
	OPTION_OPEN_ABOUT
};


struct bios_settings_struct {
	enum bios_settings_setting setting;
	const char *option_name;
	const char *option_help;
};

static int select = 0;

#define SETTINGS_AMOUNT 5
static const struct bios_settings_struct bios_settings[SETTINGS_AMOUNT] =
{
	{OPTION_QUICK_MEMTEST, "Fast memory test", "This option enables quick memory test which reduces boot time."},
	{OPTION_LBA_REPORTING, "Enable LBA support reporting", "This option controls LBA support BIOS reporting (INT 13h ax=0x41)."},
	{OPTION_LOCK_CMOS, "Lock CMOS after boot", "Enabling this option locks CMOS 0x40-0x5F NVRAM area after boot."},
	{OPTION_EMPTY, "", ""},
	{OPTION_OPEN_ABOUT, "Open About", "SeaPig information and acknowledgments."}
};
// OPTION_EMPTY cant be used twice in a row, or be first or last


static void draw_option_text(const char* text, const char* value, int x, int y, int selected) {
	vga_print_string(text, x, y, 0x70);
	vga_print_char(':', x + 30, y, 0x70);
	vga_print_string(value, x + 32, y, (selected == 1) ? 0x1F : 0x70);
}


static void draw_options() {
	int y = 12;
	for(int i=0; i<SETTINGS_AMOUNT; i++) {
		const int x = 3;
		int selected = (select == i) ? 1 : 0;

		enum draw_type_enum {
			DRAW_NONE,
			DRAW_OPTION_ONLY,
			DRAW_YES_NO,
			DRAW_TEXT
		} draw_type;

		char draw_value[16];

		switch(bios_settings[i].setting) {
			case OPTION_QUICK_MEMTEST:
				draw_type = DRAW_YES_NO;
				draw_value[0] = cmos_get(CMOS_QUICK_MEMTEST) ? 1 : 0;
				break;
			case OPTION_LBA_REPORTING:
				draw_type = DRAW_YES_NO;
				draw_value[0] = cmos_get(CMOS_LBA_ENABLED) ? 1 : 0;
				break;
			case OPTION_LOCK_CMOS:
				draw_type = DRAW_YES_NO;
				draw_value[0] = cmos_get(CMOS_LOCK_CMOS) ? 1 : 0;
				break;
			case OPTION_OPEN_ABOUT:
				draw_type = DRAW_OPTION_ONLY;
				break;
			default:
				draw_type = DRAW_NONE;
				break;
		}

		switch(draw_type) {
			case DRAW_OPTION_ONLY:
				draw_option_text(bios_settings[i].option_name, "Enter", x, y, selected);
				break;
			case DRAW_YES_NO:
				strcpy(draw_value, (draw_value[0] == 1) ? "ON" : "OFF");
				draw_option_text(bios_settings[i].option_name, draw_value, x, y, selected);
				break;

			default:
				break;
		}

		y++;
	}
}

static uint16_t l_cpuid;
static int l_is_cyrix;
static int l_mem_total;
static int l_fpu_present;
static char *l_ide_name;
static int l_ide_detected;
static int l_is_m8sbc;
static int l_chp_version;
static int modified = 0;

static void draw_modified() {
	if(modified == 1) {
		vga_print_string("Settings modified", 61, 24, 0x0C);
	}
}

static void bios_redraw() {
	char print_buffer[40];

	vga_clear(0x70);

	vga_print_string("SeaPig BIOS Settings", 30, 0, 0x07);
	vga_print_string("UP/DOWN:Navigate  ESC:Exit  F1:Help  F10:Save", 1, 24, 0x0F);
	for(int x=0; x<80; x++) {
		vga_set_char_attr(0x2F, x, 0);
		vga_set_char_attr(0x0F, x, 24);
		vga_print_char('=', x, 23, 0x78);
		vga_print_char('-', x, 2, 0x78);
		vga_print_char('-', x, 10, 0x78);
	}
	vga_print_string("System info", 1, 2, 0x78);
	vga_print_string("Settings", 1, 10, 0x78);

	vga_print_string(" " VERSION " ", 80 - sizeof(" " VERSION " "), 23, 0x78);

	vga_print_string("Machine", 3, 4, 0x71);
	vga_print_string("CPU Model", 3, 5, 0x71);
	vga_print_string("FPU available", 3, 6, 0x71);
	vga_print_string("Memory available", 3, 7, 0x71);
	vga_print_string("Primary IDE", 3, 8, 0x71);

	vga_print_char(':', 33, 4, 0x71);
	vga_print_char(':', 33, 5, 0x71);
	vga_print_char(':', 33, 6, 0x71);
	vga_print_char(':', 33, 7, 0x71);
	vga_print_char(':', 33, 8, 0x71);

	if(l_is_m8sbc) {
		vga_print_string("M8SBC-486, chipset ver: ", 35, 4, 0x71);
		itoapad(l_chp_version, print_buffer, 16, 4);
		vga_print_string(print_buffer, 59, 4, 0x71);
	} else {
		vga_print_string("Unknown", 35, 4, 0x71);
	}

	detect_486_model(l_cpuid, l_is_cyrix, print_buffer, 1);

	vga_print_string(print_buffer, 35, 5, 0x71);
	vga_print_string((l_fpu_present == 1) ? "Yes" : "No", 35, 6, 0x71);

	itoa(l_mem_total, print_buffer, 10); // also clears str
	strcat(print_buffer, " KB");
	vga_print_string(print_buffer, 35, 7, 0x71);

	vga_print_string(l_ide_name, 35, 8, 0x71);

	draw_options();

	draw_modified();
}

static int dialog_yesno(int current, const char *msg) {
	int yn_select;
	int redraw;

	yn_select = current;

	// Draw box
	const int pos_x = 22;
	const int pos_y = 9;
	const int w = 36;
	const int h = 5;

	for(int x = pos_x; x < pos_x+w; x++) {
		for(int y = pos_y; y < pos_y+h; y++) {
			vga_print_char(' ', x, y, 0x1F);
			if(y == pos_y || y == pos_y+h-1) vga_print_char('=', x, y, 0x1F);
		}
	}

	int msg_x = 40 - (strlen(msg) / 2);

	vga_print_string(msg, msg_x, pos_y+1, 0x1F);

	redraw = 1;

	kb_clear_buffer();

	while(1) {
		static uint8_t extended = 0;
		if(redraw) {
			vga_print_string("[No]", pos_x+9, pos_y+3, (yn_select == 0) ? 0x5F : 0x1F );
			vga_print_string("[Yes]", pos_x+27-5, pos_y+3, (yn_select == 1) ? 0x5F : 0x1F );
			redraw = 0;
		}

		if(kb_is_available()) {
			uint8_t scancode = kb_get_scancode();
			if(!extended) {
				if(scancode==0x01) { // ESC
					return current;
				}
				if(scancode==0x1C) { // enter
					break;
				}
				if(scancode==0xE0) {
					extended = 1;
				}
			} else {
				if(scancode==0x4B) { // left arrow
					yn_select = 0;
					redraw = 1;
				}
				if(scancode==0x4D) { // right arrow
					yn_select = 1;
					redraw = 1;
				}
				extended = 0;
			}
		}
	}
	return yn_select;
}

static void dialog_text(const char* title, const char* text) {

	// Draw box
	const int pos_x = 18;
	const int pos_y = 7;
	const int w = 44;
	const int h = 10;

	for(int x = pos_x; x < pos_x + w; x++) {
		for(int y = pos_y; y < pos_y + h; y++) {
			vga_print_char(' ', x, y, 0x1F);
			if(y == pos_y || y == pos_y + h - 1) vga_print_char('=', x, y, 0x1F);
		}
	}

	int title_x = 40 - ((int)strlen(title) / 2);
	vga_print_string(title, title_x, pos_y, 0x1F);

	// text area inside the box (leave 1 char margin)
	const int text_x0 = pos_x + 1;
	const int text_y0 = pos_y + 2;
	const int text_w  = w - 2;
	const int text_h  = h - 3; // title line + bottom border

	// clear text area
	for(int y = 0; y < text_h; y++) {
		for(int x = 0; x < text_w; x++) {
			vga_print_char(' ', text_x0 + x, text_y0 + y, 0x1F);
		}
	}

	// word-wrapping text printer:
	int i = 0;
	int cx = 0;
	int cy = 0;

	while(text[i] != '\0' && cy < text_h) {
		// Skip leading spaces (but still allow explicit newlines)
		while(text[i] == ' ') i++;

		if(text[i] == '\n') {
			cx = 0;
			cy++;
			i++;
			continue;
		}

		if(text[i] == '\0') break;

		// Determine next "word" length (until space/newline/NUL)
		int wlen = 0;
		while(text[i + wlen] != '\0' && text[i + wlen] != ' ' && text[i + wlen] != '\n')
			wlen++;

		if(wlen == 0) {
			i++;
			continue;
		}

		// If word doesn't fit on this line, go to next line (if not at line start)
		if(cx != 0 && (cx + 1 + wlen) > text_w) {
			cx = 0;
			cy++;
			continue;
		}

		// Add a separating space if needed
		if(cx != 0) {
			if(cx < text_w) {
				vga_print_char(' ', text_x0 + cx, text_y0 + cy, 0x1F);
				cx++;
			} else {
				cx = 0;
				cy++;
				continue;
			}
		}

		// Print the word; if it's too long, split across lines
		int printed = 0;
		while(printed < wlen && cy < text_h) {
			if(cx >= text_w) {
				cx = 0;
				cy++;
				if(cy >= text_h) break;
			}
			vga_print_char(text[i + printed], text_x0 + cx, text_y0 + cy, 0x1F);
			cx++;
			printed++;
		}

		i += wlen;
	}

	for(int x=0; x < 80; x++) {
		vga_print_char(' ', x, 24, 0x0F);
	}
	draw_modified();
	vga_print_string("ESC or Enter to continue", 1, 24, 0x0F);

	kb_clear_buffer();

	// Wait for ESC/ENTER to close
	while(1) {
		if(kb_is_available()) {
			uint8_t scancode = kb_get_scancode();
			if(scancode == 0x01 || scancode == 0x1C) { // ESC or Enter
				break;
			}
		}
	}
}

void setup_display(uint16_t cpuid, int is_cyrix, int mem_total, int fpu_present, char *ide_name, int ide_detected) {

	l_cpuid = cpuid;
	l_is_cyrix = is_cyrix;
	l_mem_total = mem_total;
	l_fpu_present = fpu_present;
	l_ide_name = ide_name;
	l_ide_detected = ide_detected;

	l_is_m8sbc = cmos_is_m8sbc();
	if(l_is_m8sbc) {
		l_chp_version = cmos_chp_version();
	} else {
		l_chp_version = 0;
	}

	l_ide_name[38] = '\0'; // trim too long name


	bios_redraw();

	if(ide_detected == 0) {
		dialog_text("Warning", "The system did not detect any IDE hard drives. You may attempt to continue booting by exiting this setup, but it is likely to result in failure.");
		bios_redraw();
	}

	kb_clear_buffer();

	while(1) {
		static uint8_t extended = 0;

		if(kb_is_available()) {
			uint8_t scancode = kb_get_scancode();

			if(!extended) {
				if(scancode==0x01) { // ESC
					if(modified == 1) {
						if(dialog_yesno(0, "Exit without saving?")) break;
						bios_redraw();
					} else {
						break;
					}
				}

				if(scancode==0xE0) {
					extended = 1;
				}

				if(scancode==0x1C) { // Enter
					char option_value[16] = {0}; // old & new
					enum OPTION_TYPE_ENUM {
						OPTION_TYPE_OTHER,
						OPTION_TYPE_YESNO
					} OPTION_TYPE;

					// Option fetch

					switch(bios_settings[select].setting) {
						case OPTION_QUICK_MEMTEST:
							OPTION_TYPE = OPTION_TYPE_YESNO;
							option_value[0] = cmos_get(CMOS_QUICK_MEMTEST);
							break;
						case OPTION_LBA_REPORTING:
							OPTION_TYPE = OPTION_TYPE_YESNO;
							option_value[0] = cmos_get(CMOS_LBA_ENABLED);
							break;
						case OPTION_LOCK_CMOS:
							OPTION_TYPE = OPTION_TYPE_YESNO;
							option_value[0] = cmos_get(CMOS_LOCK_CMOS);
							break;
						case OPTION_OPEN_ABOUT:
							OPTION_TYPE = OPTION_TYPE_OTHER;
							break;

						default:
							OPTION_TYPE = OPTION_TYPE_OTHER;
							break;
					}

					// Option change

					if(OPTION_TYPE == OPTION_TYPE_YESNO) {
						uint8_t old_option_val = option_value[0];
						option_value[0] = dialog_yesno(option_value[0], bios_settings[select].option_name);
						if(old_option_val!=option_value[0]) modified = 1;
					}

					// Option update / action

					switch(bios_settings[select].setting) {
						case OPTION_QUICK_MEMTEST:
							cmos_set(CMOS_QUICK_MEMTEST, option_value[0]);
							break;
						case OPTION_LBA_REPORTING:
							cmos_set(CMOS_LBA_ENABLED, option_value[0]);
							break;
						case OPTION_LOCK_CMOS:
							cmos_set(CMOS_LOCK_CMOS, option_value[0]);
							break;
						case OPTION_OPEN_ABOUT:
							about_display();
							break;

						default:
							break;
					}

					bios_redraw();
				}

				if(scancode==0x3B) { // F1 help
					dialog_text(bios_settings[select].option_name, bios_settings[select].option_help);
					bios_redraw();
				}

				if(scancode==0x44) { // F10 save
					if(dialog_yesno(0, "Save settings to CMOS?")) {
						cmos_save();
						modified = 0;
					}
					bios_redraw();
				}
			} else {
				extended = 0;

				if(scancode==0x48) { // up arrow
					if(select>0) {
						select--;
						if(bios_settings[select].setting == OPTION_EMPTY) select--;
						draw_options();
					}

				}
				if(scancode==0x50) { // down arrow
					if(select<(SETTINGS_AMOUNT-1)) {
						select++;
						if(bios_settings[select].setting == OPTION_EMPTY) select++;
						draw_options();
					}

				}
			}

		}
	}

}
