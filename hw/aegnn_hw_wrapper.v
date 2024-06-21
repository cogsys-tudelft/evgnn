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
`timescale 1ns / 1ps

module aegnn_hw_wrapper (
    input  wire          clk,
    input  wire          rstn,
    input  wire          data_valid,
    input  wire [72-1:0] new_event,
    output wire          module_ready,
    output wire          module_done
);

    aegnn_hw #(
        .FIFO_WIDTH(72)
    ) aegnn_hw_inst (
        .clk          (clk),
        .rstn         (rstn),
        .data_valid   (data_valid),
        .new_event    (new_event),
        .module_ready (module_ready),
        .module_done  (module_done)
    );

endmodule
