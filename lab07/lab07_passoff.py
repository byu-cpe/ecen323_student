#!/usr/bin/python3

# Manages file paths
import pathlib
import sys

# Add lab passoff files
resources_path = pathlib.Path(__file__).resolve().parent.parent  / 'resources'
sys.path.append( str(resources_path) )
#sys.path.append('../resources')
import lab_passoff
import tester_module

###########################################################################
# Global constants
###########################################################################

# lab-specific constants
LAB_NUMBER = 7
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
	"multicycle_io_tcl"		: "iosystem.tcl",
	"buttoncount_asm"		: "buttoncount.s",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
sv_files = {
	"multicycle_io"		    : "multicycle_iosystem.sv",
	"multicycle"		    : "../lab06/riscv_multicycle.sv",
	"datapathconstants"		: "../include/riscv_datapath_constants.sv",
	"datapath"				: "../lab05/riscv_simple_datapath.sv",
	"alu"           		: "../lab02/alu.sv",
	"alu_constants"     	: "../include/riscv_alu_constants.sv",
	"regfile"       		: "../lab03/regfile.sv",
	"iosystem"				: "../resources/iosystem/iosystem.sv",
	"io_clocks" 			: "../resources/iosystem/io_clocks.sv",
	"riscv_mem"				: "../resources/iosystem/riscv_mem.sv",
	"SevenSegmentControl4" 	: "../resources/iosystem/cores/SevenSegmentControl4.sv",
	"debounce" 				: "../resources/iosystem/cores/debounce.sv",
	"rx" 					: "../resources/iosystem/cores/rx.sv",
	"tx" 					: "../resources/iosystem/cores/tx.sv",
	"bramMacro" 			: "../resources/iosystem/cores/vga/bramMacro.v",
	"glbl"					: "../resources/glbl.v",
}
vhdl_files = {
	# Compile order matters here
	"vga_timing" 			: "../resources/iosystem/cores/vga/vga_timing.vhd",
	"font_rom" 				: "../resources/iosystem/cores/vga/list_ch13_01_font_rom.vhd",
	"charmem" 				: "../resources/iosystem/cores/vga/charColorMem3BRAM.vhd",
	"charGen3" 				: "../resources/iosystem/cores/vga/charGen3.vhd",
	"vga_ctl3" 				: "../resources/iosystem/cores/vga/vga_ctl3.vhd",
}
test_files = {
	"iosystem_asm"		: "multicycle_iosystem.s",
	"buttoncount_tcl"	: "buttoncount.tcl",
    "xdc"           	: "../resources/iosystem/iosystem.xdc",
	"tb_multicycle_io"	: "tb_multicycle_io.sv"
}
test_files.update(sv_files)
test_files.update(vhdl_files)

# Assembly language tasks
iosystem_mem = tester_module.rars_mem_file("iosystem_asm")
buttoncount_mem = tester_module.rars_mem_file("buttoncount_asm")

# TCL simulations (These are only necessary to demonstrate that the simulation builds - no checks are made)
iosystem_tcl = tester_module.tcl_simulation( "multicycle_io_tcl", "multicycle_iosystem", \
	sv_files, include_dirs = ["../include" ],vhdl_files=vhdl_files,use_glbl=True, \
	generics = ["TEXT_MEMORY_FILENAME=multicycle_iosystem_text.mem"])

buttoncount_tcl = tester_module.tcl_simulation( "buttoncount_tcl", "multicycle_iosystem", \
	sv_files, include_dirs = ["../include"],vhdl_files=vhdl_files,use_glbl=True, \
	generics = ["TEXT_MEMORY_FILENAME=buttoncount_text.mem"])

hdl_files = [ "alu", "datapath", "regfile", "multicycle", 
	"bramMacro", "tx", "rx", "debounce", "SevenSegmentControl4", "riscv_mem", "io_clocks",
	"iosystem", "multicycle_io" ]
vhdl_keys = ["vga_timing","font_rom","charmem","charGen3","vga_ctl3"]

# Testbench simulation
tb_hdl_files = hdl_files.copy()
tb_hdl_files.extend(["tb_multicycle_io" ,"glbl"])
multicycle_io_tb = tester_module.testbench_simulation( "Multicycle I/O Testbench", "tb_multicycle_io", \
		tb_hdl_files, [], include_dirs = ["../include"],vhdl_files = vhdl_keys, use_glbl=True )

# Bitstream build
buttoncount_bit = tester_module.build_bitstream( "multicycle_iosystem",["xdc"],hdl_files, implement_build =True, 
	create_dcp = False, include_dirs = ["../include"],vhdl_key_list = vhdl_keys,
	generics = ["TEXT_MEMORY_FILENAME=buttoncount_text.mem"])

def main():
	''' Main executable for script
	'''

	# Create lab tester object
	lab_test = lab_passoff.lab_test(SCRIPT_PATH, LAB_NUMBER)
	# Parse arguments
	lab_test.parse_args()
	# Prepare test
	lab_test.prepare_test(submission_files,test_files)
	# Add tests
	lab_test.add_test_module(iosystem_mem)			# Assemmble multicycle_iosystem.s
	lab_test.add_test_module(buttoncount_mem)		# Assemble buttoncount.s (student code)
	lab_test.add_test_module(iosystem_tcl)			# TCL simulation of multicycle_iosystem using student's iosystem.tcl file
	lab_test.add_test_module(multicycle_io_tb)		# Run testbench simulation of multicycle_iosystem
	lab_test.add_test_module(buttoncount_tcl)		# TCL simulation using given buttoncount.tcl file
	lab_test.add_test_module(buttoncount_bit)		# Final bitstream generation (this is the only bitstream tested)

	# Add ending message to remind students to test their bitfiles
	message = []
	message.append('')
	message.append('='*80)
	message.append("NOTE: You should test the bitfile generated by this passoff script.")
	message.append("      The TAs will test your generated bitstream and any problems")
	message.append("      with the functionality of your design will result in a significant")
	message.append("      penatly in this lab.")
	message.append('='*80)
	message.append('')
	lab_test.final_messages = message

	# Run tests
	lab_test.run_tests()

if __name__ == "__main__":
	main()