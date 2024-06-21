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

module graph_conv #(
    parameter integer ADDR_WIDTH             = 32,

    parameter integer READ_BURST_LEN         = 8,
    parameter integer C_S_AXIS_TDATA_WIDTH	 = 128,

    parameter integer WRITE_BURST_LEN        = 8,
    parameter integer C_M_AXIS_TDATA_WIDTH	 = 128,

    localparam integer RD_BUF_LEN = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH,
    localparam integer WR_BUF_LEN = WRITE_BURST_LEN * C_M_AXIS_TDATA_WIDTH,
    localparam integer PAD_WIDTH             = 128,

    localparam integer        Q_SCALE        = 255,
    localparam integer        Q_DPOS         = 256,

    localparam integer        L1_IN_C        = 3,
    localparam integer        L1_OUT_C       = 16,
    localparam [M_WIDTH -1:0] L1_M           = 8029,
    localparam                L1_W_MEM_FILE  = "L1_w.mem",
    localparam                L1_B_MEM_FILE  = "L1_b.mem",

    localparam integer        L2_IN_C        = 18,
    localparam integer        L2_OUT_C       = 32,
    localparam [M_WIDTH -1:0] L2_M           = 8215,
    localparam                L2_W_MEM_FILE  = "L2_w.mem",
    localparam                L2_B_MEM_FILE  = "L2_b.mem",

    localparam integer        L3_IN_C        = 34,
    localparam integer        L3_OUT_C       = 32,
    localparam [M_WIDTH -1:0] L3_M           = 6088,
    localparam                L3_W_MEM_FILE  = "L3_w.mem",
    localparam                L3_B_MEM_FILE  = "L3_b.mem",

    localparam integer        L4_IN_C        = 34,
    localparam integer        L4_OUT_C       = 32,
    localparam [M_WIDTH -1:0] L4_M           = 8550,
    localparam                L4_W_MEM_FILE  = "L4_w.mem",
    localparam                L4_B_MEM_FILE  = "L4_b.mem"
) (
    input  logic  clk,
    input  logic  rstn,

    // control signals
    input  logic  module_start,
    output logic  module_done,

    // new_event input, comes with module_start
    input event_s new_event,

    // FIFO read ports
    output logic  fifo_rd_en,
    input  logic  [FIFO_WIDTH -1 : 0] fifo_dout,
    input  logic  fifo_data_valid,
    input  logic  fifo_empty,

    // DDR communication ports: IP to AXIS
    // Buffer:
    // 16*8bit unused + 16*8bit layer1_out + 32*8bit layer2_out + 32*8bit layer3_out + 32*8bit layer4_out
    // layer4_out is not necessary

    output logic  uip2axi_rd_en,
    input  logic  axi2uip_rd_done,
    output logic  [ADDR_WIDTH -1 : 0] uip2axi_rd_addr,
    input  logic  [RD_BUF_LEN -1 : 0] rd_buffer,

    output logic  uip2axi_wr_en,
    input  logic  axi2uip_wr_done,
    output logic  [ADDR_WIDTH -1 : 0] uip2axi_wr_addr,
    output logic  [WR_BUF_LEN -1 : 0] wr_buffer,

    // Next module data output:  layer4_out
    output logic  [L4_OUT_C * F_WIDTH -1 : 0] last_layer_out_pack
);
    // Segment:
    // this event out:         L1o  L2o  L3o  L4o
    //                   | x | 16 | 32 | 32 | 32 |
    // next event in:          L2i  L3i  L4i

    logic [L1_OUT_C * F_WIDTH -1 : 0] L1_wr_buffer, L2_rd_buffer;
    logic [L2_OUT_C * F_WIDTH -1 : 0] L2_wr_buffer, L3_rd_buffer;
    logic [L3_OUT_C * F_WIDTH -1 : 0] L3_wr_buffer, L4_rd_buffer;
    logic [L4_OUT_C * F_WIDTH -1 : 0] L4_wr_buffer;

    assign L2_rd_buffer =
            rd_buffer[L1_OUT_C*F_WIDTH                     + PAD_WIDTH -1 :                               PAD_WIDTH];
    assign L3_rd_buffer =
            rd_buffer[(L1_OUT_C+L2_OUT_C)*F_WIDTH          + PAD_WIDTH -1 : L1_OUT_C*F_WIDTH            + PAD_WIDTH];
    assign L4_rd_buffer =
            rd_buffer[(L1_OUT_C+L2_OUT_C+L3_OUT_C)*F_WIDTH + PAD_WIDTH -1 : (L1_OUT_C+L2_OUT_C)*F_WIDTH + PAD_WIDTH];

    // for debug:
    logic [PAD_WIDTH-1:0] L1_rd_buffer;
    assign L1_rd_buffer = rd_buffer[PAD_WIDTH -1 :0];
    logic [L4_OUT_C * F_WIDTH -1 : 0] Lx_rd_buffer;
    assign Lx_rd_buffer = rd_buffer[(L1_OUT_C+L2_OUT_C+L3_OUT_C+L4_OUT_C)*F_WIDTH + PAD_WIDTH -1 : (L1_OUT_C+L2_OUT_C+L3_OUT_C)*F_WIDTH + PAD_WIDTH];


    assign wr_buffer[                                                PAD_WIDTH -1 :                                                0] =
            '1;  // for debug, write full 1s as pad date
    assign wr_buffer[L1_OUT_C*F_WIDTH                              + PAD_WIDTH -1 :                                        PAD_WIDTH] =
            L1_wr_buffer;
    assign wr_buffer[(L1_OUT_C+L2_OUT_C)*F_WIDTH                   + PAD_WIDTH -1 : L1_OUT_C*F_WIDTH                     + PAD_WIDTH] =
            L2_wr_buffer;
    assign wr_buffer[(L1_OUT_C+L2_OUT_C+L3_OUT_C)*F_WIDTH          + PAD_WIDTH -1 : (L1_OUT_C+L2_OUT_C)*F_WIDTH          + PAD_WIDTH] =
            L3_wr_buffer;
    assign wr_buffer[(L1_OUT_C+L2_OUT_C+L3_OUT_C+L4_OUT_C)*F_WIDTH + PAD_WIDTH -1 : (L1_OUT_C+L2_OUT_C+L3_OUT_C)*F_WIDTH + PAD_WIDTH] =
            L4_wr_buffer;



    // FSM state transition
    typedef enum { IDLE, READ_FIFO, WAIT_READ_FIFO, READ_MEM, LAYER, LAYER_FINAL, WRITE_MEM, DONE } graph_conv_fsm_e;
    graph_conv_fsm_e state;
    logic all_layer_neighbor_done;
    logic all_layer_conv_done;

    always @ (posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    if (module_start)
                        state <= READ_FIFO;
                end
                READ_FIFO: begin
                    if (!fifo_empty)
                        state <= WAIT_READ_FIFO;  //  Only generate 1 clk read enable pulse
                    else
                        state <= LAYER_FINAL;
                end
                WAIT_READ_FIFO: begin  // for a standard FIFO, read latency = 1. NOT suitable for FWFT
                    state <= READ_MEM;
                end
                READ_MEM: begin
                    if (axi2uip_rd_done)
                        state <= LAYER;
                end
                LAYER: begin
                    if (all_layer_neighbor_done)
                        state <= READ_FIFO;  // this neighbor has been processed, read next neighbor
                end
                LAYER_FINAL: begin
                    if (all_layer_conv_done)
                        state <= WRITE_MEM;  // all neighbors have been processed / no neighbor at all
                end
                WRITE_MEM: begin
                    if (axi2uip_wr_done)
                        state <= DONE;
                end
                DONE: begin
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end



    // FSM actions for each sub-modules

    // READ_FIFO task:
    // If FIFO is not empty, generate 1 clk read enable pulse, to read only 1 next data
    // If FIFO is empty, no read enable is needed
    always_comb begin
        if ((state == READ_FIFO) && (!fifo_empty))
            fifo_rd_en = 1'b1;
        else
            fifo_rd_en = 1'b0;
    end



    // WAIT_READ_FIFO tasks:
    // 1. Unpack FIFO data. At this time, the fifo_dout is already valid
    event_s neighbor_event;
    assign neighbor_event = fifo_dout;

    // 2. Using the handshake FIFO valid, generate layer 1 input
    logic [L1_IN_C -1:0][P_WIDTH -1:0] L1_feature_in;
    logic [P_WIDTH -1:0] q_new_p;
    logic dpos_quant_in_valid;
    logic dpos_quant_out_valid;

    assign dpos_quant_in_valid = (state == WAIT_READ_FIFO);

    dpos_quant #(
        .Q_SCALE (Q_SCALE),
        .Q_DPOS  (Q_DPOS )
    ) dpos_quant_inst (
        .clk          (clk),
        .rstn         (rstn),
        .new_x        (new_event.x),
        .neighbor_x   (neighbor_event.x),
        .new_y        (new_event.y),
        .neighbor_y   (neighbor_event.y),
        .new_p        (new_event.p),
        .neighbor_p   (neighbor_event.p),
        .in_valid     (dpos_quant_in_valid),

        .q_dx         (L1_feature_in[1]),
        .q_dy         (L1_feature_in[2]),
        .q_new_p      (q_new_p),
        .q_neighbor_p (L1_feature_in[0]),
        .out_valid    (dpos_quant_out_valid)
    );


    // READ_MEM tasks:
    // 1. Pass valid addr to DDR read port addr
    always_comb begin
        if (state == READ_MEM)
            uip2axi_rd_addr = neighbor_event.addr;
        else
            uip2axi_rd_addr = 32'hFFFF_FFFF;
    end

    // 2. Generate DDR read enable
    always_comb begin
        if (state == READ_MEM)
            uip2axi_rd_en = 1'b1;
        else
            uip2axi_rd_en = 1'b0;
    end

    // 3. Until receive rd_done, latch input DDR data and unpack it
    logic [L2_IN_C -1:0][P_WIDTH -1:0] L2_feature_in;
    logic [L3_IN_C -1:0][P_WIDTH -1:0] L3_feature_in;
    logic [L4_IN_C -1:0][P_WIDTH -1:0] L4_feature_in;
    always @ (posedge clk) begin
        if (!rstn) begin
            L2_feature_in <= '0;
            L3_feature_in <= '0;
            L4_feature_in <= '0;
        end
        else begin
            if ((state == READ_MEM) && (axi2uip_rd_done)) begin
                L2_feature_in[L2_IN_C -2] <= L1_feature_in[1];  // q_dx
                L3_feature_in[L3_IN_C -2] <= L1_feature_in[1];  // q_dx
                L4_feature_in[L4_IN_C -2] <= L1_feature_in[1];  // q_dx

                L2_feature_in[L2_IN_C -1] <= L1_feature_in[2];  // q_dy
                L3_feature_in[L3_IN_C -1] <= L1_feature_in[2];  // q_dy
                L4_feature_in[L4_IN_C -1] <= L1_feature_in[2];  // q_dy

                for (int i = 0; i < (L2_IN_C-2); i++) begin
                    L2_feature_in[i] <= {{EXT_BITS{1'b0}}, L2_rd_buffer[(i+1)*F_WIDTH -1 -: F_WIDTH]};
                end
                for (int j = 0; j < (L3_IN_C-2); j++) begin
                    L3_feature_in[j] <= {{EXT_BITS{1'b0}}, L3_rd_buffer[(j+1)*F_WIDTH -1 -: F_WIDTH]};
                end
                for (int k = 0; k < (L4_IN_C-2); k++) begin
                    L4_feature_in[k] <= {{EXT_BITS{1'b0}}, L4_rd_buffer[(k+1)*F_WIDTH -1 -: F_WIDTH]};
                end

            end
        end
    end


    // Inst all 4 layers. Due to HUGNet, 4 layers can be processed at the same time
    logic is_neighbor;
    logic no_neighbor;
    logic clean;

    logic L1_neighbor_done;
    logic [L1_OUT_C -1:0][F_WIDTH -1:0] L1_conv_out;
    logic L1_conv_done;
    layer #(
        .IN_C        (L1_IN_C),
        .OUT_C       (L1_OUT_C),
        .M           (L1_M),
        .W_MEM_FILE  (L1_W_MEM_FILE),
        .B_MEM_FILE  (L1_B_MEM_FILE)
    ) L1 (
        .clk             (clk),
        .rstn            (rstn),
        .is_neighbor     (is_neighbor),
        .no_neighbor     (no_neighbor),
        .clean           (clean),
        .feature_in_pack (L1_feature_in),

        .conv_out_pack   (L1_conv_out),
        .neighbor_done   (L1_neighbor_done),
        .conv_done       (L1_conv_done)
    );

    logic L2_neighbor_done;
    logic [L2_OUT_C -1:0][F_WIDTH -1:0] L2_conv_out;
    logic L2_conv_done;
    layer #(
        .IN_C        (L2_IN_C),
        .OUT_C       (L2_OUT_C),
        .M           (L2_M),
        .W_MEM_FILE  (L2_W_MEM_FILE),
        .B_MEM_FILE  (L2_B_MEM_FILE)
    ) L2 (
        .clk             (clk),
        .rstn            (rstn),
        .is_neighbor     (is_neighbor),
        .no_neighbor     (no_neighbor),
        .clean           (clean),
        .feature_in_pack (L2_feature_in),

        .conv_out_pack   (L2_conv_out),
        .neighbor_done   (L2_neighbor_done),
        .conv_done       (L2_conv_done)
    );

    logic L3_neighbor_done;
    logic [L3_OUT_C -1:0][F_WIDTH -1:0] L3_conv_out;
    logic L3_conv_done;
    layer #(
        .IN_C        (L3_IN_C),
        .OUT_C       (L3_OUT_C),
        .M           (L3_M),
        .W_MEM_FILE  (L3_W_MEM_FILE),
        .B_MEM_FILE  (L3_B_MEM_FILE)
    ) L3 (
        .clk             (clk),
        .rstn            (rstn),
        .is_neighbor     (is_neighbor),
        .no_neighbor     (no_neighbor),
        .clean           (clean),
        .feature_in_pack (L3_feature_in),

        .conv_out_pack   (L3_conv_out),
        .neighbor_done   (L3_neighbor_done),
        .conv_done       (L3_conv_done)
    );

    logic L4_neighbor_done;
    logic [L4_OUT_C -1:0][F_WIDTH -1:0] L4_conv_out;
    logic L4_conv_done;
    layer #(
        .IN_C        (L4_IN_C),
        .OUT_C       (L4_OUT_C),
        .M           (L4_M),
        .W_MEM_FILE  (L4_W_MEM_FILE),
        .B_MEM_FILE  (L4_B_MEM_FILE)
    ) L4 (
        .clk             (clk),
        .rstn            (rstn),
        .is_neighbor     (is_neighbor),
        .no_neighbor     (no_neighbor),
        .clean           (clean),
        .feature_in_pack (L4_feature_in),

        .conv_out_pack   (L4_conv_out),
        .neighbor_done   (L4_neighbor_done),
        .conv_done       (L4_conv_done)
    );



    // LAYER tasks:
    // 1. Generate is_neighbor pulse signal to start layer's matvec process
    // always_comb begin
    //     if (state == LAYER)
    //         is_neighbor = 1'b1;
    //     else
    //         is_neighbor = 1'b0;
    // end
    always @ (posedge clk) begin
        if (!rstn)
            is_neighbor <= 1'b0;
        else begin
            if ((state == READ_MEM) && (axi2uip_rd_done))  // <=> next_state == LAYER
                is_neighbor <= 1'b1;
            else if (state == LAYER)  // after 1 clk of entering LAYER state
                is_neighbor <= 1'b0;
            else
                is_neighbor <= 1'b0;
        end
    end

    // 2. Wait for each layer's neighbor_done appears at least 1 time
    logic [3:0] all_layer_neighbor_done_onehot;
    assign all_layer_neighbor_done = (all_layer_neighbor_done_onehot == 4'b1111);

    always @ (posedge clk) begin
        if (!rstn) begin
            all_layer_neighbor_done_onehot <= '0;
        end
        else begin
            if ((state == LAYER) && (!all_layer_neighbor_done)) begin
                if (L1_neighbor_done)
                    all_layer_neighbor_done_onehot[0] <= 1'b1;
                if (L2_neighbor_done)
                    all_layer_neighbor_done_onehot[1] <= 1'b1;
                if (L3_neighbor_done)
                    all_layer_neighbor_done_onehot[2] <= 1'b1;
                if (L4_neighbor_done)
                    all_layer_neighbor_done_onehot[3] <= 1'b1;
            end
            else begin // 1 clk pulse
                all_layer_neighbor_done_onehot <= '0;
            end
        end
    end

    // LAYER_FINAL task:
    // 1. Generate no_neighbor signal to start layer's aggr output and final bias-quantization-activation
    // always_comb begin
    //     if (state == LAYER_FINAL)
    //         no_neighbor = 1'b1;
    //     else
    //         no_neighbor = 1'b0;
    // end
    always @ (posedge clk) begin
        if (!rstn)
            no_neighbor <= 1'b0;
        else begin
            if ((state == READ_FIFO) && (fifo_empty))  // <=> next_state == LAYER_FINAL
                no_neighbor <= 1'b1;
            else if (state == LAYER_FINAL)  // after 1 clk of entering LAYER_FINAL state
                no_neighbor <= 1'b0;
            else
                no_neighbor <= 1'b0;
        end
    end

    // 2. Wait for each layer's conv_done appears at least 1 time
    logic [3:0] all_layer_conv_done_onehot;
    assign all_layer_conv_done = (all_layer_conv_done_onehot == 4'b1111);

    always @ (posedge clk) begin
        if (!rstn) begin
            all_layer_conv_done_onehot <= '0;
        end
        else begin
            if ((state == LAYER_FINAL) && (!all_layer_conv_done)) begin
                if (L1_conv_done)
                    all_layer_conv_done_onehot[0] <= 1'b1;
                if (L2_conv_done)
                    all_layer_conv_done_onehot[1] <= 1'b1;
                if (L3_conv_done)
                    all_layer_conv_done_onehot[2] <= 1'b1;
                if (L4_conv_done)
                    all_layer_conv_done_onehot[3] <= 1'b1;
            end
            else begin // 1 clk pulse
                all_layer_conv_done_onehot <= '0;
            end
        end
    end



    // WRITE_MEM tasks:
    // Note: all signals are delayed 1 clk for more robust output
    // 1. Pack conv_out signals
    always @ (posedge clk) begin
        if (!rstn) begin
            L1_wr_buffer <= '0;
            L2_wr_buffer <= '0;
            L3_wr_buffer <= '0;
            L4_wr_buffer <= '0;
        end
        else begin
            if (state == WRITE_MEM) begin
                for (int a = 0; a < (L1_OUT_C); a++) begin
                    L1_wr_buffer[(a+1)*F_WIDTH -1 -: F_WIDTH] <= L1_conv_out[a];
                end
                for (int b = 0; b < (L2_OUT_C); b++) begin
                    L2_wr_buffer[(b+1)*F_WIDTH -1 -: F_WIDTH] <= L2_conv_out[b];
                end
                for (int c = 0; c < (L3_OUT_C); c++) begin
                    L3_wr_buffer[(c+1)*F_WIDTH -1 -: F_WIDTH] <= L3_conv_out[c];
                end
                for (int d = 0; d < (L4_OUT_C); d++) begin
                    L4_wr_buffer[(d+1)*F_WIDTH -1 -: F_WIDTH] <= L4_conv_out[d];
                end
            end
        end
    end

    // 2. Enable DDR write signal
    always @ (posedge clk) begin
        if (!rstn) begin
            uip2axi_wr_en   <= 1'b0;
            uip2axi_wr_addr <= 32'hFFFF_FFFF;
        end
        else begin
            if (state == WRITE_MEM) begin
                uip2axi_wr_addr <= new_event.addr;
                if (!axi2uip_wr_done)
                    uip2axi_wr_en <= 1'b1;
                else
                    uip2axi_wr_en <= 1'b0;
            end
        end
    end

    // 3. Generate output for Max pool
    assign last_layer_out_pack = L4_wr_buffer;

    // DONE task:
    // Generate clean and done signal. Since Lx_wr_buffer only changed in WRITE_MEM state, so they are not affected
    always_comb begin
        if (state == DONE) begin
            clean       = 1'b1;
            module_done = 1'b1;
        end
        else begin
            clean       = 1'b0;
            module_done = 1'b0;
        end
    end

endmodule