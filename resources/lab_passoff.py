#!/usr/bin/python3

'''
Script for extracting a student submission from a GitHub repository and
checking the submission.

TODO:
- Provide an option that allows students to perform a 'local' passoff that just uses the files in the local repository rather than checking out their repository. This is helpful if the students want to debug their files before going through the entire process of pushing and tagging.
- Change instructions so that the students add the "--squash" flag on the merge so they don't get so
  many commits when they merge the starter code
- Squash the commit history of the starter code before the semester begins
- Checkout the starter code if it doesn't exist (or give a flag to the student code repository) and
  run the scripts from the known good repository.
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
		# Flag indicating it is ok to perform a test. Set to False when catastrophic failure occurs
		self.proceed_with_tests = True
		# Local mode of executing script
		self.local = False
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
			self.print_error("Completed - Submission has",str(self.errors),"error(s)")
		elif self.warnings:
			self.print_warning("Completed - Submission has",str(self.warnings),"warning(s)")
		else:
			self.print_color(TermColor.GREEN, "Completed - No Warnings or Errors")

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
		COMMIT_STRING_FILEPATH = self.student_extract_repo_dir / self.COMMIT_STRING_FILENAME
		try:
			fp = open(COMMIT_STRING_FILEPATH, "r")
			commit_string = fp.read()
			print(str.format("Tag '{}' committed on {}",self.LAB_TAG_STRING,commit_string))
		except FileNotFoundError:
			self.print_warning("Warning: No Commit Time String Found",COMMIT_STRING_FILEPATH)

	def prepare_remote_repo(self):
		''' Prepares the repository for the pass-off. When this function has completed,
		the repository has been copied (if necessary), verified, and the  student_extract_repo_dir 
		class variable has been set to the appropriate location.  '''

		''' Determine remote repository
		'''
		if self.args.local:
			# The pass off script is to be run on the local files - no cloning
			self.local = True
			self.student_extract_repo_dir = self.script_path
			self.print_warning("Performing Local Passoff check - will not check remote repository")
		else:
			# A remote passoff
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
			if self.student_extract_repo_dir.exists():
				if self.args.force:
					print( "Target directory",self.student_extract_repo_dir,"exists. Will be deleted before proceeding")
					shutil.rmtree(self.student_extract_repo_dir, ignore_errors=True)
				else:
					self.print_error("Target directory",self.student_extract_repo_dir,"exists. Use --force option to overwrite")
					self.proceed_with_tests = False
					return False

			# Perform the actual clone of the repo
			if not self.clone_repo(student_git_repo, self.student_extract_repo_dir,self.LAB_TAG_STRING):
				self.print_error("Failed to clone repository")
				self.proceed_with_tests = False
				return False

			# Print the repository submission time
			self.print_tag_commit_date()

		# At this point we have a valid repot
		
		# check to make sure the extracted repo is a valid 323 repo
		actual_origin_url = self.get_repo_origin_url(self.student_extract_repo_dir)
		# git@github.com:byu-ecen323-classroom/323-labs-wirthlin.git
		URL_MATCH_STRING = "git@github.com:byu-ecen323-classroom/323-labs-(\w+).git"
		match = re.match(URL_MATCH_STRING,actual_origin_url)
		if not match:
			self.print_error("Cloned repository is not part of the byu-ecen323-classroom")
			self.proceed_with_tests = False
			return False
		else:
			print("Valid byu-ecen323-classroom repository")

		# Create log file
		self.log = self.create_log_file()
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
		''' Check to make sure all the expected files exist (both submission and test).
			Returns True if all of the files exist, False otherwise. '''
		print("Checking for submission files in repository")
		all_files = self.submission_dict.copy()
		all_files.update(self.testfiles_dict)
		error = False
		for file_key in all_files.keys():
			filename = all_files[file_key]
			filepath = self.student_extract_lab_dir / filename
			if filepath.exists():
				print(" File",filename,"exists")
			else:
				self.print_error("File",filename,"does not exist",filepath.as_posix())
				error = True
				self.proceed_with_tests = False
		return not error
	
	def create_log_file(self):
		log_file_path = self.student_extract_lab_dir / self.TEST_RESULT_FILENAME
		print("Createing log file",log_file_path)
		log = open(log_file_path, 'w')
		return log

	def print_log_file(self,str):
		if self.log:
			self.log.write(str)
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
		else:
			self.print_log_file(str.format("Failed:{}\n",module_name))
			self.proceed_with_tests = False
		return result

	def clean_up_test(self):
		''' Should be called at the end of a test. It closes the log file and deletes the temporary directory. '''
		if self.log:
			self.log.close()
		if self.args.clean:
			if not self.local:
				# Don't clean up 'local' passoffs
				self.print_info( "Deleting temporary submission test directory",self.student_extract_repo_dir)
				shutil.rmtree(self.student_extract_repo_dir, ignore_errors=True)
			else:
				self.print_warning("Local Passoff: will not delete local directory")

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

		# GitHub URL for the student repository.
		self.add_argument("--git_repo", type=str, help="GitHub Remote Repository. If no repository is specified, the current repo will be used.")

		# Force git extraction if directory already exists
		self.add_argument("-f", "--force", action="store_true", help="Force clone if target directory already exists")

		# Directory for extracting repository. This directory will be deleted when
		# the script is done (unless the --noclean option is set).
		self.add_argument("--extract_dir", type=str, \
			help="Temporary directory where repository will be extracted (relative to directory script is run)",
			default=self.DEFAULT_EXTRACT_DIR)

		# Clean up the temporary directory
		self.add_argument("--clean", action="store_true", help="Clean up the extraction directory when done")

		# Do not clean up the temporary directory
		self.add_argument("--notest", action="store_true", help="Do not run the tests")

		# Local option
		self.add_argument("--local", action="store_true", help="Perform passoff script on local repository rather than cloning the remote repository")

