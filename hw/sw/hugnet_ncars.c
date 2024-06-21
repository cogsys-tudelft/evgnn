/*
* Copyright (c) 2024, Yufeng Yang (CogSys Group)
* Licensed under the MIT License;
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at: https://opensource.org/license/mit
*/

/*
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include "hugnet_ncars.h"


// Global print flags
int print_dout = 0;
int print_time = 0;
int print_stat = 0;

// Statistics
int total_samples = 0;
int total_wrongs  = 0;
int debug_samples = 400;

// File System

// For each dir/sub-dir, enter, and run ip of the data
FRESULT scan_files(
    char *path       /* Start node to be scanned (***also used as work area***) */
)
{
    FRESULT res;
    DIR dir;
    FIL fil;
    UINT i;

    static FILINFO fno;
    char current_file[256];
    char line_buf[256];

    float x,y,t,p;
    int event_idx;

    volatile pred_s pred_data;
    volatile event_s new_event;
    volatile int is_car;


    res = f_opendir(&dir, path);                       /* Open the directory */
    if (res == FR_OK) {
        for (;;) {
            res = f_readdir(&dir, &fno);                   /* Read a directory item */
            if (res != FR_OK || fno.fname[0] == 0) break;  /* Break on error or end of dir */
            if (fno.fattrib & AM_DIR) {                    /* It is a directory */
                i = strlen(path);
                sprintf(&path[i], "/%s", fno.fname);

                xil_printf("%s:\n", fno.fname);
                total_samples++;

                debug_samples--;
                if (debug_samples <= 0)
                    break;

                res = scan_files(path);                    /* Enter the directory */
                if (res != FR_OK) break;
                path[i] = 0;
            } else {                                       /* It is a file. */
            	strcpy(current_file, path);
            	strcat(current_file, "/");
            	strcat(current_file, fno.fname);
//            	xil_printf("%s\n", current_file);

                // For events file
                if (strcmp(fno.fname, "events.txt") == 0) {
                	res = f_open(&fil, current_file, FA_READ);
                	if (res != FR_OK) {
                		xil_printf("Fail to open %s\n", current_file);
                		return res;
                	}

                    // Read 1 line of the file, push to ip, and count #events
                	event_idx = 0;
                    while(f_gets(line_buf, sizeof(line_buf), &fil)) {
						sscanf(line_buf, "%f %f %f %f", &x,&y,&t,&p);
						new_event.x = (int)x;
						new_event.y = (int)y;
						new_event.p = (int)p;
						new_event.t = (int)(t*1000000);
						pred_data = push_event_and_check(new_event, event_idx);
						event_idx++;
                    }


					// xil_printf("Total events: %d\n", event_idx);
					// xil_printf("final out: [%12d, %12d]\n", pred_data.out1, pred_data.out2);
                    // xil_printf("prediction: %d", (1 - pred_data.prediction));
                    clean_ip();

                	f_close(&fil);
                }

                if (strcmp(fno.fname, "is_car.txt") == 0) {
                	res = f_open(&fil, current_file, FA_READ);
                	if (res != FR_OK) {
                		xil_printf("Fail to open %s\n", current_file);
                		return res;
                	}

                    f_gets(line_buf, sizeof(line_buf), &fil);
                    sscanf(line_buf, "%d", &is_car);

                    xil_printf("Total events: %d\n", event_idx);
                    xil_printf("final out: [%12d, %12d]\n", pred_data.out1, pred_data.out2);
                    xil_printf("prediction: %d\n", (1 - pred_data.prediction));
                    xil_printf("is_car: %d\n", is_car);
                    if ((1 - pred_data.prediction) != is_car) {
                        total_wrongs++;
                        xil_printf("Wrong\n\n");
                    }
                    else
                        xil_printf("Right\n\n");

                    f_close(&fil);
                }
            }
        }
        f_closedir(&dir);
    }

    return res;
}



// Event stream processing
pred_s push_event_and_check (event_s event,  int event_idx) {

    volatile u32 stat;
    volatile u32 ip_idle;
    volatile u32 ip_done;
    volatile u32 prediction;
    volatile u32 out1;
    volatile u32 out2;


    volatile u32 event1 = 0;
    volatile u32 event2 = 0;
    volatile u32 event3 = 0;

    XTime t_start, t_end;
    u32 t_us;

    event1 |= ((event.y & 0x000000ff) << 0);
    event1 |= ((event.x & 0x000000ff) << 8);
    event1 |= ((event.p & 0x00000001) << 16);
    event2 = (u32) event.t;
    event3 = TEMP_DATA_BASE + event_idx*TEMP_DATA_OFFSET;  // addr=0x10000000 + idx*0x80

    write_acc(CTRL, 0);  // en=0, clean=0

    write_acc(EVENT1, event1);
    write_acc(EVENT2, event2);
    write_acc(EVENT3, event3);

    // Until ip_idle, start accelerator
    while(1) {
		stat = read_acc(STAT);
		ip_idle = (stat & 0x00000001) >> 0; // bit 0
		if (ip_idle == 1) {
			write_acc(CTRL, 1);  // en=1, clean=0
			break;
		}
    }

    // Keep polling accelerator status, until ip_done
    XTime_GetTime(&t_start);
    while(1) {
        stat = read_acc(STAT);
        ip_done = (stat & 0x00000002) >> 1; // bit 1
        if (ip_done == 1) {
        	XTime_GetTime(&t_end);
            break;
        }
    }

    t_us = ((t_end - t_start)*1000000)/COUNTS_PER_SECOND;
    ip_idle = (stat & 0x00000001) >> 0; // bit 0
    prediction = (stat & 0x00000004) >> 2; // bit 2
    out1 = read_acc(OUT1);
    out2 = read_acc(OUT2);

    if (print_dout)
    	xil_printf("event %d out: [%12d, %12d]\n", event_idx, out1, out2);
    if (print_stat)
    	xil_printf("stat: %x -> prediction: %x, ip_done: %x, ip_idle: %x\n", stat, prediction, ip_done, ip_idle);
    if (print_time)
    	xil_printf("Run time:  %d us\n\n", t_us);

    write_acc(CTRL, 0);  // en=0, clean=0

    pred_s pred_data;
    pred_data.prediction = prediction;
    pred_data.out1 = out1;
    pred_data.out2 = out2;

    // Check DDR temp storing data:
    // volatile u32 content;
    // xil_printf("DDR temp data, from %x:\n\r", event3);
    // for (int i = 0; i < 8; i++) {
    //     for (int j = 0; j < 4; j++) {
    //         content = Xil_In32((event3) + (4*(j+4*i)));
    //         xil_printf("%x ", content);
    //     }
    //     xil_printf("\n\r");
    // }

    return pred_data;
}

void clean_ip() {
    volatile u32 stat;
    volatile u32 ip_clear;

    write_acc(CTRL, 2);  // en=0, clean=1
    while(1) {
        stat = read_acc(STAT);
        ip_clear = (stat & 0x00000008) >> 3; // bit 3
        if (ip_clear == 1) {
//        	xil_printf("\nIP clean finish.\n\n");
            break;
        }
    }
}


int main() {
    init_platform();
    Xil_DCacheDisable();

    FATFS fs;
    FRESULT res;

    res = f_mount(&fs, "0:/", 0);
    if (res != FR_OK) {
        xil_printf("Fail to mount SD card to 0:/");
        return -1;
    }

    clean_ip();

    xil_printf("Total_samples:%d, Total_wrongs:%d\n", total_samples, total_wrongs);
    char val_dataset_path[256] = "0:/ncars/val";
    res = scan_files(val_dataset_path);
    xil_printf("Total_samples:%d, Total_wrongs:%d\n", total_samples, total_wrongs);

//    xil_printf("Successfully ran Hello World application");
    cleanup_platform();
    return 0;
}
