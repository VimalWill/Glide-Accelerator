`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: systolic_top - ASIC Optimized Top Wrapper
// Project Name: Efficient transformer accelerator
// Description: Top wrapper for the 4x4 systolic array (MAC)
//
// This file provides a compact, vector-style interface for the array
// and instantiates the `Systolic` module implemented in `systolic_mac.sv`.
//
// ASIC Optimizations:
// - Added enable signal for clock gating
// - Parameterizable data and accumulator widths
// - Fixed module naming (systolic_top)
// - Clean vector-to-scalar port mapping
//
//////////////////////////////////////////////////////////////////////////////////

module systolic_top #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic                         clk,
    input  logic                         reset,
    input  logic                         enable,        // Global enable for clock gating
    // 4-element input vectors (signed)
    input  logic signed [DATA_WIDTH-1:0] a_in [ARRAY_SIZE-1:0],
    input  logic signed [DATA_WIDTH-1:0] b_in [ARRAY_SIZE-1:0],
    // 4x4 output matrix (signed)
    output logic signed [ACC_WIDTH-1:0]  c_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0]
);

    // Instantiate the ASIC-optimized Systolic module
    // Map the vector inputs to the scalar ports and route scalar outputs
    // into the 2D `c_out` array.
    Systolic #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_systolic (
        .clk   (clk),
        .reset (reset),
        .enable(enable),

        .a1    (a_in[0]),
        .a2    (a_in[1]),
        .a3    (a_in[2]),
        .a4    (a_in[3]),

        .b1    (b_in[0]),
        .b2    (b_in[1]),
        .b3    (b_in[2]),
        .b4    (b_in[3]),

        .c1    (c_out[0][0]), .c2  (c_out[0][1]), .c3  (c_out[0][2]), .c4  (c_out[0][3]),
        .c5    (c_out[1][0]), .c6  (c_out[1][1]), .c7  (c_out[1][2]), .c8  (c_out[1][3]),
        .c9    (c_out[2][0]), .c10 (c_out[2][1]), .c11 (c_out[2][2]), .c12 (c_out[2][3]),
        .c13   (c_out[3][0]), .c14 (c_out[3][1]), .c15 (c_out[3][2]), .c16 (c_out[3][3])
    );

endmodule
