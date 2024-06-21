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

module diff_abs #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH -1 : 0] a,  // Note: positive!
    input  logic [WIDTH -1 : 0] b,  // Note: positive!
    output logic [WIDTH -1 : 0] a_b_abs
);
    logic [WIDTH+1 -1 : 0] diff;

    always_comb begin
        diff = a - b;
        if (diff[WIDTH] == 1'b1)
            a_b_abs = (~diff) + 1'b1;
        else
            a_b_abs = diff;
    end

endmodule


module dpos_quant #(
    parameter integer Q_SCALE = 255,
    parameter integer Q_DPOS  = 256
)(
    input  logic   clk,
    input  logic   rstn,
    input  x_idx_t new_x,
    input  x_idx_t neighbor_x,
    input  y_idx_t new_y,
    input  y_idx_t neighbor_y,
    input  logic   new_p,
    input  logic   neighbor_p,
    input  logic   in_valid,
    output p_t     q_dx,
    output p_t     q_dy,
    output p_t     q_new_p,
    output p_t     q_neighbor_p,
    output logic   out_valid
);

    logic [X_PIXEL_WIDTH -1:0] dx_abs;
    logic [Y_PIXEL_WIDTH -1:0] dy_abs;

    diff_abs #(
        .WIDTH(X_PIXEL_WIDTH)
    ) diff_abs_u1 (
        .a(new_x),
        .b(neighbor_x),
        .a_b_abs(dx_abs)
    );

    diff_abs #(
        .WIDTH(Y_PIXEL_WIDTH)
    ) diff_abs_u2 (
        .a(new_y),
        .b(neighbor_y),
        .a_b_abs(dy_abs)
    );

    always @ (posedge clk) begin
        if (!rstn) begin
            q_dx         <= '0;
            q_dy         <= '0;
            q_new_p      <= '0;
            q_neighbor_p <= '0;
            out_valid    <= '0;
        end
        else begin
            if (in_valid) begin
                q_dx         <= {{EXT_BITS{1'b0}}, dx_abs} * Q_DPOS;
                q_dy         <= {{EXT_BITS{1'b0}}, dy_abs} * Q_DPOS;
                q_new_p      <= {{EXT_BITS{1'b0}}, new_p}  * Q_SCALE;
                q_neighbor_p <= {{EXT_BITS{1'b0}}, neighbor_p} * Q_SCALE;
                out_valid    <= 1'b1;
            end
            else
                out_valid    <= 1'b0;
        end
    end



endmodule