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

module tb_graph_conv;

    // graph_conv Parameters
    parameter PERIOD                = 10 ;
    parameter ADDR_WIDTH            = 32 ;
    parameter READ_BURST_LEN        = 8  ;
    parameter C_S_AXIS_TDATA_WIDTH  = 128;
    parameter WRITE_BURST_LEN       = 8  ;
    parameter C_M_AXIS_TDATA_WIDTH  = 128;
    localparam integer RD_BUF_LEN = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH;
    localparam integer WR_BUF_LEN = WRITE_BURST_LEN * C_M_AXIS_TDATA_WIDTH;
    localparam integer        L4_OUT_C       = 32;

    // graph_conv Inputs
    logic  clk                           = 0 ;
    logic  rstn                          = 0 ;
    logic  module_start                  = 0 ;
    event_s new_event                     ;
    logic  [FIFO_WIDTH -1 : 0] fifo_dout  ;
    logic  fifo_data_valid                ;
    logic  fifo_empty                     ;
    logic  axi2uip_rd_done               = 0 ;
    logic  [RD_BUF_LEN -1 : 0] rd_buffer = 0 ;
    logic  axi2uip_wr_done               = 0 ;

    // graph_conv Outputs
    logic  module_done;
    logic  fifo_rd_en;
    logic  uip2axi_rd_en;
    logic  [ADDR_WIDTH -1 : 0] uip2axi_rd_addr;
    logic  uip2axi_wr_en;
    logic  [ADDR_WIDTH -1 : 0] uip2axi_wr_addr;
    // logic  [WR_BUF_LEN -1 : 0] wr_buffer;
    logic  [127:0][F_WIDTH -1 : 0] wr_buffer;
    logic  [L4_OUT_C * F_WIDTH -1 : 0] last_layer_out_pack;

    // FIFO
    logic fifo_wr_en = 0;
    logic fifo_full;
    logic [FIFO_WIDTH -1:0] fifo_din = 0;
    event_s nei1;
    event_s nei2;

    initial begin
        new_event.unused <= 0;
        new_event.valid <= 1;
        new_event.x <= 1;
        new_event.y <= 1;
        new_event.p <= 1;
        new_event.t <= 10;
        new_event.addr <= 32'hDEAD_BEEF;

        nei1.unused <= 0;
        nei1.valid <= 1;
        nei1.x <= 2;
        nei1.y <= 1;
        nei1.p <= 1;
        nei1.t <= 7;
        nei1.addr <= 32'hDEAD_DEAD;

        nei2.unused <= 0;
        nei2.valid <= 1;
        nei2.x <= 1;
        nei2.y <= 0;
        nei2.p <= 1;
        nei2.t <= 5;
        nei2.addr <= 32'hBEEF_BEEF;
    end



    initial
    begin
        #1000;
        rstn <= 1'b1;

        #500;
        // write fifo
        fifo_wr_en <= 1;
        fifo_din <= nei1;
        #10;
        fifo_din <= nei2;
        #10;
        fifo_wr_en <= 0;

        #50;
        module_start <= 1;
        #10;
        module_start <= 0;


    end
    always #(PERIOD/2)  clk=~clk;

    int cnt = 0;
    always @ (posedge uip2axi_rd_en) begin
        #20;
        if (cnt == 0) begin
            cnt <= cnt + 1;
            axi2uip_rd_done <= 1;
            rd_buffer <= {{32{8'h44}}, {32{8'h33}}, {32{8'h22}}, {16{8'h11}}, {16{8'hFF}}};
        end
        else if (cnt == 1) begin
            axi2uip_rd_done <= 1;
            rd_buffer <= {{32{8'hDD}}, {32{8'hCC}}, {32{8'hBB}}, {16{8'hAA}}, {16{8'hEE}}};
        end
    end
    always @ (posedge axi2uip_rd_done) begin
        #10 axi2uip_rd_done <= 0;
    end

    always @ (posedge uip2axi_wr_en) begin
        #20;
        axi2uip_wr_done <= 1;
        #10;
        axi2uip_wr_done <= 0;
    end

    initial begin
        @ (posedge module_done);
        #100;
        module_start <= 1;
        #10;
        module_start <= 0;
    end


    graph_conv_fifo_wrapper #(
        .PERIOD               ( PERIOD  ),
        .ADDR_WIDTH           ( ADDR_WIDTH  ),
        .READ_BURST_LEN       ( READ_BURST_LEN   ),
        .C_S_AXIS_TDATA_WIDTH ( C_S_AXIS_TDATA_WIDTH ),
        .WRITE_BURST_LEN      ( WRITE_BURST_LEN   ),
        .C_M_AXIS_TDATA_WIDTH ( C_M_AXIS_TDATA_WIDTH ))
    graph_conv_fifo_wrapper_inst (
        .clk                  (clk                ),
        .rstn                 (rstn               ),
        .module_start         (module_start       ),
        .new_event            (new_event          ),
        .axi2uip_rd_done      (axi2uip_rd_done    ),
        .rd_buffer            (rd_buffer          ),
        .axi2uip_wr_done      (axi2uip_wr_done    ),
        .fifo_wr_en           (fifo_wr_en         ),
        .fifo_din             (fifo_din           ),

        .module_done          (module_done        ),
        .uip2axi_rd_en        (uip2axi_rd_en      ),
        .uip2axi_rd_addr      (uip2axi_rd_addr    ),
        .uip2axi_wr_en        (uip2axi_wr_en      ),
        .uip2axi_wr_addr      (uip2axi_wr_addr    ),
        .wr_buffer            (wr_buffer          ),
        .last_layer_out_pack  (last_layer_out_pack),
        .fifo_full            (fifo_full          )
    );


    // graph_conv #(
    //     .ADDR_WIDTH           ( ADDR_WIDTH           ),
    //     .READ_BURST_LEN       ( READ_BURST_LEN       ),
    //     .C_S_AXIS_TDATA_WIDTH ( C_S_AXIS_TDATA_WIDTH ),
    //     .WRITE_BURST_LEN      ( WRITE_BURST_LEN      ),
    //     .C_M_AXIS_TDATA_WIDTH ( C_M_AXIS_TDATA_WIDTH )
    // ) graph_conv_inst (
    //     .clk                  ( clk                 ),
    //     .rstn                 ( rstn                ),
    //     .module_start         ( module_start        ),
    //     .new_event            ( new_event           ),
    //     .fifo_dout            ( fifo_dout           ),
    //     .fifo_data_valid      ( fifo_data_valid     ),
    //     .fifo_empty           ( fifo_empty          ),
    //     .axi2uip_rd_done      ( axi2uip_rd_done     ),
    //     .rd_buffer            ( rd_buffer           ),
    //     .axi2uip_wr_done      ( axi2uip_wr_done     ),

    //     .module_done          ( module_done         ),
    //     .fifo_rd_en           ( fifo_rd_en          ),
    //     .uip2axi_rd_en        ( uip2axi_rd_en       ),
    //     .uip2axi_rd_addr      ( uip2axi_rd_addr     ),
    //     .uip2axi_wr_en        ( uip2axi_wr_en       ),
    //     .uip2axi_wr_addr      ( uip2axi_wr_addr     ),
    //     .wr_buffer            ( wr_buffer           ),
    //     .last_layer_out_pack  ( last_layer_out_pack )
    // );

    // fifo_xpm #(
    //     .DEPTH    (MAX_DEGREE),
    //     .WIDTH    (FIFO_WIDTH),  // 32+8+8  //debug
    //     .READ_MODE("std")
    // ) fifo_xpm_inst (
    //     // Global sync signals
    //     .clk,
    //     .rstn,

    //     // Write group
    //     .wr_en(fifo_wr_en),
    //     .din  (fifo_din),
    //     .full (fifo_full),
    //     // .wr_ack,
    //     // .overflow,
    //     // .wr_data_count,
    //     // .wr_rst_busy,

    //     // // Read group
    //     .rd_en (fifo_rd_en),  // DO NOT LEAVE IT FLOAT
    //     .dout (fifo_dout),
    //     .data_valid (fifo_data_valid),
    //     .empty (fifo_empty)
    //     // .underflow,
    //     // .rd_data_count,
    //     // .rd_rst_busy
    // );

endmodule