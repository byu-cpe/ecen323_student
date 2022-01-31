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
LAB_NUMBER = 2
# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()

# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# (relative to the lab directory) of the file to include in the submission.
submission_files = {
	"alu"            	: "alu.sv",
	"alu_tcl"           : "alu_sim.tcl",
	"alu_consts"        : "riscv_alu_constants.sv",
	"calc"        		: "calc.sv",
	"calc_tcl"        	: "calc_sim.tcl",
	"calc_xdc"        	: "calc.xdc",
}

# List of files needed for testing that should be in the repository.
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is the name of the file (relative to the lab directory)
test_files = {
	"oneshot"			: "../lab01/buttoncount/OneShot.sv",
	"tb_alu"			: "tb_alu.sv",
	"tb_calc"			: "tb_calc.sv",
}

# TCL simulations
alu_tcl = tester_module.tcl_simulation2( "alu_tcl", "alu", [ "alu", "alu_consts" ])
calc_tcl = tester_module.tcl_simulation2( "calc_tcl", "calc", [ "calc", "alu",  "alu_consts", "oneshot" ])

# Testbench simulations
alu_tb = tester_module.testbench_simulation( "ALU Testbench", "tb_alu", [ "tb_alu", "alu", "alu_consts" ], [])
calc_tb = tester_module.testbench_simulation( "Calc Testbench", "tb_calc", [ "tb_calc", "calc", "alu", "alu_consts", "oneshot" ], [])

# Bitstream build
bit_build = tester_module.build_bitstream("calc",["calc_xdc"], [ "calc", "alu",  "alu_consts", "oneshot" ], True, False)

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
	lab_test.add_test_module(alu_tcl)
	lab_test.add_test_module(calc_tcl)
	lab_test.add_test_module(alu_tb)
	lab_test.add_test_module(calc_tb)
	lab_test.add_test_module(bit_build)
	# Run tests
	lab_test.run_tests()


if __name__ == "__main__":
	main()