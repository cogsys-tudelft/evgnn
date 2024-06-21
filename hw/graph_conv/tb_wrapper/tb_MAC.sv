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

module tb_MAC;

    logic  clk;
    logic  rstn;
    f_t    feature;
    w_t    weight;
    accum_t accum;
    logic input_valid;


    initial begin
        clk <= '0;
        rstn <= '0;
        feature <= '0;
        weight <= '0;


        #200;
        rstn <= '1;

        #10;
        feature <= 255;
        weight <= -128;

        #10;
        input_valid <= '1;
        feature <= 128;
        weight <= 127;


        #10;
        feature <= 2;
        weight <= 4;

        #10;
        feature <= 0;
        weight <= -1;

        // #10;
        // rstn <= '0;

        #10
        rstn <= '1;
        feature <= 3;
        weight <= 2;
    end

    always #5 clk = ~clk;

    parameter LATENCY = 4;
    MAC #(
        .LATENCY(LATENCY),
        .DEVICE ("code")
    ) MAC_inst (
        .clk    (clk),
        .rstn   (rstn),
        .feature(feature),
        .weight (weight),
        .accum_out  (accum)
    );


endmodule
