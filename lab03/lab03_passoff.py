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
LAB_NUMBER = 3
SCRIPT_VERSION = 1.0
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
    "regfile"       : "regfile.sv",
    "alu"           : "../lab02/alu.sv",
    "constants"     : "../lab02/riscv_alu_constants.sv",
    "top"           : "regfile_top.sv",
    "xdc"           : "regfile_top.xdc",
    "regfile_tcl"   : "regfile_sim.tcl",
    "top_tcl"       : "regfile_top_sim.tcl",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"oneshot"			: "../lab01/buttoncount/OneShot.sv",
	"tb_regfile"		: "tb_regfile.sv",
	"tb_regfile_top"	: "tb_regfile_top.sv",
}

# TCL simulations
regfile_tcl = tester_module.tcl_simulation2( "regfile_tcl", "regfile", [ "regfile",])
top_tcl = tester_module.tcl_simulation2( "top_tcl", "regfile_top", [ "constants", "oneshot", "alu", "regfile", "top", "oneshot" ])

# Testbench simulations
regfile_tb = tester_module.testbench_simulation( "Regfile Testbench", "tb_regfile", [ "tb_regfile", "regfile",], [])
top_tb = tester_module.testbench_simulation( "Regfile Top Testbench", "tb_regfile_top", [ "tb_regfile_top", "regfile", "alu", "constants", "oneshot" ], [])

# Bitstream build
bit_build = tester_module.build_bitstream("regfile_top",["xdc"], [ "constants", "alu", "oneshot", "regfile", "top" ], True, False)

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
	lab_test.add_test_module(regfile_tcl)
	lab_test.add_test_module(top_tcl)
	lab_test.add_test_module(regfile_tb)
	lab_test.add_test_module(top_tb)
	lab_test.add_test_module(bit_build)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()