#!/usr/bin/python3

"""
This script is used to generate background memory files based on a text file for use
within the RISC-V project.
"""

# Manages file paths
import pathlib
# Command line argunent parser
import argparse
import re
import os
import sys

# Script defaults
script_path = pathlib.Path(__file__).absolute().parent.resolve()
cwd_path =  pathlib.Path(os.getcwd())

def generate_mem_file(input_filename,output_filename,char_array,char_color_dict,default_color):
    ''' Generates the output file for the memory ''' 
    newLines = []

    totalRows = 32
    populatedRows = 29
    totalColumns = 128

    borderEndColumn = 76
    borderEndRow = 29

    default_char = ' '
    # Create a header
    newLines.append("////////////////////////////////////////////////////////////////////////")
    newLines.append("//")
    newLines.append(f"// {output_filename}: Character background memory file: ")
    newLines.append(f"//   Generated from file {input_filename} ")
    newLines.append("//")
    newLines.append("// Locations tagged with '*' are not visible ")
    newLines.append("//")
    newLines.append("////////////////////////////////////////////////////////////////////////")
    newLines.append("")
    newLines.append("")
    newLines.append("")

    default_color_chars = []

    # Iterate over all rows
    for idx in range(totalRows):
        if idx < populatedRows:
            newLines.append(f"// Row {idx}")
        else:
            newLines.append(f"// Row {idx} - Not visible")
        if idx < len(char_array):
            # Row defined in input file
            column_vals = []
            row = char_array[idx]
            for jdx in range(totalColumns):
                if jdx < len(row):
                    # Character defined in input file
                    char_val = row[jdx]
                    # Determine color of character
                    if not char_val in char_color_dict:
                        char_color = default_color
                        if char_val not in default_color_chars:
                            default_color_chars.append(char_val)
                            print(f"The color for the ASCII character '{chr(char_val)}' ({char_val}) will be set to the default color 0x{default_color:06X}")
                    else:
                        char_color = char_color_dict[char_val]
                    if char_color is None:
                        char_color = default_color
                    # Create memory value
                    char_mem = char_val | (char_color << 8)
                else:
                    # Not defined in input file
                    char_mem = (ord(default_char))
                column_vals.append(char_mem)
        else:
            # Row not defined in input file
            column_vals = []
            for jdx in range(totalColumns):
                column_vals.append(ord(default_char))

        for jdx, char_mem in enumerate(column_vals):
            # Print value
            newStr = f"{char_mem:08x}  // \'{chr(char_mem & 0x7f)}\' {jdx},{idx}"
            if jdx >= borderEndColumn or idx >= populatedRows:
                newStr = newStr + " *"
            newLines.append(newStr)
    return newLines

def create_2d_char_array(lines):
    ''' Parses an array of ascii lines and generates an array of lines where each line is an array of ASCII values. '''
    char_array = []
    for line in lines:
        #print(line)
        line_array = []
        for c in line:
            if c=='\n':
                # Skip end of line characters
                continue
            line_array.append(ord(c))
        #print(line_array)
        char_array.append(line_array)
    #print(char_array)
    return char_array

def create_char_color_dict(lines):
    ''' Creates and returns a dictionary between an ASCII value and a color string. '''
    char_color_dict = {}
    CHAR_COLOR_REGEX = "\'(.)\'*=*(\w+)"
    for line in lines:
        rematch = re.match(CHAR_COLOR_REGEX,line)
        if rematch:
            char_val = rematch.group(1)
            color_val_str = rematch.group(2)
            char_color = int(color_val_str,16)
            #print(char_val,color_val_str,char_color)        
            char_color_dict[ord(char_val)] = char_color
    #print(char_color_dict)
    return char_color_dict

def process_file(input_filename,output_filename):
    ''' Process background template file '''

    # Load all lines into a list
    with open(input_filename) as file:
        lines = [line for line in file]
    # Strip all comment lines
    newlines = []
    for line in lines:
        if not line.startswith("#"):
            newlines.append(line)

    # Find the first line and last line of the background
    start_line = 0
    end_line = 0
    color_map_start_line = 0
    default_color = 0x000fff
    for idx, x in enumerate(newlines):
        if x.startswith(".background_start"):
            start_line = idx+1
            #print("start",start_line)
        if x.startswith(".background_end"):
            end_line = idx-1
            #print("end",end_line)
        if x.startswith(".char_color_map"):
            color_map_start = idx+1
        if x.startswith(".default_color"):
            dfcolor = x.split()
            colorstr = dfcolor[1]
            default_color = int(colorstr,16)            

    # Create two dimensional character array of background
    background_lines = newlines[start_line:end_line+1]

    #print(background_lines)
    char_array = create_2d_char_array(background_lines)  # exclusive for python
    
    # Create color dictionary
    color_dict = create_char_color_dict(lines[color_map_start:])

    # Create memory file
    output_lines = generate_mem_file(input_filename,output_filename,char_array,color_dict,default_color)

    return output_lines 

def main():

    parser = argparse.ArgumentParser(description='Create background memory files project.')
    parser.add_argument('input_file',  type=str, help='Filename of the input template file')
    parser.add_argument('output_file',  type=str, help='Filename of the output memory file')

    # Parse the command line given using the above arg definitions
    args = parser.parse_args()

    newLines = process_file(args.input_file,args.output_file)

    ################################################################################################
    #
    # Spit out the new file based on the proocessed lines of code
    #
    ################################################################################################
    outputFilePath = cwd_path / args.output_file
    with open(outputFilePath, 'w') as f:
        for line in newLines:
            f.write('%s\n' % line)

    return 0

if __name__ == "__main__":
    main()