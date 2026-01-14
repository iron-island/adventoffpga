# Copied and modified from cocotb quickstart guide
# Ref: https://docs.cocotb.org/en/stable/quickstart.html#creating-a-test

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def generate_clock(dut):
    """Generate clock pulses."""

    for _ in range(10):
        dut.clk.value = 0
        await Timer(1, unit="ns")
        dut.clk.value = 1
        await Timer(1, unit="ns")


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

