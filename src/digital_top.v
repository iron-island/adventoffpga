// FSM states
`define IDLE             3'b000
`define FETCH_START_NODE 3'b001
`define FETCH_END_NODE   3'b010
`define FETCH_NEXT_NODE  3'b011
`define RUN_MUL          3'b100
`define RUN_MAC          3'b101
`define OUTPUT_RESULT    3'b110

module digital_top
#(
    parameter PARAM_NODE_IDX_WIDTH  = 9,
    parameter PARAM_COUNTER_WIDTH   = 4,
    parameter PARAM_ACCUM_VAL_WIDTH = 24,
    parameter PARAM_FIFO_DEPTH      = 32
) (
    input                                  clk,
    input                                  rst_n,

    input                                  part_sel,
    input                                  start_run,

    output reg [PARAM_NODE_IDX_WIDTH-1:0]  node_idx,
    input      [PARAM_NODE_IDX_WIDTH-1:0]  next_node_idx,
    input      [PARAM_COUNTER_WIDTH-1:0]   next_node_counter // TODO: check max number of edges
);

    // Registers with specialized functions
    reg [PARAM_ACCUM_VAL_WIDTH-1:0] end_node_accum;
    reg [PARAM_NODE_IDX_WIDTH-1:0]  end_node_idx;
    reg                             wr_end_node;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            end_node_accum <= 'd0;
        end else if (wr_end_node) begin
            // TODO: end node accumulator

            end_node_idx <= node_idx;
        end
    end

    // Accumulator FIFO
    reg [PARAM_ACCUM_VAL_WIDTH-1:0]    fifo_accum_val[PARAM_FIFO_DEPTH];
    reg [PARAM_NODE_IDX_WIDTH-1:0]     fifo_node_idx[PARAM_FIFO_DEPTH];
    reg                                fifo_valid[PARAM_FIFO_DEPTH];

    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] fifo_wr_ptr;
    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] fifo_rd_ptr;

    reg                                fifo_wr_en;
    reg                                fifo_rd_en;

    reg                                fifo_wr_rd_ptr_eq;
    reg                                fifo_empty;
    reg                                fifo_full;

    // For simple empty and full flags, we can use any fifo_valid[*]
    //   flag to determine if FIFO is full or empty
    assign fifo_wr_rd_ptr_eq = (fifo_wr_ptr == fifo_rd_ptr);

    assign fifo_empty = (fifo_wr_rd_ptr_eq & !fifo_valid[0]);
    assign fifo_full  = (fifo_wr_rd_ptr_eq & fifo_valid[0]);

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < PARAM_FIFO_DEPTH; i++) begin
                fifo_accum_val[i] <= 'd0;
                fifo_node_idx[i]  <= 'd0;
                fifo_valid[i]     <= 'd0;
            end

            fifo_wr_ptr <= 'd0;
            fifo_rd_ptr <= 'd0;
        end else if (start_run) begin // not completely necessary since FSM should block FIFO operations,
                                      //   but allows implicit clock gating in some tools
            // Currently, simultaneous reads and writes aren't needed
            case (1'b1)
                fifo_wr_en   : begin
                    // TODO: Add node_idx checking for fifo_node_idx, where fifo_accum_val would no
                    //         longer depend on write pointer
                    fifo_accum_val[fifo_wr_ptr] <= 'd0; // TODO: accumulate instead of writing 0
                    fifo_node_idx[fifo_wr_ptr]  <= next_node_idx;
                    fifo_valid[fifo_wr_ptr]     <= 1'b1;

                    fifo_wr_ptr <= fifo_wr_ptr + 1'b1;
                end
                fifo_rd_en   : begin
                    // When reading, we pop it from the FIFO queue and clear the valid flag,
                    //   since we will use the flag for the presence of existing node indices
                    //   in the queue
                    fifo_valid[fifo_rd_ptr] <= 1'b0;

                    fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
                end
            endcase
        end
    end
    
    // Control FSM
    reg [2:0] curr_state;
    reg [2:0] next_state;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= `IDLE;
        end else begin
            curr_state <= (start_run) ? next_state : curr_state;
        end
    end

    always@(*) begin
        // default values
        fifo_wr_en = 1'b0;
        fifo_rd_en = 1'b0;

        wr_end_node = 1'b0;

        case (curr_state)
            `IDLE             : begin
                next_state = `FETCH_START_NODE;
            end
            `FETCH_START_NODE : begin
                // FIFO is used for the start node
                fifo_wr_en = 1'b1;

                next_state = `FETCH_END_NODE;
            end
            `FETCH_END_NODE   : begin
                // FIFO is not used for the end node, its saved in a separate register
                wr_end_node = 1'b1;

                next_state = `FETCH_NEXT_NODE;
            end
            `FETCH_NEXT_NODE  : begin
                // TODO: Push and pop control logic

                // TODO: transition to other states
                next_state = `FETCH_NEXT_NODE;
            end
            // TODO: other states
            default           : begin
                // Added for lint
                fifo_wr_en = 1'b0;
                fifo_rd_en = 1'b0;

                next_state = curr_state;
            end
        endcase
    end

endmodule 
