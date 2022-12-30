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
LAB_NUMBER = 11
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "final"		: "riscv_final.sv",
	"fib"		: "fib.s",
}
test_files = {
	"riscv_final_tb"		: "riscv_final_tb.sv",
	"final_asm"				: "final.s",
    "alu"           		: "../lab02/alu.sv",
    "alu_constants"     	: "../lab02/riscv_alu_constants.sv",
    "regfile"       		: "../lab03/regfile.sv",
}

# Assembly
final_mem = tester_module.rars_mem_file("final_asm", generate_data_mem=True)
fib_mem = tester_module.rars_mem_file("fib", generate_data_mem=True)

# Testbench simulations
final_tb = tester_module.testbench_simulation( "Final Testbench", \
	"riscv_final_tb", \
	[ "riscv_final_tb", "alu_constants", "alu",  "regfile", "final",   ], [], \
		 include_dirs = ["../lab02", "../include"], )

fib_tb = tester_module.testbench_simulation( "Final Testbench", \
	"riscv_final_tb", \
	[ "riscv_final_tb", "alu_constants", "alu",  "regfile", "final",   ], [], \
		 include_dirs = ["../lab02", "../include"],
		 generics = ["TEXT_MEMORY_FILENAME=fib_text.mem", \
		"DATA_MEMORY_FILENAME=fib_data.mem"])

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
	lab_test.add_test_module(final_mem)
	lab_test.add_test_module(fib_mem)
	lab_test.add_test_module(final_tb)
	lab_test.add_test_module(fib_tb)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()
