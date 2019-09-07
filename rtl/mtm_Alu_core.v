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
	
	always @(posedge clk or posedge rst_n) begin
		if (!rst_n) begin
			f_carry 		<= 0; 
			f_overflow 		<= 0; 
			f_zero 			<= 0; 
			f_negative 		<= 0;
			CTL				<= 0;
			CTL_nxt			<= 0;
			C_buff			<= 0;
			C_buff_nxt		<= 0;
			data_ready		<= 0;
			data_ready_nxt	<= 0;
			A				<= 32'hFFFFFFFF;
			B				<= 32'hFFFFFFFF;
			ALU_out_nxt		<= 55'hFFFFFFFFFFFFFF;
			state_nxt		<= IDLE;
			state			<= IDLE;
			packet_counter	<= 0;
			packet_counter_nxt<= 0;
		end
		else begin
			CTL		 		<= CTL_nxt;
			data_ready		<= data_ready_nxt;
			frame_buff		<= frame_buff_nxt;
			packet_counter	<= packet_counter_nxt;
			error			<= error_nxt;
			C_buff			<= C_buff_nxt;
			ALU_out 		<= ALU_out_nxt;
			OP				<= OP_nxt;
			A				<= A_nxt;
			B				<= B_nxt;
			OP				<= OP_nxt;
			state			<= state_nxt;
		end
	end
	
	always @* begin
		case(state) 
			IDLE: begin
				if(input_ready == 1) state_nxt = CHECK_DATA;
			end
			CHECK_DATA: begin
				//if(error == 1) state_nxt = ERROR; 
				state_nxt = BUFFER;
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
				state_nxt = IDLE;	//wyzerować frame controle
			end
			ERROR: begin
				state_nxt = SEND;
			end
		endcase
	end
	
	always @* begin
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
				else if(packet_counter_nxt == 8) begin
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
				
				CRC4forData68({B, A, 1'b1, OP_nxt}, CRC4);
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
						{f_carry, C_buff_nxt} = A + B;
						f_overflow = ((B[31] ^ C_buff_nxt[31]) ^ A[31]) ^ f_carry;
					end
					SUB: begin
						{f_carry, C_buff_nxt} = A - B;
						f_overflow = ((B[31] ^ C_buff_nxt[31]) ^ A[31]) ^ f_carry;
					end
				endcase
				
				//is negative
				if(C_buff_nxt[31] == 1) f_negative = 1;
				//is zero
				if(C_buff_nxt == 0) f_zero = 1;
				//calculate CTL
				CRC3forData37({C_buff_nxt, 1'b0, f_carry, f_overflow, f_zero, f_negative}, CRC3);
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

	task CRC3forData37;
	  // polynomial: x^3 + x^1 + 1 (0x5) with initial value 0
	  input reg [36:0] Data_in;
	  output reg [2:0] CRC3_result;

	  reg [36:0] d;
	  reg [2:0] Result;

	  begin
		 d = Data_in;
		 Result[0] = d[35] ^ d[32] ^ d[31] ^ d[30] ^ d[28] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[11] ^ d[10] ^ d[9] ^ d[7] ^ d[4] ^ d[3] ^ d[2] ^ d[0];
		 Result[1] = d[36] ^ d[35] ^ d[33] ^ d[30] ^ d[29] ^ d[28] ^ d[26] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[2] ^ d[1] ^ d[0];
		 Result[2] = d[36] ^ d[34] ^ d[31] ^ d[30] ^ d[29] ^ d[27] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[3] ^ d[2] ^ d[1];
		 CRC3_result = Result;
	  end
	endtask
	
	task CRC4forData68;
      // polynomial: x^4 + x^1 +1 (0x9) with initial value 0
      input reg [67:0] Data_in;
      output reg [3:0] CRC4_result;
      
      reg [67:0] d;
      reg [3:0] Result;

      begin
         d = Data_in;
         Result[0] = d[66] ^ d[64] ^ d[63] ^ d[60] ^ d[56] ^ d[55] ^ d[54] ^ d[53] ^ d[51] ^ d[49] ^ d[48] ^ d[45] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[36] ^ d[34] ^ d[33] ^ d[30] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[19] ^ d[18] ^ d[15] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[4] ^ d[3] ^ d[0];
         Result[1] = d[67] ^ d[66] ^ d[65] ^ d[63] ^ d[61] ^ d[60] ^ d[57] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[48] ^ d[46] ^ d[45] ^ d[42] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[33] ^ d[31] ^ d[30] ^ d[27] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[18] ^ d[16] ^ d[15] ^ d[12] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[1] ^ d[0];
         Result[2] = d[67] ^ d[66] ^ d[64] ^ d[62] ^ d[61] ^ d[58] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[49] ^ d[47] ^ d[46] ^ d[43] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[34] ^ d[32] ^ d[31] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[17] ^ d[16] ^ d[13] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[4] ^ d[2] ^ d[1];
         Result[3] = d[67] ^ d[65] ^ d[63] ^ d[62] ^ d[59] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[50] ^ d[48] ^ d[47] ^ d[44] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[35] ^ d[33] ^ d[32] ^ d[29] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[18] ^ d[17] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[3] ^ d[2];
         CRC4_result = Result;
      end
   endtask
endmodule
