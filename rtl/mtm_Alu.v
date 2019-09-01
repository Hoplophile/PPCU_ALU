/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:    mtm_Alu
 * PROJECT:   PPCU_VLSI
 * AUTHORS:
 * DATE:
 * ------------------------------------------------------------------------------
 * The ALU should operate as described in the mtmAlu_test_top module.
 * It should consist of three modules connected together:
 *   mtm_Alu_deserializer
 *   mtm_Alu_core
 *   mtm_Alu_serializer
 * The ALU should use posedge active clock and synchronous reset active LOW.
 *
 *******************************************************************************/

//TE SA DLA ALU_CORE
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

//A TE SA DLA DESERIALIZERA
//DEMUX STATES
`define IDLE 	2'b00
`define START	2'b01
`define READ	2'b10
`define STOP	2'b11

module mtm_Alu_deserializer(
	input wire clk,
	input wire rst,	
	input wire sin,		//serial input
	output reg [7:0] pout	//parallel output
);
	//todo liczenie, czy przyszło 8 ramek danych (flaga data error)
	
	reg [7:0] pout_nxt;

	reg [3:0] bit_counter;
	reg [3:0] bit_counter_nxt;
	
	reg [3:0] packet_counter;
	reg [3:0] packet_counter_nxt;

	reg [2:0] demux_state;
	reg [2:0] demux_state_nxt;


	always @(posedge clk or posedge rst) begin
		if(rst) begin
			pout	<= 0;
			demux_state <= 0;
		end
		else begin
			pout <= pout_nxt
			demux_state <= demux_state_nxt;
		end
	end

	always @* begin
		case(demux_state)
		'IDLE: begin
			pout_nxt = pout;
			bit_counter_nxt = 0;
			packet_counter_nxt = packet_counter;
			demux_state = (sin == 0) ? `START : `IDLE;
		end

		'START: begin
			pout_nxt = pout;
			bit_counter_nxt = 0;
			packet_counter_nxt = packet_counter;
			demux_state = `READ;
		end

		'READ: begin
			pout_nxt[bit_counter] = sin;
			bit_counter_nxt += 1;
			packet_counter_nxt = packet_counter;
			demux_state = (bit_counter == 8) ? `STOP : `READ;
		end

		'STOP: begin
		end			
		endcase
	end
endmodule


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
		if(rst) begin
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


module mtm_Alu_serializer(
	//pewnie jakieś wejścia i wyjścia
);

endmodule


module mtm_Alu (
    input  wire clk,   // posedge active clock
    input  wire rst_n, // synchronous reset active low
    input  wire sin,   // serial data input
    output wire sout   // serial data output
);


mtm_Alu_deserializer u_mtm_Alu_deserializer(
);

mtm_Alu_core u_mtm_Alu_core(
);

mtm_Alu_serializer u_mtm_Alu_serializer(
);


endmodule
