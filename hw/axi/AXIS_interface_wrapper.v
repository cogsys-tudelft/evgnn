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
`timescale 1 ns / 1 ps

module AXIS_interface_wrapper #(
    // Users to add parameters here
    parameter integer READ_BURST_LEN        = 8,
    parameter integer WRITE_BURST_LEN       = 8,
    parameter [31:0] TEST_ADDR              = 32'h1000_0000,
    // User parameters ends
    // Do not modify the parameters beyond this line


    // Parameters of Axi Slave Bus Interface S_AXIS_MM2S
    parameter integer C_S_AXIS_MM2S_TDATA_WIDTH = 128,  // 32/64/128 for UltraScale PS AXI HP

    // Parameters of Axi Master Bus Interface M_AXIS_S2MM
    parameter integer C_M_AXIS_S2MM_TDATA_WIDTH = 128  // 32/64/128 for UltraScale PS AXI HP
) (
    // Users to add ports here
	input  wire                                       clk,
    input  wire                                       rstn,
    output wire  [  31:0]                             uip2axi_wr_addr,
    output wire  [  31:0]                             uip2axi_rd_addr,
    output wire                                       uip2axi_wr_en,
    output wire                                       uip2axi_rd_en,
    // test group
    input  wire                                       test_start,
    output wire                                       test_done,
    output wire [1:0]                                 check_error, // 00: wait checking; 01: OK; 11: error
    // User ports ends
    // Do not modify the ports beyond this line


    // Ports of Axi Slave Bus Interface S_AXIS_MM2S
    // input  wire                                       s_axis_mm2s_aclk,
    // input  wire                                       s_axis_mm2s_aresetn,
    output wire                                       s_axis_mm2s_tready,
    input  wire [C_S_AXIS_MM2S_TDATA_WIDTH    -1 : 0] s_axis_mm2s_tdata,
    input  wire [(C_S_AXIS_MM2S_TDATA_WIDTH/8)-1 : 0] s_axis_mm2s_tstrb,
    input  wire                                       s_axis_mm2s_tlast,
    input  wire                                       s_axis_mm2s_tvalid,

    // Ports of Axi Master Bus Interface M_AXIS_S2MM
    // input  wire                                       m_axis_s2mm_aclk,
    // input  wire                                       m_axis_s2mm_aresetn,
    output wire                                       m_axis_s2mm_tvalid,
    output wire [C_M_AXIS_S2MM_TDATA_WIDTH    -1 : 0] m_axis_s2mm_tdata,
    output wire [(C_M_AXIS_S2MM_TDATA_WIDTH/8)-1 : 0] m_axis_s2mm_tstrb,
    output wire                                       m_axis_s2mm_tlast,
    input  wire                                       m_axis_s2mm_tready
);

    // Add user logic here
    localparam integer RD_BUF_LEN = READ_BURST_LEN * C_S_AXIS_MM2S_TDATA_WIDTH;
    localparam integer WR_BUF_LEN = WRITE_BURST_LEN * C_M_AXIS_S2MM_TDATA_WIDTH;


    // Common clk and reset
    wire s_axis_mm2s_aclk;
    wire s_axis_mm2s_aresetn;
	wire m_axis_s2mm_aclk;
    wire m_axis_s2mm_aresetn;

	assign s_axis_mm2s_aclk    = clk;
	assign s_axis_mm2s_aresetn = rstn;
	assign m_axis_s2mm_aclk    = clk;
	assign m_axis_s2mm_aresetn = rstn;

    // user ip ports
    // wire  uip2axi_rd_en;
    wire  axi2uip_rd_done;
    wire  [RD_BUF_LEN   -1:0] rd_buffer;

    // wire  uip2axi_wr_en;
    wire  axi2uip_wr_done;
    wire  [WR_BUF_LEN   -1:0] wr_buffer;

    // Inst test ip

    dummy_test_ip #(
        .TEST_ADDR (TEST_ADDR)
    ) dummy_test_ip_inst (
        .clk            (clk),
        .rstn           (rstn),

        .test_start     (test_start),
        .test_done      (test_done),
        .check_error    (check_error),

        .wr_en          (uip2axi_wr_en),
        .wr_done        (axi2uip_wr_done),
        .wr_addr        (uip2axi_wr_addr),
        .wr_buffer      (wr_buffer),

        .rd_en          (uip2axi_rd_en),
        .rd_done        (axi2uip_rd_done),
        .rd_addr        (uip2axi_rd_addr),
        .rd_buffer      (rd_buffer)
    );

    // User logic ends


    // Instantiation of Axi Bus Interface S_AXIS_MM2S
    IP_S_AXIS_MM2S #(
        .READ_BURST_LEN       (READ_BURST_LEN),
        .C_S_AXIS_TDATA_WIDTH (C_S_AXIS_MM2S_TDATA_WIDTH)
    ) IP_S_AXIS_MM2S_inst (
        // User ports
        .uip2axi_rd_en   (uip2axi_rd_en),
        .axi2uip_rd_done (axi2uip_rd_done),
        .rd_buffer       (rd_buffer),
        // AXIS ports
        .S_AXIS_ACLK     (s_axis_mm2s_aclk),
        .S_AXIS_ARESETN  (s_axis_mm2s_aresetn),
        .S_AXIS_TREADY   (s_axis_mm2s_tready),
        .S_AXIS_TDATA    (s_axis_mm2s_tdata),
        .S_AXIS_TSTRB    (s_axis_mm2s_tstrb),
        .S_AXIS_TLAST    (s_axis_mm2s_tlast),
        .S_AXIS_TVALID   (s_axis_mm2s_tvalid)
    );

    // Instantiation of Axi Bus Interface M_AXIS_S2MM
    IP_M_AXIS_S2MM #(
        .C_M_AXIS_TDATA_WIDTH (C_M_AXIS_S2MM_TDATA_WIDTH)
    ) IP_M_AXIS_S2MM_inst (
        // User ports
        .uip2axi_wr_en   (uip2axi_wr_en),
        .axi2uip_wr_done (axi2uip_wr_done),
        .wr_buffer       (wr_buffer),
        // AXIS ports
        .M_AXIS_ACLK     (m_axis_s2mm_aclk),
        .M_AXIS_ARESETN  (m_axis_s2mm_aresetn),
        .M_AXIS_TVALID   (m_axis_s2mm_tvalid),
        .M_AXIS_TDATA    (m_axis_s2mm_tdata),
        .M_AXIS_TSTRB    (m_axis_s2mm_tstrb),
        .M_AXIS_TLAST    (m_axis_s2mm_tlast),
        .M_AXIS_TREADY   (m_axis_s2mm_tready)
    );

endmodule
