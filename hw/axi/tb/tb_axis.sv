/*
Copyright 2024 Yufeng Yang (CogSys Group)
SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

Licensed under the Solderpad Hardware License v 2.1 (the “License”);
you may not use this file except in compliance with the License, or,
at your option, the Apache License version 2.0.
You may obtain a copy of the License at

https://solderpad.org/licenses/SHL-2.1/

Unless required by applicable law or agreed to in writing,
any work distributed under the License is distributed on an “AS IS” BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
*/
`include "aegnn.svh"
import aegnn::*;

module tb_axis;

    parameter integer READ_BURST_LEN        = 8;
    parameter integer C_S_AXIS_TDATA_WIDTH	= 128;    // 32/64/128 for UltraScale PS AXI HP
    localparam integer RD_BUF_LEN = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH;

    logic  clk;
    logic  rstn;

    // IP ports
    logic  uip2axi_rd_en;   // from user IP: now can start read
    logic   axi2uip_rd_done; // tell user IP, pulse: sink has accepted all the streaming data and stored in buffer
    logic  [RD_BUF_LEN   -1:0] rd_buffer;

    // S_AXIS ports
    logic  S_AXIS_TREADY;  // s2m
    logic [C_S_AXIS_TDATA_WIDTH    -1 : 0] S_AXIS_TDATA;  // m2s
    logic [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB;  // m2s
    logic  S_AXIS_TLAST;  // m2s
    logic  S_AXIS_TVALID;  // m2s

    IP_S_AXIS_MM2S #(
        .READ_BURST_LEN       (READ_BURST_LEN),
		.C_S_AXIS_TDATA_WIDTH (C_S_AXIS_TDATA_WIDTH)
    ) IP_S_AXIS_MM2S_inst (
		// IP ports
        .uip2axi_rd_en,   // from user IP: now can start read
        .axi2uip_rd_done, // tell user IP, pulse: sink has accepted all the streaming data and stored in buffer
        .rd_buffer,

        // S_AXIS ports
		.S_AXIS_ACLK (clk),
		.S_AXIS_ARESETN (rstn),
		.S_AXIS_TREADY,  // Ready to accept data in
		.S_AXIS_TDATA,  // Data in
		.S_AXIS_TSTRB,  // Byte qualifier
		.S_AXIS_TLAST,  // Indicates boundary of last packet / end of last packet
		.S_AXIS_TVALID  // Indicates Tdata is in valid now
	);

endmodule