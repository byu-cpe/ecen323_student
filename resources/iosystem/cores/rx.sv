//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: rx.v
//
//  Author: Mike Wirthlin
//  
//  Description:
//
//     
//////////////////////////////////////////////////////////////////////////////////

module rx(clk, rst, rx_in, odd, dout, error, data_strobe, busy);

	// Ports and parameters
	input logic clk, rst, rx_in, odd;
	output logic error;
	output [7:0] dout;
	output reg busy, data_strobe;

	parameter CLK_RATE = 100000000;		// 100 MHz
	parameter BAUD_RATE = 19200;		// 19,200 BAUD

	// Constants
    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                value = value >> 1;
            end
        end
    endfunction
    
	localparam BAUD_COUNTER_MAX_VAL = CLK_RATE / BAUD_RATE - 1;
	localparam BAUD_COUNTER_HALF_VAL = BAUD_COUNTER_MAX_VAL / 2;
	localparam BAUD_COUNTER_BITS = clogb2(BAUD_COUNTER_MAX_VAL);
    reg [BAUD_COUNTER_BITS-1:0] baud_counter = 0;
    reg [3:0] bit_counter = 0;
    localparam BIT_COUNTER_MAX_VAL = 9;
    reg ResetTimer, EnableTimer, ResetCounter, NextBit;
    wire LastCycle, HalfCycle, LastBit;

    reg [9:0] shift_reg = 0;
    reg Shift;
    wire stop_bit, r_parity;
    
    // FSM constants and signals
	localparam POWER = 3'b000;
	localparam IDLE = 3'b001;
	localparam START = 3'b010;
	localparam COUNT = 3'b011;
	localparam SHIFT = 3'b100;
	localparam STOP = 3'b101;
	localparam DONE = 3'b110;
	reg [3:0] state = POWER;
	reg [3:0] next_state;
        
	// Baud Rate Timer
    always_ff@(posedge clk)
        if (rst | ResetTimer)
            baud_counter <= 0;
        else if (EnableTimer == 1'b1)
            baud_counter <= baud_counter + 1;
    assign LastCycle = (baud_counter == BAUD_COUNTER_MAX_VAL) ? 1'b1 : 1'b0;
    assign HalfCycle = (baud_counter == BAUD_COUNTER_HALF_VAL) ? 1'b1 : 1'b0;

	// Bit counter
    always@(posedge clk)
        if (rst || ResetCounter == 1'b1)
            bit_counter <= 0;
        else if (NextBit == 1'b1)
            bit_counter <= bit_counter + 1;
    assign LastBit = (bit_counter == BIT_COUNTER_MAX_VAL) ? 1'b1 : 1'b0;

	// shift register
	always@(posedge clk) begin
		if (Shift == 1'b1)
			shift_reg <= {rx_in, shift_reg[9:1]};
	end
	assign dout = shift_reg[7:0];
    assign stop_bit = shift_reg[9];
    assign r_parity = shift_reg[8];

    // Error checker (status bit set at end of receive sequence)
	reg error_int = 0;
	always @(posedge clk)
		if (rst)
			error_int <= 0;
		else if (state == DONE) // Only set the error bit 
			error_int = (~stop_bit) | ~(r_parity ^ ((^dout)^(~odd)));
//    assign error = (~stop_bit) | ~(r_parity ^ ((^dout)^(~odd)));
    assign error = error_int;
    
	// State Machine state register
	always @(posedge clk)
		if (rst)
			state <= POWER;
		else
			state <= next_state;

	// Next state logic and outputs
	always @(*)
	begin
		// Default values
		busy = 1'b1;
		next_state = state;
        ResetTimer = 1'b0;
        ResetCounter = 1'b0;
        EnableTimer = 1'b0;
        Shift = 1'b0;
		data_strobe = 1'b0;
		NextBit = 1'b0;
		
		case(state)
			// This state will wait until rx_in goes high (i.e. initial case)
			// before looking for a start bit
            POWER: begin
				ResetTimer = 1'b1;
                ResetCounter = 1'b1;
                if (rx_in == 1'b1)
                    next_state = IDLE;                    
            end
			IDLE: begin
				busy = 1'b0;
				ResetTimer = 1'b1;
				ResetCounter = 1'b1;
				if (rx_in == 1'b0) begin
					next_state = START;
				end
			end
			START: begin
		        EnableTimer = 1'b1;
				if (HalfCycle == 1'b1) begin
					next_state = COUNT;
                    ResetTimer = 1'b1;
				end
			end
			COUNT: begin
		        EnableTimer = 1'b1;
				if (LastCycle == 1'b1) begin
					next_state = SHIFT;
				end
			end
			SHIFT: begin
			    Shift = 1'b1;
				ResetTimer = 1'b1;
				NextBit = 1'b1;
				if (LastBit == 1'b1)
					next_state = STOP;
				else
				    next_state = COUNT;
			end
			STOP: begin
    	        EnableTimer = 1'b1;
                if (HalfCycle == 1'b1)
                    next_state = DONE;
			end
			DONE: begin
			     next_state = IDLE;
			     data_strobe = 1'b1;
			end
		endcase
	end



	
endmodule