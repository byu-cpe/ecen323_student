##########################################################################
#
# Filname: final_sim.tcl
#
# This .tcl script will apply stimulus to the top-level pins of the FPGA
#
##########################################################################


# Start the simulation over
restart

# Run circuit with no input stimulus settings
run 20 ns

# Set the clock to oscillate with a period of 10 ns
add_force clk {0} {1 5} -repeat_every 10
# Run the circuit for a bit
run 40 ns

# set the top-level inputs
add_force btnc 0
add_force btnl 0
add_force btnr 0
add_force btnu 0
add_force btnd 0
add_force sw 0
add_force RsTx 1

# Simulate the starting setup instructions
run 10 us

# Simulate the btnr being pressed
add_force btnr 1
run 10 us
add_force btnr 0

# Let btnr = 0 filter through the debouncer
run 10 us

# Simulate the btnd being pressed
add_force btnd 1
run 10 us
add_force btnd 0
run 10 us



