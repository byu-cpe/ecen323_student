#!/usr/bin/python3
'''
Script for running the openocd bitstream programming executable without
having to create a script for each bitfile.
'''

# Command line argunent parser
import argparse
# File exists
import os
# Subprocess library for running openocd command
import subprocess

def main():
	''' Main executable for script
	'''

	# Create argument parser object
	parser = argparse.ArgumentParser(description="Convert a \'.bit\' file to a \'.bin\' file")
	# Add bitstream filename argument
	parser.add_argument('filename', type=str, help="\'.bit\' Bitstream filename")
	# Add binfile filename argument
	parser.add_argument('output', type=str, help="\'.bin\' Bitstream filename")
	# Don't delete download file
	parser.add_argument('-f', '--force', action="store_true", help="Force overwrite of .bin file")
	
	# Parse arguments
	args = parser.parse_args()

	# Make sure the bitfile exists
	if not os.path.exists(args.filename):
		print("File",args.filename,"does not exist")
		return 1

	# Read bit file into a byte array
	try:
		with open(args.filename, "rb") as f:
			print("Reading file",args.filename)
			bitfile_bytes = f.read()
	except IOError:
		print("Error reading file",args.filename)
		return 1

	# Find the location of the preamble in the bitstream
	first_ff = -1
	#print(len(bitfile_bytes))
	for i in range(len(bitfile_bytes)):
		#print(bitfile_bytes[i])
		if first_ff < 0 and bitfile_bytes[i] == 255:
			# This is a first 0xff. Record its location
			#print("first ff",i)
			first_ff = i
		elif first_ff > 0:  # we are counting 0xff's
			if i - first_ff == 32:		# Found preamble
				#print("start of preamble",first_ff)
				break    # Found header - exit loop
			if bitfile_bytes[i] != 255:
				#print("Not enough ffs",i)
				first_ff = -1
			else:
				#print("skip",i)
				continue   # skip over preable byte
	if first_ff == -1:
		print("No header found")
		return 1

	# See if target file exists
	if os.path.exists(args.output):
		if args.force:
			print("File",args.output,"will be overwritten")
		else:
			print("File",args.output,"exists. Use -f to overwrite")
			return 1
	# Create binary file
	binfile_bytes = bitfile_bytes[first_ff:]
	print(first_ff,len(binfile_bytes), len(bitfile_bytes))
	with open(args.output, "wb") as fo:
		fo.write(binfile_bytes)


if __name__ == "__main__":
	main()