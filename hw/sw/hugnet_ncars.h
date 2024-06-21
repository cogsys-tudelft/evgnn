/*
* Copyright (c) 2024, Yufeng Yang (CogSys Group)
* Licensed under the MIT License;
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at: https://opensource.org/license/mit
*/

#ifndef _HUGNET_CAR_H_
#define _HUGNET_CAR_H_

#include <stdio.h>
#include "xil_io.h"
#include "platform.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_cache.h"
#include "xtime_l.h"
#include "ff.h"

#define BASE   0xA0000000
#define CTRL   0
#define EVENT1 4
#define EVENT2 8
#define EVENT3 12
#define STAT   16
#define OUT1   20
#define OUT2   24

#define TEMP_DATA_BASE 0x10000000
#define TEMP_DATA_OFFSET 0x80

#define write_acc(RegOffset, Data) \
  	Xil_Out32((BASE) + (RegOffset), (u32)(Data))

#define read_acc(RegOffset) \
    Xil_In32((BASE) + (RegOffset))

typedef struct {
    int x;
    int y;
    int p;
    int t;
} event_s;

typedef struct {
    int prediction;
    int out1;
    int out2;
} pred_s;


FRESULT scan_files (
    char* path        /* Start node to be scanned (***also used as work area***) */
);
pred_s push_event_and_check (event_s event,  int event_idx);
void clean_ip();


#endif
