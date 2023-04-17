`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: vga_ctl3_tb.sv
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

    // Writes a character (and its color) to a specific column and row
	task write_character( input [6:0] col, input [4:0] row, input [31:0] value);
        // wait for clock edge
        @(negedge clk_data)
        $display("[%0tns] Writing character of 0x%h to (col,row)=0x%h,0x%h", $time/1000, value,col,row );
        char_we <= 1'b1;
        char_value <= value;
        char_addr <= {row, col};
        // Wait a clock
        @(negedge clk_data)
        char_we <= 1'b0;
    endtask

    // Reads a value from the character memory
	task read_character( input [6:0] col, input [4:0] row);
        // wait for clock edge
        @(negedge clk_data)
        char_addr <= {row, col};
        // Wait a clock
        @(negedge clk_data)
        $display("[%0tns] Reading character of 0x%h from col,row=0x%h,0x%h", $time/1000, char_read, col, row );
    endtask

    // Writes a character (and its color) to a specific column and row
	task clk_cnt( input c, input clk );
        for (int i = 0 ; i < c; i = i +1)
            @(negedge clk);
    endtask

    // Instance top-level VGA controller
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

    logic [11:0] color_val;
    logic [31:0] write_val;

	//////////////////////////////////////////////////////////////////////////////////
	//	Main
	//////////////////////////////////////////////////////////////////////////////////
	initial begin
        integer i;

		//////////////////////////////////
		//	Reset
		$display("[%0tns]Reset", $time/1000.0);
		rst <= 0; #200
		rst <= 1; #200;
		rst <= 0;
        
        // Wait for some data clocks
        clk_cnt(20,clk_data);

        // Write characters in all visible locations
        for (int row = 0; row < 29; row=row+1) begin
            for (int col = 0; col < 79; col=col+1) begin
                color_val = row << 7 | col;
                write_val = ((~color_val & 12'hfff) << 20) | (color_val << 8)  | col;
                write_character( col, row, write_val);
                clk_cnt(20,clk_data);
            end
        end
        // Write characters in all four corners of display with custom color
        write_character( 0, 0, 32'haf050f21);
        clk_cnt(20,clk_data);
        write_character( 79, 0, 32'haf050f22);
        clk_cnt(20,clk_data);
        write_character( 0, 29, 32'haf050f23);
        clk_cnt(20,clk_data);
        write_character( 79, 29, 32'haf050f24);
        clk_cnt(20,clk_data);
        // Write a character in the middle with default color
        write_character( 40, 15, 32'h25);
        clk_cnt(20,clk_data);

        // Make sure the characters was properly written
        read_character (0,0);
        read_character (79,0);
        read_character (0,29);
        read_character (79,29);
        read_character (40,15);
                
        // Wait until frame is done
        @(negedge vs)

        // Wait until frame is done
        @(negedge vs)

        // End simulation        
        $finish;

	end


endmodule

