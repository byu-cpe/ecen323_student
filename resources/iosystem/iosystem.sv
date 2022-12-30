///////////////////////////////////////////////////////////////////////////////////////////////
// 
// This file contains the I/O system logic for the RISC-V processor used 
// in ECEN 323. 
//
//  To Do:
//  - Add a second timer
//  - Add a register for controlling the intensity of each 7-segment digit.
//    A four bit register could be added that gives 16 possible intensity
//    levels for each digit (including fully on and off).
//  - Add a register to control intensity of LEDs (so you can do smooth LED pulsing)
//  - Use the higher resolution video controller from digilent
//  - Add debug logic
//    - Uses the PMOD button. When this module is connected at start up, go into 
//      debug mode.
//    - Seven segment display is overridden when in debug mode. Pressing a button
//      puts it in "regular" mode
//      - Shows the PC[15:0] by default
//    - Button for single stepping clock, res
//    - Ability to insert a breakpoint and stop when it is reacbed
//
//
///////////////////////////////////////////////////////////////////////////////////////////////

module iosystem (clk, clkvga, rst, address, MemWrite, MemRead, 
    io_memory_read, io_memory_write, valid_io_read,
    btnc, btnd, btnl, btnr, btnu, sw, led,
    an, seg, dp, RsRx, RsTx, vgaBlue, vgaGreen, vgaRed, Hsync, Vsync);


    // Input clock frequency
	parameter INPUT_CLOCK_RATE = 100000000 / 3;
    
	// I/O starting addresses
	parameter VGA_START_ADDRESS                 = 32'h00008000;
	parameter IO_START_ADDRESS                  = 32'h00007f00;

	// I/O device offests
	parameter [7:0] LED_BASE_OFFSET 	        = 8'h00;
	parameter [7:0] SWITCH_BASE_OFFSET          = 8'h04;
	parameter [7:0] TX_BASE_OFFSET              = 8'h08;
	parameter [7:0] RX_DATA_BASE_OFFSET         = 8'h10;
	parameter [7:0] RX_STATUS_BASE_OFFSET       = 8'h14;
	parameter [7:0] SEVEN_SEG_BASE_OFFSET       = 8'h18;
	parameter [7:0] SEVEN_SEG_CTRL_BASE_OFFSET  = 8'h1C; 
	parameter [7:0] BUTTON_BASE_OFFSET          = 8'h24;
	parameter [7:0] TIMER_BASE_OFFSET           = 8'h30;
	parameter [7:0] CHAR_COLOR_BASE_OFFSET      = 8'h34;

    // Misc I/O constants
	parameter IO_SIZE_BYTES = 256;
	localparam IO_ADDR_BITS = $clog2(IO_SIZE_BYTES);	
	localparam VGA_ADDR_BITS = 14; // address 16384 bytes
	parameter DEBOUNCE_DELAY_US = 10;
	parameter USE_DEBOUNCER = 1;
	parameter UART_BAUD_RATE = 115200;
	parameter UART_PARITY = 1'd0;
	parameter TIMER_CLOCK_REDUCTION = 1;  // used to reduce number of clocks per tick for simulation speed
	parameter [11:0] DEFAULT_FOREGROUND_COLOR = 12'b111111110000;  // yellow
	parameter [11:0] DEFAULT_BACKGROUND_COLOR = ~DEFAULT_FOREGROUND_COLOR; // blue
	localparam TIMER_CLOCKS_PER_MS = INPUT_CLOCK_RATE / (1000 * TIMER_CLOCK_REDUCTION);

	// Top-level ports
	input logic clk;                              // IO Clock
    input logic clkvga;                           // VGA Clock (should be 50 MHz)
    input logic rst;
    input [31:0] address;                       // Address used in "MEM" stage
    input logic MemWrite;                         // Write control signal for I/O (MEM stage)
    input logic MemRead;                         
    output [31:0] io_memory_read;           // IO read data (read from IO). Once cycle delay
    input [31:0] io_memory_write;          // IO write data (write to IO)
    output logic  valid_io_read;                   // Indicates that there is valid I/O data this clock cycle
	input logic btnc;
	input logic btnd;
	input logic btnl;
	input logic btnr;
	input logic btnu;
	input [15:0] sw;
	output [15:0] led;
	output [3:0] an;
	output [6:0] seg;
    output logic dp;
	output logic RsRx;
	input logic RsTx;
	output [3:0] vgaRed;
	output [3:0] vgaBlue;
	output [3:0] vgaGreen;
	output logic Hsync;
	output logic Vsync;

	////////////////////////////////////////////////////////////////////
	// I/O Space decoding
	////////////////////////////////////////////////////////////////////

	localparam [3:0] LED_ADDR = LED_BASE_OFFSET[5:2];                   // 0x0
	localparam [3:0] SW_ADDR = SWITCH_BASE_OFFSET[5:2];                 // 0x4
	localparam [3:0] TX_ADDR = TX_BASE_OFFSET[5:2];                     // 0x8
	localparam [3:0] RX_DATA_ADDR = RX_DATA_BASE_OFFSET[5:2];           // 0x10 (16)
	localparam [3:0] RX_STATUS_ADDR = RX_STATUS_BASE_OFFSET[5:2];       // 0x14 (20)
	localparam [3:0] SEG_ADDR = SEVEN_SEG_BASE_OFFSET[5:2];             // 0x18 (24)
	localparam [3:0] SEG_ADDR_CTRL = SEVEN_SEG_CTRL_BASE_OFFSET[5:2];   // 0x1c (28)
	localparam [3:0] BTN_ADDR = BUTTON_BASE_OFFSET[5:2];                // 0x24 (36)
	localparam [3:0] TIMER_ADDR = TIMER_BASE_OFFSET[5:2];               // 0x30 (48)
	localparam [3:0] CHAR_DEFAULT_COLOR = CHAR_COLOR_BASE_OFFSET[5:2];  // 0x34 (52)

    // Decoding signals
    logic io_space_mem;
    // Data bus signals
    logic [31:0] io_memory_read_i, LED_read, tx_status_read, rx_data_read, rx_status_read, sw_read;
    logic [31:0] btn_read, seven_seg_data_read, seven_seg_ctrl_read, ms_timer_cnt, default_color_read;
    // Write control signals
    logic LEDWrite, seven_seg_write, seven_seg_ctrl_write, tx_write;
    logic char_default_color_write, timer_value_write; 
    // VGA decoding
    logic valid_upper_vga_address_mem;
    logic [31:0] char_value_read;

    // Decode address for I/O (_mem indicates address in mem stage)
	assign io_space_mem = (address[31:IO_ADDR_BITS] == IO_START_ADDRESS[31:IO_ADDR_BITS]);
	logic[3:0] io_addr;
	assign io_addr = address[5:2]; // 16 different 32-bit I/O address spaces

    // Generate valid IO data read signal
    logic io_space_wb, valid_upper_vga_address_wb;
	always_ff@(posedge clk) begin
        io_space_wb <= io_space_mem;
        valid_upper_vga_address_wb <= valid_upper_vga_address_mem;
	end
    assign valid_io_read = (io_space_wb | valid_upper_vga_address_wb); // include MemRead (delayed version of)?
    assign io_memory_read = valid_upper_vga_address_wb ? char_value_read : io_memory_read_i;

    // Generate io read data

	// Control and decoding for I/O Writes
    always_comb begin
        LEDWrite = 0;
		seven_seg_write = 0;
		seven_seg_ctrl_write = 0;
		tx_write = 0;
		timer_value_write = 0;
		char_default_color_write = 0;
	    if(io_space_mem && MemWrite)
			case(io_addr)
				LED_ADDR : LEDWrite = 1;
				TX_ADDR : tx_write = 1;
				SEG_ADDR : seven_seg_write = 1;
				SEG_ADDR_CTRL : seven_seg_ctrl_write = 1;
				TIMER_ADDR : timer_value_write = 1;
				CHAR_DEFAULT_COLOR : char_default_color_write = 1;
			endcase
    end

	// Control and decoding for I/O Reads (these are synchronous - one cycle delay)
    always_ff @(posedge clk)
    begin
		if (rst)
			io_memory_read_i <= 0;
		else 
			case(io_addr)
				LED_ADDR : io_memory_read_i <= LED_read;
				TX_ADDR : io_memory_read_i = tx_status_read;
				RX_DATA_ADDR : io_memory_read_i = rx_data_read;
				RX_STATUS_ADDR : io_memory_read_i = rx_status_read;
                SW_ADDR : io_memory_read_i <= sw_read;
                BTN_ADDR : io_memory_read_i <= btn_read;
				SEG_ADDR : io_memory_read_i <= seven_seg_data_read;
				SEG_ADDR_CTRL : io_memory_read_i <= seven_seg_ctrl_read;
				TIMER_ADDR : io_memory_read_i <= ms_timer_cnt;
				CHAR_DEFAULT_COLOR : io_memory_read_i <= default_color_read;
			endcase
	end

    
	////////////////////////////////////////////////////////////////////
	// Buttons (read only)
	////////////////////////////////////////////////////////////////////

	// Synchronizers for buttons
	logic btnc_d, btnc_dd=0;
	logic btnd_d, btnd_dd=0;
	logic btnl_d, btnl_dd=0;
	logic btnr_d, btnr_dd=0;
	logic btnu_d, btnu_dd=0;
	always_ff@(posedge clk) begin
		btnc_d <= btnc; btnc_dd <= btnc_d;
		btnd_d <= btnd; btnd_dd <= btnd_d;
		btnl_d <= btnl; btnl_dd <= btnl_d;
		btnr_d <= btnr; btnr_dd <= btnr_d;
		btnu_d <= btnu; btnu_dd <= btnu_d;
	end

    // Debouncers for the switches
	wire btnc_deb, btnd_deb, btnl_deb, btnr_deb, btnu_deb;
    generate
		if (USE_DEBOUNCER) begin
            debounce #(.CLK_FREQUECY(INPUT_CLOCK_RATE), .DEBOUNCE_DELAY_US(DEBOUNCE_DELAY_US)) 
                btnc_debouncer (.clk(clk),.rst(rst),.debounce_in(btnc_dd),.debounce_out(btnc_deb));
            debounce #(.CLK_FREQUECY(INPUT_CLOCK_RATE), .DEBOUNCE_DELAY_US(DEBOUNCE_DELAY_US)) 
                btnd_debouncer (.clk(clk),.rst(rst),.debounce_in(btnd_dd),.debounce_out(btnd_deb));
            debounce #(.CLK_FREQUECY(INPUT_CLOCK_RATE), .DEBOUNCE_DELAY_US(DEBOUNCE_DELAY_US)) 
                btnu_debouncer (.clk(clk),.rst(rst),.debounce_in(btnu_dd),.debounce_out(btnu_deb));
            debounce #(.CLK_FREQUECY(INPUT_CLOCK_RATE), .DEBOUNCE_DELAY_US(DEBOUNCE_DELAY_US)) 
                btnl_debouncer (.clk(clk),.rst(rst),.debounce_in(btnl_dd),.debounce_out(btnl_deb));
            debounce #(.CLK_FREQUECY(INPUT_CLOCK_RATE), .DEBOUNCE_DELAY_US(DEBOUNCE_DELAY_US)) 
                btnr_debouncer (.clk(clk),.rst(rst),.debounce_in(btnr_dd),.debounce_out(btnr_deb));
		end
		else begin
			assign btnc_deb = btnc_dd;
			assign btnd_deb = btnd_dd;
			assign btnl_deb = btnl_dd;
			assign btnr_deb = btnr_dd;
			assign btnu_deb = btnu_dd;
		end
	endgenerate
    // Button read signal
	assign btn_read = {27'h0000000,btnu_deb,btnr_deb,btnd_deb,btnl_deb,btnc_deb};

	////////////////////////////////////////////////////////////////////
	// Switches (read only)
	////////////////////////////////////////////////////////////////////
	logic [15:0] sw_d, sw_dd=0;
	always_ff@(posedge clk) begin
		sw_d <= sw; sw_dd <= sw_d;
	end
    // No debouncer for the switches
	wire [15:0] sw_deb;
	assign sw_deb = sw_dd;
    // Read value for switches
	assign sw_read = {16'h0000,sw_deb};

	////////////////////////////////////////////////////////////////////
	// LED (read and write)
	////////////////////////////////////////////////////////////////////
	logic [15:0] LED_reg;
    always @(posedge clk)
    begin
        if(rst == 1)
            LED_reg <= 0;
        else if(LEDWrite == 1)
            LED_reg <= io_memory_write[15:0];          
    end
    // assign top-level LED value
	assign led = LED_reg;
    // Data to read from LEDs
	assign LED_read = {16'h0000,LED_reg};

	////////////////////////////////////////////////////////////////////
	// Seven Segment Display
	////////////////////////////////////////////////////////////////////
	logic [15:0] seven_segment_reg;
	logic [7:0] seven_segment_ctrl;
	localparam DEFAULT_SEVEN_SEG_CTRL = 8'b00001111;

    always @(posedge clk)
    begin
        if(rst == 1)
            seven_segment_reg <= 0;
        else if(seven_seg_write == 1)
            seven_segment_reg <= io_memory_write[15:0];          
    end
	assign seven_seg_data_read = {16'h0000, seven_segment_reg};

	// Seven segment control:
	// [3:0] - digit display
	// [7:4] - digit point
    always @(posedge clk)
    begin
        if(rst == 1)
            seven_segment_ctrl <= DEFAULT_SEVEN_SEG_CTRL;
        else if(seven_seg_ctrl_write == 1)
            seven_segment_ctrl <= io_memory_write[7:0];          
    end
	assign seven_seg_ctrl_read = {24'h000000, seven_segment_ctrl};

	// Instance 4 digit seven segment controller modude
    SevenSegmentControl4 ssc(.clk(clk), 
							.dataIn(seven_segment_reg), 
        					.digitPoint(seven_segment_ctrl[7:4]), 
							.digitDisplay(seven_segment_ctrl[3:0]), 
							.segment(seg),.anode(an),.dp(dp)); 


	////////////////////////////////////////////////////////////////////
	// UART
	////////////////////////////////////////////////////////////////////
	logic tx_busy;
	logic uart_tx_out;

    // Transmitter
	tx #(.CLK_FREQUECY(INPUT_CLOCK_RATE), .BAUD_RATE(UART_BAUD_RATE) ) 
	   tx (.clk(clk), .send(tx_write), .odd(UART_PARITY), .din(io_memory_write[7:0]),.busy(tx_busy),.tx_out(uart_tx_out));
	//defparam tx.CLK_FREQUECY = INPUT_CLOCK_RATE;
	//defparam tx.BAUD_RATE = UART_BAUD_RATE;
    // assign top level "receive"  (rx) on the PC to the uart transmit port
    assign RsRx = uart_tx_out;
	assign tx_status_read = {31'd0,tx_busy};

	// Uart Receiver
	logic rx_error, rx_busy, rx_data_strobe;
	logic rx_new_data;
	logic [7:0] rx_data;
    logic uart_rx_in;

    // assign the rx_in on the UARRT to the top-level RsTx (i..e, the PC Tx). This statement is used just
    // for clarification of the naming.
    assign uart_rx_in = RsTx;

	rx rx (.clk(clk), .rx_in(uart_rx_in), .odd(UART_PARITY), .error(rx_error), .busy(rx_busy), .data_strobe(rx_data_strobe),
		.dout(rx_data));
	defparam rx.CLK_RATE = INPUT_CLOCK_RATE;
	defparam rx.BAUD_RATE = UART_BAUD_RATE;
	// New data flag. It is set when the 'rx_data_strobe' goes high.
	//   It is reset when the RX data is read or the rx become busy again
    always @(posedge clk)
    begin
        if(rst == 1) begin
            rx_new_data <= 0;
        end
		else begin
			// If the data is read, reset rx_new_data.
			if ((rx_new_data && io_space_mem && MemRead && io_addr==RX_DATA_ADDR)/* || rx_busy */)
				rx_new_data <= 0;
			else if (rx_data_strobe)
				rx_new_data <= 1;
		end
    end
	assign rx_data_read = {24'd0,rx_data};
	assign rx_status_read = {29'd0,rx_error,rx_busy,rx_new_data};


	////////////////////////////////////////////////////////////////////
	// Timer
	////////////////////////////////////////////////////////////////////
	logic [19:0] ms_tick_cnt=0;
    always @(posedge clk)
    begin
        if(rst == 1) begin
            ms_timer_cnt <= 0;
			ms_tick_cnt <= 0;
        end else begin
			if (timer_value_write) begin
				ms_timer_cnt <= io_memory_write;
				ms_tick_cnt <= 0;
			end else if (ms_tick_cnt == TIMER_CLOCKS_PER_MS-1) begin
				ms_tick_cnt <= 0;
				ms_timer_cnt <= ms_timer_cnt + 1;
			end
			else
				ms_tick_cnt <= ms_tick_cnt + 1;
		end
    end	

	////////////////////////////////////////////////////////////////////
	// VGA
	//   Provides a 128x32 array of characters. Each character is 32 bits for
	//   a total address space of 4096x32 (16384 bytes). 
	//
	// The address space allocated to this
	//   memory is VGA_START_ADDRESS to VGA_START_ADDRESS+0x3fff
	//
	// The default range is 0x8000 to 0xBFFF
	////////////////////////////////////////////////////////////////////
	
	logic [VGA_ADDR_BITS-1:0] vga_char_address;
    logic char_value_write;
    logic use_default_color;
	logic [24:0] default_character_color;
    logic [11:0] char_fg_color, char_bg_color;

	// Register that contains the default color
	localparam DEFAULT_COLOR_MODE = 1'b0;  // default color mode is common background/foreground
	localparam [24:0] DEFAULT_CHARACTOR_COLOR_MODE = 
		{DEFAULT_COLOR_MODE, DEFAULT_BACKGROUND_COLOR, DEFAULT_FOREGROUND_COLOR};

	// VGA memory interface
	assign valid_upper_vga_address_mem =
		(address[31:VGA_ADDR_BITS] == VGA_START_ADDRESS[31:VGA_ADDR_BITS]);
    assign vga_char_address = address[VGA_ADDR_BITS-1:0];

	// Control (writes)
	assign char_value_write = (valid_upper_vga_address_mem & MemWrite);
    // Indicate which mode of color to use based on current mode
	assign use_default_color = default_character_color[24];
    // Determine fg and bg colors
	assign char_fg_color = default_character_color[11:0];
	assign char_bg_color = default_character_color[23:12];
	assign default_color_read = {7'd0,default_character_color};
	
	
	// Register for default color and mode
    always @(posedge clk)
    begin
        if(rst == 1) begin
			default_character_color <= DEFAULT_CHARACTOR_COLOR_MODE;
        end else begin
			if (char_default_color_write)
				default_character_color <= io_memory_write[24:0];
		end
    end	

    // Instance top-level VGA
   	vga_ctl3 vga ( 
		.clk_vga(clkvga), 
		.clk_data(clk), 
		.rst(rst),
		.char_we(char_value_write), 
		.char_value(io_memory_write), 
		.char_addr(vga_char_address[VGA_ADDR_BITS-1:2]), // ignore bottom two bits
		.custom_foreground(use_default_color),
		.foreground_rgb(char_fg_color),
		.background_rgb(char_bg_color),
		.char_read(char_value_read),
		.VGA_HS(Hsync),
		.VGA_VS(Vsync),
		.VGA_R(vgaRed),
		.VGA_G(vgaGreen),
		.VGA_B(vgaBlue)
		);


	// BEGIN_SIM_MODEL
	// synthesis translate_off

	////////////////////////////////////////////////////////////////////
	// Simulation
	// 
	// This section begins the non-synthesizable simulation code for this
	// I/O system. This code is used to allow testbench simulation of the system.
	// This simulation code will be extracted and inserted into the flattened
	// synthesized version of this I/O system so students can simulate their
	// system and take advantage of these testbench debugging resources.
	// 
	// Note that the simulation model will be inserted into the post synthesized
	// design and many signals will be optimized away/renamed. The only signals
	// that should be used are top-level ports or signals that go into the RISC-V
	// processor.
	//
	// This simulation code should be written using conventional verilog and not
	// any SystemVerilog. This is because this code will be added to a synthesized
	// Verilog file rather than a SystemVerlog file.
	//
	////////////////////////////////////////////////////////////////////

	// Don't print anything until the reset is over.
	reg reset_gone_high = 0;
	reg reset_gone_low = 0;
	always@(negedge clk) 
	begin
		if (rst && !reset_gone_high) begin
			reset_gone_high = 1;
			$display("Reset issued at time %0t",$time );
		end
		if (~rst && reset_gone_high) begin
			reset_gone_low = 1;
			$display("Reset released at time %0t",$time );
			reset_gone_high = 0;
		end
	end

	// Register delay for address
	logic [31:0] address_wb;
	logic MemRead_wb;
	always@(posedge clk) begin
		address_wb <= address;
		MemRead_wb <= MemRead;
	end

	// I/O Write Messages
	always@(negedge clk) 
	begin
		if (address[31:IO_ADDR_BITS] == IO_START_ADDRESS[31:IO_ADDR_BITS]) begin
			// I/O Writes
			if (MemWrite) begin
				case (address[5:2]) 
					LED_BASE_OFFSET[5:2] : $display("%0t:Writing 0x%h to LEDs",$time, io_memory_write);
					//SWITCH_BASE_OFFSET - No writing to switches
					TX_BASE_OFFSET[5:2] : $display("%0t:Writing 0x%h to TX",$time, io_memory_write);
					//RX_DATA_BASE_OFFSET
					//RX_STATUS_BASE_OFFSET
					SEVEN_SEG_BASE_OFFSET[5:2] : $display("%0t:Writing 0x%h to Seven Segment Display",$time, io_memory_write);
					//BUTTON_BASE_OFFSET
					TIMER_BASE_OFFSET[5:2] : $display("%0t:Writing 0x%h to Timer",$time, io_memory_write);
					CHAR_COLOR_BASE_OFFSET[5:2] : $display("%0t:Writing 0x%h to Character Default Color",$time, io_memory_write);
					default : $display("%0t:Writing 0x%h to I/O Address 0x%h",$time, io_memory_write, address);
				endcase
			end
		end
	end

	// I/O Read Messages
	always@(negedge clk) 
	begin
		if (address_wb[31:IO_ADDR_BITS] == IO_START_ADDRESS[31:IO_ADDR_BITS]) begin
			// I/O Writes
			if (MemRead_wb) begin
				case (address_wb[5:2]) 
					LED_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from LEDs",$time, io_memory_read);
					SWITCH_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from Switches",$time, io_memory_read);
					TX_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from TX",$time, io_memory_read);
					RX_DATA_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from RX Data",$time, io_memory_read);
					RX_STATUS_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from RX status",$time, io_memory_read);
					SEVEN_SEG_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from Seven Segment Display",$time, io_memory_read);
					BUTTON_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from Buttons",$time, io_memory_read);
					TIMER_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from Timer",$time, io_memory_read);
					CHAR_COLOR_BASE_OFFSET[5:2] : $display("%0t:Reading 0x%h from Character Default Color",$time, io_memory_read);
					default : $display("%0t:Reading 0x%h from I/O Address 0x%h",$time, io_memory_read, address_wb);
				endcase
			end
		end
	end
			
	always@(negedge clk) 
	begin
		// VGA Writes
		if (address[31:VGA_ADDR_BITS] == VGA_START_ADDRESS[31:VGA_ADDR_BITS] && MemWrite)
			$display("%0t:Writing 0x%h to VGA at address 0x%h",$time, io_memory_write, address);
		// VGA Reads
		if (address_wb[31:VGA_ADDR_BITS] == VGA_START_ADDRESS[31:VGA_ADDR_BITS] && MemRead_wb)
			$display("%0t:Reading 0x%h from VGA at address 0x%h",$time, io_memory_read, address_wb);
					
	end
	

	// synthesis translate_on	

endmodule