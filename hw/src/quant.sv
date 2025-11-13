module requant(
    input logic [31:0] in,
    output logic [7:0] out,

    input logic [31:0] b,
    input logic [7:0] shift_factor,

    input logic clk,
    input logic rst,
    input logic en
);

    // Pipeline stage 1: Input registration
    logic [31:0] in_s1, b_s1;
    logic [7:0] shift_s1;
    logic en_s1;

    // Pipeline stage 2: Multiplication
    logic [63:0] mult_result;
    logic [7:0] shift_s2;
    logic en_s2;

    // Pipeline stage 3: Shift operation
    logic [31:0] shifted;
    logic en_s3;

    // Pipeline stage 4: Clamping
    logic [7:0] clamped;

    // Stage 1: Input registration
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            in_s1 <= '0;
            b_s1  <= '0;
            shift_s1 <= '0;
            en_s1 <= 1'b0;
        end else begin
            in_s1 <= in;
            b_s1  <= b;
            shift_s1 <= shift_factor;
            en_s1 <= en;
        end
    end

    // Stage 2: Multiplication with registered output
    // Synthesis tools can infer DSP blocks for signed multiplication
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mult_result <= '0;
            shift_s2 <= '0;
            en_s2 <= 1'b0;
        end else begin
            if (en_s1) begin
                mult_result <= in_s1 * b_s1;
                shift_s2 <= shift_s1;
            end
            en_s2 <= en_s1;
        end
    end

    // Stage 3: Optimized barrel shifter
    // Shift the full 64-bit result, then take the relevant bits
    logic [63:0] shift_temp;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            shifted <= '0;
            en_s3 <= 1'b0;
        end else begin
            if (en_s2) begin
                // Shift full 64-bit result and take lower 32 bits
                shift_temp = mult_result >> shift_s2;
                shifted <= shift_temp[31:0];
            end
            en_s3 <= en_s2;
        end
    end

    // Stage 4: Saturation with optimized comparison
    // Check if any upper bits are set for overflow detection
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clamped <= '0;
        end else begin
            if (en_s3) begin
                // Optimized saturation: check upper bits for overflow
                if (|shifted[31:8])  // Any bit set in upper 24 bits = overflow
                    clamped <= 8'hFF;  // Saturate to max
                else
                    clamped <= shifted[7:0];
            end
        end
    end

    assign out = clamped;

endmodule