
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

#include "xil_io.h"
#include "xscugic.h"
#include "xgpio.h"
#include "xparameters.h"
#include "ff.h"
#include "xtime_l.h"
#include "sleep.h"
#include "xil_mmu.h"
#include "xil_cache.h"

#define DMA_LEAD 2

struct __attribute__((packed)) drive_configuration {
    uint16_t general_configuration[20];
    uint16_t specific_configuration[15];
};

struct __attribute__((packed)) emulation_header {
    uint16_t file_version;
    uint32_t drive_configuration_offset;
    uint32_t data_offset;
    uint16_t cylinders;
    uint16_t heads;
    uint16_t sectors_per_track;
    uint16_t sector_size_in_image;
};

static XGpio drive_gpio_inst;
static XGpio head_gpio_inst;

XScuGic interrupt_controller;
static XScuGic_Config *GicConfig;

volatile uint32_t* command_interface = (volatile uint32_t*) XPAR_AXI_ESDI_CMD_CONTROL_0_BASEADDR;
volatile uint32_t* sector_timer = 	   (volatile uint32_t*) XPAR_SECTOR_TIMER_0_BASEADDR;
volatile uint32_t* drive_select_gpio = (volatile uint32_t*) XPAR_GPIO_DRIVE_SELECT_BASEADDR;
volatile uint32_t* head_select_gpio =  (volatile uint32_t*) XPAR_GPIO_HEAD_SELECT_BASEADDR;
volatile uint32_t* dma =               (volatile uint32_t*) XPAR_AXI_DMA_0_BASEADDR;
volatile uint32_t* read_datapath =     (volatile uint32_t*) XPAR_READ_DATAPATH_0_BASEADDR;
volatile uint32_t* write_datapath =    (volatile uint32_t*) XPAR_WRITE_DATAPATH_0_BASEADDR;

static FATFS fatfs;

uint32_t descriptors[(0x40 * 128) / 4] __attribute__((aligned(0x40)));

#define EMULATION_FILE_ALIGNMENT 16
uint8_t buffers[1024 * 1224 * 16 * 36] __attribute__((aligned(EMULATION_FILE_ALIGNMENT)));

int cylinder_map[1224];

int current_drive_sel = 0;
int current_cylinder = 0;
int current_head = 0;
int head, tail;

uint16_t general_status;

int cylinder_size = 0;

struct emulation_header emu_header;
struct drive_configuration drive_conf;

bool print_location = false;

//bool seek_pending = false;
//int seek_release;

void command_interrupt_handler(void* arg) {
    if ((command_interface[1] & 0x2)) {
        uint32_t command = command_interface[2];

        uint32_t cmd = (command >> 12) & 0xf;
        uint32_t modifier = (command >> 8) & 0xf;
        uint32_t subscript = command & 0xff;

        if (cmd == 0x0) {
            current_cylinder = command & 0x0FFF;
            print_location = true;
//            seek_pending = true;
//            seek_release = tail;
            command_interface[3] = 0;
        } else if (cmd == 0x2) {
            command_interface[2] = general_status;
            command_interface[3] = 0;	// Clear the command pending bit
        } else if (cmd == 0x3) {
            if (modifier == 0) {
            	command_interface[2] = drive_conf.general_configuration[subscript] & 0xCFFE;
            } else {
                command_interface[2] = drive_conf.specific_configuration[modifier - 1];
            }
            command_interface[3] = 0;	// Clear the command pending bit
        } else if (cmd == 0x5) {
        	if (modifier == 0) {
        		general_status = 0;
        	}
        	command_interface[3] = 0;	// Clear the command pending bit
        }

    }
}

void drive_sel_interrupt_handler(void* arg) {
    if (XGpio_InterruptGetStatus(&drive_gpio_inst) & 0x1) {
        XGpio_InterruptClear(&drive_gpio_inst, 1);
        int new_dsel = drive_select_gpio[0];
        if (new_dsel != current_drive_sel) {
            current_drive_sel = new_dsel;
            if (new_dsel == 2) {
                command_interface[0] = 0xE;		// Enable interface
            } else {
                command_interface[0] = 0x0;		// Disable interface
            }
        }
    }
}

void head_sel_interrupt_handler(void* arg) {
    if (XGpio_InterruptGetStatus(&drive_gpio_inst) & 0x1) {
        XGpio_InterruptClear(&drive_gpio_inst, 1);
        int new_hsel = head_select_gpio[0];
        if (new_hsel != current_head) {
        	current_head = new_hsel;
        	print_location = true;
        }
    }
}

void dma_mm2s_interrupt_handler(void* arg) {

}

void write_datapath_interrupt_handler(void* arg) {
	if (write_datapath[1] & 0x2) {
		int sector_just_finished = write_datapath[2];
		write_datapath[1] = 0;		// Clear interrupt condition
	}
}

void dma_s2mm_interrupt_handler(void* arg) {

}


FRESULT list_dir(const char *path)
{
    FRESULT res;
    DIR dir;
    FILINFO fno;
    int nfile, ndir;


    res = f_opendir(&dir, path);                       /* Open the directory */
    if (res == FR_OK) {
        nfile = ndir = 0;
        for (;;) {
            res = f_readdir(&dir, &fno);                   /* Read a directory item */
            if (res != FR_OK || fno.fname[0] == 0) break;  /* Error or end of dir */
            if (fno.fattrib & AM_DIR) {            /* Directory */
                printf("   <DIR>   %s\n", fno.fname);
                ndir++;
            } else {                               /* File */
                printf("%10u %s\n", fno.fsize, fno.fname);
                nfile++;
            }
        }
        f_closedir(&dir);
        printf("%d dirs, %d files.\n", ndir, nfile);
    } else {
        printf("Failed to open \"%s\". (%u)\n", path, res);
    }
    return res;
}

void update_descriptor_addresses(int start, int stop) {

	if (current_cylinder >= 1224)
		return;

	int slot = cylinder_map[current_cylinder];

	if (slot == -1)
		return;

	for (int i = start; i < stop; i++) {
		int offset = (slot * cylinder_size) + (((current_head * emu_header.sectors_per_track) + i) * emu_header.sector_size_in_image);
		descriptors[((i * 0x40) + 0x08) >> 2] = (uint32_t) &buffers[offset];
	}
}

int main() {

	// Enable HW Cache Coherence for memory areas for use by DMA
	Xil_Out32(0xFD6E4000, 0x1);

	Xil_SetTlbAttributes((UINTPTR)descriptors, 0x605UL);
	uint32_t section = ((UINTPTR) buffers) / 0x100000U;
	while (((uint32_t) &buffers[(1024 * 1224 * 16 * 36) - 1]) >= (section * 0x100000U)) {
		Xil_SetTlbAttributes((UINTPTR) (section * 0x100000U), 0x605UL);
		section += 1;
	}

	dsb();

	sector_timer[0] = 0;
	write_datapath[0] = 2;

	if (command_interface[1] & 0x2) {
		uint32_t trash = command_interface[2];

	}

	// Setup GPIO HAL Driver
    XGpio_Initialize(&drive_gpio_inst, XPAR_GPIO_DRIVE_SELECT_DEVICE_ID);
    XGpio_Initialize(&head_gpio_inst, XPAR_GPIO_HEAD_SELECT_DEVICE_ID);

    // Configure Interrupts
    GicConfig = XScuGic_LookupConfig(XPAR_PSU_ACPU_GIC_DEVICE_ID);

    int status = XScuGic_CfgInitialize(&interrupt_controller, GicConfig, GicConfig->CpuBaseAddress);
    
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &interrupt_controller);

    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_ESDI_CMD_CONTROL_0_INTERRUPT_INTR, (Xil_InterruptHandler) command_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_GPIO_DRIVE_SELECT_IP2INTC_IRPT_INTR, (Xil_InterruptHandler) drive_sel_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_GPIO_HEAD_SELECT_IP2INTC_IRPT_INTR, (Xil_InterruptHandler) head_sel_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR, (Xil_InterruptHandler) dma_mm2s_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_WRITE_DATAPATH_0_INTERRUPT_INTR, (Xil_InterruptHandler) write_datapath_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR, (Xil_InterruptHandler) dma_s2mm_interrupt_handler, (void *) 0);

    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_ESDI_CMD_CONTROL_0_INTERRUPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_GPIO_DRIVE_SELECT_IP2INTC_IRPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_GPIO_HEAD_SELECT_IP2INTC_IRPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_WRITE_DATAPATH_0_INTERRUPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);

    XGpio_InterruptGlobalEnable(&drive_gpio_inst);
    XGpio_InterruptEnable(&drive_gpio_inst, 1);

    XGpio_InterruptGlobalEnable(&head_gpio_inst);
    XGpio_InterruptEnable(&head_gpio_inst, 1);

    Xil_ExceptionEnable();

    // Load Image from SD Card

    f_mount(&fatfs, "0:/", 1);

    list_dir("/");

    FIL image_file;
    FRESULT image_opened, fr_seek, fr_read;
    UINT bytes_read;

    image_opened = f_open(&image_file, "MICROP~1.EMU", FA_READ);

    if (image_opened != FR_OK) {
    	return 0;
    }

    fr_read = f_read(&image_file, (void*) &emu_header, sizeof(struct emulation_header), &bytes_read);

    if (bytes_read != sizeof(struct emulation_header)) {
    	return 0;
    }

    fr_seek = f_lseek(&image_file, emu_header.drive_configuration_offset);

    if (fr_seek) {
    	return 0;
    }

    fr_read = f_read(&image_file, (void*) &drive_conf, sizeof(struct drive_configuration), &bytes_read);

	if (bytes_read != sizeof(struct drive_configuration)) {
		return 0;
	}

	cylinder_size = emu_header.heads * emu_header.sectors_per_track * emu_header.sector_size_in_image;

	xil_printf("Emulation Header Loaded\r\n");

	fr_seek = f_lseek(&image_file, emu_header.data_offset);

	if (fr_seek) {
		return 0;
	}

    for (int i = 0; i < 1224; i++) {
    	if (i < 100)
    		cylinder_map[i] = i;
    	else
    		cylinder_map[i] = -1;
    }

	for (int i = 0; i < 100; i++) {
		fr_read = f_read(&image_file, (void*) &buffers[cylinder_size * i], cylinder_size, &bytes_read);
		if (fr_read || (bytes_read < cylinder_size)) {
			xil_printf("Failed to load cylinder %d\r\n", i);
		}
	}

	xil_printf("Loaded Data\r\n");

	// Configure hardware with emulation data

    command_interface[0] = 0x0001;	// Soft reset
    command_interface[0] = 0x0000;

    sector_timer[1] = 100000000 / 60 / emu_header.sectors_per_track;
    sector_timer[2] = emu_header.sectors_per_track;

    write_datapath[3] = drive_conf.specific_configuration[4] - 2;	// Unformatted bytes per sector

    general_status = 1 << 8;	// Power on condition

    // Prepare Descriptors

    for (int i = 0; i < emu_header.sectors_per_track; i++) {
    	uint32_t next_desc;
    	if (i == emu_header.sectors_per_track - 1)
    		next_desc = 0;
    	else
    		next_desc = i + 1;

    	descriptors[((i * 0x40) + 0x00) >> 2] = (uint32_t) &descriptors[(0x40 * next_desc) >> 2];
    	descriptors[((i * 0x40) + 0x18) >> 2] = (drive_conf.specific_configuration[4] - 2) | (3 << 26);
    	descriptors[((i * 0x40) + 0x1C) >> 2] = 0;
    }

    update_descriptor_addresses(0, emu_header.sectors_per_track);

    // Reset DMA
    dma[0] = 0x4;
    while(dma[0] & 0x04) {}

    // Set Head
    dma[0x08 >> 2] = (uint32_t) &descriptors[(0x40 * 0) >> 2];
    head = 0;

    // Run DMA
    dma[0x00 >> 2] = 0x1;
    while(dma[0x04 >> 2] & 0x01) {}

    // Set Tail
    dma[0x10 >> 2] = (uint32_t) &descriptors[(0x40 * (DMA_LEAD - 1)) >> 2];
    tail = DMA_LEAD - 1;

    write_datapath[0] = 0x5;
    sector_timer[0] = 1;		// Enable

    while(1) {
    	if (print_location) {
    		print_location = false;
    		printf("C=%d  H=%d\r\n", current_cylinder, current_head);
    	}

    	// Make local copy of current tail
		int x = tail;

		// Get the sector currently under the head
		int sector_now = sector_timer[3];

		// This is all modulo math, so this doesn't actually change the value of 'x'
		if (sector_now > x)
			x += emu_header.sectors_per_track;

		// Find out exactly how close we are to the reaching the tail
		// If the difference is two or less, then it's time to issue more descriptors
		if ((x - sector_now) >= DMA_LEAD)
			continue;

		// We are always trying to maintain the tail DMA_LEAD sectors ahead
		// of where we currently are.
		int new_tail = sector_now + DMA_LEAD;

		int i = x + 1;				// Initialize 'i' to the sector following the current tail
		while (i <= new_tail) {

			// Check the descriptors of sectors that we think have already
			// passed under the head (or are currently) for the complete bit
			// set in the status, just to be extra certain that we are not
			// having too many outstanding descriptors
			int y = (i - DMA_LEAD) % emu_header.sectors_per_track;
			if (!(descriptors[((y * 0x40) + 0x1C) >> 2] & (1 << 31)))
				break;

//			if (seek_pending && (seek_release == y)) {
//				command_interface[3] = 0;	// Clear the command pending bit
//				seek_pending = false;
//			}


			// Update the descriptors we are about to issue, by clearing
			// the complete bit and updating their buffer address
			y = i % emu_header.sectors_per_track;
			descriptors[((y * 0x40) + 0x1C) >> 2] = 0;
			//current_head = head_select_gpio[0];
			update_descriptor_addresses(y, y+1);

			// Update the tail register
			dma[0x10 >> 2] = (uint32_t) &descriptors[(0x40 * y) >> 2];
			tail = y;

			i += 1;
		}


    }

}
