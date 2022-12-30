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
LAB_NUMBER = 4
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "iterative"       : "fib_iterative.s",
    "recursive"       : "fib_recursive.s",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
}

# TCL simulations

# Testbench simulations

# Bitstream build

# Assembly language Programs
iterative_asm = tester_module.rars_sim_print("iterative")
recursive_asm = tester_module.rars_sim_print("recursive")

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
	lab_test.add_test_module(iterative_asm)
	lab_test.add_test_module(recursive_asm)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()