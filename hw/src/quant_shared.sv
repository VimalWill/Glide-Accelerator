`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Shared Quantization Module for Large Systolic Arrays
// Time-multiplexes quantization units across multiple outputs
// Optimized for 32x16 = 512 outputs with 64-128 shared units
//////////////////////////////////////////////////////////////////////////////////

module quant_shared #(
    parameter ROWS = 32,
    parameter COLS = 16,
    parameter ACC_WIDTH = 32,
    parameter OUT_WIDTH = 8,
    parameter QUANT_UNITS = 64  // Number of parallel quantization units
)(
    input  logic clk,
    input  logic reset,
    input  logic enable,

    // Quantization parameters
    input  logic [ACC_WIDTH-1:0] scale_factor,
    input  logic [7:0] shift_amount,

    // Input: All accumulated values
    input  logic signed [ACC_WIDTH-1:0] data_in [ROWS-1:0][COLS-1:0],

    // Output: Quantized values
    output logic signed [OUT_WIDTH-1:0] data_out [ROWS-1:0][COLS-1:0],
    output logic valid
);

    localparam TOTAL_ELEMENTS = ROWS * COLS;
    localparam CYCLES_PER_BATCH = (TOTAL_ELEMENTS + QUANT_UNITS - 1) / QUANT_UNITS;
    localparam PIPELINE_DEPTH = 4;  // Quantization pipeline stages

    //==========================================================================
    // State Machine for Time-Multiplexing
    //==========================================================================

    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        FLUSHING,
        DONE
    } state_t;

    state_t state, state_next;
    logic [$clog2(CYCLES_PER_BATCH+PIPELINE_DEPTH+1)-1:0] cycle_count;
    logic [$clog2(CYCLES_PER_BATCH+PIPELINE_DEPTH+1)-1:0] cycle_count_next;

    // Start signal registration
    logic enable_reg, enable_prev;
    logic start_pulse;

    always_ff @(posedge clk) begin
        if (reset) begin
            enable_prev <= 1'b0;
            enable_reg <= 1'b0;
        end else begin
            enable_prev <= enable_reg;
            enable_reg <= enable;
        end
    end

    assign start_pulse = enable_reg & ~enable_prev;

    //==========================================================================
    // State Machine
    //==========================================================================

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            cycle_count <= 0;
        end else begin
            state <= state_next;
            cycle_count <= cycle_count_next;
        end
    end

    always_comb begin
        state_next = state;
        cycle_count_next = cycle_count;

        case (state)
            IDLE: begin
                if (start_pulse) begin
                    state_next = PROCESSING;
                    cycle_count_next = 0;
                end
            end

            PROCESSING: begin
                if (cycle_count < CYCLES_PER_BATCH - 1) begin
                    cycle_count_next = cycle_count + 1;
                end else begin
                    state_next = FLUSHING;
                    cycle_count_next = 0;
                end
            end

            FLUSHING: begin
                if (cycle_count < PIPELINE_DEPTH - 1) begin
                    cycle_count_next = cycle_count + 1;
                end else begin
                    state_next = DONE;
                    cycle_count_next = 0;
                end
            end

            DONE: begin
                state_next = IDLE;
            end
        endcase
    end

    //==========================================================================
    // Input Buffering
    //==========================================================================

    logic signed [ACC_WIDTH-1:0] input_buffer [TOTAL_ELEMENTS-1:0];

    always_ff @(posedge clk) begin
        if (start_pulse) begin
            for (int i = 0; i < ROWS; i++) begin
                for (int j = 0; j < COLS; j++) begin
                    input_buffer[i * COLS + j] <= data_in[i][j];
                end
            end
        end
    end

    //==========================================================================
    // Quantization Units (Shared across cycles)
    //==========================================================================

    logic signed [ACC_WIDTH-1:0] quant_in [QUANT_UNITS-1:0];
    logic signed [OUT_WIDTH-1:0] quant_out [QUANT_UNITS-1:0];
    logic [QUANT_UNITS-1:0] quant_valid;

    // Select which elements to process this cycle
    always_comb begin
        for (int u = 0; u < QUANT_UNITS; u++) begin
            int element_idx = cycle_count * QUANT_UNITS + u;
            if (element_idx < TOTAL_ELEMENTS && state == PROCESSING) begin
                quant_in[u] = input_buffer[element_idx];
            end else begin
                quant_in[u] = 0;
            end
        end
    end

    // Instantiate quantization units
    genvar u;
    generate
        for (u = 0; u < QUANT_UNITS; u = u + 1) begin : QUANT_UNIT
            requant quant_inst (
                .clk          (clk),
                .rst          (reset),
                .en           (state == PROCESSING || state == FLUSHING),
                .in           (quant_in[u]),
                .b            (scale_factor),
                .shift_factor (shift_amount),
                .out          (quant_out[u])
            );
        end
    endgenerate

    //==========================================================================
    // Output Collection
    //==========================================================================

    logic signed [OUT_WIDTH-1:0] output_buffer [TOTAL_ELEMENTS-1:0];
    logic [$clog2(CYCLES_PER_BATCH+PIPELINE_DEPTH+1)-1:0] output_cycle;

    always_ff @(posedge clk) begin
        if (reset) begin
            output_buffer <= '{default: '0};
            output_cycle <= 0;
        end else if (state == IDLE && start_pulse) begin
            output_cycle <= 0;
        end else if (state == PROCESSING || state == FLUSHING) begin
            // Write results as they emerge from pipeline (after PIPELINE_DEPTH cycles)
            if (output_cycle >= PIPELINE_DEPTH && output_cycle < CYCLES_PER_BATCH + PIPELINE_DEPTH) begin
                int base_idx = (output_cycle - PIPELINE_DEPTH) * QUANT_UNITS;
                for (int u = 0; u < QUANT_UNITS; u++) begin
                    int element_idx = base_idx + u;
                    if (element_idx < TOTAL_ELEMENTS) begin
                        output_buffer[element_idx] <= quant_out[u];
                    end
                end
            end
            output_cycle <= output_cycle + 1;
        end
    end

    //==========================================================================
    // Output Mapping
    //==========================================================================

    always_ff @(posedge clk) begin
        if (reset) begin
            data_out <= '{default: '{default: '0}};
            valid <= 1'b0;
        end else if (state == DONE) begin
            for (int i = 0; i < ROWS; i++) begin
                for (int j = 0; j < COLS; j++) begin
                    data_out[i][j] <= output_buffer[i * COLS + j];
                end
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end

endmodule
