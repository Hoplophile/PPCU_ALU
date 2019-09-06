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
`timescale 1ns/1ps


module mtm_Alu (
    input  wire clk,   // posedge active clock
    input  wire rst_n, // synchronous reset active low
    input  wire sin,   // serial data input
    output wire sout   // serial data output
);


wire [31:0] A;
wire [31:0] B;
wire [31:0] C;
wire [7:0] CTL;
wire [7:0] CTL_out;
wire data_valid;
wire [9:0] packet;
wire [54:0] ALU_out;
wire data_ready;


mtm_Alu_deserializer u_mtm_Alu_deserializer(
  .clk(clk),
  .rst(rst_n),
  .sin(sin),
  .packet(packet),
  .data_valid(data_valid)
);

mtm_Alu_core u_mtm_Alu_core(
  .clk(clk),
  .rst_n(rst_n),
  .frame(packet),
  .input_ready(data_valid),
  .ALU_out(ALU_out),
  .data_ready(data_ready),
  .CTL_out(CTL_out)
);

mtm_Alu_serializer u_mtm_Alu_serializer(
  .clk(clk),
  .reset(rst_n),
  .Cin(C),
  .CTLin(CTL_out),
  .sout(sout)
);





endmodule
