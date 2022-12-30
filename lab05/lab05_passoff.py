#!/usr/bin/python3

# Manages file paths
import pathlib
import sys

# Add lab passoff files
resources_path = pathlib.Path(__file__).resolve().parent.parent  / 'resources'
sys.path.append( str(resources_path) )
import lab_passoff
import tester_module

###########################################################################
# Global constants
###########################################################################

# lab-specific constants
LAB_NUMBER = 5
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "datapathconstants"		: "riscv_datapath_constants.sv",
    "datapath"				: "riscv_simple_datapath.sv",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"tb_simple_datapath"	: "tb_simple_datapath.sv",
    "alu"           		: "../lab02/alu.sv",
    "alu_constants"     	: "../lab02/riscv_alu_constants.sv",
    "regfile"       		: "../lab03/regfile.sv",
}

# TCL simulations

# Testbench simulations
regfile_tb = tester_module.testbench_simulation( "Datapath Testbench", \
	"tb_simple_datapath", \
	[ "tb_simple_datapath", "datapath","alu",  "regfile", "datapathconstants", "alu_constants",   ], [], include_dirs = ["../lab02"])

# Synthesis batches
datapath_build = tester_module.build_bitstream( "riscv_simple_datapath", [], 
	[ "datapath", "alu",  "regfile", "datapathconstants", "alu_constants" ], False, False, include_dirs=["../lab02"])

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
	lab_test.add_test_module(regfile_tb)
	lab_test.add_test_module(datapath_build)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()