module digital_top(
    input         clk,
    input         rst_n,
    input         data_in,
    output reg    data_out
);

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 1'b0;
	end else begin
            data_out <= data_in;
        end
    end

endmodule 
