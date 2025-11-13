`timescale 1ns / 1ps
module Systolic_4 (
    input clk,
    input reset,
    input signed [7:0] a1, a2, a3, a4,
    input signed [7:0] b1, b2, b3, b4,
    output signed [31:0] c1, c2, c3, c4,
    output signed [31:0] c5, c6, c7, c8,
    output signed [31:0] c9, c10, c11, c12,
    output signed [31:0] c13, c14, c15, c16
);

    wire signed [7:0] a_bus [3:0][3:0];
    wire signed [7:0] b_bus [3:0][3:0];
    wire signed [31:0] c_bus [3:0][3:0];

    assign c1  = c_bus[0][0]; assign c2  = c_bus[0][1]; assign c3  = c_bus[0][2]; assign c4  = c_bus[0][3];
    assign c5  = c_bus[1][0]; assign c6  = c_bus[1][1]; assign c7  = c_bus[1][2]; assign c8  = c_bus[1][3];
    assign c9  = c_bus[2][0]; assign c10 = c_bus[2][1]; assign c11 = c_bus[2][2]; assign c12 = c_bus[2][3];
    assign c13 = c_bus[3][0]; assign c14 = c_bus[3][1]; assign c15 = c_bus[3][2]; assign c16 = c_bus[3][3];

    genvar i, j;
    generate
        for (i = 0; i < 4; i = i + 1) begin : ROW
            for (j = 0; j < 4; j = j + 1) begin : COL
                wire signed [7:0] in_a = (j == 0) ?
                    ((i == 0)? a1 : (i == 1)? a2 : (i == 2)? a3 : a4) :
                    a_bus[i][j-1];

                wire signed [7:0] in_b = (i == 0) ?
                    ((j == 0)? b1 : (j == 1)? b2 : (j == 2)? b3 : b4) :
                    b_bus[i-1][j];

                pe pe_inst (
                    .clk(clk),
                    .reset(reset),
                    .in_a(in_a),
                    .in_b(in_b),
                    .out_a(a_bus[i][j]),
                    .out_b(b_bus[i][j]),
                    .out_c(c_bus[i][j])
                );
            end
        end
    endgenerate

endmodule
