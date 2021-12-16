#!/usr/bin/python3

'''
Script for extracting a student submission from a GitHub repository and
checking the submission.
'''

###########################################################################
# Global constants
###########################################################################

# lab-specific constants
LAB_NUMBER = 12
SCRIPT_VERSION = 1.0

# lab independent constants
DEFAULT_EXTRACT_DIR = "passoff_temp_dir"
TEST_RESULT_FILENAME = str.format("lab{}_test_result.txt",LAB_NUMBER)


# List of source files used for lab submission. The key is a lab-specific keyword
# used to represent a specific file for the lab. The value is the path and filename
# of the file to include in the submission.
submission_files = {
    "final"        : "riscv_final.sv",
    "alu"               : "alu2.sv",
    "aluconstants"      : "riscv_alu_constants2.sv",
    "regfile"           : "regfile.sv",
    "font"              : "font_mem_mod.txt",
    "background"        : "background_mem.txt",
    "asm"               : "project.s",
    "instructions"      : "instructions.txt",
}

# List of files needed for testing that must be obtained from the web. 
# The key is a lab-specific keyword used to represent a specific file for the lab. 
# The value is a list: [ "url", "filename" ]
wget_files = {
    "iosystem"     : [ "http://ecen323wiki.groups.et.byu.net/media/project/", "riscv_io_final.v" ],
    "tcl_sim"       : [ "http://ecen323wiki.groups.et.byu.net/media/project/", "final_sim.tcl" ],
    "xdc"          : [ "http://ecen323wiki.groups.et.byu.net/media/multicycle_io/", "top_basys3.xdc" ],
    "glbl"         : [ "http://ecen323wiki.groups.et.byu.net/media/multicycle_io/", "glbl.v" ],
    "load_mem"      : [ "http://ecen323wiki.groups.et.byu.net/media/tutorials/", "load_mem.tcl" ],
    #"asm_script"    : ["http://ecen323wiki.groups.et.byu.net/media/tutorials/", "generate_asm.py" ],
}


user_files = {}
for key in submission_files:
    user_files[key] = submission_files[key]
for key in wget_files:
    user_files[key] = wget_files[key][1]


# List of TCL simulations to complete
# [0]: keyword in dictionary referrring to tcl file
# [1]: top-level to simulate
# [2]: List of keywords referring to sources to include
tcl_sims = [
#    [ "tcl_sim", 
#      "riscv_io_system", 
#      [ "alu", "regfile", "aluconstants", "iosystem", "final", "glbl" ],
#   ] 
]


# [1] module name
# [0] Description of simulation
# [2] list of files to include (key names)
# [3] xelab options
testbench_sims = [
]

# [0] top
# [1] xdc filename keys
# [2] set of files (key)
# [3] Boolean: implement bitstream
# [4] Boolean: create dcp file
build_set = [
            "riscv_io_system", 
             ["xdc"], 
             [ "iosystem", "final", "alu", "aluconstants", "regfile" ], 
             True,
             True, 
            ]

# List of list of assembly sets
# [0] key name for assembly file in submission files
# [1] list of options to give to RARS for the simulation
# [2] Boolean: generate .txt instruction and .data files
# [3] Boolean: Run simulator
assembly_simulate_sets = [
    [ "asm", [ "mc", "CompactTextAtZero"], True, False ],
]


# DCP Modification sets
# [0] Name of new bitfile
# [1] original dcp filename
# [2] keyname for assembly file ("" for none)
# [3] font file keyname ("" for none)
# [4] background file keyname ("" for none)
bitfile_dcp_mods = [
    [   
        "new.bit",
        "riscv_io_system.dcp",
        "asm",
        "font",
        "background"
    ],
]


# Downloads

test_result_filename = "lab12_test_result.txt"

# Manages file paths
import pathlib
# Command line argunent parser
import argparse
# Get the username of the current user
import getpass
# manage zipfiles
import zipfile
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

# Script defaults
repo_path = pathlib.Path(__file__).absolute().parent.resolve()
default_test_path = (repo_path / "submission_test").resolve()
basys3_part = "xc7a35tcpg236-1"
jar_filename = "rars1_4.jar"
jar_url = "https://github.com/TheThirdOne/rars/releases/download/v1.4/rars1_4.jar"
# used for caedem check
lab_name = "lab12"

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


#def error(*msg, returncode=-1):
#    """ Print an error message and exit program """
#
#    print_color(TermColor.RED, "ERROR:", " ".join(str(item) for item in msg))
#    sys.exit(returncode)


# Generate script that indicates filenames of included files.
# Returns a 'pathlib' filename for the generated file.
def pickle_files():
    # Create tcl build script
    print_color(TermColor.BLUE, "Creating include script", python_include_file)
    lab_files_dump = open(python_include_file, 'w')
    pickle.dumps( favorite_color, lab_files_dump)

# This function takes a filename specified in the input string
# (which may contain path information) and 
# returns the raw filename without any path string that may
# be part of the original input specification. 
def get_atomic_filename(input_file_string):
    # Create a Path object of the input_file_String relative
    # to the repo_path
    source_file = repo_path / input_file_string
    # Return only the name of this Path
    return source_file.name

# creates a list of 'pathlib' files to include in the zip repository
def get_files_to_copy_and_zip():
    print_color(TermColor.BLUE, "Files to copy and zip")

    files_to_zip=[]
    for submission_filename in submission_files.values():
        submission_file = repo_path / submission_filename
        files_to_zip.append(submission_file)
    print(
        len(files_to_zip),
        "files to zip"
    )
    return files_to_zip



def extract_solution_files(zip_path, extract_path):
    """ Copy student files to the temp repo """

    # See if solution directory exists. If so, prompt warning, delete
    if extract_path.is_dir():
        print_color(TermColor.YELLOW, "Warning: directory ", str(extract_path), " exists. Contents will be overwritten")
        # use shutil.rmtree()  to delete entire directory
    else:
        # Create directory for sumbission
        print_color(TermColor.BLUE, "Directory", str(extract_path), "is being created")
        extract_path.mkdir()

    # Copy files
    if not zipfile.is_zipfile(zip_path):
        print_color(TermColor.RED,str("File", zipfile, "is not a valid ZipFile") )
        return False

    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(extract_path)
        print_color(TermColor.BLUE, "Zip file contents extracted")
    
    # Check to see if all the files were extracted
    validExtract = True
    for submission_filename in submission_files.values():
        submission_file = extract_path / submission_filename
        if not submission_file.exists():
            validExtract = False
            print("Missing file:",submission_filename)
    return validExtract

def download_remote_files(extract_path):
    # "testbench"     : [ "http://ecen323wiki.groups.et.byu.net/media/lab_06/", "tb_multicycle_control.sv" ],
    for remote_file_key in wget_files.keys():
        remote_url = wget_files[remote_file_key][0]
        remote_filename = wget_files[remote_file_key][1]
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

def simulate_tcl_solution(extract_path, tcl_set):

    # Get the original TCL filename
    #tcl_filename = get_atomic_filename(tcl_set[0])
    tcl_filename_key = get_atomic_filename(tcl_set[0])
    tcl_filename = user_files[tcl_filename_key]
    print_color(TermColor.BLUE, "Attempting simulation of TCL script:", tcl_filename)

    # Analyze all of the files associated with the TCL simulation set
    print_color(TermColor.BLUE, " Analyzing source files")
    for src_key in tcl_set[2]:
        src = user_files[src_key]
        src_name = get_atomic_filename(src)
        xvlog_cmd = ["xvlog", "--nolog", "-sv", src_name ]
        proc = subprocess.run(xvlog_cmd, cwd=extract_path, check=False)
        if proc.returncode:
            return False

    # xvlog -sv alu.sv regfile.sv riscv_alu_constants.sv riscv_datapath_constants.sv riscv_io_multicycle.v riscv_multicycle.sv riscv_simple_datapath.sv glbl.v
    # xelab -L unisims_ver riscv_io_system work.glbl
    #return False

    # Elaborate design
    design_name = tcl_set[1]
    print_color(TermColor.BLUE, " Elaborating")
    xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L", "unisims_ver", design_name, "work.glbl" ]
    proc = subprocess.run(xelab_cmd, cwd=extract_path, check=False)

    #xelab_cmd = ["xelab", "--debug", "typical", "--nolog", design_name, "work.glbl" ]
    #xelab_cmd = ["xelab", "--debug", "typical", "--nolog", "-L xil_defaultlib", "-L unisims_ver", "-L unimacro_ver", design_name, "work.glbl" ]
    #xelab  -wto f006d1b2ec3040b5bab73404505d9a2c --debug typical --relax --mt 2 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip --snapshot riscv_io_system_behav xil_defaultlib.riscv_io_system xil_defaultlib.glbl -log elaborate.log    proc = subprocess.run(xelab_cmd, cwd=extract_path, check=False)
    if proc.returncode:
        print("Error in elaboration")
        return False

	# Modify TCL simulation script (add 'quit' command to end)
    temp_tcl_filename = str(design_name + "_tempsim.tcl")
    src_tcl = extract_path / tcl_filename
    tmp_tcl = extract_path / temp_tcl_filename
    shutil.copyfile(src_tcl, tmp_tcl)

    log = open(tmp_tcl, 'a')
    log.write('\n# Add Exit quit command\n')
    log.write('quit\n')
    log.close()

    # Simulate
    print_color(TermColor.BLUE, " Starting Simulation")
    tmp_design_name = str(design_name + "#work.glbl")
    xsim_cmd = ["xsim", "-nolog", tmp_design_name, "-tclbatch", temp_tcl_filename ]
    proc = subprocess.run(xsim_cmd, cwd=extract_path, check=False)
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
        testbench_filenames.append(wget_files[key][1])
    # submission files
    for key in testbench_set[2]:
        testbench_filenames.append(user_files[key])

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

def build_solution(extract_path):

    design_name = build_set[0]
    implement = build_set[3]
    dcp =  build_set[4]

    bitfile_filename = str(design_name + ".bit")
    dcp_filename = str(design_name + ".dcp")

    print_color(TermColor.BLUE, "Attempting to build bitfile",bitfile_filename)

    # Create tcl build script
    tcl_build_script_filename = str(design_name + "_buildscript.tcl")
    tmp_tcl = extract_path / tcl_build_script_filename

    log = open(tmp_tcl, 'w')
    log.write('# Bitfile Generation script\n')
    log.write('#\n')
    log.write('# Set the part\n')
    log.write('link_design -part ' + basys3_part +'\n')
    log.write('# Add sources\n')

    for src_key in build_set[2]:
        src = user_files[src_key]
        log.write('read_verilog -sv ' + src + '\n')
    if implement:
        log.write('# Add XDC file\n')
        for xdc_key in build_set[1]:
            src = user_files[xdc_key]
            log.write('read_xdc ' + src + '\n')
    log.write('# Synthesize design\n')
    log.write('synth_design -top ' + design_name + ' -flatten_hierarchy full\n')
    if implement:    
        log.write('# Implement Design\n')
        log.write('place_design\n')
        log.write('route_design\n')
        checkpoint_filename = str(design_name + ".dcp")
        log.write('write_checkpoint ' + checkpoint_filename + ' -force\n')
        log.write('write_bitstream -force ' + bitfile_filename +'\n')
    if dcp:
        log.write('# Create DCP\n')
        log.write(str.format("write_checkpoint {} -force\n",dcp_filename))
    log.write('# End of build script\n')
    log.close()

    # Generate bitfile
    build_cmd = ["vivado", "-nolog", "-mode", "batch", "-nojournal", "-source", tcl_build_script_filename]
    proc = subprocess.run(build_cmd, cwd=extract_path, check=False)
    if proc.returncode:
        return False

    # See if the bitfile exists (make sure it is newer)
    if implement:
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
        asmFile = user_files[assemblyKeyName]
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
        fontFile = user_files[fontKeyName]
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
        backgroundFile = user_files[backgroundKeyName]
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
    jar_file = extract_path / jar_filename
    if not jar_file.exists():
        print_color(TermColor.YELLOW, "JAR file does not exist - will attempt to download")
        # -O <name of target file> URL will overwrite file if it exists. Doesn't matter where you run command
        wget_cmd = ["wget", "-O", jar_file, jar_url ]
        proc = subprocess.run(wget_cmd, check=False)
        if proc.returncode:
            print_color(TermColor.RED, "Failed to download RARS jar")
            return False
    # Perform simulation (and possible assembly)
    for f in assembly_simulate_sets:
        asm_key = get_atomic_filename(f[0])
        asm_filename = user_files[asm_key]
        print_color(TermColor.BLUE, "Attempting RARS simulation/assembly of", asm_filename)
        if f[3]:
            # Execute assembler
            rars_cmd = ["java", "-jar", jar_filename, "ic", "se1", "ae2", "nc"]
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
            rars_text_cmd = ["java", "-jar", jar_filename, ]
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
            rars_data_cmd = ["java", "-jar", jar_filename, ]
            #rars_data_cmd = ["java", "-jar", jar_filename, "a", "dump", ".data", "HexText"]
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

def zip(zip_path, files):
    """ Zip the lab files """
    print_color(TermColor.BLUE, "Creating zip file", zip_path.relative_to(repo_path))
    if zip_path.is_file():
        print("Deleting existing zip file:" + str(zip_path.relative_to(repo_path)))
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w") as zf:
        #print("Created new zip file:" + str(zip_path.relative_to(repo_path)))
        # Loop through files
        for f in files:
            if f.relative_to(repo_path).is_file():
                print("Adding", f.relative_to(repo_path))
                zf.write(f, arcname=f.name)
            else:
                error_msg = ("Required file " + str(f.relative_to(repo_path)) + " not found")
                print_color(TermColor.RED, error_msg)
                return None
    return zip_path.relative_to(repo_path)


# Looks at the computer name and drive name. If it is a digital lab computer
# and running on the j drive, run the test on the c drive.
def check_for_caedm_j_drive(extract_path):
    #return extract_path
    # See if this is a digital lab computer
    computername_key = 'COMPUTERNAME'
    if not computername_key in os.environ:
        return extract_path
    computername = os.environ[computername_key]
    if not computername.startswith('DIGITAL-'):
        # not a digital lab computer
        return extract_path
    current_path = os.environ['PWD']
    j_drive_string = "/cygdrive/j"
    if j_drive_string in current_path:
        # Create new directory
        #userprofile=os.environ['USERPROFILE']
        #windowsPath = PureWindowsPath(userprofile)
        username = os.environ['USERNAME']
        userprofile = str("/cygdrive/c/Users/" +username)
        new_path = pathlib.Path(userprofile) / "Downloads" / str(lab_name + "_passoff")
        print_color(TermColor.YELLOW,"Running on digital lab computer",computername)
        print_color(TermColor.YELLOW,"Running on J Drive:", current_path, "will use",new_path)
        return pathlib.Path(new_path)
    return extract_path


def main():

    # Create description string for script
    description = str.format('Create and test submission archive for lab {} (v {}).',LAB_NUMBER,SCRIPT_VERSION)
    parser = argparse.ArgumentParser(description=description)

    # GitHub URL for the student repository. If this option is not set then
    # do not extract the repository (assume it has been extracted).
    parser.add_argument("--url", type=str, help="GitHub URL for Repository")

    # Directory for extracting repository. This directory will be deleted when
    # the script is done (unless the --noclean option is set).
    parser.add_argument("--extract_dir", type=str, help="Temporary directory where repository will be extracted", \
        default=DEFAULT_EXTRACT_DIR)

    # Do not clean up the temporary directory
    parser.add_argument("--noclean", type=bool, help="Do not clean up the extraction directory when done")


    """ Copy files into temp repo, build and run lab """
    default_zip_path = repo_path / (getpass.getuser() + "_" + lab + ".zip")
    default_test_path =  repo_path / "submission_test"

    filename_help = "Archive filename (default=" + str(default_zip_path.relative_to(repo_path)) + ")"
    directory_help = "Set the directory of the submission test (default=" + str(default_test_path.relative_to(repo_path)) + ")"
    parser.add_argument("-d", "--dir", type=str, help=directory_help)
    parser.add_argument("--nobuild", action="store_true", help="Don't build the zipfile (use the existing)")
    parser.add_argument("-c", "--clean", action="store_true", help="Clean the submission directory when complete")
    args = parser.parse_args()

    if args.filename:
        zip_path = repo_path / args.filename
    else:
        zip_path = default_zip_path

    # Determine test extraction directory and verify it exists
    if args.dir:
        test_dir = repo_path / args.test
    else:
        test_dir = default_test_path
    test_dir = check_for_caedm_j_drive(test_dir)

    if not args.nobuild:
        # Get a list of files need to build and zip
        files = get_files_to_copy_and_zip()
        #include_script = generate_include_script()
        #files.append(include_script)
        # Zip it
        zip_relpath = zip(zip_path, files)
        if zip_relpath == None:
            print_color(TermColor.RED, "Failed to create zip file:", zip_relpath)
            return 1
        else:
            print_color(TermColor.BLUE, "Done. Created", zip_relpath)
        # Delete temporary file
        #os.remove(include_script)

    if args.test:

        print_color(TermColor.BLUE, "Performing submission test on file", 
            str(default_zip_path.relative_to(repo_path)) + " in directory ", test_dir)

        # Extract the file
        if not extract_solution_files(zip_path, test_dir):
            if not test_dir.exists():
                test_dir.mkdir()
            log = open(test_dir / test_result_filename, 'w')
            log.write('** Extract failure\n')
            log.close()
            # If the extraction failed, don't proceed (can't do anything)
            return 1

        # Download remote files
        if not download_remote_files(test_dir):
            if not test_dir.exists():
                test_dir.mkdir()
            log = open(test_dir / test_result_filename, 'w')
            log.write('** Download failure\n')
            log.close()
            # If the download failed, don't proceed (can't do anything)
            return 1

        # At this point we have all the files and can perform experiemnts
        log = open(test_dir / test_result_filename, 'w')

        # Simulate assembly sets
        if not assembly_simulate_sets:
            print_color(TermColor.YELLOW, "No Assembly Simulations")
        else:
            for assembly_simulate_set in assembly_simulate_sets:
                if not run_assembly(test_dir, assembly_simulate_set):
                    print_color(TermColor.RED, "Assembly execution failure:")
                    log.write('** Failed Assembly simulation\n')
                else:
                    log.write('** Successful Assembly simulation\n')

        # Simulate all of the TCL simulations
        if not tcl_sims:
            print_color(TermColor.YELLOW, "No TCL Simulations")
        else:
            for tcl_sim_set in tcl_sims:
                if not simulate_tcl_solution(test_dir, tcl_sim_set):
                    log.write('** Failed TCL simulation\n')
                else:
                    log.write('** Successful TCL simulation\n')

        # Simulate all of the testbenches
        if not testbench_sims:
             print_color(TermColor.YELLOW, "No Testbench Simulations")
        else:
            for testbench_sim_set in testbench_sims:
                if not simulate_testbench_solution(test_dir, testbench_sim_set):
                    print_color(TermColor.RED, "** Failed Testbench simulation")
                    log.write('** Failed Testbench simulation:'+testbench_sim_set[0]+'\n')
                else:
                    log.write('** Successful Testbench simulation:'+testbench_sim_set[0]+'\n')

        # Build circuit
        if not build_set:        
             print_color(TermColor.YELLOW, "No Synthesis")
        else:
            if not build_solution(test_dir):
                log.write('** Failed to Synthesize\n')
            else:
                log.write('** Successful synthesis\n')

        # Modify all of the bitstreams
        if not bitfile_dcp_mods:
             print_color(TermColor.YELLOW, "No Bitstream Modifications")
        else:
            for bitfile_dcp_mod in bitfile_dcp_mods:
                if not modify_bitstream(test_dir, bitfile_dcp_mod):
                    print_color(TermColor.RED, "** Failed Bitstream Modification")
                else:
                    log.write('** Successful Bitstream Modfication\n')


        print_color(TermColor.GREEN, "Completed - Successful submission")

    # Clean the submission temporary files
    if args.clean:
        print_color(TermColor.RED, "Deleting temporary submission test directory",test_dir)
        shutil.rmtree(test_dir, ignore_errors=True)
    elif args.test:
        print_color(TermColor.YELLOW, "Temporary directory can safely be deleted",test_dir)


if __name__ == "__main__":
    main()