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
LAB_NUMBER = 6
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "multicycle"		: "riscv_multicycle.sv",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"tb_multicycle_control"	: "tb_multicycle_control.sv",
    "testbench_inst"       	: "testbench_inst.txt",
    "testbench_data"       	: "testbench_data.txt",
    "datapathconstants"		: "../lab05/riscv_datapath_constants.sv",
    "datapath"				: "../lab05/riscv_simple_datapath.sv",
    "alu"           		: "../lab02/alu.sv",
    "alu_constants"     	: "../lab02/riscv_alu_constants.sv",
    "regfile"       		: "../lab03/regfile.sv",
}

# TCL simulations

# Testbench simulations
multicycle_nomem_tb = tester_module.testbench_simulation( "Multicycle Testbench", \
	"tb_multicycle_control", \
	[ "tb_multicycle_control", "multicycle", "datapath", "alu",  "regfile", "datapathconstants", "alu_constants",   ], [], \
		 include_dirs = ["../lab02","../lab05"])

multicycle_mem_tb = tester_module.testbench_simulation( "Multicycle Testbench", \
	"tb_multicycle_control", \
	[ "tb_multicycle_control", "multicycle", "datapath", "alu",  "regfile", "datapathconstants", "alu_constants",   ], [], \
		 include_dirs = ["../lab02","../lab05"], generics = ["USE_MEMORY=1"])

# Synthesis batches
multicycle_build = tester_module.build_bitstream( "riscv_multicycle", [], 
	[ "multicycle", "datapath", "alu",  "regfile", "datapathconstants", "alu_constants" ], False, False, include_dirs=["../lab02","../lab05"])

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
	lab_test.add_test_module(multicycle_nomem_tb)
	lab_test.add_test_module(multicycle_mem_tb)
	lab_test.add_test_module(multicycle_build)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()