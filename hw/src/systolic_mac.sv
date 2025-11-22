`timescale 1ns / 1ps


module Systolic #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic clk,
    input  logic reset,
    input  logic enable,  
    input  logic signed [DATA_WIDTH-1:0] a1, a2, a3, a4,
    input  logic signed [DATA_WIDTH-1:0] b1, b2, b3, b4,
    output logic signed [ACC_WIDTH-1:0]  c1, c2, c3, c4,
    output logic signed [ACC_WIDTH-1:0]  c5, c6, c7, c8,
    output logic signed [ACC_WIDTH-1:0]  c9, c10, c11, c12,
    output logic signed [ACC_WIDTH-1:0]  c13, c14, c15, c16
);

    // Internal buses for PE interconnect
    logic signed [DATA_WIDTH-1:0] a_bus [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] b_bus [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0]  c_bus [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    // Input pipeline registers for proper timing
    logic signed [DATA_WIDTH-1:0] a_input [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] b_input [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] a_skew [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] b_skew [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0] c_output [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic reset_sync1, reset_sync2;

    always_ff @(posedge clk) begin
        reset_sync1 <= reset;
        reset_sync2 <= reset_sync1;
    end

    // Input pipeline and skewing registers
    always_ff @(posedge clk) begin
        if (reset_sync2) begin
            a_input <= '{default: '0};
            b_input <= '{default: '0};
            a_skew  <= '{default: '{default: '0}};
            b_skew  <= '{default: '{default: '0}};
        end else if (enable) begin
            // Register inputs
            a_input[0] <= a1;
            a_input[1] <= a2;
            a_input[2] <= a3;
            a_input[3] <= a4;

            b_input[0] <= b1;
            b_input[1] <= b2;
            b_input[2] <= b3;
            b_input[3] <= b4;

            for (int i = 0; i < ARRAY_SIZE; i++) begin
                a_skew[i][0] <= a_input[i];
                for (int k = 1; k < ARRAY_SIZE; k++) begin
                    a_skew[i][k] <= a_skew[i][k-1];
                end
            end

            for (int j = 0; j < ARRAY_SIZE; j++) begin
                b_skew[j][0] <= b_input[j];
                for (int k = 1; k < ARRAY_SIZE; k++) begin
                    b_skew[j][k] <= b_skew[j][k-1];
                end
            end
        end
    end

    // Output pipeline registers
    always_ff @(posedge clk) begin
        if (reset_sync2) begin
            c_output <= '{default: '{default: '0}};
        end else if (enable) begin
            c_output <= c_bus;
        end
    end

    // Map outputs from pipeline registers
    assign c1  = c_output[0][0]; assign c2  = c_output[0][1]; assign c3  = c_output[0][2]; assign c4  = c_output[0][3];
    assign c5  = c_output[1][0]; assign c6  = c_output[1][1]; assign c7  = c_output[1][2]; assign c8  = c_output[1][3];
    assign c9  = c_output[2][0]; assign c10 = c_output[2][1]; assign c11 = c_output[2][2]; assign c12 = c_output[2][3];
    assign c13 = c_output[3][0]; assign c14 = c_output[3][1]; assign c15 = c_output[3][2]; assign c16 = c_output[3][3];

    // PE array instantiation
    genvar i, j;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : ROW
            for (j = 0; j < ARRAY_SIZE; j = j + 1) begin : COL

                // Input selection logic - simplified without nested ternary
                logic signed [DATA_WIDTH-1:0] pe_in_a;
                logic signed [DATA_WIDTH-1:0] pe_in_b;

                always_comb begin
                    if (j == 0) begin
                        pe_in_a = a_skew[i][i]; 
                    end else begin
                        pe_in_a = a_bus[i][j-1];
                    end

                    if (i == 0) begin
                        pe_in_b = b_skew[j][j]; 
                    end else begin
                        pe_in_b = b_bus[i-1][j];
                    end
                end

                // PE instantiation
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .reset(reset_sync2),
                    .enable(enable),
                    .in_a(pe_in_a),
                    .in_b(pe_in_b),
                    .out_a(a_bus[i][j]),
                    .out_b(b_bus[i][j]),
                    .out_c(c_bus[i][j])
                );
            end
        end
    endgenerate

endmodule
