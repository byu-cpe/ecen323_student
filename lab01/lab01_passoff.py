#!/usr/bin/python3

# Manages file paths
import pathlib
import sys

# Add lab passoff files
sys.path.append('../resources')
import lab_passoff

###########################################################################
# Global constants
###########################################################################

# lab-specific constants
LAB_NUMBER = 1
SCRIPT_VERSION = 1.0
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

# List of TCL simulation tuples to complete. The organization of each
#  tuple is as follows
# [0]: keyword string in dictionary referrring to tcl file to simulate
# [1]: top-level module name to simulate
# [2]: List of file keywords that referr to HDL sources to include in simulation
tcl_sims = [
	( "updown_tcl", "UpDownButtonCount", [ "updown" ], ),
]

# List of bitstreams to build. Each element of the list is a tuple
#  representing a single bitstream build. The organization of each
#  tuple is as follos
# [0] top module name
# [1] list of xdc filekey names
# [2] list of HDL filekey names
# [3] Boolean: implement bitstream (False will run synthesis only)
# [4] Boolean: create dcp file
build_sets = [
	("UpDownButtonCount",["updown_xdc"], [ "updown",], True, False,),
]

def main():
	''' Main executable for script
	'''

	''' Setup the ArgumentParser '''
	parser = lab_passoff.lab_passoff_argparse(LAB_NUMBER,SCRIPT_VERSION)

	# Parse the arguments
	args = parser.parse_args()

	''' Create lab tester object '''
	lab_test = lab_passoff.lab_test(args, SCRIPT_PATH, LAB_NUMBER)

	# Prepare copy repository
	lab_test.prepare_remote_repo()

	# Set lab files
	lab_test.set_lab_fileset(submission_files,test_files)
	lab_test.check_lab_fileset()

	if not args.notest:

		for tcl_sim in tcl_sims:
			result = lab_passoff.tcl_simulation(lab_test,tcl_sim)

		# Build circuit
		for build_tuple in build_sets:
			result = lab_passoff.build_bitstream(lab_test,build_tuple)

	# Print summarizing messages
	lab_test.print_message_summary()

	lab_test.clean_up_test()


if __name__ == "__main__":
	main()