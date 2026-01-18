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

# Results

Using my puzzle input and a 100MHz (10ns period) clock input `clk`, starting from reset deassertion `rst_n` up to `done_reg` assertion the time to solve each part is:
1. Part 1: 3.38us (338 `clk` cycles)
2. Part 2: 121.220us (12,122 `clk` cycles)

# Design

## Advent of Code 2025 Day 11
The inputs for this puzzle can be represented as a directed acyclic graph (DAG), with the devices themselves representing the nodes. I initially solved both parts using DFS with memoization, and then tried solving both parts again based on BFS which maps more easily to hardware as explained in the next section. Here, the testbench uses the DFS solution as the reference answer implemented in software (`Python`), while the design implements BFS in hardware (`Verilog`).

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

This procedure is effectively a BFS where we have a FIFO queue that tracks both the node and its value. The next section explains how this is implemented and optimized in hardware.

## BFS in Hardware

The design has 5 main functional blocks:
1. First-in, First-out (FIFO) queue
2. Node index searcher
3. Control finite state machine (FSM)
4. Adder
5. Multiplier

### FIFO

The first main block of the design is the FIFO queue, implemented as a classical circular buffer. The FIFO depth chosen was 128, which is a power of 2 for simpler read/write pointer logic and seemed enough for my input after logging the maximum queue length with a BFS solution in `Python` after some optimizations using the searcher, explained later. Each entry of the FIFO has the following registers (note that FIFO depth and bitwidths are parametrized, but showing their default values for simplicity):
1. `fifo_node_idx[9:0]`   - the node represented as a numerical 10-bit node index
2. `fifo_accum_val[23:0]` - the node's accumulated value representing the number of paths found up to the node so far
3. `fifo_valid`           - a valid bit flag, which gets set/cleared when a node is pushed/popped from the FIFO

### Node index searcher

The second main block of the design is the node index searcher, which searches the whole FIFO for the presence of a given node index in a single cycle. This block is not necessary from a functional sense, but is a necessary optimization to make the hardware design more realistic/practical. The searcher provides 2 outputs:
1. `next_node_idx_present`   - a bit flag to represent whether the input node index is already present in the FIFO
2. `fifo_direct_wr_ptr[6:0]` - a pointer to where the node index is present

When an input node index is received, if that node index is already present on the FIFO based on `next_node_idx_present = 1`, then the node index is not pushed to the FIFO, but instead the `fifo_accum_val[23:0]` pointed to by `fifo_direct_wr_ptr[6:0]` is instead updated, effectively making each node index's value accumulate in only one of its entries. This avoids unnecessary pushing to the FIFO of node indices already in the queue, which would eventually gets popped later on, which would then have their output nodes pushed, and so on and so forth. Consequently, this also reduces the necessary depth of the FIFO. For example, in my input:
- The longest path was from `fft_dac = 8995504`, which required only a maximum FIFO depth of `107`. But without the searcher logic, the `Python` implementation shows that it still reaches millions (and possibly more) since it keeps pushing/popping nodes.
- The shortest path was from part 1 for `you_out = 585`, which only needed a maximum FIFO depth of `27`. Without the searcher, it also needed a depth of `585` since each entry would just be individual `1`s that eventually accumulate to `out`.

Unlike in software, the searcher in hardware checks is able to check all 128 entries of `fifo_node_idx[9:0]` and `fifo_valid` in parallel to efficiently search the whole FIFO in 1 clock cycle, with a trade off of needing more logic needed proportional to the FIFO depth.

### Control FSM

The third main block is the control FSM, which is responsible for all the input controls and data flow of the whole design, and is effectively what implements the whole BFS algorithm. The FSM is composed of 9 states:
1. `IDLE`
   - idle state when the design is not doing anything, such as during reset or after solving is done
2. `FETCH_START_NODE`
   - fetches the start node index from the `next_node_idx[9:0]` input, pushes it to the FIFO, and saves it to `start_node_idx[9:0]` register
   - in part 1, transitions to `FETCH_END_NODE`
   - in part 2, transitions to `FETCH_MID0_NODE`
3. `FETCH_MID0_NODE`
   - unused and unreachable in part 1
   - in part 2, fetches the first middle ("mid0") node index from the `next_node_idx[9:0]` input, saves it to `mid0_node_idx[9:0]` register, then transitions to `FETCH_MID1_NODE`
4. `FETCH_MID1_NODE`
   - in part 2, fetches the second middle ("mid1") node index from the `next_node_idx[9:0]` input, saves it to `mid1_node_idx[9:0]` register, then transitions to `FETCH_END_NODE`
5. `FETCH_END_NODE`
   - fetches the end node index from the `next_node_idx[9:0]` input and saves it to`end_node_idx[9:0]` register
   - loads the `node_idx_reg[9:0]` output based on the `fifo_node_idx[9:0]` pointed to by `fifo_rd_ptr[6:0]` to fetch the target nodes, then transitions to `POP_CURR_NODE`
6. `POP_CURR_NODE`
   - if the FIFO is empty, transitions to `END_BFS_ITER`
   - if the FIFO is not empty, pops a node from the FIFO (same as `node_idx_reg[9:0]`), based on the FIFO read pointer `fifo_rd_ptr[6:0]`, then transitions to `PUSH_NEXT_NODE`
7. `PUSH_NEXT_NODE`
   - if the FIFO is empty, transitions to `END_BFS_ITER`
   - if the FIFO is not empty:
     - if `next_node_idx[9:0]` is the end node (depending on part and iteration), it is not pushed to the FIFO but instead the end node's accumulated value is updated
     - if `next_node_idx[9:0]` is not in the FIFO based on the searcher logic, pushes it to the FIFO, based on the FIFO write pointer `fifo_wr_ptr[6:0]`
     - if `next_node_idx[9:0]` is in the FIFO based on the searcher logic, update the accumulated value based on the FIFO direct write pointer `fifo_direct_wr_ptr[6:0]`
     - transitions to `POP_CURR_NODE`
8. `END_BFS_ITER`
   - in part 1 this asserts the `done_reg` output flag and transitions to `IDLE`
   - in part 2 this transitions back to `POP_CURR_NODE` to do BFS 2 more times to compute for the other 2 paths
   - in part 2 on the last iteration, this starts the 1st multiplication between the start-to-mid0 (`svt_fft`) and mid0-to-mid1 (`fft_dac`) paths for saving to a product register `prod_reg[48:0]` and transitions to `END_MUL`
9. `END_MUL`
   - unused and unreachable in part 1
   - in part 2, this starts the 2nd multiplication between `prod_reg[48:0]` and the mid1-to-end (`dac_out`) paths for saving to the final answer `part_ans[48:0]`
   - in part 2, asserts the `done_reg` output flag and transitions to `IDLE`

During the BFS, the starting node is always pushed to the FIFO at the start when the FIFO is still empty, and all target nodes are pushed to the FIFO. The only exception is the end node which is never pushed to the FIFO since we aren't interested in their output nodes, and since the possible end nodes all have dedicated registers separate from the FIFO for accumulating its value so that they get directly used by the adder or multiplier:
1. `mid0_node_accum[23:0]` - accumulated value for the "mid0" node `mid0_node_idx[3:0]` (e.g. `fft`)
2. `mid1_node_accum[23:0]` - accumulated value for the "mid1" node `mid1_node_idx[3:0]` (e.g. `dac`)
3. `end_node_accum[23:0]`  - accumulated value for the end node `end_node_idx[3:0]` (e.g. `out`)

Once the puzzle is solved, the FSM transitions back to `IDLE`, where the output flag `done_reg = 1` to represent that it is done and that the part 1 or part 2 answer value is valid on the `part_ans[48:0]` output.

### Adder

The fourth block is a single cycle, combinational, 2 input, 24-bit adder that computes the accumulated value. Since only a single sum is computed at a time, only a single adder is needed. This also avoids implementing each `fifo_accum_val[23:0]` as an accumulator register which may synthesize to multiple adders. Then the adder instead has 2 inputs `accum_input0[23:0]` and `accum_input1[23:0]` whose values are multiplexed by the control FSM from input sources. The adder's combinational output `accum_result[23:0]` is also multiplexed by the control FSM to be saved to various registers, primarily to the `fifo_accum_val[23:0]` where the write pointer points to.

### Multiplier

The fifth block is a single cycle, combinational, 2 input 49-bit multiplier that computes the intermediate and final products for part 2. Similar to the adder, only a single product is computed at a time and has its inputs multiplexed and controlled by the FSM. The 2 inputs are:
1. `mul_input0[48:0]` - this is 49 bits since its largest possible input comes from the 49-bit product register `prod_reg[48:0]`, which stores the intermediate product
2. `mul_input1[23:0]` - this is only 24 bits since its largest possible input comes from the 24-bit accumulated values

The output `prod_result[48:0]` is always saved to the product register `prod_reg[48:0]`. There is no overflow detection done, since the product bit widths were only computed based on the part 2 answer using my input. Since the product bitwidth is is also parametrized, it can be increased if the expected part 2 answer does not fit.
