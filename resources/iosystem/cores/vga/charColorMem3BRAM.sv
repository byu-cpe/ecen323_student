/****************************************************************************

 VGA Color and Character Memory

 This memory can store characters for a 128x32 character display
 (128 columns and 32 rows) for a total of 4096 characters.
 Each character is specified as 32 bits as shown described below: 

    7:0 - Actual ASCII character
   19:8 - Foreground color (12 bits)
  31:20 - Background color (12 bits)

 The size required to store 128x32 (4096 characters x 32 bits each) 
 is 16384 bytes (four block rams). 12-bits are needed to address the
 4096 characters in the memory. Bits [6:0] (7 bits) indicate the column
 of the character and bits [11:7] (5 bits) indicate the rolw of the character. 
 The address space is 0x0000 to 0x3fff (byte addressable). This module
 is word addressable and as such, only 12 bits addresses are used.
 

 Each block ram is organized as 4096x8 bits and the four block rams each
 provide one byte of the 32-bit character address (BRAM 0 provides byte
 0, BRAM 1 provies byte1, and so on).


 The memory is dual ported providing two ports for reading the characters 
 (one to be read by the VGA controller
 and another for reading by a processor). This allows you to operate
 the VGA at the same time you read the character data.
 
  the 'char_read_addr' is used for reading the 'char_read_value'
  the 'char_read_addr2' is used for writing and for reading 'char_read_value2'

 
****************************************************************************/

module charColorMem3BRAM(clk_vga,clk_data,data_addr,vga_addr,data_we,data_write_value,data_read_value,vga_read_value);
    input logic clk_vga;
    input logic clk_data;
    input logic [11:0] data_addr;
    input logic [11:0] vga_addr;
    input logic data_we;
    input logic [31:0] data_write_value;
    output logic [31:0] data_read_value;
    output logic [31:0] vga_read_value;
      
    // BRAM0: Byte 0 (bits 7:0)
    bramMacro BRAM_inst_0 (.clka(clk_data), .clkb(clk_vga), .a_addr(data_addr), .b_addr(vga_addr),
        .a_we(data_we), .a_din(data_write_value[7:0]),.a_dout(data_read_value[7:0]),.b_dout(vga_read_value[7:0]));

    // BRAM1: Byte 1 (bits 15:8)
    bramMacro BRAM_inst_1 (.clka(clk_data), .clkb(clk_vga), .a_addr(data_addr), .b_addr(vga_addr),
        .a_we(data_we), .a_din(data_write_value[15:8]),.a_dout(data_read_value[15:8]),.b_dout(vga_read_value[15:8]));

    // BRAM2: Byte 2 (bits 23:16)
    bramMacro BRAM_inst_2 (.clka(clk_data), .clkb(clk_vga), .a_addr(data_addr), .b_addr(vga_addr),
        .a_we(data_we), .a_din(data_write_value[23:16]),.a_dout(data_read_value[23:16]),.b_dout(vga_read_value[23:16]));

    // BRAM3: Byte 3 (bits 31:24)
    bramMacro BRAM_inst_3 (.clka(clk_data), .clkb(clk_vga), .a_addr(data_addr), .b_addr(vga_addr),
        .a_we(data_we), .a_din(data_write_value[31:24]),.a_dout(data_read_value[31:24]),.b_dout(vga_read_value[31:24]));

endmodule

