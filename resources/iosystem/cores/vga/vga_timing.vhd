----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:56:03 02/06/2015 
-- Design Name: 
-- Module Name:    vga_timing - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_timing is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           HS : out  STD_LOGIC;
           VS : out  STD_LOGIC;
           pixel_x : out  STD_LOGIC_VECTOR (9 downto 0);
           pixel_y : out  STD_LOGIC_VECTOR (9 downto 0);
           last_column : out  STD_LOGIC;
           last_row : out  STD_LOGIC;
           blank : out  STD_LOGIC);
end vga_timing;

architecture Behavioral of vga_timing is
	signal pixel_en:std_logic:='0';
	signal x_reg,x_next,y_reg,y_next:unsigned(9 downto 0):=(others=>'0');
begin
-- clock stuff
	process(clk)
	begin
		if (clk'event and clk='1') then
			if(rst = '1') then
				pixel_en<= '0';
				x_reg<=(others=>'0');
				y_reg<=(others=>'0');
			else
				pixel_en <= not pixel_en;
			
				if (pixel_en = '1') then
					x_reg<= x_next;
					y_reg<= y_next;
				end if;
			end if;
		end if;
	end process;
-- next state stuff
	x_next <= (others=>'0') when x_reg = 799 else
				  x_reg + 1;
	y_next <= (others=>'0') when (x_reg = 799)and(y_reg=520) else
				 y_reg+1 when x_reg = 799 else
				 y_reg;
-- output logic stuff
   HS<= '0' when (x_reg>655) and (x_reg<752) else '1';
	VS<= '0' when (y_reg>489) and (y_reg<492) else '1';
	pixel_x<= std_logic_vector(x_reg);
	pixel_y<= std_logic_vector(y_reg);
	last_column<= '1' when (x_reg=639) else '0';
	last_row<= '1' when (y_reg=479) else '0';
	blank<= '0' when ((x_reg<640)and(y_reg<480)) else '1';



end Behavioral;

