/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:    mtm_Alu_core
 * PROJECT:   PPCU_VLSI
 * AUTHORS:   Piotr Ziebinski
 * DATE:      07.09.2019
 * ------------------------------------------------------------------------------
 *
 *  This module performs ALU operations, it also handles data, crc and op errors. 
 *
 *******************************************************************************/

`timescale 1ns/1ps


module mtm_Alu_core(
	input wire clk,
	input wire rst_n,
	input wire [9:0] frame,
	input wire input_ready,
	output reg [54:0] ALU_out,
	output reg data_ready
	);

	//data for calculation
	reg [2:0] OP;
	reg [2:0] OP_nxt;
	reg [31:0] A;
	reg [31:0] A_nxt;
	reg [31:0] B;
	reg [31:0] B_nxt;

	//OPs
	localparam 
	AND 	= 3'b000,
	OR 		= 3'b001,
	ADD 	= 3'b100,
	SUB 	= 3'b101;
	
	reg [2:0] state;
	reg [2:0] state_nxt;
	
	//states
	localparam
	IDLE			= 3'b000,
	CHECK_DATA		= 3'b001,
	BUFFER			= 3'b010,
	CHECK_OP_CRC	= 3'b011,
	CALCULATE		= 3'b100,
	SEND			= 3'b101,
	ERROR			= 3'b111;
		
	//sm controls
	reg [3:0] packet_counter;
	reg [3:0] packet_counter_nxt;
	reg error;
	reg error_nxt;
	reg [9:0] frame_buff;
	reg [9:0] frame_buff_nxt;

	//core controls
	reg [54:0] ALU_out_nxt;
	reg data_ready_nxt;
	reg [31:0] C_buff;
	reg [31:0] C_buff_nxt;
	reg [7:0] CTL;
	reg [7:0] CTL_nxt;
	reg [3:0] CRC4;
	reg [2:0] CRC3;

	//operation flags
	reg f_carry, f_overflow, f_zero, f_negative;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			f_carry 		<= 0; 
			f_overflow 		<= 0; 
			f_zero 			<= 0; 
			f_negative 		<= 0;
			CTL			<= 0;
			C_buff			<= 0;
			data_ready		<= 0;
			OP			<= 0;
			error			<= 0;
			frame_buff		<= 0;
			A			<= 32'hFFFFFFFF;
			B			<= 32'hFFFFFFFF;
			ALU_out			<= 55'hFFFFFFFFFFFFFF;
			state			<= IDLE;
			packet_counter		<= 0;
		end
		else begin
			CTL		 		<= CTL_nxt;
			data_ready		<= data_ready_nxt;
			frame_buff		<= frame_buff_nxt;
			packet_counter	<= packet_counter_nxt;
			error			<= error_nxt;
			C_buff			<= C_buff_nxt;
			ALU_out 		<= ALU_out_nxt;
			A				<= A_nxt;
			B				<= B_nxt;
			OP				<= OP_nxt;
			state			<= state_nxt;
		end
	end
	
	always @* begin
		state_nxt = state;
		case(state) 
			IDLE: begin
				if(input_ready == 1) state_nxt = CHECK_DATA;
			end
			CHECK_DATA: begin
				if(error == 1) state_nxt = ERROR; 
				else state_nxt = BUFFER;
			end
			BUFFER: begin
				if(packet_counter == 9) state_nxt = CHECK_OP_CRC;
				else state_nxt = IDLE;
			end
			CHECK_OP_CRC: begin
				if(error == 1) state_nxt = ERROR;
				else state_nxt = CALCULATE;
			end
			CALCULATE: begin
				state_nxt = SEND;
			end
			SEND: begin
				state_nxt = IDLE;
			end
			ERROR: begin
				state_nxt = SEND;
			end
		endcase
	end
	
	always @* begin
		ALU_out_nxt = 0;
		A_nxt = 0;
		B_nxt = 0;
		CTL_nxt = 0;
		C_buff_nxt = 0;
		OP_nxt = 0;
		error_nxt = 0;
		data_ready_nxt = 0;
		frame_buff_nxt = 0;
		packet_counter_nxt = 0;
		case(state_nxt) 
			IDLE: begin
				OP_nxt = 0;
				ALU_out_nxt = 55'hFFFFFFFFFFFFFF;
				error_nxt = 0;
				A_nxt = A;
				B_nxt = B;
				CTL_nxt = 8'hFF;
				C_buff_nxt = 0;
				data_ready_nxt = 0;
				packet_counter_nxt = packet_counter;
			end
			
			CHECK_DATA: begin
				OP_nxt = 0;
				ALU_out_nxt = ALU_out;
				error_nxt = 0;
				A_nxt = A;
				B_nxt = B;
				CTL_nxt = CTL;
				C_buff_nxt = C_buff;
				data_ready_nxt = 0;
				frame_buff_nxt = frame;
				packet_counter_nxt = packet_counter;
				
				if(packet_counter < 8) begin
					if(frame[8] == 1) begin
						error_nxt = 1;		//frame type bit error
						CTL_nxt = 8'b11001001;
					end
				end
				else if(packet_counter == 8) begin
					if(frame[8] == 0) begin
						error_nxt = 1;		//frame type bit error
						CTL_nxt = 8'b11001001;
					end
				end
				else if(frame[9] == 1) begin
					error_nxt = 1;			//start bit error
					CTL_nxt = 8'b11001001;
				end
			end
			
			BUFFER: begin
				OP_nxt = 0;
				ALU_out_nxt = ALU_out;
				error_nxt = 0;
				A_nxt = A;
				B_nxt = B;
				CTL_nxt = CTL;
				C_buff_nxt = C_buff;
				data_ready_nxt = 0;
				frame_buff_nxt = 0;
				packet_counter_nxt = packet_counter + 1;
				
				if(packet_counter < 4) B_nxt = {B, frame_buff[7:0]};		//B   received
				else if(packet_counter < 8) A_nxt = {A, frame_buff[7:0]};		//A   received
				else if(packet_counter == 8) CTL_nxt = {CTL, frame_buff[7:0]};	//CTL received
			end
			
			CHECK_OP_CRC: begin
				OP_nxt = CTL[6:4];
				ALU_out_nxt = ALU_out;
				error_nxt = 0;
				A_nxt = A;
				B_nxt = B;
				CTL_nxt = CTL;
				C_buff_nxt = C_buff;
				data_ready_nxt = 0;
				frame_buff_nxt = frame_buff;
				packet_counter_nxt = 0;
				
				CRC4_68({B, A, 1'b1, OP_nxt}, CRC4);
				if((OP_nxt != ADD) && (OP_nxt != OR) && (OP_nxt != SUB) && (OP_nxt != AND)) begin
					error_nxt = 1;				//OP error
					CTL_nxt = 8'b10010011;
				end
				else if(CTL[3:0] != CRC4) begin															//TODO LICZENIE CRC
					error_nxt = 1;				//CRC error
					CTL_nxt = 8'b10100101;
				end
				else begin
					error_nxt = 0;				//no OP/CRC error
					CTL_nxt = 0;
				end
			end
			
			CALCULATE: begin
				OP_nxt = OP;
				ALU_out_nxt = ALU_out;
				error_nxt = 0;
				A_nxt = A;
				B_nxt = B;
				CTL_nxt = CTL;
				C_buff_nxt = C_buff;
				data_ready_nxt = 0;
				frame_buff_nxt = frame_buff;
				packet_counter_nxt = 0;
				f_carry 	= 0; 
				f_overflow 	= 0; 
				f_zero 		= 0; 
				f_negative 	= 0;
			
				case(OP)
					AND: begin
						C_buff_nxt = A & B;
					end
					OR: begin
						C_buff_nxt = A | B;
					end
					ADD: begin
						{f_carry, C_buff_nxt} = {1'b0, A} + {1'b0, B};
						f_overflow = ((B[31] ^ C_buff_nxt[31]) ^ A[31]) ^ f_carry;
					end
					SUB: begin
						{f_carry, C_buff_nxt} = {1'b0, A} - {1'b0, B};
						f_overflow = ((B[31] ^ C_buff_nxt[31]) ^ A[31]) ^ f_carry;
					end
				endcase
				
				//is negative
				if(C_buff_nxt[31] == 1) f_negative = 1;
				//is zero
				if(C_buff_nxt == 0) f_zero = 1;
				//calculate CTL
				CRC3_37({C_buff_nxt, 1'b0, f_carry, f_overflow, f_zero, f_negative}, CRC3);
				CTL_nxt = {1'b0, f_carry, f_overflow, f_zero, f_negative, CRC3};
			end
			
			SEND: begin
				OP_nxt = OP;
				C_buff_nxt = C_buff;			
				error_nxt = 0;
				A_nxt = 32'hFFFFFFFF;
				B_nxt = 32'hFFFFFFFF;
				CTL_nxt = CTL;
				data_ready_nxt = 1;
				frame_buff_nxt = frame_buff;
				packet_counter_nxt = 0;
				
				ALU_out_nxt[54:44] = {2'b00, C_buff[31:24], 1'b1};
				ALU_out_nxt[43:33] = {2'b00, C_buff[23:16], 1'b1};
				ALU_out_nxt[32:22] = {2'b00, C_buff[15:8], 1'b1};
				ALU_out_nxt[21:11] = {2'b00, C_buff[7:0], 1'b1};
				ALU_out_nxt[10:0] = {2'b01, CTL, 1'b1};
			end
			
			ERROR: begin
				OP_nxt = OP;
				C_buff_nxt = 0;
				CTL_nxt = CTL;
				error_nxt = 0;
				A_nxt = 0;
				B_nxt = 0;
				data_ready_nxt = 0;
				frame_buff_nxt = frame_buff;
				packet_counter_nxt = 0;
			end
		endcase
		
	end

	task CRC3_37;

	  input reg [36:0] data;
	  output reg [2:0] CRC3_result;

	  reg [36:0] data_copy;
	  reg [2:0] Result;

	  begin
		 data_copy = data;
		 Result[0] = data_copy[35] ^ data_copy[32] ^ data_copy[31] ^ data_copy[30] ^ data_copy[28] ^ data_copy[25] ^ data_copy[24] ^ data_copy[23] ^ data_copy[21] ^ data_copy[18] ^ data_copy[17] ^ data_copy[16] ^ data_copy[14] ^ data_copy[11] ^ data_copy[10] ^ data_copy[9] ^ data_copy[7] ^ data_copy[4] ^ data_copy[3] ^ data_copy[2] ^ data_copy[0];
		 Result[1] = data_copy[36] ^ data_copy[35] ^ data_copy[33] ^ data_copy[30] ^ data_copy[29] ^ data_copy[28] ^ data_copy[26] ^ data_copy[23] ^ data_copy[22] ^ data_copy[21] ^ data_copy[19] ^ data_copy[16] ^ data_copy[15] ^ data_copy[14] ^ data_copy[12] ^ data_copy[9] ^ data_copy[8] ^ data_copy[7] ^ data_copy[5] ^ data_copy[2] ^ data_copy[1] ^ data_copy[0];
		 Result[2] = data_copy[36] ^ data_copy[34] ^ data_copy[31] ^ data_copy[30] ^ data_copy[29] ^ data_copy[27] ^ data_copy[24] ^ data_copy[23] ^ data_copy[22] ^ data_copy[20] ^ data_copy[17] ^ data_copy[16] ^ data_copy[15] ^ data_copy[13] ^ data_copy[10] ^ data_copy[9] ^ data_copy[8] ^ data_copy[6] ^ data_copy[3] ^ data_copy[2] ^ data_copy[1];
		 CRC3_result = Result;
	  end
	endtask
	
	task CRC4_68;
     
      input reg [67:0] data;
      output reg [3:0] CRC4_result;
      
      reg [67:0] data_copy;
      reg [3:0] Result;

      begin
         data_copy = data;
         Result[0] = data_copy[66] ^ data_copy[64] ^ data_copy[63] ^ data_copy[60] ^ data_copy[56] ^ data_copy[55] ^ data_copy[54] ^ data_copy[53] ^ data_copy[51] ^ data_copy[49] ^ data_copy[48] ^ data_copy[45] ^ data_copy[41] ^ data_copy[40] ^ data_copy[39] ^ data_copy[38] ^ data_copy[36] ^ data_copy[34] ^ data_copy[33] ^ data_copy[30] ^ data_copy[26] ^ data_copy[25] ^ data_copy[24] ^ data_copy[23] ^ data_copy[21] ^ data_copy[19] ^ data_copy[18] ^ data_copy[15] ^ data_copy[11] ^ data_copy[10] ^ data_copy[9] ^ data_copy[8] ^ data_copy[6] ^ data_copy[4] ^ data_copy[3] ^ data_copy[0];
         Result[1] = data_copy[67] ^ data_copy[66] ^ data_copy[65] ^ data_copy[63] ^ data_copy[61] ^ data_copy[60] ^ data_copy[57] ^ data_copy[53] ^ data_copy[52] ^ data_copy[51] ^ data_copy[50] ^ data_copy[48] ^ data_copy[46] ^ data_copy[45] ^ data_copy[42] ^ data_copy[38] ^ data_copy[37] ^ data_copy[36] ^ data_copy[35] ^ data_copy[33] ^ data_copy[31] ^ data_copy[30] ^ data_copy[27] ^ data_copy[23] ^ data_copy[22] ^ data_copy[21] ^ data_copy[20] ^ data_copy[18] ^ data_copy[16] ^ data_copy[15] ^ data_copy[12] ^ data_copy[8] ^ data_copy[7] ^ data_copy[6] ^ data_copy[5] ^ data_copy[3] ^ data_copy[1] ^ data_copy[0];
         Result[2] = data_copy[67] ^ data_copy[66] ^ data_copy[64] ^ data_copy[62] ^ data_copy[61] ^ data_copy[58] ^ data_copy[54] ^ data_copy[53] ^ data_copy[52] ^ data_copy[51] ^ data_copy[49] ^ data_copy[47] ^ data_copy[46] ^ data_copy[43] ^ data_copy[39] ^ data_copy[38] ^ data_copy[37] ^ data_copy[36] ^ data_copy[34] ^ data_copy[32] ^ data_copy[31] ^ data_copy[28] ^ data_copy[24] ^ data_copy[23] ^ data_copy[22] ^ data_copy[21] ^ data_copy[19] ^ data_copy[17] ^ data_copy[16] ^ data_copy[13] ^ data_copy[9] ^ data_copy[8] ^ data_copy[7] ^ data_copy[6] ^ data_copy[4] ^ data_copy[2] ^ data_copy[1];
         Result[3] = data_copy[67] ^ data_copy[65] ^ data_copy[63] ^ data_copy[62] ^ data_copy[59] ^ data_copy[55] ^ data_copy[54] ^ data_copy[53] ^ data_copy[52] ^ data_copy[50] ^ data_copy[48] ^ data_copy[47] ^ data_copy[44] ^ data_copy[40] ^ data_copy[39] ^ data_copy[38] ^ data_copy[37] ^ data_copy[35] ^ data_copy[33] ^ data_copy[32] ^ data_copy[29] ^ data_copy[25] ^ data_copy[24] ^ data_copy[23] ^ data_copy[22] ^ data_copy[20] ^ data_copy[18] ^ data_copy[17] ^ data_copy[14] ^ data_copy[10] ^ data_copy[9] ^ data_copy[8] ^ data_copy[7] ^ data_copy[5] ^ data_copy[3] ^ data_copy[2];
         CRC4_result = Result;
      end
   endtask
endmodule
