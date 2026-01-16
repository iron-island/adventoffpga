// FSM states
`define IDLE             3'b000
`define FETCH_START_NODE 3'b001
`define FETCH_END_NODE   3'b010
`define POP_CURR_NODE    3'b011
`define PUSH_NEXT_NODE   3'b100
`define RUN_MUL          3'b101
`define RUN_MAC          3'b110
`define OUTPUT_RESULT    3'b111

// Accumulator selects, some values
//   are repeated because they get used
//   by the distinct accum_input0 and accum_input1 muxes

// For both accum_input0_sel and accum_input1_sel
`define ZERO_VAL_SEL    2'b00

// For accum_input0_sel
`define FIFO_WR_VAL_SEL        2'b01
`define FIFO_DIRECT_WR_VAL_SEL 2'b10
`define END_NODE_SEL           2'b11

// For accum_input1_sel
`define ONE_VAL_SEL          2'b01
`define FIFO_RD_VAL_SEL      2'b10
`define FIFO_PREV_RD_VAL_SEL 2'b11

module digital_top
#(
    parameter PARAM_NODE_IDX_WIDTH  = 10,
    parameter PARAM_COUNTER_WIDTH   = 4,
    parameter PARAM_ACCUM_VAL_WIDTH = 24,
    parameter PARAM_FIFO_DEPTH      = 32
) (
    input                                  clk,
    input                                  rst_n,

    input                                  part_sel,
    input                                  start_run,

    output reg [PARAM_NODE_IDX_WIDTH-1:0]  node_idx_reg,
    output reg                             rd_next_node_reg,
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

            end_node_idx <= next_node_idx;
        end
    end

    // Accumulator
    // Inputs to the accumulator are controlled by the FSM
    wire [PARAM_ACCUM_VAL_WIDTH-1:0] accum_result;

    reg [PARAM_ACCUM_VAL_WIDTH-1:0] accum_input0;
    reg [PARAM_ACCUM_VAL_WIDTH-1:0] accum_input1;
    reg [1:0] accum_input0_sel;
    reg [1:0] accum_input1_sel;

    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] prev_fifo_rd_ptr;
    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] fifo_direct_wr_ptr;

    assign prev_fifo_rd_ptr = (fifo_rd_ptr - 1'b1);

    always@(*) begin
        case (accum_input0_sel)
            `ZERO_VAL_SEL           : accum_input0 = 'd0;
            `FIFO_WR_VAL_SEL        : accum_input0 = fifo_accum_val[fifo_wr_ptr];
            `FIFO_DIRECT_WR_VAL_SEL : accum_input0 = fifo_accum_val[fifo_direct_wr_ptr];
            `END_NODE_SEL           : accum_input0 = end_node_accum;
            default                 : accum_input0 = 'd0;
        endcase
    end

    always@(*) begin
        case (accum_input1_sel)
            `ZERO_VAL_SEL    : accum_input1 = 'd0;
            `ONE_VAL_SEL     : accum_input1 = 'd1;
            `FIFO_RD_VAL_SEL : accum_input1 = fifo_accum_val[fifo_rd_ptr];
                               // Points to the last read register in the FIFO to avoid
                               //   needing to save the value to another register.
                               // This is valid because read values don't get flushed
                               // This is also valid even when FIFO is full, but not
                               //   when it overflows because the selected register
                               //   gets overwritten during the cycle when the FIFO would be full
            `FIFO_PREV_RD_VAL_SEL : accum_input1 = fifo_accum_val[prev_fifo_rd_ptr];
            default          : accum_input1 = 'd0;
        endcase
    end
    
    assign accum_result = (accum_input0 + accum_input1);

    // Accumulator result and node index FIFO
    reg [PARAM_ACCUM_VAL_WIDTH-1:0]    fifo_accum_val[PARAM_FIFO_DEPTH];
    reg [PARAM_NODE_IDX_WIDTH-1:0]     fifo_node_idx[PARAM_FIFO_DEPTH];
    reg                                fifo_valid[PARAM_FIFO_DEPTH];

    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] fifo_wr_ptr;
    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] fifo_rd_ptr;

    reg                                fifo_wr_en;
    reg                                fifo_rd_en;
    reg                                fifo_direct_wr_en;

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
                    fifo_accum_val[fifo_wr_ptr] <= accum_result;
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
                fifo_direct_wr_en : begin // direct writes for node indices that already exist
                    // Write pointer isn't updated since the node index already exists
                    // Valid flag isn't updated since its already valid
                    // Only accumulator result is updated
                    fifo_accum_val[fifo_direct_wr_ptr] <= accum_result;
                end
            endcase
        end
    end

    // Logic for checking presence of node index in FIFO
    reg                                node_idx_present;

    always@(*) begin
        fifo_direct_wr_ptr = 'd0;
        node_idx_present   = 1'b0;

        for (int j = 0; j < PARAM_FIFO_DEPTH; j++) begin
            // If FIFO data at pointer j is valid and has the node index
            if ((fifo_valid[j[$clog2(PARAM_FIFO_DEPTH)-1:0]]) & (fifo_node_idx[j[$clog2(PARAM_FIFO_DEPTH)-1:0]] == next_node_idx)) begin
                fifo_direct_wr_ptr = j[$clog2(PARAM_FIFO_DEPTH)-1:0];
                node_idx_present   = 1'b1;
            end
        end
    end
    
    // Control FSM
    reg [2:0] curr_state;
    reg [2:0] next_state;

    reg [PARAM_NODE_IDX_WIDTH-1:0] node_idx;
    reg                            rd_next_node;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= `IDLE;

            node_idx_reg     <= 'd0;
            rd_next_node_reg <= 'd0;
        end else if (start_run) begin
            curr_state <= next_state;

            node_idx_reg     <= node_idx;
            rd_next_node_reg <= rd_next_node;
        end
    end

    always@(*) begin
        // default values
        fifo_wr_en = 1'b0;
        fifo_rd_en = 1'b0;

        fifo_direct_wr_en = 1'b0;

        wr_end_node = 1'b0;

        accum_input0_sel = `ZERO_VAL_SEL;
        accum_input1_sel = `ZERO_VAL_SEL;

        node_idx = node_idx_reg;
        rd_next_node = rd_next_node_reg;

        case (curr_state)
            `IDLE             : begin
                next_state = `FETCH_START_NODE;
            end
            `FETCH_START_NODE : begin
                // FIFO is used for the start node
                fifo_wr_en = 1'b1;

                // Initialize start node with 1
                accum_input0_sel = `ZERO_VAL_SEL;
                accum_input1_sel = `ONE_VAL_SEL;

                next_state = `FETCH_END_NODE;
            end
            `FETCH_END_NODE   : begin
                // FIFO is not used for the end node, its saved in a separate register
                wr_end_node = 1'b1;

                // Initialize end node with 0
                accum_input0_sel = `END_NODE_SEL;
                accum_input1_sel = `ZERO_VAL_SEL;

                // Prepare to register node_idx_reg for fetching
                //   during POP_CURR_NODE state, and assert read control
                node_idx = fifo_node_idx[fifo_rd_ptr];
                rd_next_node = 1'b1;

                next_state = `POP_CURR_NODE;
            end
            `POP_CURR_NODE    : begin
                // Pop the current node
                fifo_rd_en = 1'b1;

                // Prepare the accumulator inputs for pushing
                //   to the FIFO in PUSH_NEXT_NODE state
                accum_input0_sel = `FIFO_WR_VAL_SEL;
                accum_input1_sel = `FIFO_RD_VAL_SEL;

                next_state = `PUSH_NEXT_NODE;
            end
            `PUSH_NEXT_NODE   : begin
                // TODO: logic for checking if next_node_idx already exists in the FIFO
                // Push the next node
                fifo_wr_en = 1'b1;

                // Pushing new nodes so we only need to copy the accumulated
                //   value from the previous node
                accum_input0_sel = `ZERO_VAL_SEL;
                accum_input1_sel = `FIFO_PREV_RD_VAL_SEL;

                // If on the last next_node_idx, go back to popping the queue,
                //   otherwise there are more next_node_idx so keep pushing
                if (next_node_counter == 'd1) begin
                    // Prepare to register node_idx_reg for fetching
                    //   during POP_CURR_NODE state
                    node_idx = fifo_node_idx[fifo_rd_ptr];

                    next_state = `POP_CURR_NODE;
                end else begin
                    next_state = `PUSH_NEXT_NODE;
                end
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
