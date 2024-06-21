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

module axis_template_v1_0 #(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line


    // Parameters of Axi Slave Bus Interface S_AXIS_MM2S
    parameter integer C_S_AXIS_MM2S_TDATA_WIDTH = 128,  // 32/64/128 for UltraScale PS AXI HP

    // Parameters of Axi Master Bus Interface M_AXIS_S2MM
    parameter integer C_M_AXIS_S2MM_TDATA_WIDTH = 128,  // 32/64/128 for UltraScale PS AXI HP
    parameter integer C_M_AXIS_S2MM_START_COUNT = 32
) (
    // Users to add ports here
	input  wire                                       clk,
    input  wire                                       rstn,
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
    wire s_axis_mm2s_aclk;
    wire s_axis_mm2s_aresetn;
	wire m_axis_s2mm_aclk;
    wire m_axis_s2mm_aresetn;

	assign s_axis_mm2s_aclk    = clk;
	assign s_axis_mm2s_aresetn = rstn;
	assign m_axis_s2mm_aclk    = clk;
	assign m_axis_s2mm_aresetn = rstn;

    // User logic ends


    // Instantiation of Axi Bus Interface S_AXIS_MM2S
    axis_template_v1_0_S_AXIS_MM2S #(
        .C_S_AXIS_TDATA_WIDTH (C_S_AXIS_MM2S_TDATA_WIDTH)
    ) axis_template_v1_0_S_AXIS_MM2S_inst (
        .S_AXIS_ACLK    (s_axis_mm2s_aclk),
        .S_AXIS_ARESETN (s_axis_mm2s_aresetn),
        .S_AXIS_TREADY  (s_axis_mm2s_tready),
        .S_AXIS_TDATA   (s_axis_mm2s_tdata),
        .S_AXIS_TSTRB   (s_axis_mm2s_tstrb),
        .S_AXIS_TLAST   (s_axis_mm2s_tlast),
        .S_AXIS_TVALID  (s_axis_mm2s_tvalid)
    );

    // Instantiation of Axi Bus Interface M_AXIS_S2MM
    axis_template_v1_0_M_AXIS_S2MM #(
        .C_M_AXIS_TDATA_WIDTH (C_M_AXIS_S2MM_TDATA_WIDTH),
        .C_M_START_COUNT      (C_M_AXIS_S2MM_START_COUNT)
    ) axis_template_v1_0_M_AXIS_S2MM_inst (
        .M_AXIS_ACLK    (m_axis_s2mm_aclk),
        .M_AXIS_ARESETN (m_axis_s2mm_aresetn),
        .M_AXIS_TVALID  (m_axis_s2mm_tvalid),
        .M_AXIS_TDATA   (m_axis_s2mm_tdata),
        .M_AXIS_TSTRB   (m_axis_s2mm_tstrb),
        .M_AXIS_TLAST   (m_axis_s2mm_tlast),
        .M_AXIS_TREADY  (m_axis_s2mm_tready)
    );

endmodule
