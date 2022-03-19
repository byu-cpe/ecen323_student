#!/usr/bin/python3

'''
Base script for performing passoffs on ECEN 323 labs.
Provides core functionality that is used by each labs'
unique passoff script.
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

SCRIPT_VERSION = 1.0

class lab_test:
	''' An instance of this class represents a specific test for a lab passoff.
		It contains the variables needed to implement a passoff script. The purpose
		of this class is to consolidate all functionality that is common to all
		passoff scripts into a single class. Examples of common functionality used
		by the scripts include:
		- Argument parsing with common set of arguments
		- Execute test modules (and save the output to files)
		- Message printing
		- Extracting specific tagged repositories before running tests
		- Managing the mapping between lab specific file keys and their filenames

		Class variables:

		lab_num - the integer lab number
		script_path - the Path of the lab-specific script (not the path of this class)
		tests_to_perform - a list of "tester_modul" objects that represet a specific test to perform
		submission_top_path - represents the top directory where the repository files exist.
			This is specified as "cwd" for local or "extract_dir" from the arguments
		submission_lab_path - represents the directory where the lab-specific files exist
		execution_path - represents the directory where the executables will run. By default
			this is the 'submission_lab_path'. When the -run_dir flag is given, this is relative
			to 'cwd'.

		This class also has a number of constants that are the same for all scripts.

		TODO:
		- The current approach for lab passoffs checks out a tagged copy of the repository under each lab
		  directory. This will cause the students to have 12 old tagged versions of their repository in
		  their lab space (although not apart of .git). Come up with a way to checkout the repositories into
		  the same temporary "passoff" directory in their file space so that only one tagged version of their
		  repository is in use at any one time.
		- Checkout the starter code if it doesn't exist (or give a flag to the student code repository) and
		  run the scripts from the known good repository.
	'''



	def __init__(self,script_path,lab_num):
		''' Initialize variables in lab_test object'''
		# Set variables base on arguments
		self.lab_num = lab_num
		self.script_path = script_path
		# Flag indicating it is ok to perform a test. Set to False when catastrophic failure occurs
		self.proceed_with_tests = True
		# Directories to delete
		self.directories_to_delete = []
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
		self.log = None
		self.tests_to_perform = []

		# Create the argument parser
		self.parser = lab_passoff_argparse(self.lab_num)

	def parse_args(self):
		''' Parse arguments and set variables based on arguments. The most important
		parameters that are set are the directory paths. '''

		# Parse the arguments
		self.args = self.parser.parse_args()


	def prepare_test(self, submission_dict, testfiles_dict):
		''' Prepare the repository and check for all files '''
		if not self.prepare_remote_repo():
			return False
		self.set_lab_fileset(submission_dict, testfiles_dict)
		return self.check_lab_fileset()

	def add_test_module(self, test_module):
		self.tests_to_perform.append(test_module)

	def run_tests(self):
		''' Run all the registered tests '''
		if not self.args.notest:
			for test in self.tests_to_perform:
				self.execute_test_module(test)
		# Wrap up
		self.print_message_summary()
		self.clean_up_test()

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
			self.print_error("Completed - Submission has",str(self.errors),"error(s)")
		elif self.warnings:
			self.print_warning("Completed - Submission has",str(self.warnings),"warning(s)")
		else:
			self.print_color(TermColor.GREEN, "Completed - No Warnings or Errors")

	def subprocess_file_print(self,process_output_filepath, proc_cmd, proc_cwd):
		""" 
		Complete a sub-process and print to a file and stdout.

		Returns the sub-process return code.

		TODO:Provide more options on output: 1. to stdout and file, 2. To one or the other, or 3. None
		"""
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
			#print("Proc return code",proc.returncode)
			return proc.returncode
		return 0

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
			self.proceed_with_tests = False
			return False
		return True

	def get_repo_origin_url(self,cwd):
		''' Deteremines the 'remote.origin.url' of the
			repository located at the 'cwd' path '''
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
		COMMIT_STRING_FILEPATH = self.submission_top_path / self.COMMIT_STRING_FILENAME
		try:
			fp = open(COMMIT_STRING_FILEPATH, "r")
			commit_string = fp.read()
			print(str.format("Tag '{}' committed on {}",self.LAB_TAG_STRING,commit_string))
		except FileNotFoundError:
			self.print_warning("Warning: No Commit Time String Found",COMMIT_STRING_FILEPATH)

	def prepare_remote_repo(self):
		''' Prepares the repository for the pass-off. When this function has completed,
			the repository has been copied (if necessary), verified, and the  directories 
			class variable has been set to the appropriate location.
		'''

		# Determine submission directory for the test
		# 	submission_top_path:
		# 		represents the top directory where the repository files exist. This directory
		#		may or may not be extracted (depending on local setting). The tester will look here
		#		for all files needed for the submission.
		#	submission_lab_path:
		#		represents the directory where the lab-specific files exist. It is one level below
		#		submission_top_dir
		if self.args.local:
			# The pass off script is to be run on the local files in the current directory
			#self.submission_lab_path = self.script_path
			self.submission_lab_path = pathlib.Path.cwd()
			self.submission_top_path = self.submission_lab_path.parent
			print("Performing Local Passoff check - will not check remote repository")
			print("Running local passoff from files at",self.submission_lab_path)
		else:
			# A remote passoff
			self.submission_top_path = self.script_path / self.args.extract_dir
			self.submission_lab_path = self.submission_top_path / self.LAB_DIR_NAME
			if self.args.git_repo:
				# If the repository is given on the command line, save the variable
				student_git_repo = self.args.git_repo
			else:
				# If the repostiory is NOT given on the command line, determine the current repo
				student_git_repo = self.get_repo_origin_url(self.script_path)
				if not student_git_repo:
					self.print_error("git config failed")
					self.proceed_with_tests = False
					return False

			''' Clone Repository. When done, the 'student_repo_dir' variable will be set.
			'''
			# See if directory exists
			if self.submission_top_path.exists():
				# See if the submission directory matches the local directory (don't want to overwrite)
				if self.submission_top_path == self.script_path.parent:
					self.print_error("Extract directory and root of local repository are the same")
					self.proceed_with_tests = False
					return False
				if self.args.force:
					print( "Target directory",self.submission_top_path,"exists. Will be deleted before proceeding")
					shutil.rmtree(self.submission_top_path, ignore_errors=True)
				elif self.args.nodelete:
					print( "Target directory",self.submission_top_path,"exists. Will proceed WITHOUT deleting")
				else:
					self.print_error("Target directory",self.submission_top_path,"exists. Use --force option to overwrite")
					self.proceed_with_tests = False
					return False
			# Save directory for deleting (if chosen)
			self.directories_to_delete.append(self.submission_top_path)

			# Perform the actual clone of the repo
			if not self.clone_repo(student_git_repo, self.submission_top_path,self.LAB_TAG_STRING):
				self.print_error("Failed to clone repository")
				self.proceed_with_tests = False
				return False

			# Print the repository submission time
			self.print_tag_commit_date()

		# At this point we have a valid repo at self.submission_top_path
		print("Repository Top",self.submission_top_path)
		print("Repository Lab",self.submission_lab_path)

		# check to make sure the extracted repo is a valid 323 repo
		actual_origin_url = self.get_repo_origin_url(self.submission_top_path)
		# git@github.com:byu-ecen323-classroom/323-labs-wirthlin.git
		#URL_MATCH_STRING = "git@github.com:byu-ecen323-classroom/323-labs-(\w+).git"
		# For some reason, the github URL does not always have the ".git" at the end when running in the digital lab
		#URL_MATCH_STRING = "git@github.com:byu-ecen323-classroom/323-labs-(\w+)"
		# Students using HTTPs fail on the match string above.. The less restrictive one
		# below works for https and the script proceeds.
		URL_MATCH_STRING = "(.*)byu-ecen323-classroom/323-labs-(\w+)"
		match = re.match(URL_MATCH_STRING,actual_origin_url)
		if not match:
			self.print_error("Cloned repository is not part of the byu-ecen323-classroom:",actual_origin_url)
			self.proceed_with_tests = False
			return False
		else:
			print("Valid byu-ecen323-classroom repository")

		# Determine execution directory where test should be completed
		#   execution_path:
		#		represents the directory where the execution of the test will occur. 
		if self.args.run_dir:
			# If a run directory option is given, create a path that is relative to the
			# current working directory in which the script was run.
			self.execution_path = pathlib.Path.cwd() / self.args.run_dir

			# See if directory exists
			if self.execution_path.exists():
				print("Execution directory",self.execution_path,"exists.")
			else:
				# Directory does not exist - create it
				print("Execution directory",self.execution_path," does not exists. Will be created")
				os.mkdir(self.execution_path)
				self.directories_to_delete.append(self.execution_path)
		else:
			# Use the lab path as the execution path as a default
			self.execution_path = self.submission_lab_path
		print("Execution Path",self.execution_path)

		# Create log file
		self.log = self.create_log_file()
		if not self.log:
			return False

		# All is well
		return True


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

	def get_filename_from_key(self,file_key,relative_to_execution=True):
		''' Returns the filename associated with a file key that is located either in
			the submission_files dictionary or the test_files dictionary.
		'''
		filename = None
		if file_key in self.submission_dict:
			filename = self.submission_dict[file_key]
		elif file_key in self.testfiles_dict:
			filename = self.testfiles_dict[file_key]
		if not filename:
			return None

		# Get actual path of file
		if relative_to_execution:
			# Find common sequence between lab submission path and execution path
			#filepath = self.submission_lab_path / filename
			#print("path",filename,filepath,self.execution_path)
			# Find the relative path between the execution path and lab root. This
			# returns the prefix to filenames to access them from the execution directory.
			rel_path = os.path.relpath(os.path.relpath(self.submission_lab_path,self.execution_path))
			#print("rel",rel_path)
			new_path = os.path.join(rel_path,filename)
			#print("newpath=",new_path)
			#ex_relative_path = str(rel_path,filename)
			#filepath = self.submission_lab_path / filename
			#ex_relative_path = filepath.relative_to(self.execution_path)
			#print("*",filename,ex_relative_path)
			return str(new_path)
		return filename

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
		''' Check to make sure all the expected files exist (both submission and test).
			Returns True if all of the files exist, False otherwise. '''
		print("Checking for submission files in repository")
		all_files = self.submission_dict.copy()
		all_files.update(self.testfiles_dict)
		error = False
		for file_key in all_files.keys():
			filename = all_files[file_key]
			filepath = self.submission_lab_path / filename
			if filepath.exists():
				print(" File",filename,"exists")
			else:
				self.print_error("File",filename,"does not exist",filepath)
				error = True
				self.proceed_with_tests = False
		return not error
	
	def create_log_file(self):
		''' Creates a log file to record test summaries'''
		log_file_path = self.execution_path / self.TEST_RESULT_FILENAME
		try:
			log = open(log_file_path, 'w')
			print("Creating log file",log_file_path)
		except IOError:
			self.print_error("Cannot create file",log_file_path)
			self.proceed_with_tests = False
			return None
		return log

	def print_log_file(self,str,print_to_stdout=False):
		if self.log:
			self.log.write(str)
		if print_to_stdout:
			print(str)

	def execute_test_module(self, test_module):
		''' Executes the 'perform_test' function of the tester_module and logs its result in the log file '''

		# Check to see if the test should proceed
		if not self.proceed_with_tests:
			print("Skipping test",test_module.module_name(),"due to previous errors")
			return False

		module_name = test_module.module_name()
		result = test_module.perform_test(self)
		if result:
			self.print_log_file(str.format("Success:{}\n",module_name))
			self.print_color(TermColor.GREEN, str.format("Success:{}\n",module_name))
		else:
			self.print_log_file(str.format("Failed:{}\n",module_name))
			self.print_error(str.format("Error executing:{}",module_name))
			#self.proceed_with_tests = False
		return result

	def clean_up_test(self):
		''' Should be called at the end of a test. It closes the log file and deletes the temporary directory. '''
		if self.log:
			self.log.close()
		# Delete temporary directories
		if self.args.clean:
			for directory in self.directories_to_delete:
				self.print_info( "Deleting directory",directory)
				shutil.rmtree(directory, ignore_errors=True)
		else:
			print("Not deleting following directories:")
			for directory in self.directories_to_delete:
				self.print_info(directory)

class lab_passoff_argparse(argparse.ArgumentParser):
	'''
	Extends ArgumentParse to have predetermined options for lab passoffs.
	'''

	def __init__(self,lab_num):
		# Initialize variables
		self.lab_num = lab_num

		# Constants
		self.DEFAULT_EXTRACT_DIR = "passoff_temp_dir"

		# call parent initialization
		description = str.format('Create and test submission archive for lab {} (v {}).', \
			self.lab_num,SCRIPT_VERSION)
		argparse.ArgumentParser.__init__(self,description=description)

		# GitHub URL for the student repository.
		self.add_argument("--git_repo", type=str, 
			help="GitHub Remote Repository. If no repository is specified, the URL of the current repo will be used.")

		# Force use of directories if they already exists
		self.add_argument("-f", "--force", action="store_true", help="Force use of directories if they already exists: delete existing")
		self.add_argument("--nodelete", action="store_true", help="Force use of directory if it exists and to not delete")

		# Extract the prepository at the fiven directory.
		self.add_argument("--extract_dir", type=str,
			help="Temporary directory where repository will be extracted (relative to directory script is run)",
			default=self.DEFAULT_EXTRACT_DIR)

		# Run directory
		self.add_argument("--run_dir", type=str,
			help="Temporary directory where all the tests are run (relative to script dir). Default is extract_dir for clones, script directory for local")

		# Clean up the temporary directory
		self.add_argument("--clean", action="store_true", help="Clean up any directories that are created")

		# Do not clean up the temporary directory
		self.add_argument("--notest", action="store_true", help="Do not run the tests")

		# Local option
		#  allows students to perform a 'local' passoff that just uses the files in the local repository rather than checking out their repository. This is helpful if the students want to debug their files before going through the entire process of pushing and tagging.
		self.add_argument("--local", action="store_true", help="Perform passoff script on local repository rather than cloning the remote repository")

