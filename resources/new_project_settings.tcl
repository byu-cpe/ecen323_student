# This file contains several TCL commands for changing the default settings of your projects.
# These settings change the severity level of certain messages to make the messages
# more meaningful. 

set_msg_config -new_severity "ERROR" -id "Synth 8-87"
# Infer Latch
set_msg_config -new_severity "ERROR" -id "Synth 8-327"
set_msg_config -new_severity "ERROR" -id "Synth 8-3352"
# Multi-driven net
set_msg_config -new_severity "ERROR" -id "Synth 8-5559"
set_msg_config -new_severity "ERROR" -id "Synth 8-6090"
# "multi-driven net" caused by continuous assign statements along with wire declaration
set_msg_config -new_severity "ERROR" -id "Synth 8-6858"
# Upgrade the 'multi-driven net on pin' message to ERROR
set_msg_config -new_severity "ERROR" -id "Synth 8-6859"
# Upgrade the 'The design failed to meet the timing requirements' message to ERROR
set_msg_config -new_severity "ERROR" -id "Timing 38-282"
# Upgrade the 'actual bit length 8 differs from formal bit length 22 for port 'o_led' message
set_msg_config -new_severity "ERROR" -id "VRFC 10-3091"
# Downgrade the 'There are no user specified timing constraints' to WARNING
set_msg_config -new_severity "WARNING" -id "Timing 38-313"
# Downgrade the 'no constraints slected for write' from a warning to INFO
set_msg_config -new_severity "INFO" -id "Constraints 18-5210"
# Set incremental simulation to False (force all files to be re-analyzed)
set_property INCREMENTAL false [get_filesets sim_1]
# Set the initial simulation runtime when you open the simulator to zero
set_property -name {xsim.simulate.runtime} -value 0ns -objects [get_filesets sim_1]