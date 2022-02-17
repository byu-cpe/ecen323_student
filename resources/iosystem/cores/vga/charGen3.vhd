----------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity charGen3 is
    Port ( 
		clk_vga : in  STD_LOGIC;
		clk_data : in  STD_LOGIC;
        char_we : in  STD_LOGIC;
        char_value : in  STD_LOGIC_VECTOR (31 downto 0);		-- Data to write
        data_addr : in  STD_LOGIC_VECTOR (11 downto 0);
        pixel_x : in  STD_LOGIC_VECTOR (9 downto 0);
        pixel_y : in  STD_LOGIC_VECTOR (9 downto 0);
		data_read_value : out std_logic_vector (31 downto 0);
        pixel_out : out  STD_LOGIC_vector(11 downto 0)
		);
end charGen3;

architecture Behavioral of charGen3 is
	signal vga_read_addr: std_logic_vector(11 downto 0);
	signal data: std_logic_vector(7 downto 0);
	signal vga_read_value: std_logic_vector(31 downto 0);
	signal font_rom_addr: std_logic_vector(10 downto 0);
	signal char_x_pos: std_logic_vector (6 downto 0);
	signal char_y_pos: std_logic_vector (4 downto 0);
	signal char_y_pixel: std_logic_vector (3 downto 0);
	signal char_x_pixel,ddr,ddr2: std_logic_vector (2 downto 0);
	--signal color_read_val : std_logic_vector(31 downto 0);
	signal pixel_fg : std_logic;
	signal charToDisplay : std_logic_vector(6 downto 0);
begin

	-- charmem : entity work.charColorMem
	-- 	port map(
	-- 		clk => clk,
	-- 		char_read_addr => char_read_addr,
	-- 		char_write_addr=> char_addr,
	-- 		char_we => char_we,	
	-- 		char_write_value => char_value,			
	-- 		char_read_value => vga_read_value,
	-- 		char_read_value2 => char_read_value2
	-- 	);

--    charmem : entity work.charColorMem3
    charmem : entity work.charColorMem3BRAM
		port map(
            clk_vga => clk_vga,
            clk_data => clk_data,
            data_we => char_we,
            data_write_value => char_value,
            vga_read_value => vga_read_value,
            data_read_value => data_read_value,
            vga_addr => vga_read_addr,
            data_addr => data_addr
        );         
        
	fontrom : entity work.font_rom
		port map(
			clk=> clk_vga,
			addr => font_rom_addr,
			data => data
		);
		
	process(clk_vga)
	begin
		if(clk_vga'event and clk_vga ='1') then
			ddr<=char_x_pixel;
			ddr2<=ddr;
		end if;
	end process;
	
	char_x_pixel <= pixel_x(2 downto 0);
	char_y_pixel <= pixel_y(3 downto 0);
	char_x_pos <= pixel_x(9 downto 3);
	char_y_pos <= pixel_y(8 downto 4);
	vga_read_addr <= char_y_pos & char_x_pos;
	-- This odd use of both bit 7 and bit 6 is done to try and trick the synthesis tool into thinking
	-- that bit 7 is actually used. bit 6 and bit 7 should be the same so the logic shouldn't change
	-- the functionality. The following line is what noormally would be done:
	--    charToDisplay <= vga_read_value(6 downto 0);
	--charToDisplay <= (vga_read_value(7) or vga_read_value(6)) & vga_read_value(5 downto 0);
	--charToDisplay <= (vga_read_value(7) xnor vga_read_value(6)) & vga_read_value(5 downto 0);
	charToDisplay <= vga_read_value(6 downto 0);

	font_rom_addr <= charToDisplay & char_y_pixel;
	
	with ddr2 select pixel_fg <=
			data(7) when "000",
			data(6) when "001",
			data(5) when "010",
			data(4) when "011",
			data(3) when "100",
			data(2) when "101",
			data(1) when "110",
			data(0) when others;
	
	pixel_out <= vga_read_value(31 downto 20) when pixel_fg = '0' else vga_read_value(19 downto 8);
	--pixel_out <= "000000000000" when pixel_fg = '1' else "111111111111";

end Behavioral;

