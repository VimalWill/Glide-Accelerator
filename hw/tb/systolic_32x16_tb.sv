`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for 32x16 Systolic Array Accelerator
// Tests basic functionality with small test vectors
//////////////////////////////////////////////////////////////////////////////////

module systolic_32x16_tb();

    // Parameters
    parameter ROWS = 32;
    parameter COLS = 16;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10;  // 100MHz

    // Testbench signals
    logic clk;
    logic reset;
    logic enable;

    // Systolic inputs
    logic signed [DATA_WIDTH-1:0] a_in [ROWS-1:0];
    logic signed [DATA_WIDTH-1:0] b_in [COLS-1:0];

    // Accumulator control
    logic accum_clear;
    logic accum_enable;

    // Quantization parameters
    logic [ACC_WIDTH-1:0] scale_factor;
    logic [7:0] shift_amount;
    logic quant_enable;

    // Outputs
    logic signed [DATA_WIDTH-1:0] quant_out [ROWS-1:0][COLS-1:0];
    logic systolic_valid;
    logic accum_overflow;
    logic quant_valid;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================

    systolic_quant_32x16 #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .QUANT_UNITS(64)
    ) dut (
        .clk           (clk),
        .reset         (reset),
        .enable        (enable),
        .a_in          (a_in),
        .b_in          (b_in),
        .accum_clear   (accum_clear),
        .accum_enable  (accum_enable),
        .scale_factor  (scale_factor),
        .shift_amount  (shift_amount),
        .quant_enable  (quant_enable),
        .quant_out     (quant_out),
        .systolic_valid(systolic_valid),
        .accum_overflow(accum_overflow),
        .quant_valid   (quant_valid)
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
            for (int i = 0; i < ROWS; i++) a_in[i] = 0;
            for (int j = 0; j < COLS; j++) b_in[j] = 0;
            repeat(5) @(posedge clk);
            reset = 0;
            @(posedge clk);
        end
    endtask

    task display_sample_outputs();
        begin
            $display("\n  Sample outputs (first 4x4 block):");
            for (int i = 0; i < 4; i++) begin
                $display("    Row %0d: %4d %4d %4d %4d", i,
                    $signed(quant_out[i][0]), $signed(quant_out[i][1]),
                    $signed(quant_out[i][2]), $signed(quant_out[i][3]));
            end
        end
    endtask

    //==========================================================================
    // Test Stimulus
    //==========================================================================

    initial begin
        $display("========================================");
        $display("32x16 Systolic Array Testbench");
        $display("========================================\n");

        // Initialize
        reset_system();

        //----------------------------------------------------------------------
        // Test 1: Simple Outer Product (All 1s)
        //----------------------------------------------------------------------
        $display("Test 1: Outer Product [1,1,..1] x [1,1,..1]");
        $display("  Expected: All outputs = 1 * 1 = 1");

        // Clear accumulators
        @(posedge clk);
        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Set quantization (scale=1, shift=0)
        scale_factor = 32'd1;
        shift_amount = 8'd0;

        // Load inputs (all 1s)
        for (int i = 0; i < ROWS; i++) a_in[i] = 8'sd1;
        for (int j = 0; j < COLS; j++) b_in[j] = 8'sd1;

        // Enable systolic
        enable = 1;

        // Wait for systolic propagation and valid signal
        repeat(ROWS + COLS + 10) @(posedge clk);
        wait(systolic_valid);

        // Capture in accumulator (single pulse)
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;

        repeat(5) @(posedge clk);

        // Enable quantization
        quant_enable = 1;

        // Wait for quantization completion
        fork
            begin
                wait(quant_valid);
            end
            begin
                repeat(100) @(posedge clk);
                $display("  [%0t] ERROR: quant_valid timeout after 100 cycles", $time);
            end
        join_any
        disable fork;
        @(posedge clk);

        display_sample_outputs();

        //----------------------------------------------------------------------
        // Test 2: Scaled Values
        //----------------------------------------------------------------------
        $display("\n\nTest 2: Outer Product [2,2,..2] x [3,3,..3]");
        $display("  Expected: All outputs = 2 * 3 = 6");

        quant_enable = 0;
        accum_enable = 0;
        enable = 0;
        @(posedge clk);

        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Load inputs
        for (int i = 0; i < ROWS; i++) a_in[i] = 8'sd2;
        for (int j = 0; j < COLS; j++) b_in[j] = 8'sd3;

        enable = 1;
        repeat(ROWS + COLS + 10) @(posedge clk);
        wait(systolic_valid);

        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;

        repeat(5) @(posedge clk);

        quant_enable = 1;

        fork
            begin
                wait(quant_valid);
            end
            begin
                repeat(100) @(posedge clk);
                $display("  [%0t] ERROR: quant_valid timeout after 100 cycles", $time);
            end
        join_any
        disable fork;
        @(posedge clk);

        display_sample_outputs();

        //----------------------------------------------------------------------
        // Test 3: Multi-Pass Accumulation
        //----------------------------------------------------------------------
        $display("\n\nTest 3: Multi-Pass Accumulation");
        $display("  Pass 1: 2x3 = 6");
        $display("  Pass 2: 1x2 = 2");
        $display("  Expected: 6 + 2 = 8");

        quant_enable = 0;
        accum_enable = 0;
        enable = 0;
        @(posedge clk);

        accum_clear = 1;
        @(posedge clk);
        accum_clear = 0;

        // Pass 1
        for (int i = 0; i < ROWS; i++) a_in[i] = 8'sd2;
        for (int j = 0; j < COLS; j++) b_in[j] = 8'sd3;
        enable = 1;
        repeat(ROWS + COLS + 10) @(posedge clk);
        wait(systolic_valid);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        // Pass 2
        for (int i = 0; i < ROWS; i++) a_in[i] = 8'sd1;
        for (int j = 0; j < COLS; j++) b_in[j] = 8'sd2;
        repeat(ROWS + COLS + 10) @(posedge clk);
        wait(systolic_valid);
        accum_enable = 1;
        @(posedge clk);
        accum_enable = 0;
        repeat(5) @(posedge clk);

        // Quantize
        quant_enable = 1;

        fork
            begin
                wait(quant_valid);
            end
            begin
                repeat(100) @(posedge clk);
                $display("  [%0t] ERROR: quant_valid timeout after 100 cycles", $time);
            end
        join_any
        disable fork;
        @(posedge clk);

        display_sample_outputs();

        //----------------------------------------------------------------------
        // Test Complete
        //----------------------------------------------------------------------
        repeat(10) @(posedge clk);

        $display("\n========================================");
        $display("All Tests Completed!");
        $display("========================================");

        if (accum_overflow)
            $display("WARNING: Accumulator overflow detected");

        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================

    initial begin
        #2000000; // 2ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    //==========================================================================
    // Waveform Dumping
    //==========================================================================

    initial begin
        $dumpfile("systolic_32x16_tb.vcd");
        $dumpvars(0, systolic_32x16_tb);
    end

endmodule
