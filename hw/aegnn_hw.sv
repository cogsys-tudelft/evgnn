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

module aegnn_hw #(
    // parameter FIFO_WIDTH = 72
    parameter integer ADDR_WIDTH             = 32,

    parameter integer READ_BURST_LEN         = 8,
    parameter integer C_S_AXIS_TDATA_WIDTH	 = 128,

    parameter integer WRITE_BURST_LEN        = 8,
    parameter integer C_M_AXIS_TDATA_WIDTH	 = 128,

    parameter integer L4_OUT_C               = 32,
    parameter integer FC_OUT_C               = 2,

    localparam         FC_MEM_INIT_FILE      = "FC_w.mem",
    localparam integer MAC_LATENCY           = 4,
    localparam integer WR_BUF_LEN            = WRITE_BURST_LEN * C_M_AXIS_TDATA_WIDTH,
    localparam integer RD_BUF_LEN            = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH
) (
    input  logic   clk,
    input  logic   rstn,

    // IP control signals
    input  logic   ip_en,
    input  logic   ip_clean,

    output logic   ip_idle,
    output logic   ip_done,
    output logic   ip_clear,

    // Input: new event data
    input  event_s new_event,

    // Output: linear data out
    output logic   prediction,
    output logic   [FC_OUT_C * FC_OUT_WIDTH -1 : 0] fc_out_pack,

    // DDR IP Communication
    output logic   uip2axi_rd_en,
    input  logic   axi2uip_rd_done,
    output logic   [ADDR_WIDTH -1 : 0] uip2axi_rd_addr,
    input  logic   [RD_BUF_LEN -1 : 0] rd_buffer,

    output logic   uip2axi_wr_en,
    input  logic   axi2uip_wr_done,
    output logic   [ADDR_WIDTH -1 : 0] uip2axi_wr_addr,
    output logic   [WR_BUF_LEN -1 : 0] wr_buffer


);

    logic event_stream_clean;

    // Inst

    logic                     fifo_wr_en;
    logic                     fifo_full;
    logic [FIFO_WIDTH -1 : 0] fifo_din;

    logic                     fifo_rd_en;
    logic [FIFO_WIDTH -1 : 0] fifo_dout;
    logic                     fifo_data_valid;
    logic                     fifo_empty;

    fifo_xpm #(
        .DEPTH    (MAX_DEGREE),
        .WIDTH    (FIFO_WIDTH),
        .READ_MODE("std")
    ) fifo_xpm_inst (
        // Global sync signals
        .clk (clk),
        .rstn (rstn),

        // Write group
        .wr_en (fifo_wr_en),
        .din   (fifo_din),
        .full  (fifo_full),

        // Read group
        .rd_en      (fifo_rd_en),
        .dout       (fifo_dout),
        .data_valid (fifo_data_valid),
        .empty      (fifo_empty)
    );


    logic   graph_build_data_valid;
    logic   graph_build_ready;
    logic   graph_build_done;
    logic   stream_clean_done;
    graph_build #(
        .WIDTH(FIFO_WIDTH)
    ) graph_build_inst (
        // ports
        .clk (clk),
        .rstn (rstn),
        .data_valid   (graph_build_data_valid),
        .event_stream_clean (event_stream_clean),
        .stream_clean_done  (stream_clean_done),
        .new_event (new_event),
        .module_ready (graph_build_ready),
        .module_done  (graph_build_done),

        // global_neighbor_buffer FIFO Write group
        .fifo_wr_en (fifo_wr_en),
        .fifo_din (fifo_din),
        .fifo_full (fifo_full)
    );



    logic graph_conv_start;
    logic graph_conv_done;
    logic  [L4_OUT_C * F_WIDTH -1 : 0] last_layer_out_pack;
    graph_conv #(
        .ADDR_WIDTH           (ADDR_WIDTH),
        .READ_BURST_LEN       (READ_BURST_LEN),
        .C_S_AXIS_TDATA_WIDTH (C_S_AXIS_TDATA_WIDTH),
        .WRITE_BURST_LEN      (WRITE_BURST_LEN),
        .C_M_AXIS_TDATA_WIDTH (C_M_AXIS_TDATA_WIDTH)
    ) graph_conv_inst (
        .clk (clk),
        .rstn (rstn),

        // control signals
        .module_start (graph_conv_start),
        .module_done  (graph_conv_done),

        // new_event input, comes with module_start
        .new_event (new_event),

        // FIFO read ports
        .fifo_rd_en (fifo_rd_en),
        .fifo_dout (fifo_dout),
        .fifo_data_valid (fifo_data_valid),
        .fifo_empty (fifo_empty),

        // DDR communication ports: IP to AXIS
        .uip2axi_rd_en (uip2axi_rd_en),
        .axi2uip_rd_done (axi2uip_rd_done),
        .uip2axi_rd_addr (uip2axi_rd_addr),
        .rd_buffer (rd_buffer),

        .uip2axi_wr_en (uip2axi_wr_en),
        .axi2uip_wr_done (axi2uip_wr_done),
        .uip2axi_wr_addr (uip2axi_wr_addr),
        .wr_buffer (wr_buffer),

        // Next module data output:  layer4_out
        .last_layer_out_pack (last_layer_out_pack)
    );

    logic max_pool_x_start;
    logic max_pool_x_done;
    grid_idx_t grid_idx;
    logic [L4_OUT_C * F_WIDTH -1 : 0] max_pool_x_out_pack;
    logic [L4_OUT_C * F_WIDTH -1 : 0] max_pool_dx_out_pack;
    max_pool_x max_pool_x_inst(
        .clk (clk),
        .rstn (rstn),
        .module_start          (max_pool_x_start),
        .event_stream_clean (event_stream_clean),
        .module_done           (max_pool_x_done),

        .new_event_x           (new_event.x),
        .new_event_y           (new_event.y),
        .last_layer_out_pack (last_layer_out_pack),
        .grid_idx (grid_idx),
        .max_pool_x_out_pack (max_pool_x_out_pack),
        .max_pool_dx_out_pack (max_pool_dx_out_pack)
    );

    logic linear_start;
    logic linear_done;
    logic fc_out_valid;
    linear #(
        .L4_OUT_C      (L4_OUT_C),
        .FC_OUT_C      (FC_OUT_C),
        .MEM_INIT_FILE (FC_MEM_INIT_FILE),
        .MAC_LATENCY   (MAC_LATENCY)
    ) linear_inst (
        .clk (clk),
        .rstn (rstn),
        .event_stream_clean (event_stream_clean),
        .module_start          (linear_start),
        .module_done           (linear_done),

        .grid_idx (grid_idx),
        .max_pool_dx_out_pack (max_pool_dx_out_pack),

        .fc_out_valid (fc_out_valid),
        .fc_out_pack (fc_out_pack)
    );

    // FSM
    typedef enum { IDLE, STREAM_CLEAN, CONTENT_CLEAR, GRAPH_BUILD, GRAPH_CONV, MAX_POOL_X, FC, DONE } aegnn_hw_fsm_e;
    aegnn_hw_fsm_e state;

    always @ (posedge clk) begin
        if (!rstn)
            state <= IDLE;
        else begin
            case (state)
                IDLE: begin
                    if (ip_en)
                        state <= GRAPH_BUILD;
                    if (ip_clean)
                        state <= STREAM_CLEAN;
                end

                STREAM_CLEAN: begin
                    if (stream_clean_done)
                        state <= CONTENT_CLEAR;
                end

                CONTENT_CLEAR: begin
                    if (!ip_clean)
                        state <= IDLE;
                end

                GRAPH_BUILD: begin
                    if (graph_build_done)
                        state <= GRAPH_CONV;
                end

                GRAPH_CONV: begin
                    if (graph_conv_done)
                        state <= MAX_POOL_X;
                end

                MAX_POOL_X: begin
                    if (max_pool_x_done)
                        state <= FC;
                end

                FC: begin
                    if (linear_done)
                        state <= DONE;
                end

                DONE: begin
                    if (!ip_en)
                        state <= IDLE;
                end

                default:
                    state <= IDLE;
            endcase
        end
    end

    assign ip_idle = (state == IDLE);
    assign ip_done = (state == DONE);
    assign event_stream_clean = (state == STREAM_CLEAN);
    assign ip_clear = (state == CONTENT_CLEAR);

    logic [FC_OUT_WIDTH -1 : 0] fc_out_0, fc_out_1;
    assign fc_out_0 = fc_out_pack [FC_OUT_WIDTH -1 : 0];
    assign fc_out_1 = fc_out_pack [2* FC_OUT_WIDTH -1 : FC_OUT_WIDTH];
    assign prediction = (fc_out_0 <= fc_out_1)? 0 : 1;  // TODO: check, which one is indicate "car", 0 or 1

    logic graph_build_valid;
    logic graph_conv_valid;
    logic max_pool_x_valid;
    logic linear_valid;
    assign graph_build_valid = (state == GRAPH_BUILD);
    assign graph_conv_valid  = (state == GRAPH_CONV);
    assign max_pool_x_valid  = (state == MAX_POOL_X);
    assign linear_valid      = (state == FC);

    // Block level control signals
    assign graph_build_data_valid = graph_build_valid;
    rise_detect graph_conv_rise_inst(
        .clk (clk),
        .rstn (rstn),
        .level (graph_conv_valid),
        .pulse (graph_conv_start)
    );
    rise_detect max_pool_x_rise_inst(
        .clk (clk),
        .rstn (rstn),
        .level (max_pool_x_valid),
        .pulse (max_pool_x_start)
    );
    rise_detect linear_rise_inst(
        .clk (clk),
        .rstn (rstn),
        .level (linear_valid),
        .pulse (linear_start)
    );



endmodule
