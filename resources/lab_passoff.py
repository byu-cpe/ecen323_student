#!/usr/bin/python3

'''
Script for extracting a student submission from a GitHub repository and
checking the submission.

TODO:
- Change instructions so that the students add the "--squash" flag on the merge so they don't get so
  many commits when they merge the starter code
- Squash the commit history of the starter code before the semester begins
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


# TODO Reused from pygrader
class TermColor:
	""" Terminal codes for printing in color """
	# pylint: disable=too-few-public-methods
	PURPLE = "\033[95m"
	BLUE = "\033[94m"
	GREEN = "\033[92m"
	YELLOW = "\033[93m"
	RED = "\033[91m"
	END = "\033[0m"
	BOLD = "\033[1m"
	UNDERLINE = "\033[4m"


class lab_test:
	''' Represents a specific test for a lab passoff '''

	def __init__(self,args,script_path,lab_num):
		# Set variables base on arguments
		self.args = args
		self.lab_num = lab_num
		self.script_path = script_path
		# Constants
		self.BASYS3_PART = "xc7a35tcpg236-1"
		self.STARTER_CODE_REPO = "git@github.com:byu-cpe/ecen323_student.git"
		self.LAB_DIR_NAME = str.format("lab{:02d}",self.lab_num)
		self.DEFAULT_EXTRACT_DIR = "passoff_temp_dir"
		self.TEST_RESULT_FILENAME = str.format("lab{}_test_result.txt",self.lab_num)
		self.LAB_TAG_STRING = str.format("lab{}_submission",self.lab_num)
		self.TEST_RESULT_FILENAME = str.format("lab{}_test_result.txt",self.lab_num)
		self.NEW_PROJECT_SETTINGS_FILENAME = "../resources/new_project_settings.tcl"
		# The filename of the commit string relative to the current lab
		self.COMMIT_STRING_FILENAME = ".commitdate"		# Initialize variables
		self.errors = 0
		self.warnings = 0
		# This is the path of location where the repository was extracted
		self.student_extract_repo_dir = self.script_path / self.args.extract_dir
		# This is the path of lab within the extracted repository where the lab exists
		# and where the executables wil run
		self.student_extract_lab_dir = self.student_extract_repo_dir / self.LAB_DIR_NAME

	def print_color(self,color, *msg):
		""" Print a message in color """
		print(color + " ".join(str(item) for item in msg), TermColor.END)

	def print_info(self,*msg):
		""" Print an error message and exit program """
		self.print_color(TermColor.BLUE, " ".join(str(item) for item in msg))

	def print_error(self,*msg):
		""" Print an error message and exit program """
		self.print_color(TermColor.RED, "ERROR:", " ".join(str(item) for item in msg))
		self.errors += 1

	def print_warning(self,*msg):
		""" Print an error message and exit program """
		self.print_color(TermColor.YELLOW, "WARNING:", " ".join(str(item) for item in msg))
		self.warnings += 1

	def print_message_summary(self):
		if self.errors:
			self.print_error("Completed - Submission has ",str(self.errors)," errors")
		elif self.warnings:
			self.print_warning("Completed - Submission has ",str(self.warnings)," warnings")
		else:
			self.print_color(TermColor.GREEN, "Completed - No Warnings or Errors")


	def perform_test(self):
		""" Perform the class specific test. """
		return True
	
	def subprocess_file_print(self,process_output_filepath, proc_cmd, proc_cwd):
		""" Complete a sub-process and print to a file and stdout """
		with open(process_output_filepath, "w") as fp:
			proc = subprocess.Popen(
				proc_cmd,
				cwd=proc_cwd,
				stdout=subprocess.PIPE,
				stderr=subprocess.STDOUT,
				universal_newlines=True,
			)
			for line in proc.stdout:
				sys.stdout.write(line)
				fp.write(line)
				fp.flush()
			# Wait until process is done
			proc.communicate()
			if proc.returncode:
				return False
		return True

	def check_executable_existence(self, command_list):
		# See if the executable is even in the path
		''' Executes a command and traps OS error. Used to detect if
			executable exists. The command_list is a list of commandline
			arguments used in a subprocess.run. Ideally the options should
			select something that will just return immediately (like -version)
			so that nothing consuming much time will occur.
		'''
		try:
			proc = subprocess.run(command_list)
		except OSError:
			self.print_error(command_list[0], "not found (not in path of shell environment)")
			return False
		return True

	def determine_current_repo(self,cwd):
		#git config --get remote.origin.url
		cmd = ["git", "config", "--get", "remote.origin.url"]
		p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE,universal_newlines=True)
		if p.returncode:
			#self.print_error("git config failed")
			#print_color(TermColor.RED, "git config failed")
			return None
		else:
			current_repo = p.stdout.strip()
		return current_repo

	def print_tag_commit_date(self):
		'''
		Reads the ".commit" file to find commit date. Prints date
		'''
		# determin path of commit string
		COMMIT_STRING_FILEPATH = self.student_extract_repo_dir / self.COMMIT_STRING_FILENAME
		try:
			fp = open(COMMIT_STRING_FILEPATH, "r")
			commit_string = fp.read()
			print(str.format("Tag '{}' committed on {}",self.LAB_TAG_STRING,commit_string))
		except FileNotFoundError:
			self.print_warning("Warning: No Commit Time String Found",COMMIT_STRING_FILEPATH)

	def prepare_remote_repo(self):

		''' Determine remote repository
		'''
		if self.args.git_repo:
			student_git_repo = self.args.git_repo
		else:
			# Determine the current repo
			student_git_repo = self.determine_current_repo(self.script_path)
			if not student_git_repo:
				self.print_error("git config failed")
				return False

		''' Clone Repository. When done, the 'student_repo_dir' variable will be set.
		'''
		# See if directory exists
		if self.student_extract_repo_dir.exists():
			if self.args.force:
				print( "Target directory",self.student_extract_repo_dir,"exists. Will be deleted before proceeding")
				shutil.rmtree(self.student_extract_repo_dir, ignore_errors=True)
			else:
				self.print_error("Target directory",self.student_extract_repo_dir,"exists. Use --force option to overwrite")
				return False

		if not self.clone_repo(student_git_repo, self.student_extract_repo_dir,self.LAB_TAG_STRING):
			self.print_error("Failed to clone repository")
			return False

		# Print the repository submission time
		self.print_tag_commit_date()
		# Create log file
		self.log = self.create_log_file()
		
	# TODO: This function was copied from 'pygrader/pygrader/student_repos.py'
	#       - Need to import this code rather than copying it in the future.
	#       - Merge my comments into initial repository (note I changed TermColor)

	# Get the absolute path of the executing script.
	# Generate the clone string
	#     https://github.com/byu-ecen323-classroom/323-labs-wirthlin
	#patternString = "(http?://)?github.com/byu-ecen323-classroom/(\w+)"
	#match = re.match(patternString,student_git_url)
	#if match:
	#	student_repo_name = match.group(2)
	#else:
	#	print("Invalid URL:"+student_git_url)
	#	return False
	#git@github.com:byu-ecen323-classroom/323-labs-wirthlin.git
	#studet_git_clone_str = str.format("git@github.com:byu-ecen323-classroom/{}.git",student_repo_name)

	def clone_repo(self, git_path, student_repo_path, lab_tag):
		'''
		Clone student repository to local directory
		
		Parameters
		----------
		git_path: str
			The Git URL of the repository to clone
		tag: str
			The tag to use for the clone
		student_repo_path: str
			The path where the cloned repository should go
		
		'''
		if student_repo_path.is_dir() and list(student_repo_path.iterdir()):
			self.print_info(
				"Student repo",
				student_repo_path.name,
				"already cloned. Re-fetching tag",
			)

			# Fetch
			cmd = ["git", "fetch", "--tags", "-f"]
			p = subprocess.run(cmd, cwd=student_repo_path)
			if p.returncode:
				self.print_error("git fetch failed")
				return False

			# Checkout tag
			if self.LAB_TAG_STRING not in ("master", "main"):
				tag = "tags/" + lab_tag
			cmd = ["git", "checkout", tag, "-f"]
			p = subprocess.run(cmd, cwd=student_repo_path)
			if p.returncode:
				self.print_error(TermColor.RED, "git checkout of tag failed")
				return False
			return True

		self.print_info("Cloning repo, tag =", lab_tag)
		cmd = [
			"git",
			"clone",
			"--branch",
			self.LAB_TAG_STRING,
			git_path,
			str(student_repo_path.absolute()),
		]
		try:
			p = subprocess.run(cmd)
		except KeyboardInterrupt:
			shutil.rmtree(str(student_repo_path))
			sys.exit(-1)
		if p.returncode:
			self.print_error("Clone failed")
			return False
		return True

	# TODO: This function was copied from 'pygrader/pygrader/student_repos.py'
	#       Need to import this code rather than copying it in the future.
	def print_date(self, student_repo_path):
		print("Last commit: ")
		cmd = ["git", "log", "-1", r"--format=%cd"]
		proc = subprocess.run(cmd, cwd=str(student_repo_path))

	def set_lab_fileset(self, submission_dict, testfiles_dict):
		''' Set the files needed to test the lab '''
		self.submission_dict = submission_dict
		self.testfiles_dict = testfiles_dict

	def get_filename_from_key(self,file_key):
		''' Returns the filename associated with a file key that is located either in
			the submission_files dictionary or the test_files dictionary.
		'''
		if file_key in self.submission_dict:
			return self.submission_dict[file_key]
		elif file_key in self.testfiles_dict:
			return self.testfiles_dict[file_key]
		# Isn't in either dictionary. Return None
		return None

	def get_filenames_from_keylist(self,file_key_list):
		''' Returns the filename associated with a file key that is located either in
			the submission_files dictionary or the test_files dictionary.
		'''
		filenames = []
		for file_key in file_key_list:
			filename = self.get_filename_from_key(file_key)
			if filename:
				filenames.append(filename)
			else:
				print("Warning: no key ",file_key)
				print(self.submission_dict)
				print(self.testfiles_dict)
		return filenames

	def check_lab_fileset(self):
		''' Check to make sure all the expected files exist (both submission and test) '''
		print("Checking for submission files in repository")
		all_files = self.submission_dict.copy()
		all_files.update(self.testfiles_dict)
		for file_key in all_files.keys():
			filename = all_files[file_key]
			filepath = self.student_extract_lab_dir / filename
			if filepath.exists():
				print(" File",filename,"exists")
			else:
				self.print_warning(str("Warning: File "+filename+" does not exist"))
	
	def create_log_file(self):
		log = open(self.student_extract_lab_dir / self.TEST_RESULT_FILENAME, 'w')
		return log

	def print_log_file(self,str):
		if self.log:
			self.log.write(str)
		print(str)

	def clean_up_test(self):
		if self.log:
			self.log.close()
		if not self.args.noclean:
			self.print_info( "Deleting temporary submission test directory",self.student_extract_repo_dir)
			shutil.rmtree(self.student_extract_repo_dir, ignore_errors=True)

class lab_passoff_argparse(argparse.ArgumentParser):
	'''
	Extends ArgumentParse to have predetermined options for lab passoffs.
	'''

	def __init__(self,lab_num,version="1.0"):
		# Initialize variables
		self.lab_num = lab_num

		# Constants
		self.DEFAULT_EXTRACT_DIR = "passoff_temp_dir"

		# call parent initialization
		description = str.format('Create and test submission archive for lab {} (v {}).', \
			self.lab_num,version)
		argparse.ArgumentParser.__init__(self,description=description)

		# GitHub URL for the student repository. Required option for now.
		self.add_argument("--git_repo", type=str, help="GitHub Remote Repository. If no repository is specified, the current repo will be used.")

		# Force git extraction if directory already exists
		self.add_argument("-f", "--force", action="store_true", help="Force clone if target directory already exists")

		# Directory for extracting repository. This directory will be deleted when
		# the script is done (unless the --noclean option is set).
		self.add_argument("--extract_dir", type=str, \
			help="Temporary directory where repository will be extracted (relative to directory script is run)",
			default=self.DEFAULT_EXTRACT_DIR)

		# Do not clean up the temporary directory
		self.add_argument("--noclean", action="store_true", help="Do not clean up the extraction directory when done")

		# Do not clean up the temporary directory
		self.add_argument("--notest", action="store_true", help="Do not run the tests")


class tcl_simulation():

	def __init__(self,lab_test,tcl_sim_tuple):
		(tcl_key, tcl_sim_top_module, hdl_keylist) = tcl_sim_tuple
		#print(tcl_sim_tuple)
		self.lab_test = lab_test
		tcl_filename = lab_test.get_filename_from_key(tcl_key)
		hdl_filenames = lab_test.get_filenames_from_keylist(hdl_keylist)
		#print(hdl_filenames)
		result = self.perform_test(lab_test.student_extract_lab_dir, tcl_filename, tcl_sim_top_module, hdl_filenames)
		if result:
			self.lab_test.print_log_file("** Successful TCL simulation")
		else:
			self.lab_test.print_log_file("** Failed TCL simulation")

	def perform_test(self,extract_lab_path, tcl_filename, tcl_toplevel, tcl_hdl_filename_list):
		''' 
		Perform a simulation of a module with a Tcl script.
			sim_path: the path where the simulation should take place
			tcl_list: the list of items associated with a tcl simulation
		'''
		
		self.lab_test.print_info(TermColor.BLUE, "Attempting simulation of TCL script:", tcl_filename)

		# See if the executable is even in the path
		if not self.lab_test.check_executable_existence(["xvlog", "--version"]):
			return False

		# Analyze all of the files associated with the TCL simulation set
		self.lab_test.print_info(TermColor.BLUE, " Analyzing source files")
		for src_filename in tcl_hdl_filename_list:
			#print("  Analyzing File",src_filename)
			xvlog_cmd = ["xvlog", "--nolog", "-sv", src_filename ]
			proc = subprocess.run(xvlog_cmd, cwd=extract_lab_path, check=False)
			if proc.returncode:
				self.lab_test.print_error("Failed analyze of file ",src_filename)
				return False

		# xvlog -sv alu.sv regfile.sv riscv_alu_constants.sv riscv_datapath_constants.sv riscv_io_multicycle.v riscv_multicycle.sv riscv_simple_datapath.sv glbl.v
		# xelab -L unisims_ver riscv_io_system work.glbl
		#return False

		# Elaborate design
		design_name = tcl_toplevel
		self.lab_test.print_info(TermColor.BLUE, " Elaborating")
		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name, "work.glbl" ]
		xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name ]
		proc = subprocess.run(xelab_cmd, cwd=extract_lab_path, check=False)

		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", design_name, "work.glbl" ]
		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L xil_defaultlib", "-L unisims_ver", "-L unimacro_ver", design_name, "work.glbl" ]
		#xelab  -wto f006d1b2ec3040b5bab73404505d9a2c --debug typical --relax --mt 2 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip --snapshot riscv_io_system_behav xil_defaultlib.riscv_io_system xil_defaultlib.glbl -log elaborate.log    proc = subprocess.run(xelab_cmd, cwd=extract_path, check=False)
		if proc.returncode:
			self.lab_test.print_error("Error in elaboration")
			return False

		# Modify TCL simulation script (add 'quit' command to end)
		temp_tcl_filename = str(design_name + "_tempsim.tcl")
		src_tcl = extract_lab_path / tcl_filename
		tmp_tcl = extract_lab_path / temp_tcl_filename
		shutil.copyfile(src_tcl, tmp_tcl)

		log = open(tmp_tcl, 'a')
		log.write('\n# Add Exit quit command\n')
		log.write('quit\n')
		log.close()

		# Simulate
		self.lab_test.print_info(TermColor.BLUE, " Starting Simulation")
		#tmp_design_name = str(design_name + "#work.glbl")
		tmp_design_name = str(design_name)
		simulation_log_filename = str(tcl_toplevel + "_tcl_simulation.txt")
		simulation_log_filepath = extract_lab_path / simulation_log_filename
		xsim_cmd = ["xsim", "-nolog", tmp_design_name, "-tclbatch", temp_tcl_filename ]
		if not self.lab_test.subprocess_file_print(simulation_log_filepath, xsim_cmd, extract_lab_path ):
			self.lab_test.print_error("Failed simulation")
			return False
		return True

class build_bitstream():

	def __init__(self,lab_test, build_tuple):
		self.lab_test = lab_test
		(design_name, xdl_key_list, hdl_key_list, implement_build, create_dcp) = build_tuple
		#print(build_tuple)

		hdl_filenames = lab_test.get_filenames_from_keylist(hdl_key_list)
		xdl_filenames = lab_test.get_filenames_from_keylist(xdl_key_list)
		#print(hdl_filenames)

		result = self.perform_test(lab_test.student_extract_lab_dir, design_name, [self.lab_test.NEW_PROJECT_SETTINGS_FILENAME], hdl_filenames, xdl_filenames, \
			implement_build, create_dcp)
		if result:
			self.lab_test.print_log_file("** Successful Synthesis")
		else:
			self.lab_test.print_log_file("** Failed Synthesis")

	def perform_test(self, extract_path, design_name, pre_script_filenames, hdl_filenames, xdl_filenames, \
		implement_build = True, create_dcp = False ):

		part = self.lab_test.BASYS3_PART
		'''
		Build a bitstream
			extract_path: str
				The path where build files have been extracted
			build: list
				The "build" tuple
		'''
		bitfile_filename = str(design_name + ".bit")
		dcp_filename = str(design_name + ".dcp")

		self.lab_test.print_info("Attempting to build bitfile",bitfile_filename)

		# Create tcl build script (the build will involve executing this script)
		tcl_build_script_filename = str(design_name + "_buildscript.tcl")
		tmp_tcl = extract_path / tcl_build_script_filename

		log = open(tmp_tcl, 'w')
		log.write('# Bitfile Generation script (non-project mode)\n')
		log.write('#\n')
		if pre_script_filenames:
			log.write('# Pre-build source files\n')
			for pre_source_filename in pre_script_filenames:
				log.write('source '+ pre_source_filename+'\n')
		else:
			log.write('# No Pre-build script files\n')

		# Read HDL files
		log.write('# Add sources\n')
		for hdl_filename in hdl_filenames:
			#src = get_filename_from_key(src_key)
			log.write('read_verilog -sv ' + hdl_filename + '\n')
		# Read xdc files
		if implement_build:
			log.write('# Add XDC file\n')
			for xdc_filename in xdl_filenames:
				log.write('read_xdc ' + xdc_filename + '\n')
		log.write('# Synthesize design\n')
		#log.write('synth_design -top ' + design_name + ' -flatten_hierarchy full\n')
		log.write('synth_design -top ' + design_name + ' -part ' + part + '\n')
		if implement_build:    
			log.write('# Implement Design\n')
			log.write('place_design\n')
			log.write('route_design\n')
			checkpoint_filename = str(design_name + ".dcp")
			log.write('write_checkpoint ' + checkpoint_filename + ' -force\n')
			log.write('write_bitstream -force ' + bitfile_filename +'\n')
		if create_dcp:
			log.write('# Create DCP\n')
			log.write(str.format("write_checkpoint {} -force\n",dcp_filename))
		log.write('# End of build script\n')
		log.close()

		# See if the executable is even in the path
		if not self.lab_test.check_executable_existence(["vivado", "-version"]):
			return False

		implementation_log_filename = str(design_name + "_implementation.txt")
		implementation_log_filepath = extract_path / implementation_log_filename
		with open(implementation_log_filepath, "w") as fp:
			build_cmd = ["vivado", "-nolog", "-mode", "batch", "-nojournal", "-source", tcl_build_script_filename]
			proc = subprocess.Popen(
				build_cmd,
				cwd=extract_path,
				stdout=subprocess.PIPE,
				stderr=subprocess.STDOUT,
				universal_newlines=True,
			)
			for line in proc.stdout:
				sys.stdout.write(line)
				fp.write(line)
				fp.flush()
			# Wait until process is done
			proc.communicate()
			if proc.returncode:
				return False
		return True

