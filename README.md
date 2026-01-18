# Setup
1. The testbench is based on [cocotb](https://github.com/cocotb/cocotb) using [Verilator](https://github.com/verilator/verilator) for simulation. Refer to their respective documentations for installation:
   - [cocotb installation](https://docs.cocotb.org/en/stable/install.html) - this project used version `5.044`
   - [verilator installation](https://verilator.org/guide/latest/install.html) - this project used version `5.032-1`
2. Alternatively, you can build an Ubuntu 25.04 docker image with `cocotb 5.044`, `verilator 5.032-1`, and its prerequisites already installed using the provided files in the `docker/` directory:
   1. Install [docker](https://docs.docker.com/engine/install/).
   2. Clone this project and go to the `docker/` directory.
   3. Run `source docker_build.sh` to build the image.
   4. Run `source docker_run.sh` to interactively run the image. You should now have access to a `bash` terminal inside the image.

# Simulations

1. You need to provide the input file from the [Advent of Code 2025 Day 11 puzzle](https://adventofcode.com/2025/day/11) with file name `input.txt` inside the `input/` directory
   - Note that you [should not share input files for Advent of Code puzzles](https://adventofcode.com/2025/about#faq_copying).
   - You can modify the `INPUT_FILE` variable in `test/cocotb_test.py` to change the file/path of the puzzle input as needed.
3. Go to the `test/` directory
4. Run `make -B WAVES=1` to run part 1 of the puzzle, reset the design, and then run part 2 of the puzzle
   - The `WAVES=1` option allows a `tb.vcd` file to be dumped inside the same directory
   - The test should `PASS` and print the part 1 and part 2 answers from both the design and the testbench
