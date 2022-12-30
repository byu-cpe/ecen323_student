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
LAB_NUMBER = 10
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "vga_jpg"		: "vga.jpg",
	"vga_tcl"		: "vga_sim_new.tcl",
	"move_char"		: "move_char.s",
}

sv_files = {
	"forwarding_io"		    : "forwarding_iosystem.sv",
	"forwarding"		    : "../lab09/riscv_forwarding_pipeline.sv",
	"alu"           		: "../lab02/alu.sv",
	"alu_constants"     	: "../lab02/riscv_alu_constants.sv",
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
# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"forwarding_asm"		: "forwarding_iosystem.s",
    "xdc"           		: "../resources/iosystem/iosystem.xdc",
}
test_files.update(sv_files)
test_files.update(vhdl_files)

# Assembly
forwarding_mem = tester_module.rars_mem_file("forwarding_asm", generate_data_mem=True)
move_char_mem = tester_module.rars_mem_file("move_char", generate_data_mem=True)

# TCL simulations
forwarding_tcl = tester_module.tcl_simulation2( "vga_tcl", "forwarding_iosystem", \
	sv_files, include_dirs = ["../lab02", "../lab05", "../include"], \
	vhdl_files=vhdl_files,use_glbl=True, \
	generics = ["TEXT_MEMORY_FILENAME=forwarding_iosystem_text.mem", \
		"DATA_MEMORY_FILENAME=forwarding_iosystem_data.mem"])

# Bitstream build
hdl_files = [ "alu", "regfile", "forwarding", 
	"bramMacro", "tx", "rx", "debounce", "SevenSegmentControl4", "riscv_mem", "io_clocks",
	"iosystem",
	"forwarding_io" ]
vhdl_keys = ["vga_timing","font_rom","charmem","charGen3","vga_ctl3"]
#vhdl_sources = []
#for vhdl_file in vhdl_files.values():
#	vhdl_sources.append(vhdl_file)

forwarding_bit = tester_module.build_bitstream( "forwarding_iosystem",["xdc"],hdl_files, implement_build =True, 
	create_dcp = True, include_dirs = ["../lab02", "../include"],
	vhdl_key_list = vhdl_keys,
	generics = ["TEXT_MEMORY_FILENAME=buttoncount_text.mem",
	"DATA_MEMORY_FILENAME=forwarding_iosystem_data.mem"])

# Update bitfile
copy_char_bit = tester_module.update_bitstream_mem( "move_char_text.mem", "move_char_data.mem", 
	"forwarding_iosystem.dcp","move_char.bit")

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
	lab_test.add_test_module(forwarding_mem)
	lab_test.add_test_module(move_char_mem)
	lab_test.add_test_module(forwarding_tcl)
	lab_test.add_test_module(forwarding_bit)
	lab_test.add_test_module(copy_char_bit)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()
