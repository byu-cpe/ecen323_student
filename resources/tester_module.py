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

	def __init__(self, sim_top_module_name, hdl_sim_keylist, include_dirs=[], generics=[], vhdl_files=[], use_glbl=False ):
		''' Initialize the top module name and the keylist for simulation HDL files '''
		self.sim_top_module = sim_top_module_name
		self.hdl_sim_keylist = hdl_sim_keylist
		self.include_dirs = include_dirs
		self.generics = generics
		self.vhdl_files = vhdl_files
		self.use_glbl = use_glbl

	def analyze_hdl_files(self, lab_test, hdl_filename_list, log_basename, analyze_cmd,consider_include=True):
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

		# Add Include DIRS
		if len(self.include_dirs) > 0 and consider_include:
			# Need to adjust include path relative to execution path
			rel_path = os.path.relpath(os.path.relpath(lab_test.submission_lab_path,lab_test.execution_path))
			for include_dir in self.include_dirs:
				analyze_cmd.append("-i")
				rel_include_dir = os.path.join(rel_path,include_dir)
				analyze_cmd.append(rel_include_dir)

		#print(analyze_cmd)
		#print(lab_test.execution_path)
		return_code = lab_test.subprocess_file_print(self.analyze_log_filepath, analyze_cmd, lab_test.execution_path )
		if return_code != 0 :
			lab_test.print_error("Failed analyze")
			return False

		return True

	def analyze_sv_files(self, lab_test, log_basename):
		''' Perform HDL analysis on a set of files '''
		
		# Resolve the filenames
		hdl_filename_list = lab_test.get_filenames_from_keylist(self.hdl_sim_keylist)

		sv_xvlog_cmd = ["xvlog", "--nolog", "-sv", ]
		# (include DIRS added in analyze_hdl_files)
		return self.analyze_hdl_files(lab_test, hdl_filename_list, log_basename, sv_xvlog_cmd)

	def analyze_vhdl_files(self, lab_test, log_basename):
		''' Perform HDL analysis on a set of files '''
		
		# Resolve the filenames
		hdl_filename_list = lab_test.get_filenames_from_keylist(self.vhdl_files)

		xvhdl_cmd = ["xvhdl", "--nolog", ]
		return self.analyze_hdl_files(lab_test, hdl_filename_list, log_basename, xvhdl_cmd,consider_include=False)

	def elaborate(self, lab_test):
		# Elaborate design
		design_name = self.sim_top_module
		lab_test.print_info(TermColor.BLUE, " Elaborating")
		elaborate_log_filename = str(self.sim_top_module + "_elaborate.txt")
		self.elaborate_log_filepath = lab_test.execution_path / elaborate_log_filename

		#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name, "work.glbl" ]
		xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver"]
		if len(self.generics) > 0:
			# Add generic options
			for generic in self.generics:
				xelab_cmd.append("-generic_top")
				#xelab_cmd.append(str.format("\"{}\"",generic))
				xelab_cmd.append(str.format("{}",generic))
		xelab_cmd.append( design_name )
		#xelab_cmd.append( str.format("work.{}",design_name ))
		if self.use_glbl:
			#xelab_cmd.extend( ["-L", "unisims_ver", "work.glbl" ])
			#xelab_cmd.extend( ["-L", "unisims_ver", "--relax", "work.glbl" ])
			xelab_cmd.extend( ["-L", "unisims_ver", "--relax", "glbl", "-s", str.format("work.{}",design_name ) ])

		return_code = lab_test.subprocess_file_print(self.elaborate_log_filepath, xelab_cmd, lab_test.execution_path )

		if return_code != 0:
			lab_test.print_error("Failed Elaborate")
			print(xelab_cmd)
			print(lab_test.execution_path)
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
			print(xsim_cmd)
			print(lab_test.execution_path)
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
		if len(self.vhdl_files) > 0:
			if not self.analyze_vhdl_files(lab_test,self.sim_top_module):
				return False

		# Analyze
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

class tcl_simulation2(simulation_module):
	''' A modified version of the TCL simulation that sources the student file from
	a script rather than running the script directly. Will exit whether or not the
	student script finishes.
	'''
	def __init__(self,tcl_filename_key, tcl_sim_top_module, hdl_sim_keylist,
		include_dirs=[], generics=[], vhdl_files=[], use_glbl = False):
		super().__init__(tcl_sim_top_module,hdl_sim_keylist, include_dirs, generics, vhdl_files, use_glbl)

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

		# Analyze hdl		
		if not self.analyze_sv_files(lab_test,self.sim_top_module):
			return False
		debug = False
		if len(self.vhdl_files) > 0:
			if not self.analyze_vhdl_files(lab_test,self.sim_top_module):
				return False
		if debug:
			input("Pause after analyze")

		# Elaborate hdl		
		if not self.elaborate(lab_test):
			return False
		if debug:
			input("Pause after elaborate")

		lab_path = lab_test.submission_lab_path
		design_name = self.sim_top_module
		tcl_filename = lab_test.get_filename_from_key(self.tcl_filename_key)

		# Create a temporary tcl script that calls the student script
		temp_tcl_filename = str(design_name + "_tempsim2.tcl")
		src_tcl = lab_test.execution_path / tcl_filename
		tmp_tcl = lab_test.execution_path / temp_tcl_filename
		log = open(tmp_tcl, 'a')
		log.write('# Temporary script that sources TCL file\n')
		log.write(str.format('if {{ [ catch {{ source {} }} ] }} {{\n',tcl_filename))
		log.write("    puts \"Error with TCL Script\"\n")
		log.write("    # Exit script with an error\n")
		log.write("    exit 1\n")
		log.write("}\n")
		log.write('# Quit the simulator no matter what happens in the TCL script\n')
		log.write('quit\n')
		log.close()

		print(lab_test.execution_path,tmp_tcl,src_tcl)

		# Simulate
		tcl_sim_opts = [ "-tclbatch", temp_tcl_filename ]
		return self.simulate(lab_test,xsim_opts = tcl_sim_opts)


class testbench_simulation(simulation_module):
	''' An object that represents a tcl_simulation test.
	'''
	def __init__(self, testbench_description, testbench_top, hdl_sim_keylist, xe_options_list, include_dirs=[], generics=[], vhdl_files=[] ):
		super().__init__(testbench_top,hdl_sim_keylist,include_dirs,generics,vhdl_files)
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
		
		#hdl_filename_list = lab_test.get_filenames_from_keylist(self.hdl_sim_keylist)
		#extract_lab_path = lab_test.submission_lab_path

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
	''' An object that represents a bitstream implementation test.
	'''

	def __init__(self,design_name, xdl_key_list, hdl_key_list, implement_build = True, 
		create_dcp = False,  include_dirs = [], vhdl_key_list = [], generics=[]):
		self.design_name = design_name
		self.xdl_key_list = xdl_key_list
		self.hdl_key_list = hdl_key_list
		self.implement_build = implement_build
		self.create_dcp = create_dcp
		self.include_dirs = include_dirs
		self.vhdl_key_list = vhdl_key_list
		self.generics=generics

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("Synthesis/Bitstream Gen ({})",self.design_name)

	def perform_test(self, lab_test):

		part = lab_test.BASYS3_PART
		bitfile_filename = str(self.design_name + ".bit")
		dcp_filename = str(self.design_name + ".dcp")
		#extract_path = lab_test.submission_lab_path
		hdl_filenames = lab_test.get_filenames_from_keylist(self.hdl_key_list)
		#print(self.hdl_key_list)
		#print(hdl_filenames)
		xdl_filenames = lab_test.get_filenames_from_keylist(self.xdl_key_list)
		vhdl_filenames = lab_test.get_filenames_from_keylist(self.vhdl_key_list)
		#print(self.vhdl_key_list)
		#print(vhdl_filenames)

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
		log.write('# Add verilog sources\n')
		for hdl_filename in hdl_filenames:
			#src = get_filename_from_key(src_key)
			log.write('read_verilog -sv ' + hdl_filename + '\n')
		# Read VHDL files
		if len(vhdl_filenames) > 0:
			log.write('# Add VHDL sources\n')
			for vhdl_filename in vhdl_filenames:
				log.write('read_vhdl ' + vhdl_filename + '\n')
		# Read xdc files
		if self.implement_build:
			log.write('# Add XDC file\n')
			for xdc_filename in xdl_filenames:
				log.write('read_xdc ' + xdc_filename + '\n')
		log.write('# Synthesize design\n')
		# Create synthesis command
		synth_command = 'synth_design -top ' + self.design_name + ' -part ' + part
		if len(self.include_dirs) > 0:
			# Need to adjust include path relative to execution path
			rel_path = os.path.relpath(os.path.relpath(lab_test.submission_lab_path,lab_test.execution_path))
			# -include_dirs {C:/data/include1 C:/data/include2}
			synth_command += ' -include {'
			for include_dir in self.include_dirs:
				rel_include_dir = os.path.join(rel_path,include_dir)
				synth_command += rel_include_dir + " "
			synth_command += '}'
		if len(self.generics) > 0:
			for generic in self.generics:
				synth_command += str.format(" -generic {}",generic)
		synth_command += '\n'
		log.write(synth_command)

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


class rars_raw(tester_module):
	''' 
	A tester module that uses the Java RARs assembler.

	This base class contains:
	- Name of JAR
	- key for assembly language file
	- Set of RARs options
	'''

	def __init__(self, asm_filekey, rars_options=[]):
		self.rars_options = rars_options
		self.asm_filekey = asm_filekey
		#self.RARS_FILENAME = "../resources/rars1_4.jar"
		self.RARS_FILENAME = "resources/rars1_4.jar"

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("RARS with file ({})",self.asm_filekey)

	def perform_test(self, lab_test):
		asm_filename = lab_test.get_filename_from_key(self.asm_filekey)

		print( "RARS execution of", asm_filename,"with options",self.rars_options)

		jar_file_path = lab_test.submission_top_path / self.RARS_FILENAME

		#rars_cmd = ["java", "-jar", self.RARS_FILENAME, ]
		rars_cmd = ["java", "-jar", jar_file_path, ]
		rars_cmd.extend(self.rars_options)
		rars_cmd.append(asm_filename)
		rars_log_filename = str(self.asm_filekey + "_exec.txt")
		rars_log_filepath = lab_test.execution_path / rars_log_filename
		#proc = subprocess.run(rars_cmd, cwd=lab_test.execution_path,check=False)
		#if proc.returncode:
		#	lab_test.print_warning("Failed to simulate assembler files")
		#	return False
		return_code = lab_test.subprocess_file_print(rars_log_filepath, rars_cmd, lab_test.execution_path )
		if return_code:
			lab_test.print_warning("Failed to simulate assembler files")
			return False
		return True

class rars_sim_print(rars_raw):
	''' 
	Assembles the given file and then runs the file with output
	'''

	def __init__(self, asm_filekey):
		super().__init__(asm_filekey)
		#self.asm_filekey = asm_filekey
		#self.RARS_FILENAME = "../resources/rars1_4.jar"

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("RARS assembly and run with file ({})",self.asm_filekey)

	def perform_test(self, lab_test):
		# Bug! Using key for filename rather than actual file
		asm_filename = lab_test.get_filename_from_key(self.asm_filekey)
		hex_filename = str.format("{}.txt",self.asm_filekey)
		# TODO: SHould add a "ae1" to these options so that an error is given as a return code for failed assembly
		self.rars_options = ["sp","ic","100000","dump",".text","HexText",hex_filename,]
		result = super().perform_test(lab_test)
		if not result:
			return False
		# Now print the output of each compiled file
		print("Memory contents")
		hex_filepath = lab_test.execution_path / hex_filename
		f = open(hex_filepath,'r')
		file_contents = f.read()
		print(file_contents)
		f.close()
		return True

		
class rars_mem_file(rars_raw):
	''' Assembles the given file and generates an ascii memory file
	'''

	def __init__(self, asm_filekey, generate_data_mem=False):
		super().__init__(asm_filekey)
		#self.asm_filekey = asm_filekey
		#self.RARS_FILENAME = "../resources/rars1_4.jar"
		self.generate_data_mem = generate_data_mem

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("RARS memory generation with file ({})",self.asm_filekey)

	def perform_test(self, lab_test):
		asm_filename = lab_test.get_filename_from_key(self.asm_filekey)
		asm_path = pathlib.Path(asm_filename)
		asm_basename = asm_path.stem
		asm_rootname = asm_path.name
		i_mem_filename = str.format("{}_text.mem",asm_basename)		
		d_mem_filename = str.format("{}_data.mem",asm_basename)		
		# Initial options "ae1" - return a 1 return code with assembly error
		self.rars_options = ["ae1", "mc", "CompactTextAtZero", "a", "dump", ".text", "HexText", i_mem_filename]
		# Add options for data memory
		if self.generate_data_mem:
			self.rars_options.extend(["dump", ".data", "HexText", d_mem_filename])
		# Append orginal filename
		#self.rars_options.append(asm_rootname)
		# Run test
		result = super().perform_test(lab_test)
		if not result:
			return False
		return True

class update_bistream(tester_module):
	''' 
	A base update bitstream class for generating a new bitstream using the 'load_mem.tcl' vivado script
	'''
	def __init__(self, input_dcp_filename, bitstream_filename, output_dcp = ""):
		self.input_dcp_filename = input_dcp_filename
		self.bitstream_filename = bitstream_filename
		self.output_dcp = output_dcp

class update_bitstream_mem(tester_module):
	''' 
	A tester module that updates riscv bitstream memory with a program

	'''

	def __init__(self, text_mem_filename, data_mem_filename, 
		input_dcp_filename, bitstream_filename, output_dcp = ""):
		self.text_mem_filename = text_mem_filename
		self.data_mem_filename = data_mem_filename
		self.input_dcp_filename = input_dcp_filename
		self.bitstream_filename = bitstream_filename
		self.output_dcp = output_dcp

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("Bitstream Updating with ({},{})",
			self.text_mem_filename, self.data_mem_filename)

	def perform_test(self, lab_test):

		#print( "RARS execution of", asm_filename,"with options",self.rars_options)

		load_mem_path = lab_test.submission_top_path / "resources/load_mem.tcl"

		updatemem_cmd = ["vivado", "-mode", "batch", "-source", str(load_mem_path), 
			 "-tclargs", "updateMem",
			self.input_dcp_filename, self.text_mem_filename, self.data_mem_filename, 
			self.bitstream_filename]
		if self.output_dcp != "":
			updatemem_cmd.append(self.output_dcp)
		print(updatemem_cmd)
		proc = subprocess.run(updatemem_cmd, cwd=lab_test.execution_path,check=False)
		if proc.returncode:
			lab_test.print_warning("Failed to update bitfile")
			return False
		return True


class update_font_mem(tester_module):
	''' 
	A tester module that updates riscv bitstream memory with a program

	'''

	def __init__(self,input_dcp_filename, font_memory_file, bitstream_filename, output_dcp = ""):
		self.font_file = font_memory_file
		self.input_dcp_filename = input_dcp_filename
		self.bitstream_filename = bitstream_filename
		self.output_dcp = output_dcp

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("Bitstream Font Update with ({})",
			self.font_file)

	def perform_test(self, lab_test):

		#print( "RARS execution of", asm_filename,"with options",self.rars_options)

		load_mem_path = lab_test.submission_top_path / "resources/load_mem.tcl"

		updatemem_cmd = ["vivado", "-mode", "batch", "-source", str(load_mem_path), 
			 "-tclargs", "updateFont",
			self.input_dcp_filename, self.font_file,
			self.bitstream_filename]
		if self.output_dcp != "":
			updatemem_cmd.append(self.output_dcp)
		print(updatemem_cmd)
		print(lab_test.execution_path)
		proc = subprocess.run(updatemem_cmd, cwd=lab_test.execution_path,check=False)
		if proc.returncode:
			lab_test.print_warning("Failed to update bitfile")
			return False
		return True

class update_background_mem(tester_module):
	''' 
	A tester module that updates riscv bitstream memory with a program

	'''

	def __init__(self,input_dcp_filename, background_memory_file, bitstream_filename, output_dcp = ""):
		self.background_file = background_memory_file
		self.input_dcp_filename = input_dcp_filename
		self.bitstream_filename = bitstream_filename
		self.output_dcp = output_dcp

	def module_name(self):
		''' returns a string indicating the name of the module. Used for logging. '''
		return str.format("Bitstream Background Update with ({})",
			self.background_file)

	def perform_test(self, lab_test):

		#print( "RARS execution of", asm_filename,"with options",self.rars_options)

		load_mem_path = lab_test.submission_top_path / "resources/load_mem.tcl"

		updatemem_cmd = ["vivado", "-mode", "batch", "-source", str(load_mem_path), 
			 "-tclargs", "updateBackground",
			self.input_dcp_filename, self.background_file,
			self.bitstream_filename]
		if self.output_dcp != "":
			updatemem_cmd.append(self.output_dcp)
		print(updatemem_cmd)
		print(lab_test.execution_path)
		proc = subprocess.run(updatemem_cmd, cwd=lab_test.execution_path,check=False)
		if proc.returncode:
			lab_test.print_warning("Failed to update bitfile")
			return False
		return True
