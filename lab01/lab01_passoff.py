#!/usr/bin/python3

'''
Script for extracting a student submission from a GitHub repository and
checking the submission.

TODO:
- Checkout the starter code if it doesn't exist (or give a flag to the student code repository) and
  run the scripts from the known good repository.
- Does script fail if the tag doesn't exist? Need to test
'''

# Manages file paths
import pathlib
# Command line argunent parser
import argparse
# Get the username of the current user
import getpass
# Shell utilities for copying, 
import shutil
import subprocess
import sys
import re
# For os.remove
import os
# for File IO status flags
import stat
# for serialization
import pickle
# for time delay
import time

# Add global resources directory to Python system path
sys.path.append('../resources')
import lab_passoff

###########################################################################
# Global constants
###########################################################################

# lab-specific constants
LAB_NUMBER = 1
SCRIPT_VERSION = 1.0

# lab independent constants
DEFAULT_EXTRACT_DIR = "passoff_temp_dir"
TEST_RESULT_FILENAME = str.format("lab{}_test_result.txt",LAB_NUMBER)
STARTER_CODE_REPO = "git@github.com:byu-cpe/ecen323_student.git"
LAB_DIR_NAME = str.format("lab{:02d}",LAB_NUMBER)

BASYS3_PART = "xc7a35tcpg236-1"
JAR_FILENAME = "rars1_4.jar"
JAR_URL = "https://github.com/TheThirdOne/rars/releases/download/v1.4/rars1_4.jar"
LAB_TAG_STRING = str.format("lab{}_submission",LAB_NUMBER)
TEST_RESULT_FILENAME = str.format("lab{}_test_result.txt",LAB_NUMBER)
# The filename of the commit string relative to the current lab
COMMIT_STRING_FILENAME = ".commitdate"
# Filename of the project settings tcl script
NEW_PROJECT_SETTINGS_FILENAME = "../resources/new_project_settings.tcl"

# Path of script that is being run
SCRIPT_PATH = pathlib.Path(__file__).absolute().parent.resolve()
# Path of current directory when script is run
RUN_PATH = os.environ['PWD']

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
}

# The union of both file lists
all_files = submission_files.copy()
all_files.update(test_files)

# List of TCL simulation tuples to complete. The organization of each
#  tuple is as follows
# [0]: keyword string in dictionary referrring to tcl file to simulate
# [1]: top-level module name to simulate
# [2]: List of file keywords that referr to HDL sources to include in simulation
tcl_sims = [
	( "updown_tcl", "UpDownButtonCount", [ "updown" ], ),
]

# List of Testbench simulations to complete
# [1] module name
# [0] Description of simulation
# [2] list of files to include (key names)
# [3] xelab options
testbench_sims = [
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

# List of list of assembly sets
# [0] key name for assembly file in submission files
# [1] list of options to give to RARS for the simulation
# [2] Boolean: generate .txt instruction and .data files
# [3] Boolean: Run simulator
assembly_simulate_sets = [
]


# DCP Modification sets
# [0] Name of new bitfile
# [1] original dcp filename
# [2] keyname for assembly file ("" for none)
# [3] font file keyname ("" for none)
# [4] background file keyname ("" for none)
bitfile_dcp_mods = [
]

def get_filename_from_key(file_key):
	''' Returns the filename associated with a file key that is located either in
		the submission_files dictionary or the test_files dictionary.
	'''
	if file_key in submission_files:
		return submission_files[file_key]
	elif file_key in test_files:
		return test_files[file_key]
	# Isn't in either dictionary. Return None
	return None
	
def get_filepath_from_key(file_key):
	'''
	Creates a Path object for a file that is referenced from its "key" in either
	the submissions dictionary or test_files dictionary.
		file_key : str
			The key string that corresponds to an entry in the "submission" files
			or test files. Does not correspond to an actual file name.
	'''
	# Get the filename
	filename = get_filename_from_key(file_key)
	if not filename:
		return None
	# Create the Path and return
	return SCRIPT_PATH / filename


def main():
	''' Main executable for script
	'''

	''' Setup the ArgumentParser '''
	parser = lab_passoff.lab_passoff_argparse(LAB_NUMBER, DEFAULT_EXTRACT_DIR, SCRIPT_VERSION)

	# Parse the arguments
	args = parser.parse_args()

	''' Set run time variables and argument variables
	'''
	# This is the path of location where the repository was extracted
	student_extract_repo_dir = SCRIPT_PATH / args.extract_dir
	# This is the path of lab within the extracted repository where the lab exists
	# and where the executables wil run
	student_extract_lab_dir = student_extract_repo_dir / LAB_DIR_NAME

	lab_test = lab_passoff.lab_test()

	''' Determine remote repository
	'''
	if args.git_repo:
		student_git_repo = args.git_repo
	else:
		# Determine the current repo
		student_git_repo = lab_test.determine_current_repo(SCRIPT_PATH)
		if not student_git_repo:
			lab_test.print_error("git config failed")
			return False

	''' Clone Repository. When done, the 'student_repo_dir' variable will be set.
	'''
	# See if directory exists
	if student_extract_repo_dir.exists():
		if args.force:
			print( "Target directory",student_extract_repo_dir,"exists. Will be deleted before proceeding")
			shutil.rmtree(student_extract_repo_dir, ignore_errors=True)
		else:
			lab_test.print_error("Target directory",student_extract_repo_dir,"exists. Use --force option to overwrite")
			return False

	print("Cloning repository from",student_git_repo,"with tag",LAB_TAG_STRING,"to",student_extract_repo_dir)
	
	if not lab_test.clone_repo(student_git_repo, LAB_TAG_STRING, student_extract_repo_dir):
		lab_test.print_error("Failed to clone repository")
		return False

	# Print the repository submission time
	COMMIT_STRING_FILEPATH = student_extract_repo_dir / COMMIT_STRING_FILENAME
	try:
		fp = open(COMMIT_STRING_FILEPATH, "r")
		commit_string = fp.read()
		print("Tag",LAB_TAG_STRING,"commited at",commit_string)
	except FileNotFoundError:
		lab_test.print_warning("Warning: No Commit Time String Found")

	''' Check to make sure all the expected files exist (both submission and test) '''
	print("Checking to make sure required files are in repository")
	for file in all_files:
		filename = all_files[file]
		filepath = student_extract_lab_dir / filename
		if filepath.exists():
			print("File",filename,"exists")
		else:
			lab_test.print_warning(str("Warning: File "+filename+" does not exist"))


	if not args.notest:

		# At this point we have all the files and can perform experiemnts
		log = open(student_extract_lab_dir / TEST_RESULT_FILENAME, 'w')

		# Simulate all of the TCL simulations
		if tcl_sims:
			for tcl_sim_tuple in tcl_sims:
				(tcl_filekey, tcl_toplevel, tcl_hdl_keylist) = tcl_sim_tuple
				tcl_hdl_list = []
				for tcl_hdl_key in tcl_hdl_keylist:
					src_filename = get_filename_from_key(tcl_hdl_key)
					tcl_hdl_list.append(src_filename)
				tcl_filename = get_filename_from_key(tcl_filekey)
				test = lab_passoff.tcl_simulation()
				result = test.perform_test(student_extract_lab_dir, tcl_filename, tcl_toplevel, tcl_hdl_list)
				if not result:
					log.write('** Failed TCL simulation\n')
				else:
					log.write('** Successful TCL simulation\n')

		# Build circuit
		if build_sets:
			for build_tuple in build_sets:
				(design_name, xdl_key_list, hdl_key_list, implement_build, create_dcp) = build_tuple
	
				hdl_filenames=[]
				for hdl_key in hdl_key_list:
					hdl_filename = get_filename_from_key(hdl_key)
					hdl_filenames.append(hdl_filename)
				xdl_filenames = []
				for xdc_key in xdl_key_list:
					src = get_filename_from_key(xdc_key)
					xdl_filenames.append(src)

				test = lab_passoff.build_bitstream()
				result = test.perform_test(student_extract_lab_dir, design_name, \
					[NEW_PROJECT_SETTINGS_FILENAME], hdl_filenames, xdl_filenames, BASYS3_PART)
				if not result:
					log.write('** Failed to Synthesize\n')
				else:
					log.write('** Successful synthesis\n')

		# Print summarizing messages
		lab_test.print_message_summary()

	# Clean the submission temporary files
	if not args.noclean:
		lab_test.print_warning( "Deleting temporary submission test directory",student_extract_repo_dir)
		shutil.rmtree(student_extract_repo_dir, ignore_errors=True)

if __name__ == "__main__":
	main()