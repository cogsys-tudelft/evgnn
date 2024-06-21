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

module tb_aegnn_hw;

    logic clk;
    logic rstn;
    logic data_valid;
    logic module_ready;
    logic module_done;
    event_s new_event;

    aegnn_hw #(
        .FIFO_WIDTH (72)
    ) aegnn_hw_inst (
        .clk,
        .rstn,
        .data_valid,
        .module_ready,
        .module_done,
        .new_event
    );


    initial begin
        clk <= '0;
        rstn <= '0;
        data_valid <= '0;
        new_event <= '0;

        #2000;
        rstn <= 'b1;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd0;
        new_event.addr <= 'hD00D_B00F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd1;
        new_event.addr <= 'hD01D_B01F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd2;
        new_event.addr <= 'hD00D_B02F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd3;
        new_event.addr <= 'hD01D_B03F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd4;
        new_event.addr <= 'hD00D_B04F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd5;
        new_event.addr <= 'hD01D_B05F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd6;
        new_event.addr <= 'hD00D_B06F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd7;
        new_event.addr <= 'hD01D_B07F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd8;
        new_event.addr <= 'hD00D_B08F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd9;
        new_event.addr <= 'hD01D_B09F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd02;
        new_event.y <= 'd02;
        new_event.t <= 'd10;
        new_event.addr <= 'hD02D_B10F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd11;
        new_event.addr <= 'hD00D_B11F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd12;
        new_event.addr <= 'hD01D_B12F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd13;
        new_event.addr <= 'hD00D_B13F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd14;
        new_event.addr <= 'hD01D_B14F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd15;
        new_event.addr <= 'hD00D_B15F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd16;
        new_event.addr <= 'hD01D_B16F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd17;
        new_event.addr <= 'hD00D_B17F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd18;
        new_event.addr <= 'hD01D_B18F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd19;
        new_event.addr <= 'hD00D_B19F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd20;
        new_event.addr <= 'hD01D_B20F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd21;
        new_event.addr <= 'hD00D_B21F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd01;
        new_event.y <= 'd01;
        new_event.t <= 'd22;
        new_event.addr <= 'hD01D_B22F;

        #4000
        data_valid <= 'b1;
        new_event.valid <= 'b1;
        new_event.p <= 'b1;
        new_event.x <= 'd00;
        new_event.y <= 'd00;
        new_event.t <= 'd65552;
        new_event.addr <= 'hBEEF_BEEF;

    end

    // always @ (posedge module_ready) begin
    //     #63;
    //     new_event.t <= new_event.t + 1'd1;
    //     data_valid <= 'b1;
    // end

    always @ (posedge module_ready) begin
        rstn <= 'b0;
        #50;
        rstn <= 'b1;
    end

    always @ (posedge clk) begin
        if (data_valid)
            data_valid <= '0;
    end

    always #5 clk = ~clk;


endmodule