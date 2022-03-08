///////////////////////////////////////////////////////////////////////////////////////////////
// 
// Filename: io_clocks.sv
//
// Author: Mike Wirthlin
// Date: 2/4/2022
//
// Clocking infrastruture for I/O system.
//
///////////////////////////////////////////////////////////////////////////////////////////////

module io_clocks (clk_in, reset_out, clk_proc, clk_vga);

    input logic clk_in;
    output logic reset_out;
    output clk_proc;
    output clk_vga;

    // Input clock frequency
	parameter INPUT_CLOCK_RATE = 100_000_000;
	parameter PROC_CLK_DIVIDE = 3;
	parameter VGA_CLK_DIVIDE = 2;

	localparam MCM_CLOCK_RATE =  INPUT_CLOCK_RATE / PROC_CLK_DIVIDE;
    localparam INPUT_CLOCK_PERIOD_NS = INPUT_CLOCK_RATE / 10_000_000;

	////////////////////////////////////////////////////////////////////
	// Reset generation. Operates directly on input clock (for initial reset)
	////////////////////////////////////////////////////////////////////

	// Right shifting shift register (least signicant bit is ~reset)
	logic [7:0] reset_sr = 0;
	always@(posedge clk_in)
		reset_sr <= {1'b1,reset_sr[7:1]};
    logic dcm_reset;
	assign dcm_reset = ~reset_sr[0];
    
    logic rst = 1;
	logic mcm_locked;
	always@(posedge clk_in) begin
	   rst = ~mcm_locked;
	end
    assign reset_out = rst;
	
	////////////////////////////////////////////////////////////////////
	// Clock Generation (divide by 2)
	////////////////////////////////////////////////////////////////////
	
	// Processor MCM
	logic mcm_pwrdwn = 0;
	logic clk0,clk_proc,clkfb,clkfb_buf;
	//MMCME2_BASE - symbiflow needs ADV
	MMCME2_ADV mmcm(.RST(dcm_reset),.CLKIN1(clk_in),.LOCKED(mcm_locked),.PWRDWN(mcm_pwrdwn),.CLKOUT0(clk0),.CLKFBOUT(clkfb),.CLKFBIN(clkfb_buf),
		// unconnected
		.CLKFBOUTB(),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6());
	localparam CLKFBOUT_MULT_F = 8.000;
	localparam CLKOUT0_DIVIDE_F = CLKFBOUT_MULT_F * PROC_CLK_DIVIDE;
	defparam mmcm.CLKIN1_PERIOD = INPUT_CLOCK_PERIOD_NS;
	defparam mmcm.CLKFBOUT_MULT_F = CLKFBOUT_MULT_F;
	defparam mmcm.CLKOUT0_DIVIDE_F = CLKOUT0_DIVIDE_F;
	BUFG bufg1(.I(clk0),.O(clk_proc));
	BUFG bufg2(.I(clkfb),.O(clkfb_buf));
    
	// VGA clock
	logic clk_vga, clk0_vga, clkfb_vga, clkfb_buf_vga;
	//MMCME2_BASE - symbiflow needs ADV
	MMCME2_ADV mmcm_vga(.RST(dcm_reset),.CLKIN1(clk_in),.LOCKED(),.PWRDWN(mcm_pwrdwn),
		.CLKOUT0(clk0_vga),.CLKFBOUT(clkfb_vga),.CLKFBIN(clkfb_buf_vga),
		// unconnected
		.CLKFBOUTB(),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6());
	localparam CLKOUT0_DIVIDE_F_VGA = CLKFBOUT_MULT_F * VGA_CLK_DIVIDE;
	defparam mmcm_vga.CLKIN1_PERIOD = 10.0;
	defparam mmcm_vga.CLKFBOUT_MULT_F = CLKFBOUT_MULT_F;
	defparam mmcm_vga.CLKOUT0_DIVIDE_F = CLKOUT0_DIVIDE_F_VGA;
	BUFG bufg1_vga(.I(clk0_vga),.O(clk_vga));
	BUFG bufg2_vga(.I(clkfb_vga),.O(clkfb_buf_vga));

endmodule