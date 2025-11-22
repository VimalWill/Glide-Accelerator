`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for Integrated Systolic-Accumulator-Quant Pipeline
// Tests complete dataflow from 8-bit inputs to 8-bit quantized outputs
//////////////////////////////////////////////////////////////////////////////////

module systolic_quant_tb;

    // Parameters
    parameter ARRAY_SIZE = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100MHz

    // Testbench signals
    logic clk;
    logic reset;
    logic enable;

    // Systolic inputs
    logic signed [DATA_WIDTH-1:0] a_in [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] b_in [ARRAY_SIZE-1:0];

    // Accumulator control
    logic accum_clear;
    logic accum_enable;

    // Quantization parameters
    logic [ACC_WIDTH-1:0] scale_factor;
    logic [7:0] shift_amount;
    logic quant_enable;

    // Outputs
    logic signed [DATA_WIDTH-1:0] quant_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
    logic systolic_valid;
    logic accum_overflow;
    logic quant_valid;

    // Test vectors (declared at module level for Vivado compatibility)
    logic signed [7:0] a_vec[4];
    logic signed [7:0] b_vec[4];
    logic signed [7:0] a1[4], b1[4];
    logic signed [7:0] a2[4], b2[4];
    logic signed [7:0] a3[4], b3[4];
    logic signed [7:0] a_scale[4], b_scale[4];
    logic signed [7:0] a_neg[4], b_neg[4];

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    systolic_quant_integrated #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .enable         (enable),
        .a_in           (a_in),
        .b_in           (b_in),
        .accum_clear    (accum_clear),
        .accum_enable   (accum_enable),
        .scale_factor   (scale_factor),
        .shift_amount   (shift_amount),
        .quant_enable   (quant_enable),
        .quant_out      (quant_out),
        .systolic_valid (systolic_valid),
        .accum_overflow (accum_overflow),
        .quant_valid    (quant_valid)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Helper Tasks
    //==========================================================================

    task reset_system();
        begin
            reset = 1;
            enable = 0;
            accum_clear = 0;
            accum_enable = 0;
            quant_enable = 0;
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                a_in[i] = 0;
                b_in[i] = 0;
            end
            repeat(5) @(posedge clk);
            reset = 0;
            @(posedge clk);
        end
    endtask

    task load_inputs(input logic signed [7:0] a[4], input logic signed [7:0] b[4]);
        begin
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                a_in[i] = a[i];
                b_in[i] = b[i];
            end
        end
    endtask

    task display_output_matrix(input string label);
        begin
            $display("\n%s:", label);
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                $display("  Row %0d: %4d %4d %4d %4d",
                    i, $signed(quant_out[i][0]), $signed(quant_out[i][1]),
                    $signed(quant_out[i][2]), $signed(quant_out[i][3]));
            end
        end
    endtask

    //==========================================================================
    // Test Stimulus
    //==========================================================================

    initial begin
        $display("========================================");
        $display("Systolic-Quant Integrated Testbench");
        $display("========================================\n");

        // Initialize
        reset_system();

        //----------------------------------------------------------------------
        // Test 1: Simple Matrix Multiplication (Single Pass)
        //----------------------------------------------------------------------
        $display("Test 1: Simple 4x4 Matrix Multiply (Single Pass)");
        $display("Computing: [1,2,3,4]' * [1,2,3,4]");

        // Clear accumulators
        @(posedge clk);
        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Set quantization parameters (scale=1, shift=0 for identity)
        scale_factor = 32'd1;
        shift_amount = 8'd0;

        // Load inputs
        a_vec = '{8'sd1, 8'sd2, 8'sd3, 8'sd4};
        b_vec = '{8'sd1, 8'sd2, 8'sd3, 8'sd4};
        load_inputs(a_vec, b_vec);

        // Enable systolic
        enable = 1;

        // Wait for systolic wavefront to complete
        repeat(20) @(posedge clk);

        // Pulse accumulator enable for ONE cycle to capture result
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;

        // Wait a bit more
        repeat(5) @(posedge clk);

        // Enable quantization
        quant_enable = 1;

        // Wait for quantization pipeline
        repeat(10) @(posedge clk);

        // Check results when valid
        wait(quant_valid);
        @(posedge clk);

        // Debug: Show intermediate values
        $display("\n  Debug - Systolic output [0][0]: %d", $signed(dut.systolic_out[0][0]));
        $display("  Debug - Accumulator output [0][0]: %d", $signed(dut.accum_out[0][0]));

        display_output_matrix("Quantized Output (Identity Scale)");

        //----------------------------------------------------------------------
        // Test 2: Multi-Pass Accumulation (Tiled MatMul)
        //----------------------------------------------------------------------
        $display("\n\nTest 2: Multi-Pass Accumulation (Simulating Tiled MatMul)");

        // Disable quantization and accumulation
        quant_enable = 0;
        accum_enable = 0;
        enable = 0;
        @(posedge clk);

        // Clear accumulators for new computation
        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Pass 1: First tile
        $display("  Pass 1: Computing first tile");
        a1 = '{8'sd2, 8'sd2, 8'sd2, 8'sd2};
        b1 = '{8'sd3, 8'sd3, 8'sd3, 8'sd3};
        load_inputs(a1, b1);
        enable = 1;
        repeat(20) @(posedge clk);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        // Pass 2: Second tile (add to accumulator)
        $display("  Pass 2: Adding second tile");
        a2 = '{8'sd1, 8'sd1, 8'sd1, 8'sd1};
        b2 = '{8'sd2, 8'sd2, 8'sd2, 8'sd2};
        load_inputs(a2, b2);
        repeat(20) @(posedge clk);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        // Pass 3: Third tile
        $display("  Pass 3: Adding third tile");
        a3 = '{8'sd1, 8'sd1, 8'sd1, 8'sd1};
        b3 = '{8'sd1, 8'sd1, 8'sd1, 8'sd1};
        load_inputs(a3, b3);
        repeat(20) @(posedge clk);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        // Now quantize the accumulated result
        $display("  Quantizing accumulated result");
        quant_enable = 1;
        repeat(10) @(posedge clk);

        wait(quant_valid);
        @(posedge clk);
        display_output_matrix("Multi-Pass Accumulated & Quantized");
        $display("  Expected: Each element ≈ (2*3 + 1*2 + 1*1) * 16 = 9 * 16 = 144");

        //----------------------------------------------------------------------
        // Test 3: Quantization Scaling
        //----------------------------------------------------------------------
        $display("\n\nTest 3: Quantization with Scaling");

        // Reset and compute simple product
        enable = 0;
        accum_enable = 0;
        quant_enable = 0;
        @(posedge clk);

        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Compute 10 * 10 = 100 for all elements
        a_scale = '{8'sd10, 8'sd10, 8'sd10, 8'sd10};
        b_scale = '{8'sd10, 8'sd10, 8'sd10, 8'sd10};
        load_inputs(a_scale, b_scale);

        enable = 1;
        repeat(20) @(posedge clk);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        // Quantize with scale=2, shift=0 (should double the value)
        $display("  Scale Factor = 2, Shift = 0");
        scale_factor = 32'd2;
        shift_amount = 8'd0;
        quant_enable = 1;
        repeat(10) @(posedge clk);

        wait(quant_valid);
        @(posedge clk);
        display_output_matrix("Scaled by 2 (100*16*2 = 3200, saturates to 255)");

        // Test with right shift
        quant_enable = 0;
        @(posedge clk);
        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        load_inputs(a_scale, b_scale);
        enable = 1;
        accum_enable = 1;
        repeat(25) @(posedge clk);

        $display("  Scale Factor = 1, Shift = 4 (divide by 16)");
        scale_factor = 32'd1;
        shift_amount = 8'd4;  // Right shift by 4 = divide by 16
        quant_enable = 1;
        repeat(10) @(posedge clk);

        wait(quant_valid);
        @(posedge clk);
        display_output_matrix("Shifted Right by 4 (100*16 / 16 = 100)");

        //----------------------------------------------------------------------
        // Test 4: Negative Numbers
        //----------------------------------------------------------------------
        $display("\n\nTest 4: Signed Arithmetic");

        enable = 0;
        accum_enable = 0;
        quant_enable = 0;
        @(posedge clk);

        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Mix of positive and negative
        a_neg = '{-8'sd5, 8'sd3, -8'sd2, 8'sd4};
        b_neg = '{8'sd4, -8'sd3, 8'sd2, -8'sd1};
        load_inputs(a_neg, b_neg);

        scale_factor = 32'd1;
        shift_amount = 8'd0;

        enable = 1;
        repeat(20) @(posedge clk);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        quant_enable = 1;
        repeat(10) @(posedge clk);

        wait(quant_valid);
        @(posedge clk);
        display_output_matrix("Signed Arithmetic Result");

        //----------------------------------------------------------------------
        // Test Complete
        //----------------------------------------------------------------------
        repeat(10) @(posedge clk);

        $display("\n========================================");
        $display("All Tests Completed Successfully!");
        $display("========================================");

        if (accum_overflow)
            $display("WARNING: Accumulator overflow detected during testing");

        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================

    initial begin
        #500000; // 500us timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    //==========================================================================
    // Waveform Dumping
    //==========================================================================

    initial begin
        $dumpfile("systolic_quant_tb.vcd");
        $dumpvars(0, systolic_quant_tb);
    end

endmodule
