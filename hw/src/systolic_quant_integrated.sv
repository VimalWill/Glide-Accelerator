`timescale 1ns / 1ps

module systolic_quant_integrated #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(

    input  logic clk,
    input  logic reset,
    input  logic enable,           
    input  logic signed [DATA_WIDTH-1:0] a_in [ARRAY_SIZE-1:0],
    input  logic signed [DATA_WIDTH-1:0] b_in [ARRAY_SIZE-1:0],

    input  logic accum_clear,      
    input  logic accum_enable,     
    input  logic [ACC_WIDTH-1:0] scale_factor,    
    input  logic [7:0] shift_amount,     
    input  logic quant_enable,    

    output logic signed [DATA_WIDTH-1:0] quant_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0],
    output logic systolic_valid,   
    output logic accum_overflow,   
    output logic quant_valid       
);

    //==========================================================================
    // Internal Signals
    //==========================================================================

    logic signed [ACC_WIDTH-1:0] systolic_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0] accum_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic systolic_valid_reg;
    logic accum_valid_reg;
    logic [3:0] quant_valid_delay;  // Requant has 4-stage pipeline

    //==========================================================================
    // Stage 1: Systolic Array (4x4 MAC Array)
    //==========================================================================

    systolic_top #(
        .ARRAY_SIZE(ARRAY_SIZE),
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

    always_ff @(posedge clk) begin
        if (reset)
            systolic_valid_reg <= 1'b0;
        else
            systolic_valid_reg <= enable;
    end

    assign systolic_valid = systolic_valid_reg;

    //==========================================================================
    // Stage 2: Accumulator Bank
    //==========================================================================

    accumulator_bank #(
        .ARRAY_SIZE(ARRAY_SIZE),
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
    // Stage 3: Requantization Array (16 parallel requantizers)
    //==========================================================================

    genvar i, j;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : QUANT_ROW
            for (j = 0; j < ARRAY_SIZE; j = j + 1) begin : QUANT_COL

                requant u_requant (
                    .clk          (clk),
                    .rst          (reset),
                    .en           (quant_enable),
                    .in           (accum_out[i][j]),
                    .b            (scale_factor),
                    .shift_factor (shift_amount),
                    .out          (quant_out[i][j])
                );

            end
        end
    endgenerate
    always_ff @(posedge clk) begin
        if (reset)
            quant_valid_delay <= 4'b0;
        else
            quant_valid_delay <= {quant_valid_delay[2:0], quant_enable};
    end

    assign quant_valid = quant_valid_delay[3];

endmodule
