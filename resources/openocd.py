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
	parser = argparse.ArgumentParser(description="Run 'openocd' command with arbitrary bitfile")
	# Add filename argument
	parser.add_argument('filename', type=str, help="Bitstream filename")
	# Don't delete download file
	parser.add_argument('--nodelete', action="store_true", help="Don't delete openocd file when done")
	# Parse arguments
	args = parser.parse_args()

	# Make sure the bitfile exists
	if not os.path.exists(args.filename):
		print("File",args.filename,"does not exis")
		return 1

	# Create temporary ocd file
	ocd_filename = str.format("{}.ocd",args.filename)
	ocd_file = open(ocd_filename, 'w')
	ocd_file.write(str.format('# openocd script for {}\n',args.filename))
	ocd_file.write("interface ftdi\n")
	ocd_file.write("ftdi_device_desc \"Digilent USB Device\"\n")
	ocd_file.write("ftdi_vid_pid 0x0403 0x6010\n")
	ocd_file.write("# channel 1 does not have any functionality\n")
	ocd_file.write("ftdi_channel 0\n")
	ocd_file.write("# just TCK TDI TDO TMS, no reset\n")
	ocd_file.write("ftdi_layout_init 0x0088 0x008b\n")
	ocd_file.write("reset_config none\n")
	ocd_file.write("adapter_khz 10000\n")
	ocd_file.write("source [find cpld/xilinx-xc7.cfg]\n")
	ocd_file.write("source [find cpld/jtagspi.cfg]\n")
	ocd_file.write("init\n")
	ocd_file.write("puts [irscan xc7.tap 0x09]\n")
	ocd_file.write("puts [drscan xc7.tap 32 0]  \n")
	ocd_file.write("puts \"Programming FPGA...\"\n")
	ocd_file.write(str.format("pld load 0 {}\n",args.filename))
	ocd_file.write("exit\n")
	ocd_file.close()

	# Run the ocd command
	openocd_cmd = ["openocd", "-f", ocd_filename]
	p = subprocess.run(openocd_cmd)
	if p.returncode:
		print("Error running openocd")

	# Delete the temporary ocd file
	if not args.nodelete:
		if os.path.exists(ocd_filename):
			os.remove(ocd_filename)

if __name__ == "__main__":
	main()