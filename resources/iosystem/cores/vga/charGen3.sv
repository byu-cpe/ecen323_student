/*----------------------------------------------------------------------------------
--
-- charGen3
--
-- This module generates the color for pixels associated with a character display.
--
-- This module uses the charColorMem which stores the character to display at
-- each location asa well as the 12-bit foreground and 12-bit background of the
-- character.
--
-- The pixel_out is 12-bits which provides the 12-bit color for the given pixel.
--
----------------------------------------------------------------------------------*/

module charGen3(clk_vga,clk_data,char_we,char_value,data_addr,pixel_x,pixel_y,data_read_value,pixel_out);

    input logic clk_vga;
    input logic clk_data;
    input logic char_we;
    input logic[31:0]  char_value;
    input logic [11:0] data_addr;
    input logic [9:0] pixel_x;
    input logic [9:0] pixel_y;
    output logic [31:0] data_read_value;
    output logic [11:0] pixel_out;

    logic [11:0] vga_read_addr; 
    logic [31:0] vga_read_value;
    logic [10:0] font_rom_addr;
    logic [7:0] data;
	logic [2:0] char_x_pixel,ddr,ddr2;
	logic [6:0] char_x_pos;
	logic [4:0] char_y_pos;
	logic [3:0] char_y_pixel;
	logic pixel_fg;
	logic [6:0] charToDisplay;

    charColorMem3BRAM charmem (
        .clk_vga(clk_vga),
        .clk_data(clk_data),
        .data_we(char_we),
        .data_write_value(char_value),
        .vga_read_value(vga_read_value),
        .data_read_value(data_read_value),
        .vga_addr(vga_read_addr),
        .data_addr(data_addr)
    );
    
    font_rom fontrom(
        .clk(clk_vga),
        .addr(font_rom_addr),
        .data(data)
    );

    always_ff@(posedge clk_vga) begin
        ddr <= char_x_pixel;
        ddr2 <= ddr;
    end
	
	assign char_x_pixel = pixel_x[2:0];
	assign char_y_pixel = pixel_y[3:0];
	assign char_x_pos = pixel_x[9:3];
	assign char_y_pos = pixel_y[8:4];
	assign vga_read_addr = { char_y_pos , char_x_pos};
	// This odd use of both bit 7 and bit 6 is done to try and trick the synthesis tool into thinking
	// that bit 7 is actually used. bit 6 and bit 7 should be the same so the logic shouldn't change
	// the functionality. The following line is what noormally would be done:
	//    charToDisplay <= vga_read_value(6 downto 0);
	//charToDisplay <= (vga_read_value(7) or vga_read_value(6)) & vga_read_value(5 downto 0);
	//charToDisplay <= (vga_read_value(7) xnor vga_read_value(6)) & vga_read_value(5 downto 0);
	assign charToDisplay = vga_read_value[6:0];

	assign font_rom_addr = {charToDisplay , char_y_pixel};
	
    always_comb
    begin
        case (ddr2)
            3'b000: pixel_fg = data[7];
            3'b001: pixel_fg = data[6];
            3'b010: pixel_fg = data[5];
            3'b011: pixel_fg = data[4];
            3'b100: pixel_fg = data[3];
            3'b101: pixel_fg = data[2];
            3'b110: pixel_fg = data[1];
            3'b111: pixel_fg = data[0];
            default: pixel_fg = data[0];
	   endcase
	end
    
	assign pixel_out = (pixel_fg == 0) ? vga_read_value[31:20] : vga_read_value[19:8];

endmodule
