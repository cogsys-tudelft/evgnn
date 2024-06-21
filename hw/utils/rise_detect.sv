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

module rise_detect (
    input  logic clk,
    input  logic rstn,
    input  logic level,
    output logic pulse
);
    logic level_reg;

    always @ (posedge clk) begin
        if (!rstn) begin
            pulse     <= 1'b0;
            level_reg <= 1'b0;
        end
        else begin
            level_reg <= level;
            pulse <= ({level_reg, level} == 2'b01);
        end
    end
endmodule

