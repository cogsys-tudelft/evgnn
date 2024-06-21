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

module linear #(
    parameter integer L4_OUT_C = 32,
    parameter integer FC_OUT_C = 2,
    parameter         MEM_INIT_FILE = "FC_w.mem",
    parameter integer MAC_LATENCY = 4,

    localparam integer FC_IN_C = GRID_NUM * L4_OUT_C,
    localparam integer FC_IN_C_WIDTH = $clog2(FC_IN_C)
) (
    input logic clk,
    input logic rstn,
    input logic event_stream_clean,
    input logic module_start,
    output logic module_done,

    input grid_idx_t grid_idx,
    input logic [L4_OUT_C * F_WIDTH -1 : 0] max_pool_dx_out_pack,

    output logic fc_out_valid,
    output logic [FC_OUT_C * FC_OUT_WIDTH -1 : 0] fc_out_pack
);

    // Unpack
    logic [L4_OUT_C -1 : 0][F_WIDTH -1 : 0] max_pool_x;
    generate
        for (genvar i = 0; i < L4_OUT_C; i++) begin
            assign max_pool_x[i] = max_pool_dx_out_pack[(i+1)*F_WIDTH -1 -: F_WIDTH];
        end
    endgenerate

    // Control FSM
    typedef enum { IDLE, MATVEC, DONE } fc_fsm_e;
    fc_fsm_e state;
    always @ (posedge clk) begin
        if (!rstn || event_stream_clean)
            state <= IDLE;
        else begin
            case (state)
                IDLE:
                    if (module_start)
                        state <= MATVEC;
                MATVEC:
                    if (fc_out_valid)
                        state <= DONE;
                DONE:
                    state <= IDLE;
                default:
                    state <= IDLE;
            endcase
        end
    end
    logic matvec;
    assign matvec = (state == MATVEC);
    assign module_done = (state == DONE);

    // Inst Linear layer weight matrix
    logic [FC_OUT_C -1:0][FC_W_WIDTH -1:0] fc_w;
    logic [FC_IN_C_WIDTH           -1 : 0] w_idx;
    logic [FC_IN_C_WIDTH           -1 : 0] w_idx_base;
    logic [$clog2(L4_OUT_C)        -1 : 0] w_idx_offset;

    linear_w_mat #(
        .FC_IN_C       (FC_IN_C      ),
        .FC_OUT_C      (FC_OUT_C     ),
        .MEM_INIT_FILE (MEM_INIT_FILE)
    ) linear_w_mat_inst (
        .clk   (clk   ),
        .rd_en (matvec),
        .w_idx (w_idx ),
        .fc_w  (fc_w  )
    );

    // (* rom_style = "block" *) logic [FC_OUT_C * FC_W_WIDTH -1 : 0] fc_w_mem [0 : FC_IN_C -1];
    // initial begin
    //     $readmemh(MEM_INIT_FILE, fc_w_mem);
    // end
    // always @ (posedge clk) begin
    //     if (!rstn || event_stream_clean) begin
    //         fc_w <= '0;
    //     end
    //     else begin
    //         if (matvec)
    //             fc_w <= fc_w_mem[w_idx];
    //         else
    //             fc_w <= '0;
    //     end
    // end

    // Data prepare
    assign w_idx_base = grid_idx * L4_OUT_C;
    assign w_idx = w_idx_base + w_idx_offset;

    logic last_idx;
    always @ (posedge clk) begin
        if (!rstn || event_stream_clean) begin
            w_idx_offset <= '0;
            last_idx <= '0;
        end
        else begin
            if (matvec) begin
                if (w_idx_offset < L4_OUT_C - 1) begin
                    w_idx_offset <= w_idx_offset + 1;
                    last_idx <= '0;
                end
                else if (w_idx_offset == L4_OUT_C - 1) begin
                    w_idx_offset <= w_idx_offset;
                    last_idx <= '1;
                end
            end
            else begin
                w_idx_offset <= '0;
                last_idx <= '0;
            end
        end
    end

    // Delay 1 clk to sync with fc_w_mem (BRAM)
    p_t feature_reg, feature_clean, feature;

    always @(posedge clk) begin
        if (!rstn || event_stream_clean) begin
            feature_reg <= 0;
        end
        else begin
            if (matvec)
                feature_reg <= {{EXT_BITS{1'b0}}, max_pool_x[w_idx_offset]};
            else
                feature_reg <= 0;
        end
    end

    always @ (posedge clk) begin
        if (last_idx)
            feature_clean <= '0;
        else
            feature_clean <= '1;
    end
    assign feature = feature_reg & feature_clean;  // to stop accumulation


    // Channel-wise MatVec
    generate
        for (genvar out_c_idx = 0; out_c_idx < FC_OUT_C; out_c_idx++) begin
            fc_w_t fc_w_vec;
            assign fc_w_vec = fc_w[out_c_idx];
            // w_t    fc_w_extend;
            // assign fc_w_extend = {{(W_WIDTH - FC_W_WIDTH){fc_w_vec[FC_W_WIDTH-1]}}, fc_w_vec};

            fc_out_t fc_out;
            assign fc_out_pack[(out_c_idx+1)*FC_OUT_WIDTH -1 -: FC_OUT_WIDTH] = fc_out;

            // Here I still use the older MAC for 8bit*8bit, so I have to extend the fc_w
            MAC #(
                .LATENCY   (MAC_LATENCY)
            ) MAC_inst (
                .clk       (clk),
                .rstn      (rstn & ~event_stream_clean),
                .feature   (feature),
                .weight    (fc_w_vec),
                .accum_out (fc_out)
            );
        end
    endgenerate

    // Generate fc_out_valid
    logic [MAC_LATENCY -1:0] fc_out_valid_reg ;
    always @ (posedge clk) begin
        if (!rstn || event_stream_clean)
            fc_out_valid_reg <= '0;
        else begin
            if (matvec) begin
                fc_out_valid_reg[0] <= last_idx;
                for (int i = 0; i < MAC_LATENCY - 1; i++)
                    fc_out_valid_reg[i+1] <= fc_out_valid_reg[i];
                end
            else
                fc_out_valid_reg <= '0;
        end
    end
    assign fc_out_valid = fc_out_valid_reg[MAC_LATENCY - 1];



endmodule