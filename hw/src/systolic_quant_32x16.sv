`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 32x16 Systolic Array Accelerator with Shared Quantization
// Optimized for Modern AI Workloads (Transformers, LLMs)
//
// Architecture:
//   - 512 PEs (32 rows x 16 cols) for matrix multiplication
//   - INT8 precision (8-bit inputs, 32-bit accumulation)
//   - 512 dedicated accumulators for multi-pass tiling
//   - 64 shared quantization units (8× time-multiplexed)
//
// Performance:
//   @ 200 MHz: 102.4 GMAC/s (512 MACs/cycle × 200M cycles/s)
//   Throughput: 32×16×K MatMul in K+~40 cycles
//////////////////////////////////////////////////////////////////////////////////

module systolic_quant_32x16 #(
    parameter ROWS = 32,
    parameter COLS = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter QUANT_UNITS = 64  // Shared quantization units
)(
    input  logic clk,
    input  logic reset,
    input  logic enable,

    // Input matrices (row and column vectors for outer product)
    input  logic signed [DATA_WIDTH-1:0] a_in [ROWS-1:0],
    input  logic signed [DATA_WIDTH-1:0] b_in [COLS-1:0],

    // Accumulator control
    input  logic accum_clear,
    input  logic accum_enable,

    // Quantization parameters
    input  logic [ACC_WIDTH-1:0] scale_factor,
    input  logic [7:0] shift_amount,
    input  logic quant_enable,

    // Outputs
    output logic signed [DATA_WIDTH-1:0] quant_out [ROWS-1:0][COLS-1:0],
    output logic systolic_valid,
    output logic accum_overflow,
    output logic quant_valid
);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    logic signed [ACC_WIDTH-1:0] systolic_out [ROWS-1:0][COLS-1:0];
    logic signed [ACC_WIDTH-1:0] accum_out [ROWS-1:0][COLS-1:0];
    logic systolic_valid_reg;
    logic accum_valid_reg;

    //==========================================================================
    // Stage 1: Rectangular Systolic Array (32x16)
    //==========================================================================

    systolic_mac_rect #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_systolic (
        .clk    (clk),
        .reset  (reset),
        .enable (enable),
        .a_in   (a_in),
        .b_in   (b_in),
        .c_out  (systolic_out)
    );

    // Systolic valid signal (delayed by array propagation)
    localparam SYSTOLIC_LATENCY = ROWS + COLS + 2;  // Approximate
    logic [SYSTOLIC_LATENCY-1:0] valid_delay;

    always_ff @(posedge clk) begin
        if (reset) begin
            valid_delay <= '0;
            systolic_valid_reg <= 1'b0;
        end else begin
            valid_delay <= {valid_delay[SYSTOLIC_LATENCY-2:0], enable};
            systolic_valid_reg <= valid_delay[SYSTOLIC_LATENCY-1];
        end
    end

    assign systolic_valid = systolic_valid_reg;

    //==========================================================================
    // Stage 2: Accumulator Bank (512 accumulators)
    //==========================================================================

    accumulator_bank #(
        .ROWS(ROWS),
        .COLS(COLS),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_accumulator (
        .clk             (clk),
        .reset           (reset),
        .enable          (accum_enable & systolic_valid_reg),
        .clear           (accum_clear),
        .partial_sums    (systolic_out),
        .accumulated_sums(accum_out),
        .overflow_flag   (accum_overflow)
    );

    always_ff @(posedge clk) begin
        if (reset)
            accum_valid_reg <= 1'b0;
        else
            accum_valid_reg <= accum_enable & systolic_valid_reg;
    end

    //==========================================================================
    // Stage 3: Shared Quantization (64 units, 8 cycles for 512 outputs)
    //==========================================================================

    quant_shared #(
        .ROWS(ROWS),
        .COLS(COLS),
        .ACC_WIDTH(ACC_WIDTH),
        .OUT_WIDTH(DATA_WIDTH),
        .QUANT_UNITS(QUANT_UNITS)
    ) u_quant_shared (
        .clk          (clk),
        .reset        (reset),
        .enable       (quant_enable),
        .scale_factor (scale_factor),
        .shift_amount (shift_amount),
        .data_in      (accum_out),
        .data_out     (quant_out),
        .valid        (quant_valid)
    );

endmodule
