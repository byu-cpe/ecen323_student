--------------------------------------------------------------------------
--
-- VGA Color and Character Memory
--
-- This memory can store 128x32 characters (4096) where each character is
-- 32 bits. 
--
-- The 32 bits of each character are organized as follows:
--    7:0 - Actual ASCII character
--   19:8 - Foreground color (12 bits)
--  31:20 - Background color (12 bits)
--
-- The size of the memory is 4096x32 bits or 16384 bytes (four block rams).
-- 14 address bits are needed to address the memory (byte addressable).
-- The address space is 0x0000 to 0x3fff (byte addressable). This module
-- is word addressable and as such, only 12 bits addresses are used.
--
-- The memory is dual ported providing two ports for reading the characters 
-- (one to be read by the VGA controller
-- and another for reading by a processor). This allows you to operate
-- the VGA at the same time you read the character data.
-- 
--  the 'char_read_addr' is used for reading the 'char_read_value'
--  the 'char_read_addr2' is used for writing and for reading 'char_read_value2'
--
-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity charColorMem3BRAM is
   port(
      clk_vga: in std_logic;
      clk_data: in std_logic;
      data_addr : in std_logic_vector(11 downto 0);
      vga_addr: in std_logic_vector(11 downto 0);
      data_we : in std_logic;
      data_write_value : in std_logic_vector(31 downto 0);
      data_read_value : out std_logic_vector(31 downto 0);
      vga_read_value : out std_logic_vector(31 downto 0)
   );
end charColorMem3BRAM;

architecture arch of charColorMem3BRAM is

    component  bramMacro is
    port (
        clka : in std_logic;
        clkb : in std_logic;
        a_addr : in std_logic_vector(11 downto 0);
        b_addr : in std_logic_vector(11 downto 0);
        a_we : in std_logic;
        a_din : in std_logic_vector(7 downto 0);
        a_dout : out std_logic_vector(7 downto 0);
        b_dout : out std_logic_vector(7 downto 0)
    );
    end component;


begin

    BRAM_inst_0 : bramMacro
    port map(
        clka => clk_data,
        clkb => clk_vga,
        a_addr => data_addr,
        b_addr => vga_addr,
        a_we => data_we,
        a_din => data_write_value(7 downto 0),
        a_dout=> data_read_value(7 downto 0),
        b_dout => vga_read_value(7 downto 0)
    );

    BRAM_inst_1 : bramMacro
    port map(
        clka => clk_data,
        clkb => clk_vga,
        a_addr => data_addr,
        b_addr => vga_addr,
        a_we => data_we,
        a_din => data_write_value(15 downto 8),
        a_dout=> data_read_value(15 downto 8),
        b_dout => vga_read_value(15 downto 8)
    );

    BRAM_inst_2 : bramMacro
    port map(
        clka => clk_data,
        clkb => clk_vga,
        a_addr => data_addr,
        b_addr => vga_addr,
        a_we => data_we,
        a_din => data_write_value(23 downto 16),
        a_dout=> data_read_value(23 downto 16),
        b_dout => vga_read_value(23 downto 16)
    );

    BRAM_inst_3 : bramMacro
    port map(
        clka => clk_data,
        clkb => clk_vga,
        a_addr => data_addr,
        b_addr => vga_addr,
        a_we => data_we,
        a_din => data_write_value(31 downto 24),
        a_dout=> data_read_value(31 downto 24),
        b_dout => vga_read_value(31 downto 24)
    );



--   -- Data clock domain
--   process(clk_data)
--   begin
--     if (clk_data'event and clk_data='1') then
--       if (data_we = '1') then
--         char_ram(to_integer(unsigned(data_addr))) <= data_write_value;
--       end if;
--       read_a <= data_addr;
--    end if;
--   end process;
--   data_read_value <= char_ram(to_integer(unsigned(read_a)));  

--   process(clk_vga)
--   begin
--     if (clk_vga'event and clk_vga='1') then
--       read_b <= vga_addr;
--    end if;
--   end process;
--   vga_read_value <= char_ram(to_integer(unsigned(read_b)));

end arch;

