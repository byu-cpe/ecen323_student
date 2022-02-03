///////////////////////////////////////////////////////////////////////////////////////////////
// 
// multicycle_io_system.sv
//
// Top-level I/O system for multicycle RISC-V processor. 
//
///////////////////////////////////////////////////////////////////////////////////////////////

module multicycle_iosystem (clk, btnc, btnd, btnl, btnr, btnu, sw, led,
    an, seg, dp, RsRx, RsTx, vgaBlue, vgaGreen, vgaRed, Hsync, Vsync);

	// Top-level ports
	input logic clk;
	input logic btnc;
	input logic btnd;
	input logic btnl;
	input logic btnr;
	input logic btnu;
	input [15:0]sw;
	output [15:0]led;
	output [3:0]an;
	output [6:0]seg;
    output logic dp;
	output logic RsRx;
	input logic RsTx;
	output [3:0]vgaRed;
	output [3:0]vgaBlue;
	output [3:0]vgaGreen;
	output logic Hsync;
	output logic Vsync;

    // Top-level Parameters
	//parameter INPUT_CLOCK_RATE = 100000000;
    //parameter PROC_CLK_DIVIDE = 3;
	parameter TEXT_START_ADDRESS = 32'h00000000; 
	parameter DATA_START_ADDRESS = 32'h00002000;

    // Module Signals
    logic clk_proc, clk_vga, rst;
    logic [31:0] PC, instruction, dAddress, dReadData, dWriteData, WriteBackData;
    logic dMemRead, dMemWrite;

    // Clocking Module
    io_clocks clocks (.clk_in(clk), .reset_out(rst), .clk_proc(clk_proc), .clk_vga(clk_vga));

    // Processor
    logic [31:0] wb_data_read; // mux between dReadDAta and i/o
    riscv_multicycle #(.INITIAL_PC(TEXT_START_ADDRESS)) riscv (
        .clk(clk_proc), .rst(rst), .PC(PC), .instruction(instruction), 
        .dAddress(dAddress), .dReadData(wb_data_read), .dWriteData(dWriteData), 
        .MemRead(dMemRead), .MemWrite(dMemWrite), .WriteBackData(WriteBackData)
	);

    // Memories
    logic iMemRead = 1;  // Always read instruction memory
    riscv_mem mem (.clk(clk), .rst(rst), .PC(PC), .iMemRead(iMemRead), .instruction(instruction),
        .dAddress(dAddress), .MemWrite(dMemWrite), .dWriteData(dWriteData), .dReadData(dReadData) );

    // I/O Sub-system
    iosystem iosystem (
        // Clock and reset ports
        .clk(clk_proc), .clkvga(clk_vga), .rst(rst), 
        // Processor bus interface
        .address(), .MemWrite(), .MemRead(), .io_memory_read(), .io_memory_write(), .valid_io_read(),
        // Top-level ports
        .btnc(btnc), .btnd(btnd), .btnl(btnl), .btnr(btnr), .btnu(btnu), .sw(sw), 
        .led(led), .an(an), .seg(seg), .dp(dp), .RsRx(RsRx), .RsTx(RsTx), .vgaBlue(vgaBlue),
        .vgaGreen(vgaGreen), .vgaRed(vgaRed), .Hsync(Hsync), .Vsync(Vsync));

endmodule