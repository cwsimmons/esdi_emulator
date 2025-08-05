
/* 

    Copyright 2025 Christopher Simmons

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the Free
  Software Foundation, either version 2 of the License, or (at your option)
  any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <https://www.gnu.org/licenses/>.

*/

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

#define HW_FREQ			100000000
#define DMA_LEAD 1		// The number of read DMA (mm2s) descriptors
						// that we let the DMA lead the head position by
#define MAX_SUPPORTED_CYLINDERS		1224
#define MAX_SUPPORTED_SECTORS		128
#define WORST_CASE_NUM_SLOTS		100
#define DATA_BUFFER_SIZE			(1024 * WORST_CASE_NUM_SLOTS * 16 * MAX_SUPPORTED_SECTORS)
#define NUM_WRITE_DESCRIPTORS 		8
#define DIRTY_QUEUE_SIZE 			256
#define PRELOAD_CYLINDERS			100

/* ESDI Emulation File Definition */

#define EMULATION_FILE_ALIGNMENT 16

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

// Sector address struct
struct chs {
	int c;
	int h;
	int s;
};

/* Xilinx Driver Instances */
static XGpio drive_gpio_inst;
static XGpio head_gpio_inst;

XScuGic interrupt_controller;
static XScuGic_Config *GicConfig;
static FATFS fatfs;

/* Memory Mapped Hardware Registers */
volatile uint32_t* command_interface = (volatile uint32_t*) XPAR_AXI_ESDI_CMD_CONTROL_0_BASEADDR;
volatile uint32_t* sector_timer = 	   (volatile uint32_t*) XPAR_SECTOR_TIMER_0_BASEADDR;
volatile uint32_t* drive_select_gpio = (volatile uint32_t*) XPAR_GPIO_DRIVE_SELECT_BASEADDR;
volatile uint32_t* head_select_gpio =  (volatile uint32_t*) XPAR_GPIO_HEAD_SELECT_BASEADDR;
volatile uint32_t* dma =               (volatile uint32_t*) XPAR_AXI_DMA_0_BASEADDR;
volatile uint32_t* read_datapath =     (volatile uint32_t*) XPAR_READ_DATAPATH_0_BASEADDR;
volatile uint32_t* write_datapath =    (volatile uint32_t*) XPAR_WRITE_DATAPATH_0_BASEADDR;

// DMA Stuff
uint32_t descriptors[(0x40 * MAX_SUPPORTED_SECTORS) / 4] __attribute__((aligned(0x40))); // Aligned because Xilinx DMA requires it.
uint32_t write_descriptors[(0x40 * NUM_WRITE_DESCRIPTORS) / 4] __attribute__((aligned(0x40)));

struct chs write_descriptor_chs[NUM_WRITE_DESCRIPTORS];  // Keep track of the CHS address of each write descriptor
int current_write_descriptor;			// Index of the write descriptor that will be used next
int last_unacked_write_descriptor;		// Index of the write descriptor we expect to complete next

// Storage for emulated sector data
uint8_t buffers[DATA_BUFFER_SIZE] __attribute__((aligned(EMULATION_FILE_ALIGNMENT))); // AXI DMA requires alignment of at least 4

// The data in 'buffers' is divided into slots, each slot holds a cylinder.
// This array holds the mapping from cylinder to slot number
int num_slots;
int cylinder_map[MAX_SUPPORTED_CYLINDERS];

// Current state as driven by the controller
int current_drive_sel = 0;
int current_cylinder = 0;
int current_head = 0;

// Global State Variables
int tail;	// The index of the read descriptor which is currently pointed by MM2S_TAILDESC

// These variables form a pipeline which is advanced in the sector timer interrupt routine
// Their purpose is to keep track of the sector that was actually read out long enough to
// be used when a sector is written.
int next_cyl = 0;
int next_head = 0;
int last_cyl = 0;
int last_head = 0;

// Once sectors are written to memory, their address is enqueued here
int dirty_queue_head = 0;
int dirty_queue_tail = 0;
struct chs dirty_queue[DIRTY_QUEUE_SIZE];

// The general status which is returned to the ESDI controller
uint16_t general_status;

// The size of a cylinder derived from the emulation file
int cylinder_size = 0;

// Info pulled from the emulation file
struct emulation_header emu_header;
struct drive_configuration drive_conf;

// Whether the main loop should print the current cylinder and head
bool print_location = false;

// Head and cylinder changes will immediately silence the read datapath.
// These flags are used to keep track of when this happens
bool seek_pending = false;
bool head_change_pending = false;
int seek_release;

// Handle for commands and configuration/status queries from the ESDI controller
void command_interrupt_handler(void* arg) {
	// Check that there is actually a command pending
    if ((command_interface[1] & 0x2)) {
        uint32_t command = command_interface[2];

        uint32_t cmd = (command >> 12) & 0xf;
        uint32_t modifier = (command >> 8) & 0xf;
        uint32_t subscript = command & 0xff;

        if (cmd == 0x0) {	// Seek
            current_cylinder = command & 0x0FFF;
            print_location = true;
            seek_pending = true;
            seek_release = tail;
            read_datapath[0] = 1;
            command_interface[3] = 0;
        } else if (cmd == 0x1) {	// recalibrate
        	command_interface[3] = 0;	// Clear the command pending bit
        } else if (cmd == 0x2) {	// Request Status
            command_interface[2] = general_status;
            command_interface[3] = 0;	// Clear the command pending bit
        } else if (cmd == 0x3) {	// Request Configuration
            if (modifier == 0) {
            	// Mask out support for track offset and data strobe offset support.
            	command_interface[2] = drive_conf.general_configuration[subscript] & 0xCFFE;
            } else {
                command_interface[2] = drive_conf.specific_configuration[modifier - 1];
            }
            command_interface[3] = 0;	// Clear the command pending bit
        } else if (cmd == 0x5) {	// "Control"
        	if (modifier == 0) {	// 		Reset interface attention and standard status
        		general_status = 0;
        	}
        	command_interface[3] = 0;	// Clear the command pending bit
        }
    }
}

// Update hardware registers when the drive is [un]selected
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

// Silence the read datapath when the head changes
void head_sel_interrupt_handler(void* arg) {
    if (XGpio_InterruptGetStatus(&head_gpio_inst) & 0x1) {
        XGpio_InterruptClear(&head_gpio_inst, 1);
        int new_hsel = head_select_gpio[0];
        if (new_hsel != current_head) {
        	current_head = new_hsel;
        	print_location = true;
        	read_datapath[0] = 1;
        	head_change_pending = true;
        	seek_release = tail;
        }
    }
}

// Unused / Never Enabled
void dma_mm2s_interrupt_handler(void* arg) {

}

// Write Datapath Interrupt Routine
void write_datapath_interrupt_handler(void* arg) {
	uint32_t write_datapath_status = write_datapath[1];
	if (write_datapath_status & 0x2) {		// Check that the interrupt actually occurred
		if (write_datapath_status & 0x4) {	// Check if a sector has been written
			int sector_just_finished = write_datapath[2];	// Get the physical sector number of the new sector

			// Store the CHS for later when we go to write it into the file
			write_descriptor_chs[current_write_descriptor].c  = last_cyl;
			write_descriptor_chs[current_write_descriptor].h  = last_head;
			write_descriptor_chs[current_write_descriptor].s  = sector_just_finished;

			// Determine the address where the sector should be written to in memory
			int slot = cylinder_map[last_cyl];
			int offset = (slot * cylinder_size) + (((last_head * emu_header.sectors_per_track) + sector_just_finished) * emu_header.sector_size_in_image);

			// Update a write descriptor to use now
			write_descriptors[((current_write_descriptor * 0x40) + 0x08) >> 2] = (uint32_t) (intptr_t) &buffers[offset];
			write_descriptors[((current_write_descriptor * 0x40) + 0x1C) >> 2] = 0;

			// Update the DMA tail descriptor pointer
			dma[0x40 >> 2] = (uint32_t) (intptr_t) &write_descriptors[(current_write_descriptor * 0x40) >> 2];

			// Increment write descriptor index
			current_write_descriptor += 1;
			if (current_write_descriptor == NUM_WRITE_DESCRIPTORS) {
				current_write_descriptor = 0;
			}
		}
		write_datapath[1] = 0;		// Clear interrupt condition
	}
}

// S2MM DMA Interrupt Handler. Enabled for completed descriptors only (IOC_IrqEn = 1)
void dma_s2mm_interrupt_handler(void* arg) {
	if (dma[0x34 >> 2] & (1 << 12)) {	// Check for interrupt condition
		dma[0x34 >> 2] = (1 << 12);		// Clear interrupt

		// Get the status of the descriptor we expect to compete next
		uint32_t desc_status = write_descriptors[((last_unacked_write_descriptor * 0x40) + 0x1C) >> 2];
		if (desc_status & (1 << 31)) {	// If the descriptor has completed

			// Check for space in the dirty queue
			if (((dirty_queue_tail + 1) % DIRTY_QUEUE_SIZE) != dirty_queue_head) {
				// Enqueue the dirty sector's address
				dirty_queue[dirty_queue_tail] = write_descriptor_chs[last_unacked_write_descriptor];
				dirty_queue_tail = (dirty_queue_tail + 1) % DIRTY_QUEUE_SIZE;
			} else {
				printf("X");
			}

			// Increment
			last_unacked_write_descriptor += 1;
			if (last_unacked_write_descriptor == NUM_WRITE_DESCRIPTORS) {
				last_unacked_write_descriptor = 0;
			}
		}
	}
}

// Update the address in read DMA descriptors to match the current cylinder/head
void update_descriptor_addresses(int start, int stop) {

	if (current_cylinder >= MAX_SUPPORTED_CYLINDERS)
		return;

	int slot = cylinder_map[current_cylinder];

	if (slot == -1)
		return;

	for (int i = start; i < stop; i++) {
		int offset = (slot * cylinder_size) + (((current_head * emu_header.sectors_per_track) + i) * emu_header.sector_size_in_image);
		descriptors[((i * 0x40) + 0x08) >> 2] = (uint32_t) (intptr_t) &buffers[offset];
	}
}

// Sector Timer Interrupt Routine
// This interrupt fires 15us before the end of each sector. This is when we determine
// what sector will be read out next.
void sector_timer_interrupt_handler(void* arg) {
	uint32_t status = sector_timer[0];		// Reading this register has the side effect of clearing the interrupt condition
	(void) status;

	// Advance pipeline
	last_cyl = next_cyl;
	last_head = next_head;

	next_cyl = current_cylinder;
	next_head = current_head;

	// Make local copy of current tail
	int x = tail;

	// Get the sector currently under the head
	int sector_now = sector_timer[3];

	// This is all modulo math, so this doesn't actually change the value of 'x'
	if (sector_now > x)
		x += emu_header.sectors_per_track;

	// Find out exactly how close we are to the reaching the tail
	// If the difference is less than DMA lead, then it's time to issue more descriptors,
	// otherwise stop.
	if ((x - sector_now) >= DMA_LEAD)
		return;

	// We are always trying to maintain the tail DMA_LEAD sectors ahead
	// of where we currently are. So calculate the new tail accordingly
	int new_tail = sector_now + DMA_LEAD;

	int i = x + 1;				// Initialize 'i' to the sector following the current tail

	// Issue the descriptors up to and including 'new_tail'
	while (i <= new_tail) {

		// Check the descriptors of sectors that we think have already
		// passed under the head (or are currently) for the complete bit
		// set in the status, just to be extra certain that we are not
		// having too many outstanding descriptors
		int y = (i - DMA_LEAD) % emu_header.sectors_per_track;
		if (!(descriptors[((y * 0x40) + 0x1C) >> 2] & (1 << 31)))
			break;

		if ((seek_pending || head_change_pending ) && (seek_release == y)) {
//			command_interface[3] = 0;	// Clear the command pending bit
			seek_pending = false;
			head_change_pending = false;
			read_datapath[0] = 0;
		}


		// Update the descriptors we are about to issue, by clearing
		// the complete bit and updating their buffer address
		y = i % emu_header.sectors_per_track;
		descriptors[((y * 0x40) + 0x1C) >> 2] = 0;
		update_descriptor_addresses(y, y+1);

		// Update the tail register
		dma[0x10 >> 2] = (uint32_t) (intptr_t) &descriptors[(0x40 * y) >> 2];
		tail = y;

		i += 1;
	}
}

int main() {

	// Enable HW Cache Coherence for memory areas for use by DMA
	Xil_Out32(0xFD6E4000, 0x1);

	Xil_SetTlbAttributes((UINTPTR)descriptors, 0x605UL);

	Xil_SetTlbAttributes((UINTPTR)write_descriptors, 0x605UL);

	uint32_t section = ((UINTPTR) buffers) / 0x100000U;
	while (((uint32_t) (intptr_t) &buffers[DATA_BUFFER_SIZE - 1]) >= (section * 0x100000U)) {
		Xil_SetTlbAttributes((UINTPTR) (section * 0x100000U), 0x605UL);
		section += 1;
	}

	dsb();

	// Initialize hardware
	sector_timer[0] = 0;
	write_datapath[0] = 2;
	read_datapath[0] = 0;

	if (command_interface[1] & 0x2) {
		uint32_t trash = command_interface[2];
		(void) trash;
	}

	// Setup GPIO HAL Driver
    XGpio_Initialize(&drive_gpio_inst, XPAR_GPIO_DRIVE_SELECT_DEVICE_ID);
    XGpio_Initialize(&head_gpio_inst, XPAR_GPIO_HEAD_SELECT_DEVICE_ID);

    // Configure Interrupts
    GicConfig = XScuGic_LookupConfig(XPAR_PSU_ACPU_GIC_DEVICE_ID);

    XScuGic_CfgInitialize(&interrupt_controller, GicConfig, GicConfig->CpuBaseAddress);

    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &interrupt_controller);

    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_ESDI_CMD_CONTROL_0_INTERRUPT_INTR, (Xil_InterruptHandler) command_interrupt_handler, (void *) 0);
    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_GPIO_DRIVE_SELECT_IP2INTC_IRPT_INTR, (Xil_InterruptHandler) drive_sel_interrupt_handler, (void *) 0);
    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_GPIO_HEAD_SELECT_IP2INTC_IRPT_INTR, (Xil_InterruptHandler) head_sel_interrupt_handler, (void *) 0);
    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR, (Xil_InterruptHandler) dma_mm2s_interrupt_handler, (void *) 0);
    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_WRITE_DATAPATH_0_INTERRUPT_INTR, (Xil_InterruptHandler) write_datapath_interrupt_handler, (void *) 0);
    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR, (Xil_InterruptHandler) dma_s2mm_interrupt_handler, (void *) 0);
    XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_SECTOR_TIMER_0_INTERRUPT_INTR,(Xil_InterruptHandler) sector_timer_interrupt_handler, (void *) 0);

    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_ESDI_CMD_CONTROL_0_INTERRUPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_GPIO_DRIVE_SELECT_IP2INTC_IRPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_GPIO_HEAD_SELECT_IP2INTC_IRPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_WRITE_DATAPATH_0_INTERRUPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_SECTOR_TIMER_0_INTERRUPT_INTR);

    XGpio_InterruptGlobalEnable(&drive_gpio_inst);
    XGpio_InterruptEnable(&drive_gpio_inst, 1);

    XGpio_InterruptGlobalEnable(&head_gpio_inst);
    XGpio_InterruptEnable(&head_gpio_inst, 1);

    Xil_ExceptionEnable();

    // Load Image from SD Card

    f_mount(&fatfs, "0:/", 1);

    FIL image_file;
    FRESULT image_opened, fr_seek, fr_read;
    UINT bytes_read;

    image_opened = f_open(&image_file, "MICROP~1.EMU", FA_READ | FA_WRITE);

    if (image_opened != FR_OK) {
    	return 0;
    }

    // Read Emulation File Header
    fr_read = f_read(&image_file, (void*) &emu_header, sizeof(struct emulation_header), &bytes_read);

    if (bytes_read != sizeof(struct emulation_header)) {
    	return 0;
    }

    // Read Drive Configuration Data
    fr_seek = f_lseek(&image_file, emu_header.drive_configuration_offset);

    if (fr_seek) {
    	return 0;
    }

    fr_read = f_read(&image_file, (void*) &drive_conf, sizeof(struct drive_configuration), &bytes_read);

	if (bytes_read != sizeof(struct drive_configuration)) {
		return 0;
	}

	// Compute cylinder size from drive parameters
	cylinder_size = emu_header.heads * emu_header.sectors_per_track * emu_header.sector_size_in_image;

	uint16_t unformatted_bytes_per_sector = drive_conf.specific_configuration[4];

	uint16_t drive_rpm = 3600;

	xil_printf("Emulation Header Loaded\r\n");
	printf("    Emulation File parameters:\n");
	printf("        Cylinders = %d\n", emu_header.cylinders);
	printf("        Heads = %d\n", emu_header.heads);
	printf("        Sectors = %d\n", emu_header.sectors_per_track);

	if (emu_header.cylinders > MAX_SUPPORTED_CYLINDERS) {
		printf("The selected disk image has more cylinders than this build can support\r\n");
		return 0;
	}

	if (emu_header.sectors_per_track > MAX_SUPPORTED_SECTORS) {
		printf("The selected disk image has more sectors per track than this build can support\r\n");
		return 0;
	}

	num_slots = DATA_BUFFER_SIZE / cylinder_size;

	printf("Number of slots: %d\r\n", num_slots);

	// Load Initial cylinders
	fr_seek = f_lseek(&image_file, emu_header.data_offset);

	if (fr_seek) {
		return 0;
	}

    for (int i = 0; i < MAX_SUPPORTED_CYLINDERS; i++) {
    	if (i < PRELOAD_CYLINDERS)
    		cylinder_map[i] = i;
    	else
    		cylinder_map[i] = -1;
    }

	for (int i = 0; i < PRELOAD_CYLINDERS; i++) {
		fr_read = f_read(&image_file, (void*) &buffers[cylinder_size * i], cylinder_size, &bytes_read);
		if (fr_read || (bytes_read < cylinder_size)) {
			xil_printf("Failed to load cylinder %d\r\n", i);
		}
	}

	xil_printf("Loaded Data\r\n");

	// Configure hardware with emulation data

    command_interface[0] = 0x0001;	// Soft reset
    command_interface[0] = 0x0000;

    sector_timer[1] = HW_FREQ / (drive_rpm / 60) / emu_header.sectors_per_track;
    sector_timer[2] = emu_header.sectors_per_track;
    sector_timer[5] = (HW_FREQ / (drive_rpm / 60) / emu_header.sectors_per_track) - (15e-6 * HW_FREQ);	// 15us before the end of the sector

    write_datapath[3] = unformatted_bytes_per_sector - 3;	// Unformatted bytes per sector less two to match read datapath and also less one to leave space for sector number

    general_status = 1 << 8;	// Power on condition

    // Prepare Read Descriptors

    for (int i = 0; i < emu_header.sectors_per_track; i++) {
    	uint32_t next_desc;
    	if (i == emu_header.sectors_per_track - 1)
    		next_desc = 0;
    	else
    		next_desc = i + 1;

    	descriptors[((i * 0x40) + 0x00) >> 2] = (uint32_t) (intptr_t) &descriptors[(0x40 * next_desc) >> 2];
    	descriptors[((i * 0x40) + 0x18) >> 2] = (unformatted_bytes_per_sector - 2) | (3 << 26);
    	descriptors[((i * 0x40) + 0x1C) >> 2] = 0;
    }

    update_descriptor_addresses(0, emu_header.sectors_per_track);

    // Prepare Write Descriptors
    for (int i = 0; i < NUM_WRITE_DESCRIPTORS; i++) {
    	uint32_t next_desc;
		if (i == NUM_WRITE_DESCRIPTORS - 1)
			next_desc = 0;
		else
			next_desc = i + 1;

		write_descriptors[((i * 0x40) + 0x00) >> 2] = (uint32_t) (intptr_t) &write_descriptors[(0x40 * next_desc) >> 2];
		write_descriptors[((i * 0x40) + 0x18) >> 2] = (unformatted_bytes_per_sector - 2) | (3 << 26);
		write_descriptors[((i * 0x40) + 0x1C) >> 2] = 0;
    }

    // Reset DMA
    dma[0] = 0x4;
    while(dma[0x00 >> 2] & 0x04) {}
    while(dma[0x30 >> 2] & 0x04) {}

    // Set Read DMA Head
    dma[0x08 >> 2] = (uint32_t) (intptr_t) &descriptors[(0x40 * 0) >> 2];

    // Set Write DMA Head
    dma[0x38 >> 2] = (uint32_t) (intptr_t) &write_descriptors[(0x40 * 0) >> 2];
    current_write_descriptor = 0;
    last_unacked_write_descriptor = 0;

    // Run DMA
    dma[0x00 >> 2] = 0x1;
    while(dma[0x04 >> 2] & 0x01) {}

    dma[0x30 >> 2] = 0x1 | (1 << 12);
    while(dma[0x34 >> 2] & 0x01) {}

    // Set Initial Read DMA Tail
    dma[0x10 >> 2] = (uint32_t) (intptr_t) &descriptors[(0x40 * (DMA_LEAD - 1)) >> 2];
    tail = DMA_LEAD - 1;

    // Enable Hardware
    write_datapath[0] = 0x5;
    sector_timer[0] = 3;		// Enable

    // Main Loop
    while(1) {
    	if (print_location) {
    		print_location = false;
    		printf("C=%d  H=%d\r\n", current_cylinder, current_head);
    	}

    	// TODO: Check if we need to load a cylinder

    	// Write a dirty sector to SD if there is one
    	if (dirty_queue_head != dirty_queue_tail) {
    		struct chs dirty_sector = dirty_queue[dirty_queue_head];
    		dirty_queue_head = (dirty_queue_head + 1) % DIRTY_QUEUE_SIZE;
    		printf("Dirty (%d,%d,%d)\r\n", dirty_sector.c, dirty_sector.h, dirty_sector.s);
    		int slot = cylinder_map[dirty_sector.c];
    		if (slot == -1) {
    			continue;
    		}
    		fr_seek = f_lseek(&image_file, emu_header.data_offset + (cylinder_size * dirty_sector.c) + (((dirty_sector.h * emu_header.sectors_per_track) + dirty_sector.s) * emu_header.sector_size_in_image));

			if (fr_seek) {
				continue;
			}

			unsigned int bytes_written;
    		f_write(&image_file, &buffers[(cylinder_size * slot) + (((dirty_sector.h * emu_header.sectors_per_track) + dirty_sector.s) * emu_header.sector_size_in_image)], emu_header.sector_size_in_image, &bytes_written);
    	}


    }

}
