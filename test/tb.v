`default_nettype none
`timescale 1ns / 1ps

/* Testbench top copied and modified from Tiny Tapeout Verilog template,
 *   so that this serves as the dut and where the wires are defined which
 *   cocotb drives
 */
module tb ();

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
    reg data_in;
    
    wire data_out;
    
    // Actual design digital top
    digital_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (data_in),
        .data_out (data_out)
    );

endmodule
