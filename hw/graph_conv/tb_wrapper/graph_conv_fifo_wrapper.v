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
`timescale 1ns/1ps

module graph_conv_fifo_wrapper #(
    parameter PERIOD                = 10 ,
    parameter ADDR_WIDTH            = 32 ,
    parameter READ_BURST_LEN        = 8  ,
    parameter C_S_AXIS_TDATA_WIDTH  = 128,
    parameter WRITE_BURST_LEN       = 8  ,
    parameter C_M_AXIS_TDATA_WIDTH  = 128,
    localparam integer RD_BUF_LEN = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH,
    localparam integer WR_BUF_LEN = WRITE_BURST_LEN * C_M_AXIS_TDATA_WIDTH,
    localparam integer L4_OUT_C       = 32,
    localparam integer FIFO_WIDTH = 72,
    localparam integer F_WIDTH = 8
) (
        // graph_conv Inputs
    input wire  clk                            ,
    input wire  rstn                           ,
    input wire  module_start                   ,
    input wire [FIFO_WIDTH -1 : 0] new_event,

    input wire  axi2uip_rd_done                ,
    input wire  [RD_BUF_LEN -1 : 0] rd_buffer  ,
    input wire  axi2uip_wr_done                ,

    // graph_conv Outputs
    output wire  module_done,
    output wire  uip2axi_rd_en,
    output wire  [ADDR_WIDTH -1 : 0] uip2axi_rd_addr,
    output wire  uip2axi_wr_en,
    output wire  [ADDR_WIDTH -1 : 0] uip2axi_wr_addr,
    output wire  [WR_BUF_LEN -1 : 0] wr_buffer,
    output wire  [L4_OUT_C * F_WIDTH -1 : 0] last_layer_out_pack,

    // FIFO
    input  wire fifo_wr_en ,
    output wire fifo_full,
    input  wire [FIFO_WIDTH -1:0] fifo_din
);

    wire  [FIFO_WIDTH -1 : 0] fifo_dout  ;
    wire  fifo_data_valid                ;
    wire  fifo_empty                     ;
    wire  fifo_rd_en;

    graph_conv #(
        .ADDR_WIDTH           ( ADDR_WIDTH           ),
        .READ_BURST_LEN       ( READ_BURST_LEN       ),
        .C_S_AXIS_TDATA_WIDTH ( C_S_AXIS_TDATA_WIDTH ),
        .WRITE_BURST_LEN      ( WRITE_BURST_LEN      ),
        .C_M_AXIS_TDATA_WIDTH ( C_M_AXIS_TDATA_WIDTH )
    ) graph_conv_inst (
        .clk                  ( clk                 ),
        .rstn                 ( rstn                ),
        .module_start         ( module_start        ),
        .new_event            ( new_event           ),
        .fifo_dout            ( fifo_dout           ),
        .fifo_data_valid      ( fifo_data_valid     ),
        .fifo_empty           ( fifo_empty          ),
        .axi2uip_rd_done      ( axi2uip_rd_done     ),
        .rd_buffer            ( rd_buffer           ),
        .axi2uip_wr_done      ( axi2uip_wr_done     ),

        .module_done          ( module_done         ),
        .fifo_rd_en           ( fifo_rd_en          ),
        .uip2axi_rd_en        ( uip2axi_rd_en       ),
        .uip2axi_rd_addr      ( uip2axi_rd_addr     ),
        .uip2axi_wr_en        ( uip2axi_wr_en       ),
        .uip2axi_wr_addr      ( uip2axi_wr_addr     ),
        .wr_buffer            ( wr_buffer           ),
        .last_layer_out_pack  ( last_layer_out_pack )
    );


    localparam MAX_DEGREE = 16;
    fifo_xpm #(
        .DEPTH    (MAX_DEGREE),
        .WIDTH    (FIFO_WIDTH),  // 32+8+8  //debug
        .READ_MODE("std")
    ) fifo_xpm_inst (
        // Global sync signals
        .clk (clk),
        .rstn (rstn),

        // Write group
        .wr_en(fifo_wr_en),
        .din  (fifo_din),
        .full (fifo_full),


        // Read group
        .rd_en (fifo_rd_en),  // DO NOT LEAVE IT FLOAT
        .dout (fifo_dout),
        .data_valid (fifo_data_valid),
        .empty (fifo_empty)

    );
endmodule