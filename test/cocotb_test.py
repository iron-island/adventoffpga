# Copied and modified from cocotb quickstart guide
# Ref: https://docs.cocotb.org/en/stable/quickstart.html#creating-a-test

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer

import pprint

CLK_PERIOD_NS = 10
INPUT_FILE = "../input/input.txt"

#---------------------------------
# Native Python Utility Functions
#---------------------------------

# Function for parsing the puzzle input file and outputting a dictionary
#   to represent the graph
def parse_input(in_file):
    graph_dict = {}

    with open(in_file) as file:
        line = file.readline()

        while line:
            line = line.strip()

            node, next_nodes = line.split(": ")
            graph_dict[node] = next_nodes.split(" ")

            line = file.readline()

    return graph_dict

#-------------------
# cocotb Coroutines
#-------------------

async def generate_clock(dut):
    """Generate clock pulses."""

    for _ in range(100):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS/2, unit="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS/2, unit="ns")

async def generate_reset(dut):
    """ Generate reset pulse"""

    # Assert reset, can be asynchronous but wait for a clock edge for simplicity
    await Timer(CLK_PERIOD_NS, unit="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    cocotb.log.info("Asserted reset")

    # Deassert reset synchronously
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    cocotb.log.info("Deasserted reset")

#--------------
# cocotb Tests
#--------------

@cocotb.test()
async def reset_test(dut):
    """Check reset values"""

    cocotb.start_soon(generate_clock(dut))  # run the clock "in the background"
    cocotb.start_soon(generate_reset(dut))

    await Timer(5, unit="ns")  # wait a bit
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"

    cocotb.log.info("FSM state is %s", dut.dut.curr_state)
    assert dut.dut.curr_state.value == 0

    # Wait for a few clock cycles before simulation ends
    await Timer(50*CLK_PERIOD_NS, unit="ns")

@cocotb.test()
async def input_file_test(dut):
    graph_dict = parse_input(INPUT_FILE)

    # Print graph
    #pprint.pp(graph_dict)
