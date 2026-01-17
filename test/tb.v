`default_nettype none
`timescale 1ns / 1ps

/* Testbench top copied and modified from Tiny Tapeout Verilog template,
 *   so that this serves as the dut and where the wires are defined which
 *   cocotb drives
 */
module tb ();

    parameter PARAM_NODE_IDX_WIDTH  = 10;
    parameter PARAM_COUNTER_WIDTH   = 5;   // Part 1, 4 is enough, Part 2 needs 5
    parameter PARAM_ACCUM_VAL_WIDTH = 24;
    parameter PARAM_FIFO_DEPTH      = 128; // For part 1, depth of 32 is enough
                                           // For part 2, depth of 128 is needed,
                                           //   assuming we are restricted to a
                                           //   power of 2

    // Directly copied from Tiny Tapeout
    // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
    initial begin
      $dumpfile("tb.vcd");
      $dumpvars(0, tb);
      #1;
    end
    
    // Wire up the inputs and outputs:
    reg clk;
    reg rst_n;

    reg part_sel;
    reg start_run;

    reg [PARAM_NODE_IDX_WIDTH-1:0] node_idx_reg;
    reg                            rd_next_node_reg;
    reg [PARAM_NODE_IDX_WIDTH-1:0] next_node_idx;
    reg [PARAM_COUNTER_WIDTH-1:0]  next_node_counter;

    reg [PARAM_ACCUM_VAL_WIDTH-1:0] part1_ans;
    reg                             done_reg;

    // Testbench variables for logging nodes as 3-character strings
    reg [3*8:1] curr_node_string;
    reg [3*8:1] next_node_string;
    
    // Actual design digital top
    digital_top dut (
        .clk      (clk),
        .rst_n    (rst_n),

        .part_sel (part_sel),
        .start_run(start_run),

        .node_idx_reg(node_idx_reg),
        .rd_next_node_reg(rd_next_node_reg),
        .next_node_idx(next_node_idx),
        .next_node_counter(next_node_counter),

        .part1_ans(part1_ans),
        .done_reg(done_reg)
    );

endmodule
