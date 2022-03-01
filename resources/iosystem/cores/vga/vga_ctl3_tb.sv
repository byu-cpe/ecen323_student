`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: riscv_forwarding_tb.v
//
//  Author: Mike Wirthlin
//  
//  Version 1.3 (2/25/2020)
//   - Change the text below to reflect the version in the testbench output
//     search for "RISCV PIPELINE TESTBENCH V"
//   
//////////////////////////////////////////////////////////////////////////////////

module vga_ctl3_tb();

    logic clk_vga, clk_data, rst;
    logic hs, vs;
    logic [3:0] vga_r, vga_g, vga_b;
    logic char_we = 0;
    logic [31:0] char_value = 0;
    logic [11:0] char_addr = 0;
    logic [11:0] foreground_rgb = 12'hfff;
    logic [11:0] background_rgb = 12'h000;
    logic [31:0] char_read;

	task write_character( input [6:0] col, input [4:0] row, input [31:0] value);
        // wait for clock edge
        @(negedge clk_data)
        $display("[%0tns] Writing character of 0x%h to (col,row)=0x%h,0x%h", $time/1000, value[7:0],col,row );
        char_we <= 1'b1;
        char_value <= value;
        char_addr <= {row, col};
        // Wait a clock
        @(negedge clk_data)
        char_we <= 1'b0;
    endtask

	task read_character( input [6:0] col, input [4:0] row);
        // wait for clock edge
        @(negedge clk_data)
        char_addr <= {row, col};
        // Wait a clock
        @(negedge clk_data)
        $display("[%0tns] Reading character of 0x%h to col,row=0x%h,0x%h", $time/1000, char_read[7:0],col,row );
    endtask

    vga_ctl3 vga (.clk_vga(clk_vga), .clk_data(clk_data), .rst(rst), 
        .char_we(char_we), .char_value(char_value), .char_addr(char_addr),
        .foreground_rgb(foreground_rgb), .background_rgb(background_rgb), .char_read(char_read),
        .VGA_HS(hs), .VGA_VS(vs), .VGA_R(vga_r), .VGA_G(vga_g), .VGA_B(vga_b) );

    // VGA Clock (50 MHz)
    initial begin
        forever begin
            clk_vga = 1; #10;
            clk_vga = 0; #10;        
        end
    end

    // Data Clock (33 MHz)
    initial begin
        forever begin
            clk_data = 1; #16.5;
            clk_data = 0; #16.5;        
        end
    end

    // Reset
    initial begin
        rst <= 0; #200;
        rst <= 1; #200;
        rst <= 0;
    end

	//////////////////////////////////////////////////////////////////////////////////
	//	Main
	//////////////////////////////////////////////////////////////////////////////////
	initial begin
        integer i;

		//////////////////////////////////
		//	Reset
		//$display("[%0tns]Reset", $time/1000.0);
		//dReadData = 0;
		rst <= 0; #200
		rst <= 1; #200;
		rst <= 0;
        
        for (i = 0 ; i < 20; i = i +1) begin
            @(negedge clk_data);
        end

        // Write space character (' ') on first line
        write_character( 64, 0, 32'h20);
        for (i = 0 ; i < 20; i = i +1)
            @(negedge clk_data);

        // Make sure the character was properly written
        read_character (64,0);
        
        // Write character (first corner before new frame is displayed)
        write_character( 0, 0, 32'h21);

	end


endmodule

