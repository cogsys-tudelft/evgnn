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

module IP_M_AXIS_MM2S_CMD #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer READ_BURST_LEN = 8,
    parameter integer C_S_AXIS_TDATA_WIDTH	= 128,

    localparam integer BTT = READ_BURST_LEN * (C_S_AXIS_TDATA_WIDTH / 8)
)(
    input  wire clk,
    input  wire rstn,

    input  wire uip2axi_rd_en,
    input  wire [ADDR_WIDTH -1:0] uip2axi_rd_addr,

    output wire m_axis_mm2s_cmd_tvalid,
    input  wire m_axis_mm2s_cmd_tready,
    output wire [ADDR_WIDTH+40 -1:0] m_axis_mm2s_cmd_tdata
);

    reg [ADDR_WIDTH+40 -1:0] cmd;
    reg                      tvalid_reg;

    assign m_axis_mm2s_cmd_tdata = cmd;
    // assign m_axis_mm2s_cmd_tvalid = tvalid_reg;

    always @ (posedge clk) begin
        if (!rstn)
            cmd <= 'b0;
        else begin
            if (uip2axi_rd_en) begin
                cmd[ADDR_WIDTH+39 : ADDR_WIDTH+36] <= 4'b0;             // Reserved
                cmd[ADDR_WIDTH+35 : ADDR_WIDTH+32] <= 4'hA;             // Command T"A"G
                cmd[ADDR_WIDTH+31 :            32] <= uip2axi_rd_addr;  // Start Address
                cmd[                           31] <= 1'b0;             // DRE ReAlignment Request
                cmd[                           30] <= 1'b1;             // EOF  //TODO: DEBUG
                cmd[           29 :            24] <= 6'b0;             // DRE Stream Alignment
                cmd[                           23] <= 1'b1;             // Type: 1=INCR, 0=FIXED
                cmd[           22 :             0] <= BTT;              // Bytes to Transfer
            end
        end
    end

    // FSM
    localparam [1:0] IDLE           = 2'b00,
                     WAIT_HANDSHAKE = 2'b01,
                     HANDSHAKED     = 2'b10;
    reg [1:0] state;

    always @ (posedge clk) begin
        if (!rstn)
            state <= IDLE;
        else begin
            case (state)
            IDLE: begin
                if (uip2axi_rd_en)
                    state <= WAIT_HANDSHAKE;
                else
                    state <= IDLE;
            end
            WAIT_HANDSHAKE: begin
                if (m_axis_mm2s_cmd_tready)
                    state <= HANDSHAKED;
                else
                    state <= WAIT_HANDSHAKE;
            end
            HANDSHAKED: begin
                if (!uip2axi_rd_en)
                    state <= IDLE;
                else
                    state <= HANDSHAKED;
            end
            default: begin
                state <= IDLE;
            end
            endcase
        end
    end

    assign m_axis_mm2s_cmd_tvalid = (state == WAIT_HANDSHAKE);

    // // single command transfer
    // always @ (posedge clk) begin
    //     if (!rstn)
    //         tvalid_reg <= 1'b0;
    //     else begin
    //         case (tvalid_reg)
    //             1'b0: begin
    //                 if (uip2axi_rd_en)
    //                     tvalid_reg <= 1'b1;
    //                 else
    //                     tvalid_reg <= 1'b0;
    //             end
    //             1'b1: begin
    //                 if (m_axis_mm2s_cmd_tready)
    //                     tvalid_reg <= 1'b0;
    //                 else
    //                     tvalid_reg <= 1'b1;
    //             end
    //         endcase
    //     end
    // end


endmodule