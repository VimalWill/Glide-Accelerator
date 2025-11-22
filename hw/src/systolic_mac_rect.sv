`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Rectangular Systolic Array - Supports M x N dimensions
// Optimized for modern AI workloads (e.g., 32x16 for transformers)
//////////////////////////////////////////////////////////////////////////////////

module systolic_mac_rect #(
    parameter ROWS = 32,        // M dimension (output features)
    parameter COLS = 16,        // N dimension (input features / reduction dim)
    parameter DATA_WIDTH = 8,   // INT8 precision
    parameter ACC_WIDTH = 32    // 32-bit accumulation
)(
    input  logic clk,
    input  logic reset,
    input  logic enable,

    // Vectorized inputs (M rows, N cols)
    input  logic signed [DATA_WIDTH-1:0] a_in [ROWS-1:0],
    input  logic signed [DATA_WIDTH-1:0] b_in [COLS-1:0],

    // Outputs (M x N matrix)
    output logic signed [ACC_WIDTH-1:0]  c_out [ROWS-1:0][COLS-1:0]
);

    //==========================================================================
    // Internal PE interconnect buses
    //==========================================================================

    logic signed [DATA_WIDTH-1:0] a_bus [ROWS-1:0][COLS-1:0];
    logic signed [DATA_WIDTH-1:0] b_bus [ROWS-1:0][COLS-1:0];
    logic signed [ACC_WIDTH-1:0]  c_bus [ROWS-1:0][COLS-1:0];

    //==========================================================================
    // Input skewing for systolic dataflow
    //==========================================================================

    // Synchronized reset
    logic reset_sync1, reset_sync2;

    always_ff @(posedge clk) begin
        reset_sync1 <= reset;
        reset_sync2 <= reset_sync1;
    end

    // Skew registers for A inputs (row-wise broadcast with delay)
    logic signed [DATA_WIDTH-1:0] a_skew [ROWS-1:0][COLS-1:0];

    // Skew registers for B inputs (column-wise broadcast with delay)
    logic signed [DATA_WIDTH-1:0] b_skew [ROWS-1:0][COLS-1:0];

    always_ff @(posedge clk) begin
        if (reset_sync2) begin
            a_skew <= '{default: '{default: '0}};
            b_skew <= '{default: '{default: '0}};
        end else if (enable) begin
            // A input skewing (horizontal propagation with delay)
            for (int i = 0; i < ROWS; i++) begin
                a_skew[i][0] <= a_in[i];
                for (int j = 1; j < COLS; j++) begin
                    a_skew[i][j] <= a_skew[i][j-1];
                end
            end

            // B input skewing (vertical propagation with delay)
            for (int j = 0; j < COLS; j++) begin
                b_skew[0][j] <= b_in[j];
                for (int i = 1; i < ROWS; i++) begin
                    b_skew[i][j] <= b_skew[i-1][j];
                end
            end
        end
    end

    //==========================================================================
    // Output pipeline registers
    //==========================================================================

    always_ff @(posedge clk) begin
        if (reset_sync2) begin
            c_out <= '{default: '{default: '0}};
        end else if (enable) begin
            c_out <= c_bus;
        end
    end

    //==========================================================================
    // PE Array Instantiation
    //==========================================================================

    genvar i, j;
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : ROW
            for (j = 0; j < COLS; j = j + 1) begin : COL

                // Input selection logic for systolic dataflow
                logic signed [DATA_WIDTH-1:0] pe_in_a;
                logic signed [DATA_WIDTH-1:0] pe_in_b;

                always_comb begin
                    // A flows horizontally (left to right)
                    if (j == 0) begin
                        // First column gets input directly (with row delay via skew)
                        pe_in_a = a_skew[i][0];
                    end else begin
                        // Subsequent columns get from previous PE
                        pe_in_a = a_bus[i][j-1];
                    end

                    // B flows vertically (top to bottom)
                    if (i == 0) begin
                        // First row gets input directly (with column delay via skew)
                        pe_in_b = b_skew[0][j];
                    end else begin
                        // Subsequent rows get from previous PE
                        pe_in_b = b_bus[i-1][j];
                    end
                end

                // PE instantiation
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk     (clk),
                    .reset   (reset_sync2),
                    .enable  (enable),
                    .in_a    (pe_in_a),
                    .in_b    (pe_in_b),
                    .out_a   (a_bus[i][j]),
                    .out_b   (b_bus[i][j]),
                    .out_c   (c_bus[i][j])
                );

            end
        end
    endgenerate

endmodule
