// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
// Date        : Tue Jun 27 22:41:31 2023
// Host        : warp02.ewi.tudelft.nl running 64-bit Red Hat Enterprise Linux Server release 7.9 (Maipo)
// Command     : write_verilog -force -mode synth_stub
//               /users/yyang22/thesis/aegnn_project/vivado_dir/sys_acc/sys_acc.gen/sources_1/bd/top_bd/ip/top_bd_top_0_0/top_bd_top_0_0_stub.v
// Design      : top_bd_top_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xck26-sfvc784-2LV-c
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "top,Vivado 2022.2" *)
module top_bd_top_0_0(clk, rstn, S_AXI_AWADDR, S_AXI_AWPROT, 
  S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WVALID, S_AXI_BREADY, S_AXI_ARADDR, 
  S_AXI_ARPROT, S_AXI_ARVALID, S_AXI_RREADY, S_AXI_AWREADY, S_AXI_WREADY, S_AXI_BRESP, 
  S_AXI_BVALID, S_AXI_ARREADY, S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, M_AXI_AWID, 
  M_AXI_AWADDR, M_AXI_AWLEN, M_AXI_AWSIZE, M_AXI_AWBURST, M_AXI_AWLOCK, M_AXI_AWCACHE, 
  M_AXI_AWPROT, M_AXI_AWQOS, M_AXI_AWUSER, M_AXI_AWVALID, M_AXI_AWREADY, M_AXI_WDATA, 
  M_AXI_WSTRB, M_AXI_WLAST, M_AXI_WUSER, M_AXI_WVALID, M_AXI_WREADY, M_AXI_BID, M_AXI_BRESP, 
  M_AXI_BUSER, M_AXI_BVALID, M_AXI_BREADY, M_AXI_ARID, M_AXI_ARADDR, M_AXI_ARLEN, M_AXI_ARSIZE, 
  M_AXI_ARBURST, M_AXI_ARLOCK, M_AXI_ARCACHE, M_AXI_ARPROT, M_AXI_ARQOS, M_AXI_ARUSER, 
  M_AXI_ARVALID, M_AXI_ARREADY, M_AXI_RID, M_AXI_RDATA, M_AXI_RRESP, M_AXI_RLAST, M_AXI_RUSER, 
  M_AXI_RVALID, M_AXI_RREADY, ip_idle, ip_done, ip_clear, prediction, fc_out_pack, ip_en, ip_clean, 
  new_event)
/* synthesis syn_black_box black_box_pad_pin="clk,rstn,S_AXI_AWADDR[4:0],S_AXI_AWPROT[2:0],S_AXI_AWVALID,S_AXI_WDATA[31:0],S_AXI_WSTRB[3:0],S_AXI_WVALID,S_AXI_BREADY,S_AXI_ARADDR[4:0],S_AXI_ARPROT[2:0],S_AXI_ARVALID,S_AXI_RREADY,S_AXI_AWREADY,S_AXI_WREADY,S_AXI_BRESP[1:0],S_AXI_BVALID,S_AXI_ARREADY,S_AXI_RDATA[31:0],S_AXI_RRESP[1:0],S_AXI_RVALID,M_AXI_AWID[0:0],M_AXI_AWADDR[31:0],M_AXI_AWLEN[7:0],M_AXI_AWSIZE[2:0],M_AXI_AWBURST[1:0],M_AXI_AWLOCK,M_AXI_AWCACHE[3:0],M_AXI_AWPROT[2:0],M_AXI_AWQOS[3:0],M_AXI_AWUSER[0:0],M_AXI_AWVALID,M_AXI_AWREADY,M_AXI_WDATA[127:0],M_AXI_WSTRB[15:0],M_AXI_WLAST,M_AXI_WUSER[0:0],M_AXI_WVALID,M_AXI_WREADY,M_AXI_BID[0:0],M_AXI_BRESP[1:0],M_AXI_BUSER[0:0],M_AXI_BVALID,M_AXI_BREADY,M_AXI_ARID[0:0],M_AXI_ARADDR[31:0],M_AXI_ARLEN[7:0],M_AXI_ARSIZE[2:0],M_AXI_ARBURST[1:0],M_AXI_ARLOCK,M_AXI_ARCACHE[3:0],M_AXI_ARPROT[2:0],M_AXI_ARQOS[3:0],M_AXI_ARUSER[0:0],M_AXI_ARVALID,M_AXI_ARREADY,M_AXI_RID[0:0],M_AXI_RDATA[127:0],M_AXI_RRESP[1:0],M_AXI_RLAST,M_AXI_RUSER[0:0],M_AXI_RVALID,M_AXI_RREADY,ip_idle,ip_done,ip_clear,prediction,fc_out_pack[63:0],ip_en,ip_clean,new_event[71:0]" */;
  input clk;
  input rstn;
  input [4:0]S_AXI_AWADDR;
  input [2:0]S_AXI_AWPROT;
  input S_AXI_AWVALID;
  input [31:0]S_AXI_WDATA;
  input [3:0]S_AXI_WSTRB;
  input S_AXI_WVALID;
  input S_AXI_BREADY;
  input [4:0]S_AXI_ARADDR;
  input [2:0]S_AXI_ARPROT;
  input S_AXI_ARVALID;
  input S_AXI_RREADY;
  output S_AXI_AWREADY;
  output S_AXI_WREADY;
  output [1:0]S_AXI_BRESP;
  output S_AXI_BVALID;
  output S_AXI_ARREADY;
  output [31:0]S_AXI_RDATA;
  output [1:0]S_AXI_RRESP;
  output S_AXI_RVALID;
  output [0:0]M_AXI_AWID;
  output [31:0]M_AXI_AWADDR;
  output [7:0]M_AXI_AWLEN;
  output [2:0]M_AXI_AWSIZE;
  output [1:0]M_AXI_AWBURST;
  output M_AXI_AWLOCK;
  output [3:0]M_AXI_AWCACHE;
  output [2:0]M_AXI_AWPROT;
  output [3:0]M_AXI_AWQOS;
  output [0:0]M_AXI_AWUSER;
  output M_AXI_AWVALID;
  input M_AXI_AWREADY;
  output [127:0]M_AXI_WDATA;
  output [15:0]M_AXI_WSTRB;
  output M_AXI_WLAST;
  output [0:0]M_AXI_WUSER;
  output M_AXI_WVALID;
  input M_AXI_WREADY;
  input [0:0]M_AXI_BID;
  input [1:0]M_AXI_BRESP;
  input [0:0]M_AXI_BUSER;
  input M_AXI_BVALID;
  output M_AXI_BREADY;
  output [0:0]M_AXI_ARID;
  output [31:0]M_AXI_ARADDR;
  output [7:0]M_AXI_ARLEN;
  output [2:0]M_AXI_ARSIZE;
  output [1:0]M_AXI_ARBURST;
  output M_AXI_ARLOCK;
  output [3:0]M_AXI_ARCACHE;
  output [2:0]M_AXI_ARPROT;
  output [3:0]M_AXI_ARQOS;
  output [0:0]M_AXI_ARUSER;
  output M_AXI_ARVALID;
  input M_AXI_ARREADY;
  input [0:0]M_AXI_RID;
  input [127:0]M_AXI_RDATA;
  input [1:0]M_AXI_RRESP;
  input M_AXI_RLAST;
  input [0:0]M_AXI_RUSER;
  input M_AXI_RVALID;
  output M_AXI_RREADY;
  output ip_idle;
  output ip_done;
  output ip_clear;
  output prediction;
  output [63:0]fc_out_pack;
  output ip_en;
  output ip_clean;
  output [71:0]new_event;
endmodule
