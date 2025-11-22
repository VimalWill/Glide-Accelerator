`timescale 1ns / 1ps


module accumulator_bank #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter ACC_WIDTH = 32
)(
    input  logic clk,
    input  logic reset,
    input  logic enable,
    input  logic clear,


    input  logic signed [ACC_WIDTH-1:0]  partial_sums [ROWS-1:0][COLS-1:0],
    output logic signed [ACC_WIDTH-1:0]  accumulated_sums [ROWS-1:0][COLS-1:0],
    output logic overflow_flag
);

    logic signed [ACC_WIDTH-1:0] accum_regs [ROWS-1:0][COLS-1:0];
    logic signed [ACC_WIDTH:0] accum_temp [ROWS-1:0][COLS-1:0];
    logic overflow_detected [ROWS-1:0][COLS-1:0];
    logic any_overflow;

    always_ff @(posedge clk) begin
        if (reset) begin
            accum_regs <= '{default: '{default: '0}};
            overflow_detected <= '{default: '{default: 1'b0}};
        end else if (clear) begin
            accum_regs <= '{default: '{default: '0}};
            overflow_detected <= '{default: '{default: 1'b0}};
        end else if (enable) begin
            for (int i = 0; i < ROWS; i++) begin
                for (int j = 0; j < COLS; j++) begin
                    accum_temp[i][j] = {partial_sums[i][j][ACC_WIDTH-1], partial_sums[i][j]} +
                                       {accum_regs[i][j][ACC_WIDTH-1], accum_regs[i][j]};

                    if (accum_temp[i][j][ACC_WIDTH] != accum_temp[i][j][ACC_WIDTH-1]) begin
                        overflow_detected[i][j] <= 1'b1;
                        if (accum_temp[i][j][ACC_WIDTH]) begin
                            accum_regs[i][j] <= {1'b1, {(ACC_WIDTH-1){1'b0}}};
                        end else begin
                            accum_regs[i][j] <= {1'b0, {(ACC_WIDTH-1){1'b1}}};
                        end
                    end else begin
                        accum_regs[i][j] <= accum_temp[i][j][ACC_WIDTH-1:0];
                    end
                end
            end
        end
    end

    always_comb begin
        any_overflow = 1'b0;
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                any_overflow |= overflow_detected[i][j];
            end
        end
    end

    // Output assignments
    assign accumulated_sums = accum_regs;
    assign overflow_flag = any_overflow;

endmodule
