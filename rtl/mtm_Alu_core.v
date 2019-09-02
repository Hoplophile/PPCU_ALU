/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:    mtm_Alu_core
 * PROJECT:   PPCU_VLSI
 * AUTHORS:
 * DATE:
 * ------------------------------------------------------------------------------
 *
 *******************************************************************************/

//OPERATIONS
`define AND		3'b000
`define OR		3'b001
`define ADD		3'b100
`define SUB		3'b101

//FLAGS
`define CARRY		4'b1000
`define OVERFLOW	4'b0100
`define ZERO		4'b0010
`define NEGATIVE	4'b0001

//ERROR FLAGS
`define ERR_DATA	6'b100100
`define ERR_CRC		6'b010010
`define ERR_OP		6'b001001

//OTHERS
`define PARITY		1'b0


module mtm_Alu_core(
	input wire clk,
	input wire rst,	
	input reg [2:0] OP,	//operation selection
	input reg [31:0] A, B,	//input values
	output wire [31:0] C,	//operation result
	output wire [7:0] CTL	//operation flags or errors
	);

	reg [31:0] C_nxt;
	reg [2:0] CRC 		= 3'b000;
	reg [3:0] FLAGS 	= 4'b0000;
	reg [5:0] ERR_FLAGS 	= 6'b000000;
	reg [7:0] CTL_nxt 	= 8'b00000000;
	wire COUT;

	always @(posedge clk or posedge rst) begin
		if(!rst) begin
			C_nxt 	<= 0;
			CTL_nxt <= 0;
			FLAGS 	<= 0;
			CARRY 	<= 0;
		end
		else begin
			C 	<= C_nxt;
			CTL 	<= CTL_nxt;
		end
	end

	always @* begin
		case(OP) 
		`AND: begin
			C_nxt = A & B;
		end

		`OR: begin
			C_nxt = A | B;
		end

		`ADD: begin
			assign {COUT, C_nxt} = {1'b0, A} + {1'b0, B}
			if(COUT != 1'b0) FLAGS |= `OVERFLOW;
		end	
	
		`SUB: begin
			if(B > A) begin
				C_nxt = B - A
				FLAGS |= `NEGATIVE;
			end
			else begin
				C_nxt = A - B;
			end
		end

		default: begin
			ERR_FLAGS |= `ERR_OP;
		end		
		endcase

		if(C_nxt == 0) FLAGS |= `ZERO;
		if(ERR_FLAGS == 0) CTL_nxt = {1'b0, FLAGS, CRC};
		else CTL_nxt = {1'b1, ERR_FLAGS, `PARITY);
		//todo liczenie CRC (flaga CRC error)
	end
endmodule
