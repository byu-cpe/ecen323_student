// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 1 picosecond. This 
// is used for simulation and all of your SystemVerilog files should have 
// this statement at the top. 
`timescale 1 ns / 1 ps 

/***************************************************************************
* 
* File: OneShot.sv
*
* Author: Professor Mike Wirthlin
* Class: ECEN 323
* Date: 12/15/2021
*
* Module: OneShot
* Description:
*    This module performs a "OneShot" function that generates a single clock
*    cycle pulse when the input transitions from zero to one. This function is
*    useful for buttons and switches when you want to know when the signal first
*    changes. This one shot functionality is implemented with a simple state machine.
*
****************************************************************************/

module OneShot(clk, rst, in, os);

	input wire logic clk;       // Global clock signal
	input wire logic rst;       // Global reset signal
	input wire logic in;        // Input signal used to generate one shot
	output logic os;            // Output oneshot signal
	
	// The current state and next state of the state machine
	logic [1:0] state, next_state;

	// Constants for the state machine state assignments.
	//  CODING STANDARD: You should always use a named constant (localparam)
	//  rather than "magic constants" in the body of your RTL code.
	localparam ZERO = 2'b00;
	localparam INC = 2'b01;
	localparam ONE = 2'b10;


	// One Shot state machine
	//  This state machine is used to detect the first zero to one transition
	//  on the input signal. When this transition occurs, the output signal
	//  will be asserted for a single clock cycle. This state machine is
	//  necessary to make sure that the one shot signal is asserted only once for each
	//  0->1 transition of the input. This is an exmaple of a "Moore" state machine
	//  (outputs only depend on current state and not the inputs).

	// State register for button state machine. This sequential code will synthesize
	// the flip flops for the state register.
	always_ff@(posedge clk)
		if (rst)
			state <= ZERO;
		else
			state <= next_state;

	// Next state logic for state machine
	//  This is a *combinational* circuit - no flip-flops or state are synthesized
	//  for this statement. 
	always_comb begin
		// Default assignment statement (stay in the same state)
		next_state = state;
		// Case statement for each state to override the default next_state
		// assignment.
		case(state)
			// The ZERO state occurs when the button is not pressed (zero) and 
			// will stay in this state until the button is first pressed.
			ZERO:
				// Transition to the INC state when the 'inc' signal is high
				// (otherwise stay in this state due to the default assignment statement)
				if (in)
					next_state = INC;
			// The INC state occurs when the button is first pressed. The state machine
			// will only be in this state for one clock cycle and move directly to either the 
			// ONE state or the ZERO state.
			INC:
				if (in)
					next_state = ONE;
				else
					next_state = ZERO;
			// The ONE state occurs when the button is being pressed. The state machine
			// will stay in this state until the button is released.
			ONE:
				// Transition to the ZERO state when the 'inc' signal is low. Otherwise
				//   stay in this state.
				if (!in)
					next_state = ZERO;			         
		endcase
	end

	// Output forming logic. This combinational logic will set the value of the 
	// "os" signal high when the current state of the state machine is in the
	// "INC" state. 
	assign os = (state == INC);
	
endmodule