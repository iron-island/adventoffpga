`default_nettype none
`timescale 1ns / 1ps

/* Testbench top copied and modified from Tiny Tapeout Verilog template,
 *   so that this serves as the dut and where the wires are defined which
 *   cocotb drives
 */
module tb ();

    parameter PARAM_NODE_IDX_WIDTH  = 9;
    parameter PARAM_COUNTER_WIDTH   = 4;
    parameter PARAM_ACCUM_VAL_WIDTH = 24;
    parameter PARAM_FIFO_DEPTH      = 32;

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

    reg start_run;

    reg [PARAM_NODE_IDX_WIDTH-1:0] node_idx;
    reg [PARAM_NODE_IDX_WIDTH-1:0] next_node_idx;
    reg [PARAM_COUNTER_WIDTH-1:0]  next_node_counter;
    
    // Actual design digital top
    digital_top dut (
        .clk      (clk),
        .rst_n    (rst_n),

        .part_sel (1'b0), // TODO: use for part 1 and part 2
        .start_run(start_run),

        .node_idx(node_idx),
        .next_node_idx(next_node_idx),
        .next_node_counter(next_node_counter)
    );

endmodule
