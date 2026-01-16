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

    # Add "out" node with no target nodes
    graph_dict["out"] = []

    return graph_dict

def node_str2int(node):
    # The nodes are 3 characters, so interpret each character as 8-bit ASCII
    return (ord(node[0]) << 16) + (ord(node[1]) << 8) + (ord(node[2]))

#-------------------
# cocotb Coroutines
#-------------------

async def generate_clock(dut, num_cycles):
    """Generate clock pulses """

    for _ in range(num_cycles):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS/2, unit="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS/2, unit="ns")

async def generate_reset(dut):
    """ Generate reset pulse """

    # Assert reset, can be asynchronous but wait for a clock edge for simplicity
    await Timer(CLK_PERIOD_NS, unit="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    cocotb.log.info("Asserted reset")

    # Deassert reset synchronously
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    cocotb.log.info("Deasserted reset")

def update_tb_node_strings(dut, curr_node, next_node):
    """ Updates value of 24-bit testbench variable """

    if (curr_node != ""):
        dut.curr_node_string.value = node_str2int(curr_node)
    dut.next_node_string.value = node_str2int(next_node)

#--------------
# cocotb Tests
#--------------

#@cocotb.test()
async def reset_test(dut):
    """Check reset values"""

    cocotb.start_soon(generate_clock(dut, 20))  # run the clock "in the background"
    cocotb.start_soon(generate_reset(dut))

    await Timer(5, unit="ns")  # wait a bit
    await FallingEdge(dut.clk)  # wait for falling edge/"negedge"

    cocotb.log.info("FSM state is %s", dut.dut.curr_state)
    assert dut.dut.curr_state.value == 0

    # Wait for a few clock cycles before simulation ends
    await Timer(50*CLK_PERIOD_NS, unit="ns")

#@cocotb.test()
async def input_file_test(dut):
    graph_dict = parse_input(INPUT_FILE)

    # Print graph
    #pprint.pp(graph_dict)

@cocotb.test()
async def part1_test(dut):
    graph_dict = parse_input(INPUT_FILE)

    # Create index values for nodes
    # Index values don't need to be in order, so no sorting is needed
    node_idx_dict = {}
    idx_node_dict = {}
    for idx, node in enumerate(graph_dict):
        node_idx_dict[node] = idx
        idx_node_dict[idx] = node

    cocotb.start_soon(generate_clock(dut, 2000))
    cocotb.start_soon(generate_reset(dut))

    # Wait for a few cycles before starting the run
    await Timer(3*CLK_PERIOD_NS, unit="ns")

    # Start the run synchronized to negedge
    await FallingEdge(dut.clk)
    dut.part_sel.value = 0
    dut.start_run.value = 1
    await RisingEdge(dut.clk)

    # TODO: Testbench has knowledge of the design to know when to drive the start and end node indices,
    #         by reusing the next_node_idx input. Alternatively this can be replaced by dedicated
    #         inputs to be more general, and would also simplify the design

    # Input start node index
    start_node = "you"
    start_node_idx_exp = node_idx_dict[start_node]
    end_node = "out"
    end_node_idx_exp = node_idx_dict[end_node]

    await FallingEdge(dut.clk)
    dut.next_node_idx.value = start_node_idx_exp
    update_tb_node_strings(dut, "", start_node)
    await RisingEdge(dut.clk)

    # Check that start node index was written to FIFO
    await FallingEdge(dut.clk)
    cocotb.log.info(f'Start node: {start_node}, index {start_node_idx_exp}')
    assert(dut.dut.fifo_node_idx[0].value == start_node_idx_exp)

    # Input end node index
    dut.next_node_idx.value = end_node_idx_exp
    update_tb_node_strings(dut, "", end_node)
    await RisingEdge(dut.clk)

    # Check that end node index was written to register
    await FallingEdge(dut.clk)
    cocotb.log.info(f'End node: {end_node}, index {end_node_idx_exp}')
    assert(dut.dut.end_node_idx.value == end_node_idx_exp)

    # Drive target nodes
    await FallingEdge(dut.clk)
    timeout_count = 500 # TODO: remove once design can flag its done
    count = 0
    while (dut.rd_next_node_reg.value) and (count < timeout_count):
        count += 1

        node_idx = int(dut.node_idx_reg.value)
        node = idx_node_dict[node_idx]
        next_node_count = len(graph_dict[node])
        for next_node in graph_dict[node]:
            # Convert to node index
            next_node_idx = node_idx_dict[next_node]

            dut.next_node_idx.value = next_node_idx
            dut.next_node_counter.value = next_node_count

            next_node_count -= 1

            # Update testbench variable for debugging and logging
            update_tb_node_strings(dut, node, next_node)

            await FallingEdge(dut.clk)

    # TODO

    # Wait for a few clock cycles before simulation ends
    await Timer(10*CLK_PERIOD_NS, unit="ns")
