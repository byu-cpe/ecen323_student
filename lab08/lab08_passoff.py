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
LAB_NUMBER = 8
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "pipeline"		: "riscv_basic_pipeline.sv",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"riscv_pipeline_tb"		: "riscv_pipeline_tb.sv",
	"pipeline_nop"			: "pipeline_nop.s",
    "alu"           		: "../lab02/alu.sv",
    "alu_constants"     	: "../lab02/riscv_alu_constants.sv",
    "regfile"       		: "../lab03/regfile.sv",
}

# Assembly
pipeline_nop_mem = tester_module.rars_mem_file("pipeline_nop", generate_data_mem=True)

# TCL simulations

# Testbench simulations
pipeline_tb = tester_module.testbench_simulation( "Pipeline Testbench", \
	"riscv_pipeline_tb", \
	[ "riscv_pipeline_tb", "alu_constants", "alu",  "regfile", "pipeline",   ], [], \
		 include_dirs = ["../lab02", "../include"], )

# Synthesis batches
pipeline_build = tester_module.build_bitstream( "riscv_basic_pipeline", [], 
	[ "alu_constants", "alu",  "regfile", "pipeline", ], False, False, \
		include_dirs=["../lab02", "../include"])

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
	lab_test.add_test_module(pipeline_nop_mem)
	lab_test.add_test_module(pipeline_tb)
	lab_test.add_test_module(pipeline_build)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()