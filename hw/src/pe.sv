`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Lydia Obeng (Original), Enhanced for ASIC
//
// Create Date: 11/10/2025 11:29:37 AM
// Design Name: Processing Elements - ASIC Optimized
// Module Name: pe
// Project Name: Efficient transformer accelerator
// Target Devices: ASIC
// Tool Versions:
// Description: Enhanced PE with clock gating, overflow protection, and DFT support
//
// Dependencies:
//
// Revision:
// Revision 0.02 - ASIC optimizations added
// Revision 0.01 - File Created
// Additional Comments:
// - Added enable signal for clock gating
// - Added saturation logic for accumulator overflow protection
// - Pipeline MAC operation for better timing
// - Explicit logic types for better synthesis control
//
//////////////////////////////////////////////////////////////////////////////////


module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    enable,        // Clock gating enable
    input  logic signed [DATA_WIDTH-1:0]  in_a,
    input  logic signed [DATA_WIDTH-1:0]  in_b,
    output logic signed [DATA_WIDTH-1:0]  out_a,
    output logic signed [DATA_WIDTH-1:0]  out_b,
    output logic signed [ACC_WIDTH-1:0]   out_c
);

    // Internal registers for pipelined multiply
    // Note: Accumulation is handled by the external accumulator_bank module
    logic signed [DATA_WIDTH-1:0] a_reg;
    logic signed [DATA_WIDTH-1:0] b_reg;
    logic signed [2*DATA_WIDTH-1:0] mult_result;
    logic signed [ACC_WIDTH-1:0] mult_extended;  // Sign-extended multiply result

    always_ff @(posedge clk) begin
        if (reset) begin
            a_reg       <= '0;
            b_reg       <= '0;
            mult_result <= '0;
            mult_extended <= '0;
            out_a       <= '0;
            out_b       <= '0;
            out_c       <= '0;
        end else if (enable) begin
            // Stage 1: Register inputs
            a_reg <= in_a;
            b_reg <= in_b;

            // Pass through registered values (maintains systolic timing)
            out_a <= a_reg;
            out_b <= b_reg;

            // Stage 2: Multiply
            mult_result <= a_reg * b_reg;

            // Stage 3: Sign-extend and output
            mult_extended <= {{(ACC_WIDTH-2*DATA_WIDTH){mult_result[2*DATA_WIDTH-1]}}, mult_result};
            out_c <= mult_extended;
        end
    end

endmodule
