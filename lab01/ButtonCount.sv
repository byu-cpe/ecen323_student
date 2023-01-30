// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 1 picosecond. This 
// is used for simulation and all of your SystemVerilog files should have 
// this statement at the top. 
`timescale 1 ns / 1 ps 

/***************************************************************************
* 
* File: ButtonCount.sv
*
* Author: Professor Mike Wirthlin
* Class: ECEN 323, Winter Semester 2020
* Date: 12/10/2020
*
* Module: ButtonCount
*
* Description:
*    This module includes a state machine that will provide a one cycle
*    signal every time the top button (btnu) is pressed (this is sometimes
*    called a 'single-shot' filter of the button signal). This signal
*    is used to increment a counter that is displayed on the LEDs. The
*    center button (btnc) is used as a synchronous reset.
*
*    This module is used to help students review their RTL design skills and
*    get the design tools working.  
*
****************************************************************************/

module ButtonCount(clk, btnc, btnu, led);

	input wire logic clk, btnc, btnu;
	output logic [15:0] led;
	
	// The internal 16-bit count signal. 
	logic [15:0] count_i;
	// The increment counter output from the one shot module
	logic inc_count;
	// reset signal
	logic rst;
	// increment signals (synchronized version of btnu)
	logic btnu_d, btnu_dd, inc;

	// Assign the 'rst' signal to button c
	assign rst = btnc;

	// The following always block creates a "synchronizer" for the 'btnu' input.
	// A synchronizer synchronizes the asynchronous 'btnu' input to the global
	// clock (when you press a button you are not synchronous with anything!).
	// This particular synchronizer is just two flip-flop in series: 'btnu_d'
	// is the first flip-flop of the synchronizer and 'btnu_dd' is the second
	// flip-flop of the synchronizer. You should always have a synchronizer on
	// any button input if they are used in a sequential circuit.
	always_ff@(posedge clk)
		if (rst) begin
			btnu_d <= 0;
			btnu_dd <= 0;
		end
		else begin
			btnu_d <= btnu;
			btnu_dd <= btnu_d;
		end

	// Rename the output of the synchronizer to something more descriptive
	assign inc = btnu_dd;

	// Instance the OneShot module
	OneShot os (.clk(clk), .rst(rst), .in(inc), .os(inc_count));

	// 16-bit Counter. Increments once each time button is pressed. 
	//
	// This is an exmaple of a 'sequential' statement that will synthesize flip-flops
	// as well as the logic for incrementing the count value.
	//
	//  CODING STANDARD: Every "segment/block" of your RTL code must have at least
	//  one line of white space between it and the previous and following block. Also,
	//  ALL always blocks must have a coment.
	always_ff@(posedge clk)
		if (rst)
			count_i <= 0;
		else if (inc_count)
			count_i <= count_i + 1;
	
	// Assign the 'led' output the value of the internal count_i signal.
	assign led = count_i;

endmodule
