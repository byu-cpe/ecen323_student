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

	def __init__(self):
		pass

	def print_color(self,color, *msg):
		""" Print a message in color """
		print(color + " ".join(str(item) for item in msg), TermColor.END)

	def print_info(self,*msg):
		""" Print an error message and exit program """
		self.print_color(TermColor.BLUE, " ".join(str(item) for item in msg))

	def print_error(self,*msg):
		""" Print an error message and exit program """
		self.print_color(TermColor.RED, "ERROR:", " ".join(str(item) for item in msg))
		#sys.exit(returncode)

	def print_warning(self,*msg):
		""" Print an error message and exit program """
		self.print_color(TermColor.YELLOW, "WARNING:", " ".join(str(item) for item in msg))

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

	# TODO: This function was copied from 'pygrader/pygrader/student_repos.py'
	#       - Need to import this code rather than copying it in the future.
	#       - Merge my comments into initial repository (note I changed TermColor)
	def clone_repo(self, git_path, tag, student_repo_path):
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
			if tag not in ("master", "main"):
				tag = "tags/" + tag
			cmd = ["git", "checkout", tag, "-f"]
			p = subprocess.run(cmd, cwd=student_repo_path)
			if p.returncode:
				self.print_error(TermColor.RED, "git checkout of tag failed")
				return False
			return True

		self.print_info("Cloning repo, tag =", tag)
		cmd = [
			"git",
			"clone",
			"--branch",
			tag,
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

	# TODO: This function was copied from 'pygrader/pygrader/student_repos.py'
	#       Need to import this code rather than copying it in the future.
	def print_date(self, student_repo_path):
		print("Last commit: ")
		cmd = ["git", "log", "-1", r"--format=%cd"]
		proc = subprocess.run(cmd, cwd=str(student_repo_path))


class tcl_simulation(lab_test):

	def perform_test(self,extract_lab_path, tcl_filename, tcl_toplevel, tcl_hdl_filename_list):
		''' 
		Perform a simulation of a module with a Tcl script.
			sim_path: the path where the simulation should take place
			tcl_list: the list of items associated with a tcl simulation
		'''
		
		self.print_info(TermColor.BLUE, "Attempting simulation of TCL script:", tcl_filename)

		# See if the executable is even in the path
		if not self.check_executable_existence(["xvlog", "--version"]):
			return False

		# Analyze all of the files associated with the TCL simulation set
		self.print_info(TermColor.BLUE, " Analyzing source files")
		for src_filename in tcl_hdl_filename_list:
			xvlog_cmd = ["xvlog", "--nolog", "-sv", src_filename ]
			proc = subprocess.run(xvlog_cmd, cwd=extract_lab_path, check=False)
			if proc.returncode:
				self.print_error("Failed analyze of file ",src_filename)
				return False

		# xvlog -sv alu.sv regfile.sv riscv_alu_constants.sv riscv_datapath_constants.sv riscv_io_multicycle.v riscv_multicycle.sv riscv_simple_datapath.sv glbl.v
		# xelab -L unisims_ver riscv_io_system work.glbl
		#return False

		# Elaborate design
		design_name = tcl_toplevel
		self.print_info(TermColor.BLUE, " Elaborating")
		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name, "work.glbl" ]
		xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name ]
		proc = subprocess.run(xelab_cmd, cwd=extract_lab_path, check=False)

		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", design_name, "work.glbl" ]
		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L xil_defaultlib", "-L unisims_ver", "-L unimacro_ver", design_name, "work.glbl" ]
		#xelab  -wto f006d1b2ec3040b5bab73404505d9a2c --debug typical --relax --mt 2 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip --snapshot riscv_io_system_behav xil_defaultlib.riscv_io_system xil_defaultlib.glbl -log elaborate.log    proc = subprocess.run(xelab_cmd, cwd=extract_path, check=False)
		if proc.returncode:
			self.print_error("Error in elaboration")
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
		self.print_info(TermColor.BLUE, " Starting Simulation")
		#tmp_design_name = str(design_name + "#work.glbl")
		tmp_design_name = str(design_name)
		simulation_log_filename = str(tcl_toplevel + "_tcl_simulation.txt")
		simulation_log_filepath = extract_lab_path / simulation_log_filename
		xsim_cmd = ["xsim", "-nolog", tmp_design_name, "-tclbatch", temp_tcl_filename ]
		if not self.subprocess_file_print(simulation_log_filepath, xsim_cmd, extract_lab_path ):
			self.print_error("Failed simulation")
			return False
		return True

class build_bitstream(lab_test):

	def perform_test(self, extract_path, design_name, pre_source_filenames, hdl_filenames, \
			xdl_filenames, part, implement_build = True, create_dcp = False ):

		'''
		Build a bitstream
			extract_path: str
				The path where build files have been extracted
			build: list
				The "build" tuple
		'''
		bitfile_filename = str(design_name + ".bit")
		dcp_filename = str(design_name + ".dcp")

		self.print_info("Attempting to build bitfile",bitfile_filename)

		# Create tcl build script (the build will involve executing this script)
		tcl_build_script_filename = str(design_name + "_buildscript.tcl")
		tmp_tcl = extract_path / tcl_build_script_filename

		log = open(tmp_tcl, 'w')
		log.write('# Bitfile Generation script (non-project mode)\n')
		log.write('#\n')
		#log.write('# Set the part\n')
		#log.write('link_design -part ' + BASYS3_PART +'\n')
		if pre_source_filenames:
			log.write('# Pre-build source files\n')
			for pre_source_filename in pre_source_filenames:
				log.write('source '+ pre_source_filename+'\n')

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
		if not self.check_executable_existence(["vivado", "-version"]):
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

