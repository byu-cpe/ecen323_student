#!/usr/bin/python3
'''
Script for running the openocd bitstream programming executable without
having to create a script for each bitfile.
'''

# Command line argunent parser
import argparse



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
	lab_test.add_test_module(iosystem_mem)
	lab_test.add_test_module(buttoncount_mem)
	lab_test.add_test_module(iosystem_tcl)
	lab_test.add_test_module(buttoncount_tcl)
	lab_test.add_test_module(buttoncount_bit)

	# Run tests
	lab_test.run_tests()

if __name__ == "__main__":
	main()