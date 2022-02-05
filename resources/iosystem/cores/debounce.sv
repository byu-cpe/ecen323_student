//`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: debounce.sv
//
//  Author: Mike Wirthlin
//  
//////////////////////////////////////////////////////////////////////////////////

module debounce
    #(parameter CLK_FREQUECY = 100000000, parameter DEBOUNCE_DELAY_US = 1_000)
    (clk, rst, debounce_in, debounce_out);
	
    input wire logic clk;
    input wire logic rst;
    input wire logic debounce_in;
    output logic debounce_out;

	//parameter CLK_FREQUECY = 100000000;		// 100 MHz
    //parameter DEBOUNCE_DELAY_US = 1_000;    // 1 ms
    localparam DEBOUNCE_BITS = $clog2(CLK_FREQUECY / 1_000_000 * DEBOUNCE_DELAY_US) + 1;

    logic [DEBOUNCE_BITS-1:0] debounce_counter = 0;
    logic db_state;
    logic debounce_out_d;

    assign debounce_out = db_state;
    
    // debounce counter
    always_ff @(posedge clk) begin
        if (rst) begin
            db_state = 0;
            debounce_counter <= 0;
        end
        else if (db_state) begin
            if (~debounce_in) begin
                if (debounce_counter[DEBOUNCE_BITS-1]) begin
                    db_state <= 0;
                    debounce_counter <= 0;
                end else
                    debounce_counter <= debounce_counter + 1;
            end else
                debounce_counter <=0;                                
        end
        else begin
            // db_state = 0
            if (debounce_in) begin
                if (debounce_counter[DEBOUNCE_BITS-1]) begin
                    db_state <= 1;
                    debounce_counter <= 0;
                end else
                    debounce_counter <= debounce_counter + 1;
            end
            else
                debounce_counter <=0;                
        end
    end	

endmodule