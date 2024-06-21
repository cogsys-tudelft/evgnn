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

module layer #(
    parameter integer        IN_C        = 34,
    parameter integer        OUT_C       = 32,
    parameter integer        MAC_LATENCY = 4,
    parameter [M_WIDTH -1:0] M           = 12345,
    parameter integer        NM          = 20,
    parameter                W_MEM_FILE  = "test_data.mem",
    parameter                B_MEM_FILE  = "test_bias_data.mem"
) (
    input  logic                        clk,
    input  logic                        rstn,
    input  logic                        is_neighbor,     // indicate a neighbor comes
    input  logic                        no_neighbor,     // indicate no future neighbor will come
    input  logic                        clean,           // indicate the whole graph conv of this event is finish, clean for next event
    input  logic [ IN_C * P_WIDTH -1:0] feature_in_pack,
    output logic [OUT_C * F_WIDTH -1:0] conv_out_pack,
    output logic                        neighbor_done,   // indicate a matvec is done
    output logic                        conv_done        // indicate this layer's all conv is done
);

    logic                          conv_out_valid;
    logic                          aggr_clean;
    logic                          calc_en;
    logic [OUT_C * B_WIDTH -1 : 0] accum_out_pack;
    logic                          accum_out_valid;
    logic [OUT_C * B_WIDTH -1 : 0] aggr_pack;
    logic                          aggr_valid;
    logic                          matvec_clean;


    // Inst
    matvec #(
        .IN_C             (IN_C       ),
        .OUT_C            (OUT_C      ),
        .MEM_INIT_FILE    (W_MEM_FILE ),
        .MAC_LATENCY      (MAC_LATENCY)
    ) matvec_inst (
        .clk              (clk            ),
        .rstn             (rstn           ),
        .clean            (matvec_clean   ),
        .calc_en          (calc_en        ),
        .feature_in_pack  (feature_in_pack),

        .accum_out_pack   (accum_out_pack ),
        .accum_out_valid  (accum_out_valid)
    );

    aggr #(
        .OUT_C           (OUT_C)
    ) aggr_inst (
        .clk             (clk            ),
        .rstn            (rstn           ),
        .is_neighbor     (is_neighbor    ),
        .no_neighbor     (no_neighbor    ),
        .clean           (aggr_clean      ),
        .accum_out_pack  (accum_out_pack ),
        .accum_out_valid (accum_out_valid),

        .aggr_pack       (aggr_pack      ),
        .aggr_valid      (aggr_valid     )
    );

    bias_act_quant #(
        .OUT_C          (OUT_C     ),
        .M              (M         ),
        .NM             (NM        ),
        .MEM_INIT_FILE  (B_MEM_FILE)
    ) bias_act_quant_inst (
        .clk            (clk           ),
        .rstn           (rstn          ),
        .aggr_pack      (aggr_pack     ),
        .aggr_valid     (aggr_valid    ),

        .conv_out_pack  (conv_out_pack ),
        .conv_out_valid (conv_out_valid)
    );

    // FSM
    typedef enum { IDLE, MATVEC, MATVEC_CLEAN, AGGR, BAQ, DONE, CLEAN } layer_fsm_e;
    layer_fsm_e state;

    always @ (posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    if (is_neighbor)       // if a real neighbor comes
                        state <= MATVEC;
                    else if (no_neighbor)  // if no more neighbors or no neighbor at all (fifo_empty at the beginning)
                        state <= AGGR;     // at the same time, aggr's state will change from IDLE to PASS_THROUGH / from COMPARE to OUTPUT
                    else
                        state <= IDLE;
                end
                MATVEC: begin
                    if (accum_out_valid)
                        state <= MATVEC_CLEAN;
                    else
                        state <= MATVEC;
                end
                MATVEC_CLEAN: begin
                    state <= IDLE;
                end
                AGGR: begin
                    if (aggr_valid)
                        state <= BAQ;
                    else
                        state <= AGGR;
                end
                BAQ: begin
                    if (conv_out_valid)
                        state <= DONE;
                    else
                        state <= BAQ;
                end
                DONE: begin
                    if (clean)
                        state <= CLEAN;
                    else
                        state <= DONE;
                end
                CLEAN: begin  // 1 clk for clean should be enough  TODO: 检查清空
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    assign calc_en       = (state == MATVEC);
    assign matvec_clean  = (state == MATVEC_CLEAN);
    assign neighbor_done = accum_out_valid;        // after neighbor_done, the outside is_neighbor should pull down

    assign conv_done     = (state == DONE);
    assign aggr_clean    = (conv_done && clean);






endmodule