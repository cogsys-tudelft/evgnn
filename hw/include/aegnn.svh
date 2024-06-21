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
`ifndef AEGNN_H
`define AEGNN_H

`timescale 1ns / 10ps

package aegnn;

    // Camera parameters
    parameter int X_PIXEL = 120;
    parameter int Y_PIXEL = 100;
    parameter int X_PIXEL_WIDTH = 8;
    parameter int Y_PIXEL_WIDTH = 8;
    parameter int TOT_PIXEL = X_PIXEL * Y_PIXEL;

    parameter int GRID_LENGTH = 16;
    parameter int GRID_HEIGHT = 16;
    parameter int GRID_X = (X_PIXEL + GRID_LENGTH - 1) / GRID_LENGTH;
    parameter int GRID_Y = (Y_PIXEL + GRID_HEIGHT - 1) / GRID_HEIGHT;
    parameter int GRID_NUM = GRID_X * GRID_Y;
    parameter int GRID_IDX_WIDTH = $clog2(GRID_NUM);
    parameter int TOT_PIXEL_WIDTH = $clog2(TOT_PIXEL);

    // Network hyper params
    parameter int MAX_DEGREE = 16;  //debug: 16?
    parameter int MAX_DT = 65535;  //debug: 65535?
    parameter int MAX_DS_RANGE = 25;  // // L1 distance, max_ds = 3, so containing 25 points

    // Quantization params
    parameter int W_WIDTH = 8;
    parameter int B_WIDTH = 32;
    parameter int F_WIDTH = 8;
    parameter int EXT_BITS = 2;
    parameter int P_WIDTH = F_WIDTH + EXT_BITS;  // dpos quant width
    parameter int M_WIDTH = 32;
    parameter int FC_W_WIDTH = 8;
    parameter int FC_OUT_WIDTH = 32;

    // Data on-chip storage
    parameter int T_WIDTH = 17;  // 17 is the lower limit; may need larger
    parameter int ADDR_WIDTH = 32;  // debug: check ARM addr width

    parameter int URAM_WIDTH = 72;
    parameter int FIFO_WIDTH = URAM_WIDTH;


    typedef logic signed   [W_WIDTH           -1 : 0] w_t;      // for weights in NN
    typedef logic unsigned [F_WIDTH           -1 : 0] f_t;      // for features in NN
    typedef logic unsigned [P_WIDTH           -1 : 0] p_t;      // for dpos "features" in NN
    typedef logic signed   [B_WIDTH           -1 : 0] b_t;      // for bias in NN
    typedef logic signed   [P_WIDTH + W_WIDTH -1 : 0] mult_t;   // for f*w result
    typedef logic signed   [B_WIDTH           -1 : 0] accum_t;  // for accumulated partial sum
    typedef logic signed   [B_WIDTH           -1 : 0] bias_t;   // bias is same as accumulated partial sum
    typedef logic signed   [FC_W_WIDTH        -1 : 0] fc_w_t;   // for weights in Linear (FC) layer
    typedef logic signed   [FC_OUT_WIDTH      -1 : 0] fc_out_t; // for outputs of Linear (FC) layer

    typedef logic [X_PIXEL_WIDTH    -1 : 0] x_idx_t;
    typedef logic [Y_PIXEL_WIDTH    -1 : 0] y_idx_t;
    typedef logic [TOT_PIXEL_WIDTH  -1 : 0] pixel_idx_t;
    typedef logic [GRID_IDX_WIDTH   -1 : 0] grid_idx_t;  // grid idx (< 63), used for max pool x and FC
    typedef logic [T_WIDTH          -1 : 0] time_t;
    typedef logic [ADDR_WIDTH       -1 : 0] mem_addr_t;


    typedef enum {
        IDLE,
        GRAPH_BUILD,
        GRAPH_CONV,
        MAXP,
        FC
    } func_stage_e;

    parameter int UNUSED_WIDTH = URAM_WIDTH - 2 - X_PIXEL_WIDTH - Y_PIXEL_WIDTH - T_WIDTH - ADDR_WIDTH;
    typedef struct packed {  // valid [1bit] + unused [5bit] + p [1bit] + x [8bit] + y [8bit] + time [17bit] + addr [32bit] = 72bit
        logic                        valid;
        logic [UNUSED_WIDTH  -1 : 0] unused;
        logic                        p;
        logic [X_PIXEL_WIDTH -1 : 0] x;
        logic [Y_PIXEL_WIDTH -1 : 0] y;
        logic [T_WIDTH       -1 : 0] t;
        logic [ADDR_WIDTH    -1 : 0] addr;
    } event_s;
endpackage

`endif


