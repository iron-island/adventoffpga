This implements a solution to the [Advent of Code 2025 Day 11 puzzle](https://adventofcode.com/2025/day/11) (both parts) in synthesizable Verilog.

The Verilog RTL top module is found in `src/digital_top.v`.

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

# Design

## Advent of Code 2025 Day 11
The inputs for this puzzle can be represented as a directed acyclic graph (DAG), with the devices themselves representing the nodes. So both parts can be solved with either a depth-first search (DFS) or a breadth-first search (BFS). Here, the testbench uses DFS as the reference answer implemented in software (`Python`), while the design implements BFS in hardware (`Verilog`). We'll first discuss the BFS-based solution as that is what is implemented in hardware.

A BFS-based solution is based on the idea that if we start from some initial start node that stores a value `1`, if we propagate that value to the whole graph by accumulating all values that a node gets from all its inputs, at the end node we would eventually get a value that corresponds to the number of paths.

```
aaa: you hhh
you: bbb ccc
bbb: ddd eee
ccc: ddd eee fff
ddd: ggg
eee: out
fff: out
ggg: out
hhh: ccc fff iii
iii: out
```

Using the puzzle's part 1 example:

1. If our start node is `you`, we set `you = 1`, while all other nodes have a value of `0`.
2. We propagate `you`'s value to its outputs, so that:
   - `bbb = 1`
   - `ccc = 1`
3. Now, we propagate the values of `bbb` and `ccc` to their respective outputs. However, since they share the output nodes `ddd` and `eee`, we accumulate both values there so that:
   - `ddd = 2` from both `bbb = 1` and `ccc = 1`
   - `eee = 2` from both `bbb = 1` and `ccc = `
   - `fff = 1` from `ccc = 1`
4. We repeat this process of propagating values until we arrive at the end node `out`, where we should eventually get `out = 5`.

This procedure can be used for both parts 1 and 2. For part 1, the value of the end node is the answer itself if we propagate it from the start node `you` to the end node `out`. For part 2, since the graph is a DAG and that it requires that we pass through both "middle" nodes `fft` and `dac`, instead of propagating the paths directly between `svr` and `out`, we can decompose the paths into 3:
- Path (1): from the start node `svr` to the middle node `fft`*
- Path (2): from the middle node `fft` to the other middle node `dac`
- Path (3): from the middle node `dac` to the end node `out`

If we use the procedure above for each of the 3 paths to get some value `svr_fft`, `fft_dac`, and `dac_out` and then multiply their results, we should get the part 2 answer.
*This assumes `fft` comes first before `dac`, which seems to be the case for the inputs to this puzzle based on my own input after solving it and on `r/adventofcode` discussions. The Verilog implementation assumes the same. The general solution I did was to compute for `(svr_fft*fft_dac*dac_out) + (svr_dac*dac_fft*fft_out)` where `svr_fft` ignores values for `dac` and `svr_dac` ignores values for `fft`.
