///////////////////////////////////////////////////////////////////////////
// 
// bramMacro.v
//
// Macro for BRAM module instantiation (reduce ports)
//
///////////////////////////////////////////////////////////////////////////

module bramMacro (clka, clkb, a_addr,b_addr,a_we,a_din,a_dout,b_dout);

  input wire clka;
  input wire clkb;
  input [11:0] a_addr;
  input [11:0] b_addr;
  input a_we;
  input [7:0] a_din;
  output reg [7:0] a_dout;
  output reg [7:0] b_dout;

    /*
  wire [15:0] a_addr_i, b_addr_i;
  wire [31:0] a_din_i;
  assign a_addr_i = {1'b1,a_addr,3'h0};
  assign b_addr_i = {1'b1,b_addr,3'h0};
  assign a_din_i = {24'h0,a_din};
  reg [31:0] a_dout_i, b_dout_i;
  assign a_dout = a_dout_i[7:0];
  assign b_dout = b_dout_i[7:0];
  wire [3:0] a_we_i;
  assign a_we_i = {3'b000,a_we};
  */

  reg [7:0] myram [4096]; 

  always @(posedge clka) begin
    if (a_we)
      myram[a_addr] <= a_din;
      a_dout <= myram[a_addr];
  end
  
  always @(posedge clkb)
    b_dout <= myram[b_addr];
  
  /*
  // Instance bram module
  RAMB36E1 bram(
          .DOADO(a_dout_i),
          .DOBDO(b_dout_i),
          .CASCADEINA(1'b1),
          .CASCADEINB(1'b1),
          .ADDRARDADDR(a_addr_i),
          .ADDRBWRADDR(b_addr_i),
          .CLKARDCLK(clka),
          .CLKBWRCLK(clkb),
          .DIADI(a_din_i),
          .DIBDI(32'h0),
          .DIPADIP(4'h0),
          .DIPBDIP(4'h0),
          .ENARDEN(1'b1),
          .ENBWREN(1'b1),
          .INJECTDBITERR(1'b0),
          .INJECTSBITERR(1'b0),
          .REGCEAREGCE(1'b0),
          .REGCEB(1'b0),
          .RSTRAMARSTRAM(1'b0),
          .RSTRAMB(1'b0),
          .RSTREGARSTREG(1'b0),
          .RSTREGB(1'b0),
          .WEA(a_we_i),
          .WEBWE(8'b0)
        );

    defparam bram.READ_WIDTH_A = 9;
    defparam bram.READ_WIDTH_B = 9;
    defparam bram.WRITE_WIDTH_A = 9;
    defparam bram.WRITE_WIDTH_B = 9;
    defparam bram.RAM_MODE = "TDP";
    defparam bram.DOA_REG = 0;
    defparam bram.DOB_REG = 0;

  */

  /*
  // Instance bram module
  RAMB36E1 bram(
          .DOADO(a_dout_i),
          .DOBDO(b_dout_i),
          .CASCADEINA(1'b1),
          .CASCADEINB(1'b1),
          .ADDRARDADDR(a_addr_i),
          .ADDRBWRADDR(b_addr_i),
          .CLKARDCLK(clka),
          .CLKBWRCLK(clkb),
          .DIADI(a_din_i),
          .DIBDI(32'h0),
          .DIPADIP(4'h0),
          .DIPBDIP(4'h0),
          .ENARDEN(1'b1),
          .ENBWREN(1'b1),
          .INJECTDBITERR(1'b0),
          .INJECTSBITERR(1'b0),
          .REGCEAREGCE(1'b0),
          .REGCEB(1'b0),
          .RSTRAMARSTRAM(1'b0),
          .RSTRAMB(1'b0),
          .RSTREGARSTREG(1'b0),
          .RSTREGB(1'b0),
          .WEA(a_we_i),
          .WEBWE(8'b0)
        );

    defparam bram.READ_WIDTH_A = 9;
    defparam bram.READ_WIDTH_B = 9;
    defparam bram.WRITE_WIDTH_A = 9;
    defparam bram.WRITE_WIDTH_B = 9;
    defparam bram.RAM_MODE = "TDP";
    defparam bram.DOA_REG = 0;
    defparam bram.DOB_REG = 0;
*/
endmodule
