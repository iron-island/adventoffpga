# Copied and modified from cocotb quickstart guide
# Ref: https://docs.cocotb.org/en/stable/quickstart.html#creating-a-test

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer

import pprint

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

#--------------------------
# cocotb Utility Functions
#--------------------------

async def generate_clock(dut):
    """Generate clock pulses."""

    for _ in range(10):
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")

#--------------
# cocotb Tests
#--------------

@cocotb.test()
async def reset_test(dut):
    """Check reset values"""

    cocotb.start_soon(generate_clock(dut))  # run the clock "in the background"

    dut.rst_n.value = 1
    dut.data_in.value = 1
    await Timer(5, unit="ns")  # wait a bit
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"

    # Assert reset
    dut.rst_n.value = 0

    await Timer(1, unit="ps") # check after a small amount of time after reset was asserted
    cocotb.log.info("data_out is %s", dut.data_out.value)
    assert dut.data_out.value == 0

    # Deassert reset
    await Timer(2, unit="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # Wait for a few clock cycles before simulation ends
    await Timer(5, unit="ns")

@cocotb.test()
async def input_file_test(dut):
    graph_dict = parse_input(INPUT_FILE)

    # Print graph
    pprint.pp(graph_dict)
