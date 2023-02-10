`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_multicycle_io.v
//
//  Author: Mike Wirthlin
//  
//////////////////////////////////////////////////////////////////////////////////

module tb_multicycle_io 
	#(
		parameter instruction_memory_filename = "multicycle_iosystem_text.mem",
		parameter data_memory_filename = ""
	);

    logic tb_clk, tb_btnc, tb_btnu, tb_btnd, tb_btnl, tb_btnr;
    logic [15:0] tb_sw, tb_led;
    logic [3:0] tb_an;
    logic [6:0] tb_seg;
    logic tb_dp;
    logic tb_RsTx = 1;  // UART not active

	task error();
		// Provide some delay after error so that you don't have to look at end of waveform
		#100 tb_clk = 0;
		$fatal("Exiting with error");
	endtask;

	task buttons_off;
        tb_btnc = 0;
        tb_btnu = 0;
        tb_btnd = 0;
        tb_btnl = 0;
        tb_btnr = 0;
	endtask

	task test_switches;
        // Set the switches with no buttons pressed and see if LEDs follow
		input [15:0] sw_val;
		begin
		  buttons_off();
		  tb_sw = sw_val;
		  #5us
          if (tb_led != tb_sw) begin
            $display("**** LEDs did not update with changes in switches");
            error();
          end
          else begin
            $display("**** LEDs updated to correct value");
          end
		end
	endtask


	task test_btnd;
        // # Check button D: turn LEDs off
		input [15:0] sw_val;
		begin
		  buttons_off();
		  tb_sw = sw_val;
		  #100
		  tb_btnd = 1;
		  #5us
          if (tb_led != 0) begin
            $display("**** LEDs did not turn off with BTND");
            error();
          end
          else begin
            $display("**** LED turned off with BTND");
          end
		end
	endtask

	task test_btnu;
        // 	# Button U pressed - write ffff to LEDs (turn them on)
		input [15:0] sw_val;
		begin
		  buttons_off();
		  tb_sw = sw_val;
		  #100
		  tb_btnu = 1;
		  #5us
          if (tb_led != 16'hffff) begin
            $display("**** LEDs did not turn on with BTNU");
            error();
          end
          else begin
            $display("**** LED turned on with BTNU");
          end
		end
	endtask

	task test_btnr;
        // 	# Check button R: Invert switches when displaying on LEDs
		input [15:0] sw_val;
		begin
		  buttons_off();
		  tb_sw = sw_val;
		  #100
		  tb_btnr = 1;
		  #5us
          if (tb_led != ~tb_sw) begin
            $display("**** LEDs did not invert with BTNR");
            error();
          end
          else begin
            $display("**** LED inverted with BTNR");
          end
		end
	endtask
 

	task test_btnl;
        // 	# Check button R: Invert switches when displaying on LEDs
		input [15:0] sw_val;
		begin
		  buttons_off();
		  tb_sw = sw_val;
		  #100
		  tb_btnl = 1;
		  #5us
          if (tb_led != tb_sw << 1) begin
            $display("**** LEDs did not shift with BTNL");
            error();
          end
          else begin
            $display("**** LED shifted with BTNL");
          end
		end
	endtask

     /*	
	# Button C pressed - fall through to clear timer and seven segmeent dislplay
    */

    // Clock
    initial begin
        #200
        forever begin
            #5 tb_clk = 1; 
            #5 tb_clk = 0;
        end
    end
    
    // I/O
    initial begin

        // Startup delay
        #100

        // Initialize inputs
        buttons_off();
        tb_sw = 0;
        #10us

        // Change the switchces and observe LEDs
        $display("Test #1: change switches");
        test_switches(16'ha5a5);
        $display("Test #2: BTNL");
        test_btnl(16'h00ff);
        $display("Test #3: BTNR");
        test_btnr(16'hff00);
        $display("Test #4: BTNU");
        test_btnu(16'h0ff0);
        $display("Test #5: BTND");
        test_btnd(16'hf00f);
        
        // Wrap up
        buttons_off();
        tb_sw = 16'h0;
        #1us
        tb_btnr = 1'b0;
        
/*  
        tb_btnr = 1'b0;
        #1us


# Press BTNR and observe LEDs
add_force btnr 1
run 10 us
# Release BTNR and observe LEDs
add_force btnr 0
run 1 us

# Press BTNL and observe LEDs
add_force btnl 1
run 10 us
# Release BTNL and observe LEDs
add_force btnl 0
run 1 us

# Press BTNL and observe LEDs
add_force btnu 1
run 10 us
# Release BTNL and observe LEDs
add_force btnu 0
run 1 us

# Press BTNL and observe LEDs
add_force btnd 1
run 10 us
# Release BTNL and observe LEDs
add_force btnd 0
run 1 us

# Run 1 ms for timer
run 1 ms

# Press BTNL and observe LEDs
add_force btnc 1
run 10 us
# Release BTNL and observe LEDs
add_force btnc 0
run 1 us

Checks:
- Make sure LEDs follow buttons after switches are changed


*/

        $display("Successful Simulation");
        $finish;
    end


    // Instance system
    multicycle_iosystem #(.TEXT_MEMORY_FILENAME(instruction_memory_filename),
        .DATA_MEMORY_FILENAME(data_memory_filename),.USE_DEBOUNCER(0))
    riscv(.clk(tb_clk), 
        .btnc(tb_btnc), .btnd(tb_btnd), .btnl(tb_btnl), .btnr(tb_btnr), .btnu(tb_btnu), 
        .sw(tb_sw), .led(tb_led),
        .an(tb_an), .seg(tb_seg), .dp(tb_db), 
        .RsRx(), .RsTx(tb_RsTx), 
        .vgaBlue(), .vgaGreen(), .vgaRed(), .Hsync(), .Vsync()
    );


endmodule