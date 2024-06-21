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

module tb_mult;

    logic  clk;
    f_t    feature;
    w_t    weight;
    mult_t product_code;
    mult_t product_ip;

    initial begin
        clk <= '0;
        feature <= '0;
        weight <= '0;

        #10;
        feature <= 255;
        weight <= -128;

        #50;
        feature <= 128;
        weight <= 127;

        #50;
        feature <= 2;
        weight <= 4;

        #50;
        feature <= 0;
        weight <= -1;
    end

    always #5 clk = ~clk;

    parameter LATENCY = 2;
    mult_GNN #(
        .LATENCY(LATENCY),
        .DEVICE ("code")
    ) mult_GNN_code (
        .clk    (clk),
        .feature(feature),
        .weight (weight),
        .product(product_code)
    );

    mult_GNN #(
        .LATENCY(LATENCY),
        .DEVICE ("ip")
    ) mult_GNN_ip (
        .clk    (clk),
        .feature(feature),
        .weight (weight),
        .product(product_ip)
    );

endmodule
