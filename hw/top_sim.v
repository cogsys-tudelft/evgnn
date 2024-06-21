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

module top_sim #(
    parameter  integer FC_OUT_C               = 2,
    parameter  integer L4_OUT_C               = 32,
	parameter  integer FC_OUT_WIDTH           = 32,
    parameter  integer URAM_WIDTH             = 72,
    parameter  integer ADDR_WIDTH             = 32,

    parameter  integer S_AXI_NUM_REG          = 8,
    parameter  integer C_S_AXI_DATA_WIDTH     = 32,
    parameter  integer READ_BURST_LEN         = 8,
    parameter  integer C_S_AXIS_TDATA_WIDTH	  = 128,
    parameter  integer WRITE_BURST_LEN        = 8,
    parameter  integer C_M_AXIS_TDATA_WIDTH	  = 128,

    parameter  integer C_M_TARGET_SLAVE_BASE_ADDR	= 32'h00000000,
    parameter  integer C_M_AXI_BURST_LEN	  = 8,
    parameter  integer C_M_AXI_ID_WIDTH	      = 1,
    parameter  integer C_M_AXI_ADDR_WIDTH	  = 32,
    parameter  integer C_M_AXI_DATA_WIDTH	  = 128,
    parameter  integer C_M_AXI_AWUSER_WIDTH	  = 0,
    parameter  integer C_M_AXI_ARUSER_WIDTH	  = 0,
    parameter  integer C_M_AXI_WUSER_WIDTH	  = 0,
    parameter  integer C_M_AXI_RUSER_WIDTH	  = 0,
    parameter  integer C_M_AXI_BUSER_WIDTH	  = 0,

	parameter  integer C_S_AXI_ADDR_WIDTH     = $clog2(S_AXI_NUM_REG * C_S_AXI_DATA_WIDTH / 8),
    localparam integer WR_BUF_LEN             = WRITE_BURST_LEN * C_M_AXIS_TDATA_WIDTH,
    localparam integer RD_BUF_LEN             = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH
)(
    input  wire clk,
    input  wire rstn,

    // due to sim, temporarily comment
    /*
    // S_AXI_Lite
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire [2 : 0] S_AXI_AWPROT,
    input  wire S_AXI_AWVALID,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire S_AXI_WVALID,
    input  wire S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input  wire [2 : 0] S_AXI_ARPROT,
    input  wire S_AXI_ARVALID,
    input  wire S_AXI_RREADY,

    output wire S_AXI_AWREADY,
    output wire S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    output wire S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire S_AXI_RVALID,
    */

    // M_AXI
    output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
    output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
    output wire [7 : 0] M_AXI_AWLEN,
    output wire [2 : 0] M_AXI_AWSIZE,
    output wire [1 : 0] M_AXI_AWBURST,
    output wire  M_AXI_AWLOCK,
    output wire [3 : 0] M_AXI_AWCACHE,
    output wire [2 : 0] M_AXI_AWPROT,
    output wire [3 : 0] M_AXI_AWQOS,
    output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
    output wire  M_AXI_AWVALID,
    input  wire  M_AXI_AWREADY,
    output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
    output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
    output wire  M_AXI_WLAST,
    output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
    output wire  M_AXI_WVALID,
    input  wire  M_AXI_WREADY,
    input  wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
    input  wire [1 : 0] M_AXI_BRESP,
    input  wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
    input  wire  M_AXI_BVALID,
    output wire  M_AXI_BREADY,
    output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
    output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
    output wire [7 : 0] M_AXI_ARLEN,
    output wire [2 : 0] M_AXI_ARSIZE,
    output wire [1 : 0] M_AXI_ARBURST,
    output wire  M_AXI_ARLOCK,
    output wire [3 : 0] M_AXI_ARCACHE,
    output wire [2 : 0] M_AXI_ARPROT,
    output wire [3 : 0] M_AXI_ARQOS,
    output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
    output wire  M_AXI_ARVALID,
    input  wire  M_AXI_ARREADY,
    input  wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
    input  wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
    input  wire [1 : 0] M_AXI_RRESP,
    input  wire  M_AXI_RLAST,
    input  wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
    input  wire  M_AXI_RVALID,
    output wire  M_AXI_RREADY,

    // sim: IP control and I/O
    output wire                                ip_idle,
    output wire                                ip_done,
    output wire                                ip_clear,
    output wire                                prediction,
    output wire [FC_OUT_C * FC_OUT_WIDTH -1:0] fc_out_pack,

    input  wire                                ip_en,
    input  wire                                ip_clean,
    input  wire [URAM_WIDTH              -1:0] new_event
);

    // // IP control and I/O
    // wire                                ip_idle;
    // wire                                ip_done;
    // wire                                prediction;
    // wire [FC_OUT_C * FC_OUT_WIDTH -1:0] fc_out_pack;

    // wire                                ip_en;
    // wire                                ip_clean;
    // wire [URAM_WIDTH              -1:0] new_event;


    // IP DDR communication
    wire                      uip2axi_rd_en;
    wire                      axi2uip_rd_done;
    wire  [ADDR_WIDTH -1 : 0] uip2axi_rd_addr;
    wire  [RD_BUF_LEN -1 : 0] rd_buffer;

    wire                      uip2axi_wr_en;
    wire                      axi2uip_wr_done;
    wire  [ADDR_WIDTH -1 : 0] uip2axi_wr_addr;
    wire  [WR_BUF_LEN -1 : 0] wr_buffer;

    aegnn_hw #(
        .ADDR_WIDTH           ( ADDR_WIDTH           ),
        .READ_BURST_LEN       ( READ_BURST_LEN       ),
        .C_S_AXIS_TDATA_WIDTH ( C_S_AXIS_TDATA_WIDTH ),
        .WRITE_BURST_LEN      ( WRITE_BURST_LEN      ),
        .C_M_AXIS_TDATA_WIDTH ( C_M_AXIS_TDATA_WIDTH ),
        .L4_OUT_C             ( L4_OUT_C             ),
        .FC_OUT_C             ( FC_OUT_C             )
    ) aegnn_hw_inst (
        .clk             ( clk             ),
        .rstn            ( rstn            ),
        // IP control signals
        .ip_en           ( ip_en           ),
        .ip_clean        ( ip_clean        ),
        .ip_idle         ( ip_idle         ),
        .ip_done         ( ip_done         ),
        .ip_clear        ( ip_clear        ),
        // Input: new event data
        .new_event       ( new_event       ),
        // Output: linear data out
        .prediction      ( prediction      ),
        .fc_out_pack     ( fc_out_pack     ),
        // DDR IP Communication
        .uip2axi_rd_en   ( uip2axi_rd_en   ),
        .axi2uip_rd_done ( axi2uip_rd_done ),
        .uip2axi_rd_addr ( uip2axi_rd_addr ),
        .rd_buffer       ( rd_buffer       ),
        .uip2axi_wr_en   ( uip2axi_wr_en   ),
        .axi2uip_wr_done ( axi2uip_wr_done ),
        .uip2axi_wr_addr ( uip2axi_wr_addr ),
        .wr_buffer       ( wr_buffer       )
    );

    wire                                   M_AXIS_TVALID;
	wire [C_M_AXIS_TDATA_WIDTH     -1 : 0] M_AXIS_TDATA;
	wire [(C_M_AXIS_TDATA_WIDTH/8) -1 : 0] M_AXIS_TSTRB;
	wire                                   M_AXIS_TLAST;
	wire                                   M_AXIS_TREADY;

    IP_M_AXIS_S2MM #(
        .WRITE_BURST_LEN        ( WRITE_BURST_LEN      ),
		.C_M_AXIS_TDATA_WIDTH	( C_M_AXIS_TDATA_WIDTH )
    ) IP_M_AXIS_S2MM_inst (
        .uip2axi_wr_en   ( uip2axi_wr_en   ),
        .axi2uip_wr_done ( axi2uip_wr_done ),
        .wr_buffer       ( wr_buffer       ),

		.M_AXIS_ACLK     ( clk             ),
		.M_AXIS_ARESETN  ( rstn            ),
		.M_AXIS_TVALID   ( M_AXIS_TVALID   ),
		.M_AXIS_TDATA    ( M_AXIS_TDATA    ),
		.M_AXIS_TSTRB    ( M_AXIS_TSTRB    ),
		.M_AXIS_TLAST    ( M_AXIS_TLAST    ),
		.M_AXIS_TREADY   ( M_AXIS_TREADY   )
	);


    wire                                    S_AXIS_TREADY;
    wire  [C_S_AXIS_TDATA_WIDTH     -1 : 0] S_AXIS_TDATA;
    wire  [(C_S_AXIS_TDATA_WIDTH/8) -1 : 0] S_AXIS_TSTRB;
    wire                                    S_AXIS_TLAST;
    wire                                    S_AXIS_TVALID;

    IP_S_AXIS_MM2S #(
        .READ_BURST_LEN        ( READ_BURST_LEN       ),
		.C_S_AXIS_TDATA_WIDTH  ( C_S_AXIS_TDATA_WIDTH )
    ) IP_S_AXIS_MM2S_inst (
        .uip2axi_rd_en    ( uip2axi_rd_en   ),
        .axi2uip_rd_done  ( axi2uip_rd_done ),
        .rd_buffer        ( rd_buffer       ),

		.S_AXIS_ACLK      ( clk             ),
		.S_AXIS_ARESETN   ( rstn            ),
		.S_AXIS_TREADY    ( S_AXIS_TREADY   ),
		.S_AXIS_TDATA     ( S_AXIS_TDATA    ),
		.S_AXIS_TSTRB     ( S_AXIS_TSTRB    ),
		.S_AXIS_TLAST     ( S_AXIS_TLAST    ),
		.S_AXIS_TVALID    ( S_AXIS_TVALID   )
	);

    wire S2MM_ADDRVALID, S2MM_ADDRREADY;
    rise_detect gen_S2MM_ADDRVALID(
        .clk   ( clk            ),
        .rstn  ( rstn           ),
        .level ( uip2axi_wr_en  ),
        .pulse ( S2MM_ADDRVALID )
    );
    wire MM2S_ADDRVALID, MM2S_ADDRREADY;
    rise_detect gen_MM2S_ADDRVALID(
        .clk   ( clk            ),
        .rstn  ( rstn           ),
        .level ( uip2axi_rd_en  ),
        .pulse ( MM2S_ADDRVALID )
    );
    AXIS_AXIMM_v1_0_M00_AXI #(
        .C_M_TARGET_SLAVE_BASE_ADDR ( C_M_TARGET_SLAVE_BASE_ADDR ),
        .C_M_AXI_BURST_LEN          ( C_M_AXI_BURST_LEN          ),
        .C_M_AXI_ID_WIDTH           ( C_M_AXI_ID_WIDTH           ),
        .C_M_AXI_ADDR_WIDTH         ( C_M_AXI_ADDR_WIDTH         ),
        .C_M_AXI_DATA_WIDTH         ( C_M_AXI_DATA_WIDTH         ),
        .C_M_AXI_AWUSER_WIDTH       ( C_M_AXI_AWUSER_WIDTH       ),
        .C_M_AXI_ARUSER_WIDTH       ( C_M_AXI_ARUSER_WIDTH       ),
        .C_M_AXI_WUSER_WIDTH        ( C_M_AXI_WUSER_WIDTH        ),
        .C_M_AXI_RUSER_WIDTH        ( C_M_AXI_RUSER_WIDTH        ),
        .C_M_AXI_BUSER_WIDTH        ( C_M_AXI_BUSER_WIDTH        )
    ) AXIS_AXIMM_v1_0_M00_AXI_inst (
        .S2MM_ADDR               ( uip2axi_wr_addr  ),
        .S2MM_ADDRVALID          ( S2MM_ADDRVALID   ),
        .S2MM_TDATA              ( M_AXIS_TDATA     ),
        .S2MM_TLAST              ( M_AXIS_TLAST     ),
        .S2MM_TVALID             ( M_AXIS_TVALID    ),
        .S2MM_ADDRREADY          ( S2MM_ADDRREADY   ),
        .S2MM_TREADY             ( M_AXIS_TREADY     ),

        .MM2S_ADDR               ( uip2axi_rd_addr  ),
        .MM2S_ADDRVALID          ( MM2S_ADDRVALID   ),
        .MM2S_TREADY             ( S_AXIS_TREADY    ),
        .MM2S_ADDRREADY          ( MM2S_ADDRREADY   ),
        .MM2S_TVALID             ( S_AXIS_TVALID    ),
        .MM2S_TDATA              ( S_AXIS_TDATA     ),
        .MM2S_TLAST              ( S_AXIS_TLAST     ),

        .M_AXI_ACLK              ( clk              ),
        .M_AXI_ARESETN           ( rstn             ),
        .M_AXI_AWREADY           ( M_AXI_AWREADY    ),
        .M_AXI_WREADY            ( M_AXI_WREADY     ),
        .M_AXI_BID               ( M_AXI_BID        ),
        .M_AXI_BRESP             ( M_AXI_BRESP      ),
        .M_AXI_BUSER             ( M_AXI_BUSER      ),
        .M_AXI_BVALID            ( M_AXI_BVALID     ),
        .M_AXI_ARREADY           ( M_AXI_ARREADY    ),
        .M_AXI_RID               ( M_AXI_RID        ),
        .M_AXI_RDATA             ( M_AXI_RDATA      ),
        .M_AXI_RRESP             ( M_AXI_RRESP      ),
        .M_AXI_RLAST             ( M_AXI_RLAST      ),
        .M_AXI_RUSER             ( M_AXI_RUSER      ),
        .M_AXI_RVALID            ( M_AXI_RVALID     ),
        .M_AXI_AWID              ( M_AXI_AWID       ),
        .M_AXI_AWADDR            ( M_AXI_AWADDR     ),
        .M_AXI_AWLEN             ( M_AXI_AWLEN      ),
        .M_AXI_AWSIZE            ( M_AXI_AWSIZE     ),
        .M_AXI_AWBURST           ( M_AXI_AWBURST    ),
        .M_AXI_AWLOCK            ( M_AXI_AWLOCK     ),
        .M_AXI_AWCACHE           ( M_AXI_AWCACHE    ),
        .M_AXI_AWPROT            ( M_AXI_AWPROT     ),
        .M_AXI_AWQOS             ( M_AXI_AWQOS      ),
        .M_AXI_AWUSER            ( M_AXI_AWUSER     ),
        .M_AXI_AWVALID           ( M_AXI_AWVALID    ),
        .M_AXI_WDATA             ( M_AXI_WDATA      ),
        .M_AXI_WSTRB             ( M_AXI_WSTRB      ),
        .M_AXI_WLAST             ( M_AXI_WLAST      ),
        .M_AXI_WUSER             ( M_AXI_WUSER      ),
        .M_AXI_WVALID            ( M_AXI_WVALID     ),
        .M_AXI_BREADY            ( M_AXI_BREADY     ),
        .M_AXI_ARID              ( M_AXI_ARID       ),
        .M_AXI_ARADDR            ( M_AXI_ARADDR     ),
        .M_AXI_ARLEN             ( M_AXI_ARLEN      ),
        .M_AXI_ARSIZE            ( M_AXI_ARSIZE     ),
        .M_AXI_ARBURST           ( M_AXI_ARBURST    ),
        .M_AXI_ARLOCK            ( M_AXI_ARLOCK     ),
        .M_AXI_ARCACHE           ( M_AXI_ARCACHE    ),
        .M_AXI_ARPROT            ( M_AXI_ARPROT     ),
        .M_AXI_ARQOS             ( M_AXI_ARQOS      ),
        .M_AXI_ARUSER            ( M_AXI_ARUSER     ),
        .M_AXI_ARVALID           ( M_AXI_ARVALID    ),
        .M_AXI_RREADY            ( M_AXI_RREADY     )
    );

    // due to sim, temporarily comment
    /*
    config_S_AXILite #(
        .S_AXI_NUM_REG      (S_AXI_NUM_REG     ),
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH)
    ) config_S_AXILite_inst (
        .ip_idle            (ip_idle        ),
        .ip_done            (ip_done        ),
        .ip_clear           (ip_clear       ),
        .prediction         (prediction     ),
        .FC_out             (fc_out_pack    ),

        .S_AXI_ACLK         (clk            ),
        .S_AXI_ARESETN      (rstn           ),

        .S_AXI_AWADDR       (S_AXI_AWADDR   ),
        .S_AXI_AWPROT       (S_AXI_AWPROT   ),
        .S_AXI_AWVALID      (S_AXI_AWVALID  ),
        .S_AXI_WDATA        (S_AXI_WDATA    ),
        .S_AXI_WSTRB        (S_AXI_WSTRB    ),
        .S_AXI_WVALID       (S_AXI_WVALID   ),
        .S_AXI_BREADY       (S_AXI_BREADY   ),
        .S_AXI_ARADDR       (S_AXI_ARADDR   ),
        .S_AXI_ARPROT       (S_AXI_ARPROT   ),
        .S_AXI_ARVALID      (S_AXI_ARVALID  ),
        .S_AXI_RREADY       (S_AXI_RREADY   ),

        .ip_en              (ip_en          ),
        .ip_clean           (ip_clean       ),
        .new_event          (new_event      ),

        .S_AXI_AWREADY      (S_AXI_AWREADY  ),
        .S_AXI_WREADY       (S_AXI_WREADY   ),
        .S_AXI_BRESP        (S_AXI_BRESP    ),
        .S_AXI_BVALID       (S_AXI_BVALID   ),
        .S_AXI_ARREADY      (S_AXI_ARREADY  ),
        .S_AXI_RDATA        (S_AXI_RDATA    ),
        .S_AXI_RRESP        (S_AXI_RRESP    ),
        .S_AXI_RVALID       (S_AXI_RVALID   )
    );
    */

endmodule