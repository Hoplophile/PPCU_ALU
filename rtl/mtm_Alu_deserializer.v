/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:    mtm_Alu_deserializer
 * PROJECT:   PPCU_VLSI
 * AUTHORS:		P. Ziebinski
 * DATE:
 * ------------------------------------------------------------------------------
 *
 *******************************************************************************/

//DEMUX STATES
`define IDLE 	3'b000
`define START	3'b001
`define READ	3'b010
`define STOP	3'b011
`define ERROR	3'b100

//ERROR FLAGS
`define ERR_DATA	6'b100100
`define ERR_CRC		6'b010010
`define ERR_OP		6'b001001


module mtm_Alu_deserializer(
	input wire clk,
	input wire rst,	
	input wire sin,		//serial input
	output reg [31:0] Aout	//A output
	output reg [31:0] Bout	//B output
	output reg [2:0] OPout	//CTL output
);
	
	reg [31:0] Aout_nxt;
	reg [31:0] A;
	reg [31:0] A_nxt;
	
	reg [31:0] Bout_nxt;
	reg [31:0] B;
	reg [31:0] B_nxt;
	
	reg [2:0] CRC;
	
	reg [2:0] OPout_nxt;
	reg [2:0] CTL;
	reg [2:0] CTL_nxt;
	
	reg [5:0] ERR_FLAGS;
	reg [5:0] ERR_FLAGS_nxt;

	reg [3:0] bit_counter;
	reg [3:0] bit_counter_nxt;
	
	reg [3:0] packet_counter;
	reg [3:0] packet_counter_nxt;

	reg [2:0] demux_state;
	reg [2:0] demux_state_nxt;

	
	always @(posedge clk or posedge rst) begin
		if(!rst) begin
			demux_state 	<= `IDLE;
			A				<= 0;
			B				<= 0;
			CTL				<= 0;
			bit_counter		<= 0;
			packet_counter	<= 0;
			ERR_FLAGS		<= 0;
			Aout			<= 32'hFFFFFFFF;
			Bout			<= 32'hFFFFFFFF;
			OPout			<= 3'b111;
		end
		else begin
			demux_state 	<= demux_state_nxt;
			A				<= A_nxt;
			B				<= B_nxt;
			CTL				<= CTL_nxt;
			bit_counter		<= bit_counter_nxt;
			packet_counter	<= packet_counter_nxt;
			ERR_FLAGS		<= ERR_FLAGS_nxt;
			Aout			<= Aout_nxt;
			Bout			<= Bout_nxt;
			OPout			<= OPout_nxt;
		end
	end

	
	always @* begin
		case(demux_state)
		`IDLE: begin
			bit_counter_nxt = 0;
			packet_counter_nxt = packet_counter;
			ERR_FLAGS_nxt = ERR_FLAGS;
			Aout_nxt = Aout;
			Bout_nxt = Bout;
			OPout_nxt = OPout;
			A_nxt = A;
			B_nxt = B;
			CTL_nxt = CTL;
			
			//scan for incoming packet 
			if(sin == 0) begin
				demux_state_nxt = `START;
			end
			
			else begin
				demux_state_nxt = `IDLE;
			end
		end
		
		
		`START: begin
			Aout_nxt = Aout;
			Bout_nxt = Bout;
			OPout_nxt = OPout;
			A_nxt = A;
			B_nxt = B;
			CTL_nxt = CTL;
			packet_counter_nxt = packet_counter;
			
			//packet DATA not starting with 0
			if(packet_counter <= 7 && bit_counter == 0 && sin == 1) begin
				ERR_FLAGS_nxt |= `ERR_DATA;
				demux_state_nxt = `ERROR;
			end
			
			//packet CTL not starting with 1
			else if(packet_counter == 8 && bit_counter == 0 && sin == 0) begin
				ERR_FLAGS_nxt |= `ERR_DATA;
				demux_state_nxt = `ERROR;
			end
			
			//packet starting correctly - read payload
			else begin
				bit_counter_nxt = bit_counter + 1;
				demux_state_nxt = `READ;
				ERR_FLAGS_nxt = ERR_FLAGS;
			end
		end

		
		`READ: begin
			Aout_nxt = Aout;
			Bout_nxt = Bout;
			OPout_nxt = OPout;
			
			//payload bits
			if(bit_counter <= 8) begin
				bit_counter_nxt = bit_counter + 1;
				packet_counter_nxt = packet_counter;
				demux_state_nxt = `READ;
				ERR_FLAGS_nxt = ERR_FLAGS;
				
				if(packet_counter <= 3) begin	//HERE COMES THE A
					A_nxt = {A, sin};
					B_nxt = B;
					CTL_nxt = CTL;
				end
				
				else if(packet_counter > 3 && packet_counter <= 7) begin //HERE COMES THE B
					B_nxt = {B, sin};
					A_nxt = A;
					CTL_nxt = CTL;
				end
				
				else if(packet_counter == 8) begin	//AND HERE'S THE CTL
					CTL_nxt = {CTL, sin};
					A_nxt = A;
					B_nxt = B;
				end
			end
			
			//stop bit
			else if(bit_counter == 9) begin
			
				//stop bit is not 1
				if(sin == 0) begin
					ERR_FLAGS_nxt |= `ERR_DATA;
					demux_state_nxt = `ERROR;
				end
				
				//last packet received, finish reception
				else if(packet_counter == 8) begin
					demux_state_nxt = `STOP;
					packet_counter_nxt = packet_counter;
					ERR_FLAGS_nxt = ERR_FLAGS;
					bit_counter_nxt = 0;
				end
				
				//end of packet, wait for next one
				else begin
					packet_counter_nxt = packet_counter + 1;
					bit_counter_nxt = 0;
					demux_state_nxt = `IDLE;
					ERR_FLAGS_nxt = ERR_FLAGS;
				end
			end
		end

		
		`STOP: begin
			A_nxt = 0;
			B_nxt = 0;
			CTL_nxt = 0;
			packet_counter_nxt = 0;
			bit_counter_nxt = 0
			OP = CTL[6:4];
			CRC = nextCRC4_D68({B, A, 1'b1, OP});
			if(CRC == CTL[3:0]) begin
				Aout_nxt = A;
				Bout_nxt = B;
				OPout_nxt = OP;
				demux_state_nxt = `IDLE;
				ERR_FLAGS_nxt = ERR_FLAGS;
			end
			else begin
				ERR_FLAGS_nxt |= `ERR_CRC;
				demux_state_nxt = `ERROR;
			end
		end	
		
		
		`ERROR: begin
			//todo nie wiem jak obslugujemy wyjatki
		end
		endcase
	end
	
	
	function [3:0] nextCRC4_D68;
	// polynomial: x^4 + x^1 + 1
	// data width: 68
	// convention: the first serial bit is D[67]

		input [67:0] Data;
		input [3:0] crc;
		reg [67:0] d;
		reg [3:0] c;
		reg [3:0] newcrc;
		
		begin
			d = Data;
			c = crc;

			newcrc[0] = d[66] ^ d[64] ^ d[63] ^ d[60] ^ d[56] ^ d[55] ^ d[54] ^ d[53] ^ d[51] ^ d[49] ^ d[48] ^ d[45] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[36] ^ d[34] ^ d[33] ^ d[30] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[19] ^ d[18] ^ d[15] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[4] ^ d[3] ^ d[0] ^ c[0] ^ c[2];
			newcrc[1] = d[67] ^ d[66] ^ d[65] ^ d[63] ^ d[61] ^ d[60] ^ d[57] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[48] ^ d[46] ^ d[45] ^ d[42] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[33] ^ d[31] ^ d[30] ^ d[27] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[18] ^ d[16] ^ d[15] ^ d[12] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[1] ^ d[0] ^ c[1] ^ c[2] ^ c[3];
			newcrc[2] = d[67] ^ d[66] ^ d[64] ^ d[62] ^ d[61] ^ d[58] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[49] ^ d[47] ^ d[46] ^ d[43] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[34] ^ d[32] ^ d[31] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[17] ^ d[16] ^ d[13] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[4] ^ d[2] ^ d[1] ^ c[0] ^ c[2] ^ c[3];
			newcrc[3] = d[67] ^ d[65] ^ d[63] ^ d[62] ^ d[59] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[50] ^ d[48] ^ d[47] ^ d[44] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[35] ^ d[33] ^ d[32] ^ d[29] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[18] ^ d[17] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[3] ^ d[2] ^ c[1] ^ c[3];
			nextCRC4_D68 = newcrc;
		end
	endfunction
	
	
endmodule
