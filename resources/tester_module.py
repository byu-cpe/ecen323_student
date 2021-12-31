#!/usr/bin/python3

'''
Script for extracting a student submission from a GitHub repository and
checking the submission.

TODO:
- Add modules for assembly
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

import lab_passoff
from lab_passoff import TermColor

class tester_module():
	""" Super class for all test modules """

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return "BASE MODULE"

	def perform_test(self, lab_test):
		''' This is the function that should be overridden by a test module. '''
		lab_test.print_print_warning("This should be overridden")
		return False

class simulation_module(tester_module):
	''' A tester module that performs simulations with Vivado tools. This includes functions
	for analyzing, elaborating, and simulating. This should be extended.

	TODO: Add support for analyzing VHDL and verilog
	'''

	def __init__(self, sim_top_module_name, hdl_sim_keylist):
		''' Initialize the top module name and the keylist for simulation HDL files '''
		self.sim_top_module = sim_top_module_name
		self.hdl_sim_keylist = hdl_sim_keylist

	def analyze_hdl_files(self, lab_test, hdl_filename_list, log_basename, analyze_cmd):
		''' Perform HDL analysis on a set of files. This is a generic function and should
		be called by another function to specify the actual command.  '''
		
		# See if the executable is even in the path
		if not lab_test.check_executable_existence(["xvlog", "--version"]):
			return False

		# Analyze all of the files associated with the TCL simulation set
		lab_test.print_info(TermColor.BLUE, " Analyzing source files")

		analyze_log_filename = str(log_basename + "_analyze.txt")
		self.analyze_log_filepath = lab_test.execution_path / analyze_log_filename
		for filename in hdl_filename_list:
			analyze_cmd.append(filename)
		
		return_code = lab_test.subprocess_file_print(self.analyze_log_filepath, analyze_cmd, lab_test.execution_path )
		if return_code != 0 :
			lab_test.print_error("Failed simulation")
			return False

		return True

	def analyze_sv_files(self, lab_test, log_basename):
		''' Perform HDL analysis on a set of files '''
		
		# Resolve the filenames
		hdl_filename_list = lab_test.get_filenames_from_keylist(self.hdl_sim_keylist)

		sv_xvlog_cmd = ["xvlog", "--nolog", "-sv", ]
		return self.analyze_hdl_files(lab_test, hdl_filename_list, log_basename, sv_xvlog_cmd)

	def elaborate(self, lab_test):
		# Elaborate design
		design_name = self.sim_top_module
		lab_test.print_info(TermColor.BLUE, " Elaborating")
		elaborate_log_filename = str(self.sim_top_module + "_elaborate.txt")
		self.elaborate_log_filepath = lab_test.execution_path / elaborate_log_filename

		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name, "work.glbl" ]
		xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name ]

		return_code = lab_test.subprocess_file_print(self.elaborate_log_filepath, xelab_cmd, lab_test.execution_path )

		if return_code != 0:
			lab_test.print_error("Failed simulation")
			return False

		return True

	def simulate(self,lab_test,xsim_opts=[]):
		# Simulate
		#extract_lab_path = lab_test.submission_lab_path
		lab_test.print_info(TermColor.BLUE, " Starting Simulation")
		simulation_log_filename = str(self.sim_top_module + "_simulation.txt")
		self.simulation_log_filepath = lab_test.execution_path / simulation_log_filename
		# default simulation commands
		xsim_cmd = ["xsim", "-nolog", self.sim_top_module,]
		# Add options from function parameters
		for opt in xsim_opts:
			xsim_cmd.append(opt)

		return_code = lab_test.subprocess_file_print(self.simulation_log_filepath, xsim_cmd, lab_test.execution_path )
		if return_code != 0:
			lab_test.print_error("Failed simulation")
			return False
		return True

class tcl_simulation(simulation_module):
	''' An object that represents a tcl_simulation test. Extends simulation_module
	'''
	def __init__(self,tcl_filename_key, tcl_sim_top_module, hdl_sim_keylist):
		super().__init__(tcl_sim_top_module,hdl_sim_keylist)

		self.tcl_filename_key = tcl_filename_key

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("TCL Simulation ({})",self.tcl_filename_key)

	def perform_test(self, lab_test):
		''' 
		Perform a simulation of a module with a Tcl script.
			sim_path: the path where the simulation should take place
			tcl_list: the list of items associated with a tcl simulation
		'''
		
		if not self.analyze_sv_files(lab_test,self.sim_top_module):
			return False
		if not self.elaborate(lab_test):
			return False

		lab_path = lab_test.submission_lab_path
		design_name = self.sim_top_module
		tcl_filename = lab_test.get_filename_from_key(self.tcl_filename_key)

		# Modify TCL simulation script (add 'quit' command to end)
		temp_tcl_filename = str(design_name + "_tempsim.tcl")
		src_tcl = lab_test.execution_path / tcl_filename
		tmp_tcl = lab_test.execution_path / temp_tcl_filename
		print(lab_test.execution_path,tmp_tcl,src_tcl)
		shutil.copyfile(src_tcl, tmp_tcl)

		log = open(tmp_tcl, 'a')
		log.write('\n# Add Exit quit command\n')
		log.write('quit\n')
		log.close()

		# Simulate
		tcl_sim_opts = [ "-tclbatch", temp_tcl_filename ]
		return self.simulate(lab_test,xsim_opts = tcl_sim_opts)


class testbench_simulation(simulation_module):
	''' An object that represents a tcl_simulation test.
	'''
	def __init__(self,testbench_description, testbench_top, hdl_sim_keylist, xe_options_list):
		super().__init__(testbench_top,hdl_sim_keylist)
		self.testbench_description = testbench_description
		#self.testbench_top = testbench_top
		#self.hdl_sim_keylist = hdl_sim_keylist
		self.xe_options_list = xe_options_list

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("Testbench Simulation \"{}\" ({})",self.testbench_description, self.sim_top_module)
		
	def perform_test(self, lab_test):
		''' 
		Perform a simulation of a module with a Tcl script.
			sim_path: the path where the simulation should take place
			tcl_list: the list of items associated with a tcl simulation
		'''
		
		hdl_filename_list = lab_test.get_filenames_from_keylist(self.hdl_sim_keylist)
		extract_lab_path = lab_test.submission_lab_path

		if not self.analyze_sv_files(lab_test,self.sim_top_module):
			return False
		if not self.elaborate(lab_test):
			return False
		
		# Simulate
		#tb_sim_opts = [ "-runall", "--onerror", "quit" ]
		tb_sim_opts = [ "-runall", ]
		sim_result = self.simulate(lab_test, xsim_opts=tb_sim_opts)
		if not sim_result:
			return False

		# Parse the simulation output to see if there are errors
		return self.check_for_no_errors(lab_test,["Errors", "Error", "ERROR"])

	def check_for_no_errors(self, lab_test, error_strings):
		with open(self.simulation_log_filepath) as sim_file:
			for line in sim_file:
				for error_string in error_strings:
					if error_string in line:
						lab_test.print_error("Error in simulation:",line)
						return False
		print("No errors in testbench simulation")
		#tb_sim_opts = [ "-runall", "--onerror", "quit" ]
		return True

class build_bitstream(tester_module):
	''' An object that represents a tcl_simulation test.
	'''

	def __init__(self,design_name, xdl_key_list, hdl_key_list, implement_build = True, create_dcp = False):
		self.design_name = design_name
		self.xdl_key_list = xdl_key_list
		self.hdl_key_list = hdl_key_list
		self.implement_build = implement_build
		self.create_dcp = create_dcp

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("Synthesis/Bitstream Gen ({})",self.design_name)

	def perform_test(self, lab_test):

		part = lab_test.BASYS3_PART
		bitfile_filename = str(self.design_name + ".bit")
		dcp_filename = str(self.design_name + ".dcp")
		#extract_path = lab_test.submission_lab_path
		hdl_filenames = lab_test.get_filenames_from_keylist(self.hdl_key_list)
		xdl_filenames = lab_test.get_filenames_from_keylist(self.xdl_key_list)

		# Get name of new settings file (need to make it relative to execution path)
		rel_path = os.path.relpath(os.path.relpath(lab_test.submission_lab_path,lab_test.execution_path))
		new_path = os.path.join(rel_path,lab_test.NEW_PROJECT_SETTINGS_FILENAME)
		pre_script_filenames = [ new_path ]
		lab_test.print_info("Attempting to build bitfile",bitfile_filename)

		# Create tcl build script (the build will involve executing this script)
		tcl_build_script_filename = str(self.design_name + "_buildscript.tcl")
		tmp_tcl = lab_test.execution_path / tcl_build_script_filename

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
		if self.implement_build:
			log.write('# Add XDC file\n')
			for xdc_filename in xdl_filenames:
				log.write('read_xdc ' + xdc_filename + '\n')
		log.write('# Synthesize design\n')
		#log.write('synth_design -top ' + design_name + ' -flatten_hierarchy full\n')
		log.write('synth_design -top ' + self.design_name + ' -part ' + part + '\n')
		if self.implement_build:    
			log.write('# Implement Design\n')
			log.write('place_design\n')
			log.write('route_design\n')
			checkpoint_filename = str(self.design_name + ".dcp")
			log.write('write_checkpoint ' + checkpoint_filename + ' -force\n')
			log.write('write_bitstream -force ' + bitfile_filename +'\n')
		if self.create_dcp:
			log.write('# Create DCP\n')
			log.write(str.format("write_checkpoint {} -force\n",dcp_filename))
		log.write('# End of build script\n')
		log.close()

		# See if the executable is even in the path
		if not lab_test.check_executable_existence(["vivado", "-version"]):
			return False

		implementation_log_filename = str(self.design_name + "_implementation.txt")
		implementation_log_filepath = lab_test.execution_path / implementation_log_filename
		build_cmd = ["vivado", "-nolog", "-mode", "batch", "-nojournal", "-source", tcl_build_script_filename]


		return_code = lab_test.subprocess_file_print(implementation_log_filepath, build_cmd, lab_test.execution_path )
		if return_code != 0:
			lab_test.print_error("Failed Implemeneetation")
			return False
		return True
