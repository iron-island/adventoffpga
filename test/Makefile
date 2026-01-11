# Makefile

# Copied and modified from cocotb quickstart guide
# Ref: https://docs.cocotb.org/en/stable/quickstart.html#creating-a-makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
SRC_DIR ?= $(PWD)/../src

# Include directory for design files
COMPILE_ARGS += -I$(SRC_DIR)
# Timing related argument, otherwise Verilator throws a NEEDTIMINGOPT error
#   due to presence of timing constructs in the testbench
# Ref: https://verilator.org/guide/latest/warnings.html#cmdoption-arg-NEEDTIMINGOPT
COMPILE_ARGS += --timing

# Required to be able to dump a waveform
# Ref: https://docs.cocotb.org/en/stable/simulator_support.html#sim-verilator-waveforms
EXTRA_ARGS += --trace --trace-structs

VERILOG_SOURCES += $(PWD)/tb.v

#--------
# cocotb
#--------
# cocotb configurations, copied and modified from quickstart guide
# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
COCOTB_TOPLEVEL = tb

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = cocotb_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
