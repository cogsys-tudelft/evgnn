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
`timescale 1 ns / 1 ps

	module AXIS_AXIMM_v1_0_M00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Base address of targeted slave
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		// Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		parameter integer C_M_AXI_BURST_LEN	= 8,
		// Thread ID Width
		parameter integer C_M_AXI_ID_WIDTH	= 1,
		// Width of Address Bus
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		// Width of Data Bus
		parameter integer C_M_AXI_DATA_WIDTH	= 32,
		// Width of User Write Address Bus
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		// Width of User Read Address Bus
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		// Width of User Write Data Bus
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		// Width of User Read Data Bus
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		// Width of User Response Bus
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here
		input wire [C_M_AXI_ADDR_WIDTH - 1 : 0] 	S2MM_ADDR,
		input wire 									S2MM_ADDRVALID,
		output wire 								S2MM_ADDRREADY,

		input wire [C_M_AXI_ADDR_WIDTH - 1 : 0] 	MM2S_ADDR,
		input wire 									MM2S_ADDRVALID,
		output wire 								MM2S_ADDRREADY,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ready to accept data in
		output wire  S2MM_TREADY,
		// Data in
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] S2MM_TDATA,
		// Indicates boundary of last packet
		input wire  S2MM_TLAST,
		// Data is in valid
		input wire  S2MM_TVALID,


		// Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted.
		output wire  MM2S_TVALID,
		// TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] MM2S_TDATA,
		// TLAST indicates the boundary of a packet.
		output wire  MM2S_TLAST,
		// TREADY indicates that the slave can accept a transfer in the current cycle.
		input wire  MM2S_TREADY,


		input wire  M_AXI_ACLK,
		// Global Reset Singal. This Signal is Active Low
		input wire  M_AXI_ARESETN,


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


	// function called clogb2 that returns an integer which has the
	//value of the ceiling of the log base 2

	  // function called clogb2 that returns an integer which has the
	  // value of the ceiling of the log base 2.
	  function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
	      bit_depth = bit_depth >> 1;
	    end
	  endfunction

	// C_TRANSACTIONS_NUM is the width of the index counter for
	// number of write or read transaction.
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);

	// Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
	// Non-2^n lengths will eventually cause bursts across 4K address boundaries.
	 localparam integer C_MASTER_LENGTH	= 12;
	// total number of burst transfers is master length divided by burst length and burst size
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);

	// AXI4LITE signals
	//AXI4 internal temp signals
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid;
	reg  	axi_bready;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid;
	reg  	axi_rready;
	//write beat count in a burst
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg  	error_reg;

	//Interface response error flags
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;



	// I/O Connections assignments

	//I/O Connections. Write Address (AW)
	assign M_AXI_AWID	= 'b0;
	//The AXI address is a concatenation of the target base address + active offset range
	assign M_AXI_AWADDR	= S2MM_ADDR;
	//Burst LENgth is number of transaction beats, minus 1
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	//Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	//INCR burst type is usually used, except for keyhole bursts
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	//Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;


	//Write Data(W)
	assign M_AXI_WDATA	= S2MM_TDATA;
	//All bursts are complete and aligned in this example
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= S2MM_TVALID;
	assign S2MM_TREADY = M_AXI_WREADY;

	//Write Response (B)
	assign M_AXI_BREADY	= axi_bready;

	//Read Address (AR)
	assign M_AXI_ARID	= 'b0;
	assign M_AXI_ARADDR	= MM2S_ADDR;
	//Burst LENgth is number of transaction beats, minus 1
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	//Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	//INCR burst type is usually used, except for keyhole bursts
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	//Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID	= axi_arvalid;

	//Read and Read Response (R)
	assign M_AXI_RREADY	= MM2S_TREADY;
	assign MM2S_TVALID = M_AXI_RVALID;
	assign MM2S_TDATA = M_AXI_RDATA;
	assign MM2S_TLAST = M_AXI_RLAST;


	//--------------------
	//Write Address Channel
	//--------------------

	// The purpose of the write address channel is to request the address and
	// command information for the entire transaction.  It is a single beat
	// of information.

	// The AXI4 Write address channel in this example will continue to initiate
	// write commands as fast as it is allowed by the slave/interconnect.
	// The address will be incremented on each accepted address transaction,
	// by burst_size_byte to point to the next address.

	always @(posedge M_AXI_ACLK)
		begin
		    if (M_AXI_ARESETN == 0)
				begin
					axi_awvalid <= 1'b0;
				end
		    // If previously not valid , start next transaction
		    else if (S2MM_ADDRVALID)
		    	begin
		        	axi_awvalid <= 1'b1;
		      	end
		    else if (M_AXI_AWREADY && axi_awvalid)
		      	begin
		        	axi_awvalid <= 1'b0;
		      	end
		    else
		      	axi_awvalid <= axi_awvalid;
	    end
	assign S2MM_ADDRREADY =  M_AXI_AWREADY;



	//--------------------
	//Write Data Channel
	//--------------------

	//The write data will continually try to push write data across the interface.

	//The amount of data accepted will depend on the AXI slave and the AXI
	//Interconnect settings, such as if there are FIFOs enabled in interconnect.

	//Note that there is no explicit timing relationship to the write address channel.
	//The write channel has its own throttling flag, separate from the AW channel.

	//Synchronization between the channels must be determined by the user.

	//The simpliest but lowest performance would be to only issue one address write
	//and write data burst at a time.

	//In this example they are kept in sync by using the same address increment
	//and burst sizes. Then the AW and W channels have their transactions measured
	//with threshold counters as part of the user logic, to make sure neither
	//channel gets too far ahead of each other.

	//Forward movement occurs when the write channel is valid and ready

	  assign wnext = M_AXI_WREADY & S2MM_TVALID;

	//WLAST generation on the MSB of a counter underflow
	// WVALID logic, similar to the axi_awvalid always block above
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        axi_wlast <= 1'b0;
	      end
	    // axi_wlast is asserted when the write index
	    // count reaches the penultimate count to synchronize
	    // with the last write data when write_index is b1111
	    // else if (&(write_index[C_TRANSACTIONS_NUM-1:1])&& ~write_index[0] && wnext)
	    else if (((write_index == C_M_AXI_BURST_LEN-2 && C_M_AXI_BURST_LEN >= 2) && wnext) || (C_M_AXI_BURST_LEN == 1 ))
	      begin
	        axi_wlast <= 1'b1;
	      end
	    // Deassrt axi_wlast when the last write data has been
	    // accepted by the slave with a valid response
	    else if (wnext)
	      axi_wlast <= 1'b0;
	    else if (axi_wlast && C_M_AXI_BURST_LEN == 1)
	      axi_wlast <= 1'b0;
	    else
	      axi_wlast <= axi_wlast;
	  end


	/* Burst length counter. Uses extra counter register bit to indicate terminal
	 count to reduce decode logic */
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0 )
	      	begin
	        	write_index <= 0;
	      	end
	    else if (wnext && (write_index != C_M_AXI_BURST_LEN-1))
	      	begin
	        	write_index <= write_index + 1;
	      	end
	    else  if (wnext && axi_wlast)
	    	write_index <= 0;
	    else
	    	write_index <= write_index;
	  end





	//----------------------------
	//Write Response (B) Channel
	//----------------------------

	//The write response channel provides feedback that the write has committed
	//to memory. BREADY will occur when all of the data and the write address
	//has arrived and been accepted by the slave.

	//The write issuance (number of outstanding write addresses) is started by
	//the Address Write transfer, and is completed by a BREADY/BRESP.

	//While negating BREADY will eventually throttle the AWREADY signal,
	//it is best not to throttle the whole data channel this way.

	//The BRESP bit [1] is used indicate any errors from the interconnect or
	//slave for the entire write burst. This example will capture the error
	//into the ERROR output.

	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        axi_bready <= 1'b0;
	      end
	    // accept/acknowledge bresp with axi_bready by the master
	    // when M_AXI_BVALID is asserted by slave
	    else if (M_AXI_BVALID && ~axi_bready)
	      begin
	        axi_bready <= 1'b1;
	      end
	    // deassert after one clock cycle
	    else if (axi_bready)
	      begin
	        axi_bready <= 1'b0;
	      end
	    // retain the previous value
	    else
	      axi_bready <= axi_bready;
	  end


	//Flag any write response errors
	  assign write_resp_error = axi_bready & M_AXI_BVALID & M_AXI_BRESP[1];


	//----------------------------
	//Read Address Channel
	//----------------------------

	//The Read Address Channel (AW) provides a similar function to the
	//Write Address channel- to provide the tranfer qualifiers for the burst.

	//In this example, the read address increments in the same
	//manner as the write address channel.

	  always @(posedge M_AXI_ACLK)
	  begin

	    if (M_AXI_ARESETN == 0)
	      begin
	        axi_arvalid <= 1'b0;
	      end
	    // If previously not valid , start next transaction
	    else if (MM2S_ADDRVALID)
	      begin
	        axi_arvalid <= 1'b1;
	      end
	    else if (M_AXI_ARREADY && axi_arvalid)
	      begin
	        axi_arvalid <= 1'b0;
	      end
	    else
	      axi_arvalid <= axi_arvalid;
	  end
	 assign MM2S_ADDRREADY = M_AXI_ARREADY;




	//--------------------------------
	//Read Data (and Response) Channel
	//--------------------------------

	 // Forward movement occurs when the channel is valid and ready
	  assign rnext = M_AXI_RVALID && MM2S_TREADY;

	//Flag any read response errors
	  assign read_resp_error = MM2S_TREADY & M_AXI_RVALID & M_AXI_RRESP[1];

	//----------------------------------
	//Example design error register
	//----------------------------------

	//Register and hold any data mismatches, or read/write interface errors

	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        error_reg <= 1'b0;
	      end
	    else if (write_resp_error || read_resp_error)
	      begin
	        error_reg <= 1'b1;
	      end
	    else
	      error_reg <= error_reg;
	  end

	// Add user logic here

	// User logic ends

	endmodule
