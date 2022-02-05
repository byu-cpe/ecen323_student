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
	"vga"		            : "vga.jpg",
	"buttoncount"		    : "buttoncount.s",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"multicycle_io"		    : "multicycle_iosystem.sv",
	"multicycle"		    : "../lab06/riscv_multicycle.sv",
	"datapathconstants"		: "../lab05/riscv_datapath_constants.sv",
	"datapath"				: "../lab05/riscv_simple_datapath.sv",
	"alu"           		: "../lab02/alu.sv",
	"alu_constants"     	: "../lab02/riscv_alu_constants.sv",
	"regfile"       		: "../lab03/regfile.sv",
}

# TCL simulations

# Testbench simulations

# Synthesis batches

# Bitstream build

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
	print("SCRIPT NOT READY")
	#lab_test.add_test_module(multicycle_nomem_tb)
	#lab_test.add_test_module(multicycle_mem_tb)
	#lab_test.add_test_module(multicycle_build)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()