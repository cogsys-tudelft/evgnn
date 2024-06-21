/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
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

#include <stdio.h>
#include "xil_io.h"
#include "platform.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_cache.h"
#include "test_s_axilite.h"

#define INTR_ID XPAR_FABRIC_TEST_S_AXILITE_0_IP_DONE_IRQ_INTR
#define BASE XPAR_TEST_S_AXILITE_0_S00_AXI_BASEADDR

#define IP_START    TEST_S_AXILITE_S00_AXI_SLV_REG0_OFFSET
#define NEW_EVENT_1 TEST_S_AXILITE_S00_AXI_SLV_REG1_OFFSET
#define NEW_EVENT_2 TEST_S_AXILITE_S00_AXI_SLV_REG2_OFFSET

#define IP_IDLE     TEST_S_AXILITE_S00_AXI_SLV_REG3_OFFSET
#define IP_DONE     TEST_S_AXILITE_S00_AXI_SLV_REG4_OFFSET
#define PREDICTION  TEST_S_AXILITE_S00_AXI_SLV_REG5_OFFSET
#define FC_OUT_1    TEST_S_AXILITE_S00_AXI_SLV_REG6_OFFSET
#define FC_OUT_2    TEST_S_AXILITE_S00_AXI_SLV_REG7_OFFSET

static XScuGic intc;
static int cnt = 1;

static void intr_handler (void *intc_inst_ptr) {

    xil_printf("IP Done!\n\r");
    xil_printf("Interrupt counter: %d", cnt);
    cnt++;

    u32 ip_idle;
    u32 ip_done;
    u32 prediction;
    u32 fc_out_1;
    u32 fc_out_2;

    ip_idle = TEST_S_AXILITE_mReadReg(BASE, IP_IDLE);
    ip_done = TEST_S_AXILITE_mReadReg(BASE, IP_DONE);
    prediction = TEST_S_AXILITE_mReadReg(BASE, PREDICTION);
    fc_out_1 = TEST_S_AXILITE_mReadReg(BASE, FC_OUT_1);
    fc_out_2 = TEST_S_AXILITE_mReadReg(BASE, FC_OUT_2);

    xil_printf("ip_idle = %d \n\r", ip_idle);
    xil_printf("ip_done = %d \n\r", ip_done);
    xil_printf("prediction = %d \n\r", prediction);
    xil_printf("fc_out_1 = %x \n\r", fc_out_1);
    xil_printf("fc_out_2 = %x \n\r", fc_out_2);
}

int setup_interrupt_system() {

    int result;
    XScuGic *intc_instance_ptr = &intc;
    XScuGic_Config *intc_config;

    // get config for interrupt controller
    intc_config = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
    if (NULL == intc_config) {
        return XST_FAILURE;
    }

    // initialize the interrupt controller driver
    result = XScuGic_CfgInitialize(intc_instance_ptr, intc_config, intc_config->CpuBaseAddress);
    if (result != XST_SUCCESS) {
        return result;
    }

    // set the priority of IRQ_F2P[0:0] to 0xA0 (highest 0xF8, lowest 0x00) and a trigger for a rising edge 0x3.
    XScuGic_SetPriorityTriggerType(intc_instance_ptr, INTR_ID, 0xA0, 0x3);

    // connect the interrupt service routine isr0 to the interrupt controller
    result = XScuGic_Connect(intc_instance_ptr, INTR_ID, (Xil_ExceptionHandler)intr_handler, (void *)&intc);
    if (result != XST_SUCCESS) {
        return result;
    }

    // enable interrupts for IRQ_F2P[0:0]
    XScuGic_Enable(intc_instance_ptr, INTR_ID);


    // initialize the exception table and register the interrupt controller handler with the exception table
    Xil_ExceptionInit();

    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, intc_instance_ptr);

    // enable non-critical exceptions
    Xil_ExceptionEnable();

    return XST_SUCCESS;
}


int main()
{
    init_platform();
    Xil_DCacheDisable();

    xil_printf("Hello World\n\r");

    int status = setup_interrupt_system();
    if (status != XST_SUCCESS) {
         return XST_FAILURE;
    }

    u32 new_event_1 = 0x0A0B0C0D;  // 0x0A0B0C0D
    u32 new_event_2 = 0xDEADBEEF;  // 0xDEADBEEF

    TEST_S_AXILITE_mWriteReg(BASE, NEW_EVENT_1, new_event_1);
    TEST_S_AXILITE_mWriteReg(BASE, NEW_EVENT_2, new_event_2);
    TEST_S_AXILITE_mWriteReg(BASE, IP_START, 1);

    xil_printf("Wait for interrupt");
    while(1){
        if (cnt == 3)
            break;
    }


    print("Successfully ran Hello World application");
    cleanup_platform();
    return 0;
}
