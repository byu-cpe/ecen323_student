/*----------------------------------------------------------------------------------
--
-- vga_ctl3
--
--  clk_vga: VGA clock for timing
--  clk_data: clock for data interface
-- 
-- The color values are specified as:
--  [11:8] - Red
--  [7:4] - Green
--  [3:0] - Blue
--
----------------------------------------------------------------------------------*/

module vga_ctl3 (clk_vga, clk_data, rst, char_we, char_value, char_addr,
        custom_foreground, // This is not used but needed for compatibility with VHDL
        foreground_rgb, background_rgb, char_read,
        VGA_HS, VGA_VS,VGA_R, VGA_G,VGA_B );

    input logic clk_vga;
    input logic clk_data;
    input logic rst;
    input logic char_we;
    input logic [31:0] char_value;
    input logic [11:0] char_addr;
    input logic custom_foreground;
    input logic [11:0] foreground_rgb;
    input logic [11:0] background_rgb;
    output logic [31:0] char_read;
    output logic VGA_HS;
    output logic VGA_VS;
    output logic[3:0] VGA_R;
    output logic[3:0] VGA_G;
    output logic[3:0] VGA_B;


	(* dont_touch = "true" *) logic [31:0] char_data_to_write;
    logic [31:0] default_char_value;
	logic [9:0] pixel_x,pixel_y;
	logic [11:0] pixel_out;
    logic hs, vs, blank;
	logic vs_d, hs_d, vs_d2, hs_d2;
	logic blank_d, blank_d2;


	/* Mux to select which char data is written: the default data with a fixed foreground and background or
	-- custom, character specific color data.
	--char_data_to_write <= char_value when custom_foreground = '1' else background_rgb & foreground_rgb & char_value(7 downto 0);
	-- char_data_to_write <= 
    --     char_value when char_value(7) = '1' else 
    --         -- The double use of char_value(6) is to try and trick the synthesis tool into
    --         -- thinking the bit is actually used. 
    --         --background_rgb & foreground_rgb &  char_value(6) & char_value(6 downto 0);
    --         background_rgb & foreground_rgb &  '1' & char_value(6 downto 0);
    */
    assign default_char_value = { background_rgb , foreground_rgb ,  1'b0, char_value[6:0] };
    assign char_data_to_write = (char_value[31:8] == 24'd0) ?
        default_char_value : char_value;

    // charGen3
    charGen3 charGen (
        .clk_vga(clk_vga), 
        .clk_data(clk_data), 
        .char_value(char_data_to_write), 
        .char_we(char_we), 
        .data_addr(char_addr), 
        .pixel_x(pixel_x), 
        .pixel_y(pixel_y), 
        .data_read_value(char_read),
        .pixel_out(pixel_out) );

    // VGA Timing
    vga_timing vga_timing(
		.clk(clk_vga),
		.rst(rst),
		.HS(hs),
		.VS(vs),
		.pixel_x(pixel_x),
		.pixel_y(pixel_y),
		.last_column(),
		.last_row(),
		.blank(blank)
    );

    // Two cycle delay on VGA signals
    always_ff@(posedge clk_vga)
        if(rst)  begin
            vs_d <= 0;
            hs_d <= 0;
            vs_d2 <= 0;
            hs_d2 <= 0;
            blank_d <= 0;
            blank_d2 <= 0;
        end else begin
            vs_d <= vs;
            hs_d <= hs;
            vs_d2 <= vs_d;
            hs_d2 <= hs_d;
            blank_d <= blank;
            blank_d2 <= blank_d;
        end

    // VGA outputs        
    assign VGA_HS = hs_d2;
    assign VGA_VS = vs_d2;
    assign VGA_R = blank_d2 ? 0 : pixel_out[11:8];
    assign VGA_G = blank_d2 ? 0 : pixel_out[7:4];
    assign VGA_B = blank_d2 ? 0 : pixel_out[3:0];   

endmodule
