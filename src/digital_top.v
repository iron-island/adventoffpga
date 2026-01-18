// FSM states
`define IDLE             4'd0
`define FETCH_START_NODE 4'd1
`define FETCH_MID0_NODE  4'd2
`define FETCH_MID1_NODE  4'd3
`define FETCH_END_NODE   4'd4
`define POP_CURR_NODE    4'd5
`define PUSH_NEXT_NODE   4'd6
`define END_BFS_ITER     4'd7
`define END_MUL          4'd8

// Part 1 or 2 selection
`define PART1_SEL 1'b0
`define PART2_SEL 1'b1 // not used, but added for completeness

// For Part 2 iteration count
`define PART2_ITER_MID0 2'b00
`define PART2_ITER_MID1 2'b01
`define PART2_ITER_END  2'b11

// Accumulator selects, some values
//   are repeated because they get used
//   by the distinct accum_input0 and accum_input1 muxes

// For accum_input0_sel
`define ZERO_IN0_SEL           3'b000
`define FIFO_WR_IN0_SEL        3'b001
`define FIFO_DIRECT_WR_IN0_SEL 3'b010
`define MID0_NODE_IN0_SEL      3'b011
`define MID1_NODE_IN0_SEL      3'b100
`define END_NODE_IN0_SEL       3'b101

// For accum_input1_sel
`define ZERO_IN1_SEL         2'b00
`define ONE_IN1_SEL          2'b01
`define FIFO_RD_IN1_SEL      2'b10
`define FIFO_PREV_RD_IN1_SEL 2'b11

// For selecting input data to FIFO when writing
`define FIFO_PUSH_MID0 2'b01
`define FIFO_PUSH_MID1 2'b10

// Multiplier selects
// For mul_input0_sel
`define ZERO_MUL_IN0_SEL      2'b00
`define MID0_NODE_MUL_IN0_SEL 2'b01
`define PROD_MUL_IN0_SEL      2'b10

// For mul_input1_sel
`define ZERO_MUL_IN1_SEL      2'b00
`define MID1_NODE_MUL_IN1_SEL 2'b01
`define END_NODE_MUL_IN1_SEL  2'b10

// For padding MSBs of accumulator value to product width
`define ZERO_PAD_ACCUM {PARAM_PROD_VAL_WIDTH-PARAM_ACCUM_VAL_WIDTH{1'b0}}

module digital_top
#(
    parameter PARAM_NODE_IDX_WIDTH  = 10,
    parameter PARAM_COUNTER_WIDTH   = 5,   // Part 1, 4 is enough, Part 2 needs 5
    parameter PARAM_ACCUM_VAL_WIDTH = 24,
    parameter PARAM_PROD_VAL_WIDTH  = 49,
    parameter PARAM_FIFO_DEPTH      = 128  // For part 1, depth of 32 is enough
                                           // For part 2, depth of 128 is needed,
                                           //   assuming we are restricted to a
                                           //   power of 2
) (
    input                                  clk,
    input                                  rst_n,

    input                                  part_sel,
    input                                  start_run,

    output reg [PARAM_NODE_IDX_WIDTH-1:0]  node_idx_reg,
    output reg                             rd_next_node_reg,
    input      [PARAM_NODE_IDX_WIDTH-1:0]  next_node_idx,
    input      [PARAM_COUNTER_WIDTH-1:0]   next_node_counter, // TODO: check max number of edges

    output reg [PARAM_PROD_VAL_WIDTH-1:0]  part_ans,
    output reg                             done_reg
);

    // Part 1: Answer is the end node accumulated value
    // Part 2: Answer is the product register value
    assign part_ans = (part_sel) ? prod_reg : {`ZERO_PAD_ACCUM, end_node_accum};

    // Registers with specialized functions
    reg [PARAM_NODE_IDX_WIDTH-1:0]  start_node_idx;
    reg [PARAM_NODE_IDX_WIDTH-1:0]  mid0_node_idx;
    reg [PARAM_NODE_IDX_WIDTH-1:0]  mid1_node_idx;
    reg [PARAM_NODE_IDX_WIDTH-1:0]  end_node_idx;

    reg [PARAM_ACCUM_VAL_WIDTH-1:0] mid0_node_accum;
    reg [PARAM_ACCUM_VAL_WIDTH-1:0] mid1_node_accum;
    reg [PARAM_ACCUM_VAL_WIDTH-1:0] end_node_accum;

    reg                             wr_start_node;
    reg                             wr_mid0_node;
    reg                             wr_mid1_node;
    reg                             wr_end_node;
    reg                             wr_prod;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_node_idx <= 'd0;
            mid0_node_idx  <= 'd0;
            mid1_node_idx  <= 'd0;
            end_node_idx   <= 'd0;

            end_node_accum <= 'd0;
        end else if (wr_start_node) begin
            start_node_idx  <= next_node_idx;
        end else if (wr_mid0_node) begin
            mid0_node_idx   <= next_node_idx;
            mid0_node_accum <= accum_result;
        end else if (wr_mid1_node) begin
            mid1_node_idx   <= next_node_idx;
            mid1_node_accum <= accum_result;
        end else if (wr_end_node) begin
            end_node_idx    <= next_node_idx;
            end_node_accum  <= accum_result;
        end
    end

    // Multiplier
    wire [PARAM_PROD_VAL_WIDTH-1:0] prod_result;

    reg [PARAM_PROD_VAL_WIDTH-1:0] prod_reg;

    // Same width as product register since this uses it as as input,
    //   but can be reduced since this only uses the partial product
    reg [PARAM_PROD_VAL_WIDTH-1:0]  mul_input0;
    // Same width as the accumulators since it only uses them as input
    reg [PARAM_ACCUM_VAL_WIDTH-1:0] mul_input1;

    reg [1:0] mul_input0_sel;
    reg [1:0] mul_input1_sel;

    always@(*) begin
        case (mul_input0_sel)
            `ZERO_MUL_IN0_SEL      : mul_input0 = 'd0;
                                     // Pad MSBs with 0s
            `MID0_NODE_MUL_IN0_SEL : mul_input0 = {`ZERO_PAD_ACCUM, mid0_node_accum};
            `PROD_MUL_IN0_SEL      : mul_input0 = prod_reg;
            default                : mul_input0 = 'd0;
        endcase
    end

    always@(*) begin
        case (mul_input1_sel)
            `ZERO_MUL_IN1_SEL      : mul_input1 = 'd0;
            `MID1_NODE_MUL_IN1_SEL : mul_input1 = mid1_node_accum;
            `END_NODE_MUL_IN1_SEL  : mul_input1 = end_node_accum;
            default                : mul_input1 = 'd0;
        endcase
    end

    assign prod_result = (mul_input0 * mul_input1);

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prod_reg <= 'd0;
        end else if (wr_prod) begin
            prod_reg <= prod_result;
        end
    end

    // Accumulator
    // Inputs to the accumulator are controlled by the FSM
    wire [PARAM_ACCUM_VAL_WIDTH-1:0] accum_result;

    reg [PARAM_ACCUM_VAL_WIDTH-1:0] accum_input0;
    reg [PARAM_ACCUM_VAL_WIDTH-1:0] accum_input1;
    reg [2:0] accum_input0_sel;
    reg [1:0] accum_input1_sel;

    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] prev_fifo_rd_ptr;
    reg [$clog2(PARAM_FIFO_DEPTH)-1:0] fifo_direct_wr_ptr;

    assign prev_fifo_rd_ptr = (fifo_rd_ptr - 1'b1);

    always@(*) begin
        case (accum_input0_sel)
            `ZERO_IN0_SEL           : accum_input0 = 'd0;
            `FIFO_WR_IN0_SEL        : accum_input0 = fifo_accum_val[fifo_wr_ptr];
            `FIFO_DIRECT_WR_IN0_SEL : accum_input0 = fifo_accum_val[fifo_direct_wr_ptr];
            `MID0_NODE_IN0_SEL      : accum_input0 = mid0_node_accum;
            `MID1_NODE_IN0_SEL      : accum_input0 = mid1_node_accum;
            `END_NODE_IN0_SEL       : accum_input0 = end_node_accum;
            default                 : accum_input0 = 'd0;
        endcase
    end

    always@(*) begin
        case (accum_input1_sel)
            `ZERO_IN1_SEL    : accum_input1 = 'd0;
            `ONE_IN1_SEL     : accum_input1 = 'd1;
            `FIFO_RD_IN1_SEL : accum_input1 = fifo_accum_val[fifo_rd_ptr];
                               // Points to the last read register in the FIFO to avoid
                               //   needing to save the value to another register.
                               // This is valid because read values don't get flushed
                               // This is also valid even when FIFO is full, but not
                               //   when it overflows because the selected register
                               //   gets overwritten during the cycle when the FIFO would be full
            `FIFO_PREV_RD_IN1_SEL : accum_input1 = fifo_accum_val[prev_fifo_rd_ptr];
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

    reg [1:0]                          fifo_wr_data_sel;

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
                    fifo_accum_val[fifo_wr_ptr] <= accum_result;
                    if (fifo_wr_data_sel == `FIFO_PUSH_MID0) begin
                        fifo_node_idx[fifo_wr_ptr] <= mid0_node_idx;
                    end else if (fifo_wr_data_sel == `FIFO_PUSH_MID1) begin
                        fifo_node_idx[fifo_wr_ptr] <= mid1_node_idx;
                    end else begin
                        fifo_node_idx[fifo_wr_ptr] <= next_node_idx;
                    end
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
    reg                            next_node_idx_present;
    reg                            enable_check;

    always@(*) begin
        fifo_direct_wr_ptr    = 'd0;
        next_node_idx_present = 1'b0;

        for (int j = 0; j < PARAM_FIFO_DEPTH; j++) begin
            // Confirm that node index already exists in the FIFO based on 3 conditions:
            //   1. Current state is PUSH_NEXT_NODE, signaled by enable_check, can be removed but
            //        this reduces the activity on when checking is done
            //   2. FIFO data at pointer j is valid
            //   3. FIFO node index at pointer j matches
            if (enable_check &
                (fifo_valid[j[$clog2(PARAM_FIFO_DEPTH)-1:0]]) &
                (fifo_node_idx[j[$clog2(PARAM_FIFO_DEPTH)-1:0]] == next_node_idx)) begin
                fifo_direct_wr_ptr    = j[$clog2(PARAM_FIFO_DEPTH)-1:0];
                next_node_idx_present = 1'b1;
            end
        end
    end
    
    // Control FSM
    reg [3:0] curr_state;
    reg [3:0] next_state;

    reg [1:0] curr_part2_iter;
    reg [1:0] next_part2_iter;

    reg [PARAM_NODE_IDX_WIDTH-1:0] node_idx;
    reg                            rd_next_node;
    reg                            done;

    reg part1_selected;
    reg part2_selected;
    reg part2_iter_mid0_selected;
    reg part2_iter_mid1_selected;
    reg part2_iter_end_selected;

    reg [PARAM_NODE_IDX_WIDTH-1:0]  start_node_used;

    assign part1_selected = (part_sel == `PART1_SEL);
    assign part2_selected = !part1_selected;

    assign part2_iter_mid0_selected = (part2_selected & (curr_part2_iter == `PART2_ITER_MID0));
    assign part2_iter_mid1_selected = (part2_selected & (curr_part2_iter == `PART2_ITER_MID1));
    assign part2_iter_end_selected  = (part2_selected & (curr_part2_iter == `PART2_ITER_END));

    always@(*) begin
        if (part2_iter_mid1_selected) begin
            start_node_used = mid0_node_idx;
        end else if (part2_iter_end_selected) begin
            start_node_used = mid1_node_idx;
        end else begin
            // Covers part 1 and 1st iteration of part 2
            start_node_used = start_node_idx;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= `IDLE;

            curr_part2_iter  <= `PART2_ITER_MID0;

            node_idx_reg     <= 'd0;
            rd_next_node_reg <= 'd0;
            done_reg         <= 'd0;
        end else if (start_run) begin
            curr_state <= next_state;

            curr_part2_iter  <= next_part2_iter;

            node_idx_reg     <= node_idx;
            rd_next_node_reg <= rd_next_node;
            done_reg         <= done;
        end
    end

    always@(*) begin
        // default values
        next_part2_iter = curr_part2_iter;

        fifo_wr_en = 1'b0;
        fifo_rd_en = 1'b0;

        fifo_direct_wr_en = 1'b0;

        fifo_wr_data_sel = 2'b00;

        wr_start_node = 1'b0;
        wr_mid0_node  = 1'b0;
        wr_mid1_node  = 1'b0;
        wr_end_node   = 1'b0;
        wr_prod       = 1'b0;

        accum_input0_sel = `ZERO_IN0_SEL;
        accum_input1_sel = `ZERO_IN1_SEL;

        mul_input0_sel = `ZERO_MUL_IN0_SEL;
        mul_input1_sel = `ZERO_MUL_IN1_SEL;

        enable_check = 1'b0;

        node_idx = node_idx_reg;
        rd_next_node = rd_next_node_reg;
        done = done_reg;

        case (curr_state)
            `IDLE             : begin
                next_state = (done_reg) ? `IDLE : `FETCH_START_NODE;
            end
            `FETCH_START_NODE : begin
                // FIFO is used for the start node
                fifo_wr_en = 1'b1;
                wr_start_node = 1'b1;

                // Initialize start node with 1
                accum_input0_sel = `ZERO_IN0_SEL;
                accum_input1_sel = `ONE_IN1_SEL;

                // For part 1, skip fetching of middle nodes
                next_state = (part1_selected) ? `FETCH_END_NODE : `FETCH_MID0_NODE;
            end
            `FETCH_MID0_NODE : begin
                wr_mid0_node = 1'b1;

                next_state = `FETCH_MID1_NODE;
            end
            `FETCH_MID1_NODE : begin
                wr_mid1_node = 1'b1;

                next_state = `FETCH_END_NODE;
            end
            `FETCH_END_NODE   : begin
                // FIFO is not used for the end node, its saved in a separate register
                wr_end_node = 1'b1;

                // Initialize end node with 0
                accum_input0_sel = `ZERO_IN0_SEL;
                accum_input1_sel = `ZERO_IN1_SEL;

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
                accum_input0_sel = `FIFO_WR_IN0_SEL;
                accum_input1_sel = `FIFO_RD_IN1_SEL;

                if (fifo_empty) begin
                    next_state = `END_BFS_ITER;

                    // Assert done flag only after part 1
                    done = part1_selected;

                    // Deassert read control only after part 1 or after last iteration of part 2
                    rd_next_node = !(part1_selected | part2_iter_end_selected);

                end else begin
                    next_state = `PUSH_NEXT_NODE;
                end
            end
            `PUSH_NEXT_NODE   : begin
                // Enable checking if node index already exists in the FIFO
                enable_check = 1'b1;

                // If the received node index matches the middle or end node indices
                if ((next_node_idx == end_node_idx) &
                    (part1_selected | part2_iter_end_selected)) begin
                    // Write to the end node registers
                    wr_end_node = 1'b1;

                    // Use the existing value of the end node register
                    accum_input0_sel = `END_NODE_IN0_SEL;
                    accum_input1_sel = `FIFO_PREV_RD_IN1_SEL;
                end else if ((next_node_idx == mid0_node_idx) & part2_iter_mid0_selected) begin
                    // Write to the mid0 node registers
                    wr_mid0_node = 1'b1;

                    // Use the existing value of the mid0 node register
                    accum_input0_sel = `MID0_NODE_IN0_SEL;
                    accum_input1_sel = `FIFO_PREV_RD_IN1_SEL;
                end else if ((next_node_idx == mid1_node_idx) & part2_iter_mid1_selected) begin
                    // Write to the mid1 node registers
                    wr_mid1_node = 1'b1;

                    // Use the existing value of the mid1 node register
                    accum_input0_sel = `MID1_NODE_IN0_SEL;
                    accum_input1_sel = `FIFO_PREV_RD_IN1_SEL;
                end else if (next_node_idx_present) begin
                    // Enable direct write to where next_node_idx is present in the FIFO
                    fifo_direct_wr_en = 1'b1;

                    // Use the existing value of the FIFO data
                    accum_input0_sel = `FIFO_DIRECT_WR_IN0_SEL;
                    accum_input1_sel = `FIFO_PREV_RD_IN1_SEL;
                end else begin
                    // Push the next node
                    fifo_wr_en = 1'b1;

                    // Pushing new nodes so we only need to copy the accumulated
                    //   value from the previous node
                    accum_input0_sel = `ZERO_IN0_SEL;
                    accum_input1_sel = `FIFO_PREV_RD_IN1_SEL;
                end

                // If FIFO is already empty, and it wasn't due to popping the starting node,
                //   output is done
                if (fifo_empty & (node_idx_reg != start_node_used)) begin
                    next_state = `END_BFS_ITER;

                    // Assert done flag only after part 1
                    done = part1_selected;

                    // Deassert read control only after part 1 or after last iteration of part 2
                    rd_next_node = !(part1_selected | part2_iter_end_selected);

                    // Do not push the next node anymore
                    fifo_wr_en = 1'b0;

                // If on the last next_node_idx, go back to popping the queue,
                //   otherwise there are more next_node_idx so keep pushing
                end else if (next_node_counter == 'd1) begin
                    // Prepare to register node_idx_reg for fetching
                    //   during POP_CURR_NODE state
                    node_idx = fifo_node_idx[fifo_rd_ptr];

                    next_state = `POP_CURR_NODE;
                end else begin
                    next_state = `PUSH_NEXT_NODE;
                end
            end
            `END_BFS_ITER : begin
                if (part2_iter_mid0_selected) begin
                    // Push mid0 node to the FIFO queue
                    //   as the start node
                    fifo_wr_en = 1'b1;
                    fifo_wr_data_sel = `FIFO_PUSH_MID0;

                    // Initialize pushed node with 1
                    accum_input0_sel = `ZERO_IN0_SEL;
                    accum_input1_sel = `ONE_IN1_SEL;

                    // Prepare to register node_idx_reg for fetching
                    //   during POP_CURR_NODE state
                    node_idx = mid0_node_idx;
                    // Update part 2 iteration
                    next_part2_iter = `PART2_ITER_MID1;

                    next_state = `POP_CURR_NODE;
                end else if (part2_iter_mid1_selected) begin
                    // Push mid1 node to the FIFO queue
                    //   as the start node
                    fifo_wr_en = 1'b1;
                    fifo_wr_data_sel = `FIFO_PUSH_MID1;

                    // Initialize pushed node with 1
                    accum_input0_sel = `ZERO_IN0_SEL;
                    accum_input1_sel = `ONE_IN1_SEL;

                    // Prepare to register node_idx_reg for fetching
                    //   during POP_CURR_NODE state
                    node_idx = mid1_node_idx;
                    // Update part 2 iteration
                    next_part2_iter = `PART2_ITER_END;

                    next_state = `POP_CURR_NODE;
                end else if (part2_iter_end_selected) begin
                    // Write to product register which is also where the part 2
                    //   answer is
                    wr_prod = 1'b1;

                    // Use mid0 and mid1 nodes as inputs to multiplier
                    mul_input0_sel = `MID0_NODE_MUL_IN0_SEL;
                    mul_input1_sel = `MID1_NODE_MUL_IN1_SEL;

                    next_state = `END_MUL;
                end else begin
                    // Go to idle state after part 1
                    next_state = `IDLE;
                end
            end
            `END_MUL : begin
                // Write to product register again
                wr_prod = 1'b1;

                // Use the previous product register's value and
                //   the accumulated end node value as inputs to the multiplier
                mul_input0_sel = `PROD_MUL_IN0_SEL;
                mul_input1_sel = `END_NODE_MUL_IN1_SEL;

                // Assert done flag, since this is the end of part 2
                done = 1'b1;

                next_state = `IDLE;
            end
            default           : begin
                // Added for lint
                fifo_wr_en = 1'b0;
                fifo_rd_en = 1'b0;

                next_state = curr_state;
            end
        endcase
    end

endmodule 
