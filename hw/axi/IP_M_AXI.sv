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

module IP_M_AXI #(
    // parameter


    parameter integer C_M_AXI_BURST_LEN	    = 8,   // Burst Length. (1, 2, 4, 8, 16, 32, 64, 128, 256)
    parameter integer C_M_AXI_ADDR_WIDTH	= 32,  // Width of Address Bus
    parameter integer C_M_AXI_DATA_WIDTH	= 128, // Width of Data Bus
    parameter integer C_M_AXI_ID_WIDTH	    = 1,   // Thread ID Width
    parameter integer C_M_AXI_AWUSER_WIDTH	= 0,   // Width of User Write Address Bus
    parameter integer C_M_AXI_ARUSER_WIDTH	= 0,   // Width of User Read Address Bus
    parameter integer C_M_AXI_WUSER_WIDTH	= 0,   // Width of User Write Data Bus
    parameter integer C_M_AXI_RUSER_WIDTH	= 0,   // Width of User Read Data Bus
    parameter integer C_M_AXI_BUSER_WIDTH	= 0,   // Width of User Response Bus

    // Total bits to transfer. Equal to buffer width
    localparam integer C_BUF_WIDTH = C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH,
    localparam integer C_BUF_IDX_WIDTH  = $clog2(C_M_AXI_BURST_LEN),
    // C_TRANSACTIONS_NUM is the width of the index counter for
	// number of write or read transaction.
    localparam integer C_TRANSACTIONS_NUM = $clog2(C_M_AXI_BURST_LEN),
	// Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
	// Non-2^n lengths will eventually cause bursts across 4K address boundaries.
    localparam integer C_MASTER_LENGTH	= 12,
	// total number of burst transfers is master length divided by burst length and burst size
    localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-$clog2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8))
) (
    input wire clk,
    input wire rstn,

    // IP Write
    input  wire  uip2axi_wr_en,   // from user IP: now can start write
    input  wire  [C_M_AXI_ADDR_WIDTH -1:0] uip2axi_wr_addr,
    output reg   axi2uip_wr_done, // tell user IP, pulse: write done
    input  reg   [C_BUF_WIDTH -1:0] wr_buffer,  // valid buffer from IP, should come with wr_en

    // IP Read
    input  wire  uip2axi_rd_en,   // from user IP: now can start read
    input  wire  [C_M_AXI_ADDR_WIDTH -1:0] uip2axi_rd_addr,
    output reg   axi2uip_rd_done, // tell user IP, pulse: sink has accepted all the MM data
    output reg   [C_BUF_WIDTH -1:0] rd_buffer,  // buffer to store MM data

    // M AXI
    // Write Address Channel
    // Master Interface Write Address ID
    output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
    // Master Interface Write Address
    output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
    // Burst length. The burst length gives the exact number of transfers in a burst
    output wire [7 : 0] M_AXI_AWLEN,
    // Burst size. This signal indicates the size of each transfer in the burst
    output wire [2 : 0] M_AXI_AWSIZE,
    // Burst type. The burst type and the size information,
    // determine how the address for each transfer within the burst is calculated.
    output wire [1 : 0] M_AXI_AWBURST,
    // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
    output wire  M_AXI_AWLOCK,
    // Memory type. This signal indicates how transactions
    // are required to progress through a system.
    output wire [3 : 0] M_AXI_AWCACHE,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    output wire [2 : 0] M_AXI_AWPROT,
    // Quality of Service, QoS identifier sent for each write transaction.
    output wire [3 : 0] M_AXI_AWQOS,
    // Optional User-defined signal in the write address channel.
    output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
    // Write address valid. This signal indicates that
    // the channel is signaling valid write address and control information.
    output wire  M_AXI_AWVALID,
    // Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
    input wire  M_AXI_AWREADY,

    // Write Channel
    // Master Interface Write Data.
    output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
    // Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
    output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
    // Write last. This signal indicates the last transfer in a write burst.
    output wire  M_AXI_WLAST,
    // Optional User-defined signal in the write data channel.
    output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
    // Write valid. This signal indicates that valid write
    // data and strobes are available
    output wire  M_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    input wire  M_AXI_WREADY,

    // Write Response Channel
    // Master Interface Write Response.
    input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
    // Write response. This signal indicates the status of the write transaction.
    input wire [1 : 0] M_AXI_BRESP,
    // Optional User-defined signal in the write response channel
    input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
    // Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
    input wire  M_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    output wire  M_AXI_BREADY,

    // Read Address Channel
    // Master Interface Read Address.
    output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
    // Read address. This signal indicates the initial
    // address of a read burst transaction.
    output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
    // Burst length. The burst length gives the exact number of transfers in a burst
    output wire [7 : 0] M_AXI_ARLEN,
    // Burst size. This signal indicates the size of each transfer in the burst
    output wire [2 : 0] M_AXI_ARSIZE,
    // Burst type. The burst type and the size information,
    // determine how the address for each transfer within the burst is calculated.
    output wire [1 : 0] M_AXI_ARBURST,
    // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
    output wire  M_AXI_ARLOCK,
    // Memory type. This signal indicates how transactions
    // are required to progress through a system.
    output wire [3 : 0] M_AXI_ARCACHE,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    output wire [2 : 0] M_AXI_ARPROT,
    // Quality of Service, QoS identifier sent for each read transaction
    output wire [3 : 0] M_AXI_ARQOS,
    // Optional User-defined signal in the read address channel.
    output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
    // Write address valid. This signal indicates that
    // the channel is signaling valid read address and control information
    output wire  M_AXI_ARVALID,
    // Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
    input wire  M_AXI_ARREADY,

    // Read Channel
    // Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
    input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
    // Master Read Data
    input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
    // Read response. This signal indicates the status of the read transfer
    input wire [1 : 0] M_AXI_RRESP,
    // Read last. This signal indicates the last transfer in a read burst
    input wire  M_AXI_RLAST,
    // Optional User-defined signal in the read address channel.
    input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
    // Read valid. This signal indicates that the channel
    // is signaling the required read data.
    input wire  M_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    output wire  M_AXI_RREADY
);

    typedef enum { IDLE, AW, W, B, WR_DONE, AR, R, RD_DONE } axi_fsm_e;
    axi_fsm_e state;

    reg	[C_BUF_IDX_WIDTH-1:0]	wr_buffer_idx;	// wr_buffer read pointer   // same as a data counter
    reg	[C_BUF_IDX_WIDTH-1:0]	rd_buffer_idx;	// rd_buffer write pointer  // same as a data counter

    // Overall FSM for AXI control
    always @ (posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin  // Not support full duplex
                    if (uip2axi_wr_en)
                        state <= AW;
                    if (uip2axi_rd_en)
                        state <= AR;
                end

                AW: begin
                    if (/*aw_handshake*/)
                        state <= W;
                end
                W: begin
                    if (/*some wr end*/)
                        state <= B;
                end
                B: begin
                    if (/*b_handshake*/)
                        state <= WR_DONE;
                end
                WR_DONE: begin
                    if (!uip2axi_wr_en)
                        state <= IDLE;
                end

                AR: begin
                    if (/*ar_handshake*/)
                        state <= R;
                end
                R: begin
                    if (/*some rd end*/)
                        state <= RD_DONE;
                end
                RD_DONE: begin
                    if (!uip2axi_rd_en)
                        state <= IDLE;
                end

                default:
                    state <= IDLE;
            endcase
        end
    end

endmodule