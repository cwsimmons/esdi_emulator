
#include <stdint.h>
#include <stdio.h>

#include "xscugic.h"
#include "xgpio.h"
#include "xparameters.h"
#include "ff.h"

static XGpio drive_gpio_inst;

XScuGic interrupt_controller;
static XScuGic_Config *GicConfig;

volatile uint32_t* command_interface = (volatile uint32_t*) XPAR_AXI_ESDI_CMD_CONTROL_0_BASEADDR;
volatile uint32_t* sector_timer = 	   (volatile uint32_t*) XPAR_SECTOR_TIMER_0_BASEADDR;
volatile uint32_t* drive_select_gpio = (volatile uint32_t*) XPAR_GPIO_DRIVE_SELECT_BASEADDR;
volatile uint32_t* head_select_gpio =  (volatile uint32_t*) XPAR_GPIO_HEAD_SELECT_BASEADDR;

int current_drive_sel = 0;

static FATFS fatfs;

void command_interrupt_handler(void* arg) {
    if ((command_interface[1] & 0x4)) {
        uint32_t command = command_interface[2];

        uint32_t cmd = (command >> 12) & 0xf;
        uint32_t modifier = (command >> 8) & 0xf;
        uint32_t subscript = command & 0xff;

        if (cmd == 0x3) {
            if (modifier == 0) {
                command_interface[2] = 0b0111001001001010;
            } else if (modifier == 1) {
                command_interface[2] = 422;
            } else if (modifier == 2) {
                command_interface[2] = 0;
            } else if (modifier == 3) {
                command_interface[2] = 0x0006;
            } else if (modifier == 4) {
                command_interface[2] = 21000;
            } else if (modifier == 5) {
                command_interface[2] = 600;
            } else if (modifier == 6) {
                command_interface[2] = 9;
            } else if (modifier == 7) {
                command_interface[2] = 0x0408;
            } else if (modifier == 8) {
                command_interface[2] = 12;
            } else if (modifier == 9) {
                command_interface[2] = 0;
            } else {
                command_interface[2] = 0;
            }
        } else if (cmd == 0x2) {

                command_interface[2] = 0b000000000000000000;

        }

        command_interface[3] = 0;	// Clear the command pending bit
    }
    xil_printf("C");
}

void drive_sel_interrupt_handler(void* arg) {
    if (XGpio_InterruptGetStatus(&drive_gpio_inst) & 0x1) {
        XGpio_InterruptClear(&drive_gpio_inst, 1);
        int new_dsel = drive_select_gpio[0];
        if (new_dsel != current_drive_sel) {
            current_drive_sel = new_dsel;
            if (new_dsel == 1) {
                command_interface[0] = 0xE;		// Enable interface
            } else {
                command_interface[0] = 0x0;		// Disable interface
            }
        }
    }
//	xil_printf("D");
}

void head_sel_interrupt_handler(void* arg) {
    if (head_select_gpio[6] & 0x1) {
        head_select_gpio[6] = 0x1;		// IDK why this doesn't work
    }
    xil_printf("H");
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

int main() {

    XGpio_Initialize(&drive_gpio_inst, XPAR_GPIO_DRIVE_SELECT_DEVICE_ID);

    GicConfig = XScuGic_LookupConfig(XPAR_PSU_ACPU_GIC_DEVICE_ID);

    int status = XScuGic_CfgInitialize(&interrupt_controller, GicConfig, GicConfig->CpuBaseAddress);
    
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &interrupt_controller);

    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_AXI_ESDI_CMD_CONTROL_0_INTERRUPT_INTR, (Xil_InterruptHandler) command_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_GPIO_DRIVE_SELECT_IP2INTC_IRPT_INTR, (Xil_InterruptHandler) drive_sel_interrupt_handler, (void *) 0);
    status = XScuGic_Connect(&interrupt_controller, XPAR_FABRIC_GPIO_HEAD_SELECT_IP2INTC_IRPT_INTR, (Xil_InterruptHandler) head_sel_interrupt_handler, (void *) 0);

    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_AXI_ESDI_CMD_CONTROL_0_INTERRUPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_GPIO_DRIVE_SELECT_IP2INTC_IRPT_INTR);
    XScuGic_Enable(&interrupt_controller, XPAR_FABRIC_GPIO_HEAD_SELECT_IP2INTC_IRPT_INTR);

    command_interface[0] = 0x0001;	// Soft reset
    command_interface[0] = 0x0000;

    sector_timer[1] = 46296;	// 100 MHz / 60 rps / 36 spt
    sector_timer[2] = 36;		// Num sectors
    sector_timer[0] = 1;		// Enable

//    drive_select_gpio[1] = 7;
//	drive_select_gpio[5] = 0x01;	// Enable Channel 1 interrupt
//	drive_select_gpio[4] = 0x80000000;	// Enable GIER
    XGpio_InterruptGlobalEnable(&drive_gpio_inst);
    XGpio_InterruptEnable(&drive_gpio_inst, 1);

//    head_select_gpio[5] = 0x01;	// Enable Channel 1 interrupt		// IDK why this doesn't work
//    head_select_gpio[4] = 0x80000000;	// Enable GIER

    Xil_ExceptionEnable();

    f_mount(&fatfs, "0:/", 0);

    list_dir("/");


    int prev_ds = 0;
    while(1) {
        sleep(1);
		xil_printf("Hello World\r\n");
//		int ds = drive_select_gpio[0] & 1;
//		if (ds != prev_ds) {
//			prev_ds = ds;
//
//			xil_printf("%d\r\n", prev_ds);
//		}
//		drive_select_gpio[6] = 0x1;
    }

}
