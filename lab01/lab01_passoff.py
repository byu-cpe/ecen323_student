#!/usr/bin/python3

# Manages file paths
import pathlib
import sys

# Add lab passoff files
sys.path.append('../resources')
import lab_passoff
import tester_module

###########################################################################
# Global constants
###########################################################################

# lab-specific constants
LAB_NUMBER = 1
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
	"aboutme"           : "aboutme.txt",
	"updown"            : "UpDownButtonCount.sv",
	"updown_tcl"        : "UpDownButtonCount_sim.tcl",
	"updown_xdc"        : "UpDownButtonCount.xdc",
	"updown_jpg"        : "UpDownButtonCount.jpg",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"oneshot"			: "./buttoncount/OneShot.sv"
}

# TCL simulation
tcl_sim = tester_module.tcl_simulation( "updown_tcl", "UpDownButtonCount", [ "updown", "oneshot" ])

# Bitstream build
bit_build = tester_module.build_bitstream("UpDownButtonCount",["updown_xdc"], [ "updown", "oneshot" ], True, False)

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
	lab_test.add_test_module(tcl_sim)
	lab_test.add_test_module(bit_build)
	# Run tests
	lab_test.run_tests()

if __name__ == "__main__":
	main()