----------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vga_ctl3 is
    Port ( 
		clk_vga : in STD_LOGIC;
		clk_data : in STD_LOGIC;
        rst : in STD_LOGIC;
        char_we : in STD_LOGIC;
        char_value : in  STD_LOGIC_VECTOR (31 downto 0);
        char_addr : in  STD_LOGIC_VECTOR (11 downto 0);
		custom_foreground : in std_logic;
		foreground_rgb : in  STD_LOGIC_VECTOR (11 downto 0);
		background_rgb : in  STD_LOGIC_VECTOR (11 downto 0);
		char_read : out std_logic_vector(31 downto 0);
        VGA_HS : out  STD_LOGIC;
        VGA_VS : out  STD_LOGIC;
        VGA_R : out  STD_LOGIC_VECTOR (3 downto 0);
        VGA_G : out  STD_LOGIC_VECTOR (3 downto 0);
        VGA_B : out  STD_LOGIC_VECTOR (3 downto 0)
        );
end vga_ctl3;

architecture Behavioral of vga_ctl3 is

	signal pixel_x,pixel_y: std_logic_vector(9 downto 0);
	--signal RGB: std_logic_vector(11 downto 0);
	signal hs,vs,blank : std_logic;
	signal pixel_out : std_logic_Vector(11 downto 0);
	signal vs_d,hs_d,vs_d2,hs_d2 : std_logic;
	signal blank_d,blank_d2 : std_logic;
	signal char_data_to_write : std_logic_Vector(31 downto 0);
    attribute dont_touch : string;
    attribute dont_touch of char_data_to_write : signal is "true";
begin

	-- Mux to select which char data is written: the default data with a fixed foreground and background or
	-- custom, character specific color data.
	--char_data_to_write <= char_value when custom_foreground = '1' else background_rgb & foreground_rgb & char_value(7 downto 0);
	-- char_data_to_write <= 
    --     char_value when char_value(7) = '1' else 
    --         -- The double use of char_value(6) is to try and trick the synthesis tool into
    --         -- thinking the bit is actually used. 
    --         --background_rgb & foreground_rgb &  char_value(6) & char_value(6 downto 0);
    --         background_rgb & foreground_rgb &  '1' & char_value(6 downto 0);
    char_data_to_write <= 
        background_rgb & foreground_rgb &  '0' & char_value(6 downto 0) 
            when char_value(31 downto 8) = X"000000" else
            char_value;
        
	charGen : entity work.charGen3
		port map(
			clk_vga => clk_vga,
            clk_data => clk_data,
			char_value=> char_data_to_write,
            char_we => char_we,
            data_addr => char_addr,
			pixel_x => pixel_x,
			pixel_y => pixel_y,
            data_read_value => char_read,
			pixel_out => pixel_out);

            
	vga_timing: entity work.vga_timing
		port map(
		clk => clk_vga,
		rst => rst,
		HS => hs,
		VS => vs,
		pixel_x => pixel_x,
		pixel_y => pixel_y,
		last_column => open,
		last_row => open,
		blank => blank);
    
	process (rst,clk_vga)
    begin
        if(rst='1') then
            --nothing for now
            vs_d<='0';
            hs_d<='0';
            vs_d2 <= '0';
            hs_d2<='0';
            blank_d<='0';
            blank_d2 <= '0';
        elsif(clk_vga'event and clk_vga ='1') then
            -- regs;
            vs_d <= vs;
            hs_d <= hs;
            vs_d2 <= vs_d;
            hs_d2 <= hs_d;
            blank_d <= blank;
            blank_d2 <= blank_d;
        end if;
    end process;
        
-----outputs
    --RGB <= background_rgb when pixel_out = '0' else foreground_rgb;
    VGA_HS <= hs_d2;
    VGA_VS <= vs_d2;
    VGA_R <= pixel_out(11 downto 8) when blank_d2 ='0' else (others=>'0');
    VGA_G <= pixel_out(7 downto 4) when blank_d2 ='0' else (others=>'0');
    VGA_B <= pixel_out(3 downto 0) when blank_d2 ='0' else (others=>'0');   

end Behavioral;
