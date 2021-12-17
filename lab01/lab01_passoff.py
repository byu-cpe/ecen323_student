#!/usr/bin/python3

'''
Script for extracting a student submission from a GitHub repository and
checking the submission.
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

#user_files = {}
#for key in submission_files:
#    user_files[key] = submission_files[key]
#for key in wget_files:
#    user_files[key] = wget_files[key][1]


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



# Color constants for terminal
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


# Print message to console with a color
def print_color(color, *msg):
	""" Print a message in color """
	print(color + " ".join(str(item) for item in msg), TermColor.END)


def error(*msg, returncode=-1):
	""" Print an error message and exit program """
	print_color(TermColor.RED, "ERROR:", " ".join(str(item) for item in msg))
	sys.exit(returncode)


# Generate script that indicates filenames of included files.
# Returns a 'pathlib' filename for the generated file.
def pickle_files(python_include_file,favorite_color):
	# Create tcl build script
	print_color(TermColor.BLUE, "Creating include script", python_include_file)
	lab_files_dump = open(python_include_file, 'w')
	pickle.dumps( favorite_color, lab_files_dump)

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


def download_remote_files(extract_path):
	# "testbench"     : [ "http://ecen323wiki.groups.et.byu.net/media/lab_06/", "tb_multicycle_control.sv" ],
	for remote_file_key in test_files.keys():
		remote_url = test_files[remote_file_key][0]
		remote_filename = test_files[remote_file_key][1]
		wget_url = str(remote_url + remote_filename)
		wget_file = extract_path / remote_filename
		# -O <name of target file> URL will overwrite file if it exists. Doesn't matter where you run command
		wget_cmd = ["wget", "-O", wget_file, wget_url ]
		print_color(TermColor.YELLOW, "Attempting to dowload remote file:",remote_filename)
		proc = subprocess.run(wget_cmd, check=False)
		if proc.returncode:
			print_color(TermColor.RED, "Failed to download file")
			return False

	return True

# execute a procoess and save the stdout. Print the stdout as it occurs. Return the process
# for subsequent processing
def executeProcess(command):
	#process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	process = subprocess.Popen(command, shell=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

	# Poll process for new output until finished
	while True:
		nextline = process.stdout.readline()
		if nextline == '' and process.poll() is not None:
			break
		sys.stdout.write(nextline)
		sys.stdout.flush()

	#output = process.communicate()[0]
	#exitCode = process.returncode
	#if (exitCode == 0):
	#    return output
	#else:
	#    raise ProcessException(command, exitCode, output)
	return process

def simulate_tcl_solution(extract_lab_path, tcl_tuple):
	''' 
	Perform a simulation of a module with a Tcl script.
		sim_path: the path where the simulation should take place
		tcl_list: the list of items associated with a tcl simulation
	'''
	# extract the tcl simulation tuple
	(tcl_filekey, tcl_toplevel, tcl_hdl_list) = tcl_tuple
	
	# Get the original TCL filename
	tcl_filename = get_filename_from_key(tcl_filekey)
	print_color(TermColor.BLUE, "Attempting simulation of TCL script:", tcl_filename)

	# See if the executable is even in the path
	try:
		proc = subprocess.run(["xvlog", "--version"])
	except OSError:
		print_color(TermColor.RED, "xvlog not in shell environment")
		return False

	# Analyze all of the files associated with the TCL simulation set
	print_color(TermColor.BLUE, " Analyzing source files")
	for src_key in tcl_hdl_list:
		src_filename = get_filename_from_key(src_key)
		if not src_filename:
			print_color(TermColor.RED, "No filename for key", src_key)
			return False
		xvlog_cmd = ["xvlog", "--nolog", "-sv", src_filename ]
		proc = subprocess.run(xvlog_cmd, cwd=extract_lab_path, check=False)
		if proc.returncode:
			return False

	# xvlog -sv alu.sv regfile.sv riscv_alu_constants.sv riscv_datapath_constants.sv riscv_io_multicycle.v riscv_multicycle.sv riscv_simple_datapath.sv glbl.v
	# xelab -L unisims_ver riscv_io_system work.glbl
	#return False

	# Elaborate design
	design_name = tcl_toplevel
	print_color(TermColor.BLUE, " Elaborating")
	#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name, "work.glbl" ]
	xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name ]
	proc = subprocess.run(xelab_cmd, cwd=extract_lab_path, check=False)

	#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", design_name, "work.glbl" ]
	#xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L xil_defaultlib", "-L unisims_ver", "-L unimacro_ver", design_name, "work.glbl" ]
	#xelab  -wto f006d1b2ec3040b5bab73404505d9a2c --debug typical --relax --mt 2 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip --snapshot riscv_io_system_behav xil_defaultlib.riscv_io_system xil_defaultlib.glbl -log elaborate.log    proc = subprocess.run(xelab_cmd, cwd=extract_path, check=False)
	if proc.returncode:
		print("Error in elaboration")
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
	print_color(TermColor.BLUE, " Starting Simulation")
	#tmp_design_name = str(design_name + "#work.glbl")
	tmp_design_name = str(design_name)
	xsim_cmd = ["xsim", "-nolog", tmp_design_name, "-tclbatch", temp_tcl_filename ]
	#print(xsim_cmd)
	proc = subprocess.run(xsim_cmd, cwd=extract_lab_path, check=False)
	if proc.returncode:
		return False
	return True

def simulate_testbench_solution(extract_path, testbench_set):
	simulation_description = testbench_set[0]
	print_color(TermColor.BLUE, "Attempting simulation:",simulation_description)

	# Analyze design files
	print_color(TermColor.BLUE, " Analyzing source files")

	# Determine files to include in testbench set
	testbench_filenames = []
	# wget testbench files
	for key in testbench_set[3]:
		testbench_filenames.append(test_files[key][1])
	# submission files
	for key in testbench_set[2]:
		testbench_filenames.append(test_files[key])

	# Check to see if each file exists
	for filename in testbench_filenames:
		testbench_file = extract_path / filename
		if not testbench_file.exists():
			print_color(TermColor.RED, "File missing for simulation:",filename)
			return False
	
	# Analyze each file
	for src in testbench_filenames:
		print_color(TermColor.BLUE, "  ",src)
		xvlog_cmd = ["xvlog", "--nolog", "-sv", src ]
		proc = subprocess.run(xvlog_cmd, cwd=extract_path, check=False)
		if proc.returncode:
			return False

	# Elaborate design
	testbench_name = testbench_set[1]
	print_color(TermColor.BLUE, " Elaborating")

	# see if we are using windows or linux
	oskeyname = 'OS'
	if oskeyname in os.environ and os.environ[oskeyname]:
		# Windows
		print_color(TermColor.BLUE, "   Using Windows Script")
		batch_filename = "xelab_ex.bat"
		batch_file_path = extract_path / batch_filename
		batch_file = open(batch_file_path, 'w') 
		batch_file.write("xelab --debug typical --nolog ")
		for option in testbench_set[3]:
			batch_file.write(option+" ")
		batch_file.write(testbench_name+'\n')
		batch_file.close()
		# Set permissions so script can see and execute batch file
		os.chmod(batch_file_path, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)
		print(extract_path)
		proc = subprocess.run(batch_file_path, cwd=extract_path, check=False)
		if proc.returncode:
			print_color(TermColor.YELLOW, " Sim Err")
			return False
	else:
		# Unix
		print_color(TermColor.BLUE, "   Using NonWindows Script")
		xelab_cmd = ["xelab", "--debug", "typical", "--nolog", testbench_name ]
		for option in testbench_set[3]:
			xelab_cmd.append(option)
		print(xelab_cmd)
		proc = subprocess.run(xelab_cmd, cwd=extract_path, check=False)
		if proc.returncode:
			return False

	# Simulate
	print_color(TermColor.BLUE, " Simulating")
	xsim_cmd = ["xsim", "-nolog", testbench_name, "-runall"]
	#proc = subprocess.run(xsim_cmd, cwd=extract_path, check=False, capture_output=True)
	proc = subprocess.run(xsim_cmd, cwd=extract_path, check=False)
	if proc.returncode:
		print_color(TermColor.YELLOW, " Sim Err")
		return False
	#print_color(TermColor.YELLOW, " Sim OK. Std Out")
	#print(proc.stdout.decode('utf-8'))
	return True

def build_solution(extract_path, build_tuple):
	'''
	Build a bitstream
		extract_path: str
			The path where build files have been extracted
		build: list
			The "build" tuple
	'''
	(design_name, xdl_key_list, hdl_key_list, implement_build, create_dcp) = build_tuple
	#design_name = build_set[0]
	#implement = build_set[3]
	#dcp =  build_set[4]

	bitfile_filename = str(design_name + ".bit")
	dcp_filename = str(design_name + ".dcp")

	print_color(TermColor.BLUE, "Attempting to build bitfile",bitfile_filename)

	# Create tcl build script (the build will involve executing this script)
	tcl_build_script_filename = str(design_name + "_buildscript.tcl")
	tmp_tcl = extract_path / tcl_build_script_filename

	log = open(tmp_tcl, 'w')
	log.write('# Bitfile Generation script\n')
	log.write('#\n')
	log.write('# Set the part\n')
	log.write('link_design -part ' + BASYS3_PART +'\n')
	log.write('# Add sources\n')

	# Read files
	for src_key in hdl_key_list:
		src = get_filename_from_key(src_key)
		log.write('read_verilog -sv ' + src + '\n')
	if implement_build:
		log.write('# Add XDC file\n')
		for xdc_key in xdl_key_list:
			src = get_filename_from_key(xdc_key)
			log.write('read_xdc ' + src + '\n')
	log.write('# Synthesize design\n')
	log.write('synth_design -top ' + design_name + ' -flatten_hierarchy full\n')
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
	try:
		proc = subprocess.run(["vivado", "--version"])
	except OSError:
		print_color(TermColor.RED, "vivado not in shell environment")
		return False

	# Generate bitfile
	build_cmd = ["vivado", "-nolog", "-mode", "batch", "-nojournal", "-source", tcl_build_script_filename]
	proc = subprocess.run(build_cmd, cwd=extract_path, check=False)
	if proc.returncode:
		return False

	# See if the bitfile exists (make sure it is newer)
	if implement_build:
		bitstream_file = extract_path / bitfile_filename
		if not bitstream_file.exists():
			print_color(TermColor.RED, "Bitstream file",bitfile_filename,"not created")
			return False
		else:
			print_color(TermColor.BLUE, "Bitstream file",bitstream_file,"exists")

	return True

# modify bitstream
def modify_bitstream(extract_path,file_set):
	newBitfileName = file_set[0]
	origDCPFilename = file_set[1]
	print_color(TermColor.BLUE, str.format("Attempting to make bitfile {} from {}",newBitfileName,origDCPFilename))

	# Find the DCP file
	dcp_file = extract_path / origDCPFilename
	if not dcp_file.exists():
		print_color(TermColor.RED, "DCP File does not exist:",origDCPFilename)
		return False

	# Modify the program
	step1DCP = str("step1.dcp")
	assemblyKeyName = file_set[2]
	fontKeyName = file_set[3]
	backgroundKeyName = file_set[4]
	# Update with program
	if assemblyKeyName == "":
		step1DCP = origDCPFilename
	else:
		# Get the name of assembly language file
		programBitFileName = "newCode.bit"
		print_color(TermColor.YELLOW, str.format("Attempting to update instruction memory"))
		asmFile = get_filename_from_key(assemblyKeyName)
		[text_filename, data_filename] = getHexTextFileNames(asmFile)
		#vivado -mode batch -source load_mem.tcl -tclargs updateMem <checkpoint filename> <.text memory file> <.data memory file> <new bitstream filename>
		updateCmd = ["vivado", "-mode", "batch", "-source", "load_mem.tcl", "-tclargs", "updateMem",
			origDCPFilename, text_filename, data_filename, programBitFileName, step1DCP ]
		proc = subprocess.run(updateCmd, cwd=extract_path, check=False)
		if proc.returncode:
			print_color(TermColor.RED, "Failed to Update memory with program file")
			return False
		# Copy the bitfile modified with the new program to the new bitfilename
		print(programBitFileName, newBitfileName)
		#shutil.copyfile(programBitFileName, newBitfileName)

	# Update font
	if fontKeyName == "":
		step2DCP = step1DCP
	else:
		fontBitFileName = "font.bit"
		print_color(TermColor.YELLOW, str.format("Attempting to update Font"))
		# Get the name of the font file
		fontFile = get_filename_from_key(fontKeyName)
		step2DCP = "step2.dcp"
		# vivado -mode batch -source load_mem.tcl -tclargs updateFont project.dcp font_mem_mod.txt font.bit font.dcp        #vivado -mode batch -source load_mem.tcl -tclargs updateMem <checkpoint filename> <.text memory file> <.data memory file> <new bitstream filename>
		updateCmd = ["vivado", "-mode", "batch", "-source", "load_mem.tcl", "-tclargs", "updateFont",
			step1DCP,  fontFile, fontBitFileName, step2DCP ]
		proc = subprocess.run(updateCmd, cwd=extract_path, check=False)
		if proc.returncode:
			print_color(TermColor.RED, "Failed to Update memory with font")
			return False
		# Copy the bitfile modified with the new font to the new bitfilename
		#shutil.copyfile(fontBitFileName, newBitfileName)

	# Update background
	if backgroundKeyName != "":
		backgroundBitFileName = "background.bit"
		print_color(TermColor.YELLOW, str.format("Attempting to update Character Background"))
		# Get the name of the font file
		backgroundFile = get_filename_from_key(backgroundKeyName)
		# vivado -mode batch -source load_mem.tcl -tclargs updateBackground font.dcp background_mem.txt back.bit back.dcp
		updateCmd = ["vivado", "-mode", "batch", "-source", "load_mem.tcl", "-tclargs", "updateBackground",
			step2DCP,  backgroundFile, newBitfileName ]
		print(updateCmd)
		proc = subprocess.run(updateCmd, cwd=extract_path, check=False)
		if proc.returncode:
			print_color(TermColor.RED, "Failed to Update memory with background")
			return False
		# Copy the bitfile modified with the new background to the new bitfilename
		#shutil.copyfile(backgroundBitFileName, newBitfileName)
	
	return True

# input is an assembly language filename (xxx.s)
# returns a list of the associated hexadecimal textfiles
# (i.e., xxx_inst.txt and xxx_data.txt)
def getHexTextFileNames(asmFilename):
	fileParts = asmFilename.split('.')  # Split string by '.'
	basename = fileParts[0]
	text_filename = str(basename + "_inst.txt")
	data_filename = str(basename + "_data.txt")
	filenames = [ text_filename, data_filename ]
	return filenames

# Run an assembly set
def run_assembly(extract_path,file_set):
	# See if the JAR exists, if not, download it
	jar_file = extract_path / JAR_FILENAME
	if not jar_file.exists():
		print_color(TermColor.YELLOW, "JAR file does not exist - will attempt to download")
		# -O <name of target file> URL will overwrite file if it exists. Doesn't matter where you run command
		wget_cmd = ["wget", "-O", jar_file, JAR_URL ]
		proc = subprocess.run(wget_cmd, check=False)
		if proc.returncode:
			print_color(TermColor.RED, "Failed to download RARS jar")
			return False
	# Perform simulation (and possible assembly)
	for f in assembly_simulate_sets:
		asm_key = f[0]
		asm_filename = get_filename_from_key(asm_key)
		print_color(TermColor.BLUE, "Attempting RARS simulation/assembly of", asm_filename)
		if f[3]:
			# Execute assembler
			rars_cmd = ["java", "-jar", JAR_FILENAME, "ic", "se1", "ae2", "nc"]
			# Add simulation specific parameters
			for param in f[1]:
				rars_cmd.append(param)
			# Add the file to simulation
			rars_cmd.append(asm_filename)
			print(rars_cmd)
			# Run command
			proc = subprocess.run(rars_cmd, cwd=extract_path, check=False)
			if proc.returncode:
				print_color(TermColor.RED, "Failed to simulate assembler files")
				return False
		# Assemble the files if needed
		if f[2]:
			# Determine base name of assembly file
			[text_filename, data_filename] = getHexTextFileNames(asm_filename)
			#fileParts = asm_filename.split('.')  # Split string by '.'
			#basename = fileParts[0]
			# Create text file
			rars_text_cmd = ["java", "-jar", JAR_FILENAME, ]
			for param in f[1]:
				rars_text_cmd.append(param)
			rars_text_cmd.extend(["a", "dump", ".text", "HexText"])
			#text_filename = str(basename + "_inst.txt")
			rars_text_cmd.append(text_filename)
			rars_text_cmd.append(asm_filename)
			print("TEXT",rars_text_cmd)
			proc = subprocess.run(rars_text_cmd, cwd=extract_path, check=False)
			if proc.returncode:
				print_color(TermColor.RED, "Failed to generate text assembly file")
				return False
			# Create data file
			rars_data_cmd = ["java", "-jar", JAR_FILENAME, ]
			#rars_data_cmd = ["java", "-jar", JAR_FILENAME, "a", "dump", ".data", "HexText"]
			for param in f[1]:
				rars_data_cmd.append(param)
			rars_data_cmd.extend([ "a", "dump", ".data", "HexText"])
			#data_filename = str(basename + "_data.txt")
			rars_data_cmd.append(data_filename)
			rars_data_cmd.append(asm_filename)
			print("DATA",rars_data_cmd)
			proc = subprocess.run(rars_data_cmd, cwd=extract_path, check=False)
			if proc.returncode:
				print_color(TermColor.RED, "Failed to generate data assembly file")
				return False
			#sys.exit(0)
			# Add the file to simulation
			#asm_command = ["java", "-jar", args.rars_jar, "mc", "CompactTextAtZero", "a", "dump", ".text", "HexText", asmTextFileName, args.asm_file ]
			#rars_cmd.append(asm_filename)
			#print(rars_cmd)
			# Run command
			#proc = subprocess.run(rars_cmd, cwd=extract_path, check=False)
			#if proc.returncode:
			#    print_color(TermColor.RED, "Failed to simulate assembler files")
			#    return False
	return True


# TODO: This function was copied from 'pygrader/pygrader/student_repos.py'
#       - Need to import this code rather than copying it in the future.
#       - Merge my comments into initial repository (note I changed TermColor)
def clone_repo(git_path, tag, student_repo_path):
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
		print_color(
			TermColor.BLUE,
			"Student repo",
			student_repo_path.name,
			"already cloned. Re-fetching tag",
		)

		# Fetch
		cmd = ["git", "fetch", "--tags", "-f"]
		p = subprocess.run(cmd, cwd=student_repo_path)
		if p.returncode:
			print_color(TermColor.RED, "git fetch failed")
			return False

		# Checkout tag
		if tag not in ("master", "main"):
			tag = "tags/" + tag
		cmd = ["git", "checkout", tag, "-f"]
		p = subprocess.run(cmd, cwd=student_repo_path)
		if p.returncode:
			print_color(TermColor.RED, "git checkout of tag failed")
			return False
		return True

	print_color(TermColor.BLUE, "Cloning repo, tag =", tag)
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
		print_color(TermColor.RED, "Clone failed")
		return False
	return True

# TODO: This function was copied from 'pygrader/pygrader/student_repos.py'
#       Need to import this code rather than copying it in the future.
def print_date(student_repo_path):
	print("Last commit: ")
	cmd = ["git", "log", "-1", r"--format=%cd"]
	proc = subprocess.run(cmd, cwd=str(student_repo_path))

def main():
	''' Main executable for script
	'''

	''' Setup the ArgumentParser '''
	# Create description string for script and setup ArgumentParser
	description = str.format('Create and test submission archive for lab {} (v {}).',LAB_NUMBER,SCRIPT_VERSION)
	parser = argparse.ArgumentParser(description=description)

	# GitHub URL for the student repository. Required option for now.
	parser.add_argument("--git_repo", type=str, help="GitHub Remote Repository. If no repository is specified, the current repo will be used.")

	# Force git extraction if directory already exists
	parser.add_argument("-f", "--force", action="store_true", help="Force clone if target directory already exists")

	# Directory for extracting repository. This directory will be deleted when
	# the script is done (unless the --noclean option is set).
	parser.add_argument("--extract_dir", type=str, \
		help="Temporary directory where repository will be extracted (relative to directory script is run)",
		default=DEFAULT_EXTRACT_DIR)

	# Do not clean up the temporary directory
	#parser.add_argument("-c", "--clean", action="store_true", help="Clean the submission directory when complete")
	parser.add_argument("--noclean", type=bool, help="Do not clean up the extraction directory when done")

	# Do not clean up the temporary directory
	#parser.add_argument("-c", "--clean", action="store_true", help="Clean the submission directory when complete")
	parser.add_argument("--notest", type=bool, help="Do not run the tests")

	# Parse the arguments
	args = parser.parse_args()

	''' Set run time variables and argument variables
	'''
	# This is the path of location where the repository was extracted
	student_extract_repo_dir = SCRIPT_PATH / args.extract_dir
	# This is the path of lab within the extracted repository where the lab exists
	# and where the executables wil run
	student_extract_lab_dir = student_extract_repo_dir / LAB_DIR_NAME

	''' Determine remote repository
	'''
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
	if args.git_repo:
		student_git_repo = args.git_repo
	else:
		# Determine the current repo
		#git config --get remote.origin.url
		cmd = ["git", "config", "--get", "remote.origin.url"]
		p = subprocess.run(cmd, cwd=SCRIPT_PATH, stdout=subprocess.PIPE,universal_newlines=True)
		if p.returncode:
			print_color(TermColor.RED, "git config failed")
			return False
		else:
			student_git_repo = p.stdout.strip()

	''' Clone Repository. When done, the 'student_repo_dir' variable will be set.
	'''
	# See if directory exists
	if student_extract_repo_dir.exists():
		if args.force:
			print( "Target directory",student_extract_repo_dir,"exists. Will be deleted before proceeding")
			shutil.rmtree(student_extract_repo_dir, ignore_errors=True)
		else:
			print_color(TermColor.RED, "Target directory",student_extract_repo_dir,"exists. Use --force option to overwrite")
			return False

	print("Cloning repository from",student_git_repo,"with tag",LAB_TAG_STRING,"to",student_extract_repo_dir)
	
	if not clone_repo(student_git_repo, LAB_TAG_STRING, student_extract_repo_dir):
		return False

	''' Check to make sure all the expected files exist (both submission and test) '''
	print("Checking to make sure required files are in repository")
	for file in all_files:
		filename = all_files[file]
		filepath = student_extract_lab_dir / filename
		if filepath.exists():
			print("File",filename,"exists")
		else:
			print_color(TermColor.YELLOW, str("Warning: File "+filename+" does not exist"))


	if not args.notest:

		# At this point we have all the files and can perform experiemnts
		log = open(student_extract_lab_dir / TEST_RESULT_FILENAME, 'w')

		# Simulate assembly sets
		#if not assembly_simulate_sets:
		#    print_color(TermColor.YELLOW, "No Assembly Simulations")
		#else:
		if assembly_simulate_sets:
			for assembly_simulate_set in assembly_simulate_sets:
				if not run_assembly(student_extract_lab_dir, assembly_simulate_set):
					print_color(TermColor.RED, "Assembly execution failure:")
					log.write('** Failed Assembly simulation\n')
				else:
					log.write('** Successful Assembly simulation\n')

		# Simulate all of the TCL simulations
		if tcl_sims:
			for tcl_sim_set in tcl_sims:
				if not simulate_tcl_solution(student_extract_lab_dir, tcl_sim_set):
					log.write('** Failed TCL simulation\n')
				else:
					log.write('** Successful TCL simulation\n')

		# Simulate all of the testbenches
		if testbench_sims:
			for testbench_sim_set in testbench_sims:
				if not simulate_testbench_solution(student_extract_lab_dir, testbench_sim_set):
					print_color(TermColor.RED, "** Failed Testbench simulation")
					log.write('** Failed Testbench simulation:'+testbench_sim_set[0]+'\n')
				else:
					log.write('** Successful Testbench simulation:'+testbench_sim_set[0]+'\n')

		# Build circuit
		if build_sets:
			for build in build_sets:
				if not build_solution(student_extract_lab_dir, build):
					log.write('** Failed to Synthesize\n')
				else:
					log.write('** Successful synthesis\n')

		# Modify all of the bitstreams
		if bitfile_dcp_mods:
			for bitfile_dcp_mod in bitfile_dcp_mods:
				if not modify_bitstream(student_extract_lab_dir, bitfile_dcp_mod):
					print_color(TermColor.RED, "** Failed Bitstream Modification")
				else:
					log.write('** Successful Bitstream Modfication\n')


		print_color(TermColor.GREEN, "Completed - Successful submission")

	# Clean the submission temporary files
	if not args.noclean:
		print_color(TermColor.YELLOW, "Deleting temporary submission test directory",student_extract_repo_dir)
		shutil.rmtree(student_extract_lab_dir, ignore_errors=True)


if __name__ == "__main__":
	main()