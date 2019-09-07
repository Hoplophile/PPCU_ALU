/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:    mtm_Alu_deserializer
 * PROJECT:   PPCU_VLSI
 * AUTHORS:   Szymon Janik
 * DATE:      06.09.2019
 * ------------------------------------------------------------------------------
 *
 *  This module retrieves raw bit data from the input stream.
 *  It prepares 10-bit data packets and sends them to the alu_core module.  
 *
 *******************************************************************************/



`timescale 1ns/1ps

module mtm_Alu_deserializer(
	input wire clk,
	input wire rst,	
	input wire sin,				
	output reg [9:0] packet,		
	output reg data_valid	

);
	
    reg state, next_state, data_valid_next;
    reg [3:0] bit_counter, next_bit_counter;
    reg [9:0] buffer, buffer_next, packet_next;

	
	parameter IDLE = 1'b0, ACQUIRE = 1'b1;
  
    always @ (posedge clk) begin
		if (!rst) begin

			state <= IDLE;
            next_state <= IDLE;

            data_valid <= 0;
            buffer <= 0;
            buffer_next <= 0;			
			bit_counter <= 0; 
			next_bit_counter <= 0;
			
        end	else begin

            state <= next_state;            
            bit_counter <= next_bit_counter;
            buffer <= buffer_next;
            packet <= packet_next;
            data_valid <= data_valid_next;

        end			
	end

    always @* begin
        next_bit_counter = bit_counter;
        buffer_next = 0;
        packet_next = 10'b0000000000;
        data_valid_next = 1'b0;

        case (next_state)
            IDLE: begin
                
                next_bit_counter = 0;
                packet_next = 10'b0000000000;
                data_valid_next = 1'b0;

                if (bit_counter == 10) begin
                    if (sin == 0) begin
                        packet_next = 10'b0000000000;
                        data_valid_next = 1'b0;
                    end else begin
                        packet_next = buffer;
                        data_valid_next = 1'b1;
                    end
                end else begin
                    packet_next = 10'b0000000000;
                    data_valid_next = 1'b0;
                end

            end

            ACQUIRE:
                begin
                    next_bit_counter = bit_counter + 1;  
                    buffer_next = {buffer[8:0], sin};                  
                end
        endcase
    end
	
	always @* begin
		case (state)
			IDLE: 
				begin
                    if (sin == 0) begin
                        next_state = ACQUIRE;
                    end else begin
                        next_state = IDLE;
                    end
                end
            ACQUIRE: 
                begin
                    if (bit_counter < 10) begin
                        next_state = ACQUIRE;
                    end else begin
                        next_state = IDLE;
                    end                    
                end
            default:
                next_state = IDLE;

		endcase
	end

  
	
	
endmodule //deserializer