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

module MAC_wrapper (
    input         clk,
    input         rstn,
    input  [8-1:0]  feature,
    input  [8-1:0]  weight,
    output [32-1:0] accum
);

    parameter LATENCY = 3;

    MAC #(
        .LATENCY(LATENCY),
        .DEVICE ("code")
    ) MAC_inst (
        .clk    (clk),
        .rstn   (rstn),
        .feature(feature),
        .weight (weight),
        .accum(accum)
    );



endmodule