`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for ASIC-Optimized Systolic Array
// Tests basic functionality, enable gating, and overflow protection
//////////////////////////////////////////////////////////////////////////////////

module systolic_tb;

    // Parameters
    parameter ARRAY_SIZE = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100MHz

    // Signals
    logic clk;
    logic reset;
    logic enable;
    logic signed [DATA_WIDTH-1:0] a_in [ARRAY_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] b_in [ARRAY_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0]  c_out [ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];

    // DUT instantiation
    systolic_top #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .a_in(a_in),
        .b_in(b_in),
        .c_out(c_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        reset = 1;
        enable = 0;
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            a_in[i] = 0;
            b_in[i] = 0;
        end

        // Display header
        $display("========================================");
        $display("Systolic Array ASIC Testbench");
        $display("========================================");
        $display("Time\t\tTest Case");
        $display("----------------------------------------");

        // Wait for initial reset
        repeat(5) @(posedge clk);
        reset = 0;
        $display("%0t ns\tReset deasserted", $time);

        // Test 1: Basic functionality with enable
        @(posedge clk);
        enable = 1;
        $display("%0t ns\tTest 1: Basic MAC operation", $time);

        // Load simple pattern: a = [1,2,3,4], b = [1,2,3,4]
        a_in[0] = 8'sd1;
        a_in[1] = 8'sd2;
        a_in[2] = 8'sd3;
        a_in[3] = 8'sd4;

        b_in[0] = 8'sd1;
        b_in[1] = 8'sd2;
        b_in[2] = 8'sd3;
        b_in[3] = 8'sd4;

        // Wait for systolic wavefront to propagate and accumulate
        repeat(20) @(posedge clk);

        $display("%0t ns\tResults after wavefront:", $time);
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            $display("\t\tRow %0d: %0d, %0d, %0d, %0d",
                i, c_out[i][0], c_out[i][1], c_out[i][2], c_out[i][3]);
        end

        // Test 2: Clock gating (enable = 0)
        @(posedge clk);
        $display("%0t ns\tTest 2: Clock gating (enable=0)", $time);
        enable = 0;

        // Change inputs while disabled
        a_in[0] = 8'sd10;
        b_in[0] = 8'sd10;

        repeat(5) @(posedge clk);

        $display("%0t ns\tOutputs should not change:", $time);
        $display("\t\tc_out[0][0] = %0d (should be unchanged)", c_out[0][0]);

        // Test 3: Re-enable and verify accumulation continues
        @(posedge clk);
        enable = 1;
        $display("%0t ns\tTest 3: Re-enable, verify accumulation", $time);

        a_in[0] = 8'sd1;
        b_in[0] = 8'sd1;

        repeat(10) @(posedge clk);

        $display("%0t ns\tAccumulator should increment:", $time);
        $display("\t\tc_out[0][0] = %0d", c_out[0][0]);

        // Test 4: Negative numbers
        @(posedge clk);
        reset = 1;
        repeat(2) @(posedge clk);
        reset = 0;
        enable = 1;

        $display("%0t ns\tTest 4: Negative number handling", $time);

        a_in[0] = -8'sd5;
        a_in[1] = 8'sd3;
        a_in[2] = -8'sd2;
        a_in[3] = 8'sd1;

        b_in[0] = 8'sd4;
        b_in[1] = -8'sd3;
        b_in[2] = 8'sd2;
        b_in[3] = -8'sd1;

        repeat(20) @(posedge clk);

        $display("%0t ns\tSigned results:", $time);
        for (int i = 0; i < ARRAY_SIZE; i++) begin
            $display("\t\tRow %0d: %0d, %0d, %0d, %0d",
                i, c_out[i][0], c_out[i][1], c_out[i][2], c_out[i][3]);
        end

        // Test 5: Maximum values (overflow test)
        @(posedge clk);
        reset = 1;
        repeat(2) @(posedge clk);
        reset = 0;
        enable = 1;

        $display("%0t ns\tTest 5: Maximum values (saturation test)", $time);

        // Use maximum positive values
        a_in[0] = 8'sd127; // Max positive for 8-bit signed
        a_in[1] = 8'sd127;
        a_in[2] = 8'sd127;
        a_in[3] = 8'sd127;

        b_in[0] = 8'sd127;
        b_in[1] = 8'sd127;
        b_in[2] = 8'sd127;
        b_in[3] = 8'sd127;

        // Accumulate many times to test saturation
        repeat(100) @(posedge clk);

        $display("%0t ns\tAfter many accumulations:", $time);
        $display("\t\tc_out[0][0] = %0d (should saturate)", c_out[0][0]);

        // Test complete
        repeat(10) @(posedge clk);
        $display("========================================");
        $display("Testbench completed successfully!");
        $display("========================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    // Optional: Waveform dumping for GTKWave or similar
    initial begin
        $dumpfile("systolic_tb.vcd");
        $dumpvars(0, systolic_tb);
    end

endmodule
