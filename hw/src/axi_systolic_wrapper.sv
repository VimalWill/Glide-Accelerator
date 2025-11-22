`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI4 Wrapper for Systolic Array Accelerator
//
// This wrapper provides AXI4-Lite (control/status) and AXI4-Stream (data)
// interfaces to the systolic_quant_32x16 core for PS-PL integration.
//
// Memory Map (AXI4-Lite):
//   0x00: CTRL       - Control register [0]: enable, [1]: reset_core, [2]: start
//   0x04: STATUS     - Status register [0]: busy, [1]: done, [2]: overflow
//   0x08: ACCUM_CTRL - [0]: accum_enable, [1]: accum_clear
//   0x0C: QUANT_CTRL - [0]: quant_enable
//   0x10: SCALE      - Quantization scale factor (32-bit)
//   0x14: SHIFT      - Quantization shift amount (8-bit)
//   0x18: ROWS_COLS  - [15:0]: rows, [31:16]: cols (read-only)
//   0x1C: VERSION    - IP version (read-only)
//
// AXI4-Stream:
//   - S_AXIS: Input data stream (matrix A and B elements)
//   - M_AXIS: Output data stream (quantized results)
//////////////////////////////////////////////////////////////////////////////////

module axi_systolic_wrapper #(
    parameter ROWS = 32,
    parameter COLS = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter QUANT_UNITS = 64,

    // AXI4-Lite Parameters
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6,

    // AXI4-Stream Parameters
    parameter C_S_AXIS_TDATA_WIDTH = 128,  // 16 bytes = 16 x INT8
    parameter C_M_AXIS_TDATA_WIDTH = 128,

    // IP Version
    parameter VERSION = 32'h0100_0000  // v1.0.0
)(
    // Global signals
    input  logic aclk,
    input  logic aresetn,

    //========================================================================
    // AXI4-Lite Slave Interface (Control/Status Registers)
    //========================================================================
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic [2:0]                      s_axi_awprot,
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,

    input  logic [C_S_AXI_DATA_WIDTH-1:0]  s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,

    output logic [1:0]                      s_axi_bresp,
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic [2:0]                      s_axi_arprot,
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,

    output logic [C_S_AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output logic [1:0]                      s_axi_rresp,
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,

    //========================================================================
    // AXI4-Stream Slave Interface (Input Data)
    //========================================================================
    input  logic [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  logic                             s_axis_tvalid,
    output logic                             s_axis_tready,
    input  logic                             s_axis_tlast,

    //========================================================================
    // AXI4-Stream Master Interface (Output Data)
    //========================================================================
    output logic [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output logic                             m_axis_tvalid,
    input  logic                             m_axis_tready,
    output logic                             m_axis_tlast,

    //========================================================================
    // Interrupt
    //========================================================================
    output logic interrupt
);

    //========================================================================
    // Register Map
    //========================================================================
    localparam ADDR_CTRL       = 6'h00;
    localparam ADDR_STATUS     = 6'h04;
    localparam ADDR_ACCUM_CTRL = 6'h08;
    localparam ADDR_QUANT_CTRL = 6'h0C;
    localparam ADDR_SCALE      = 6'h10;
    localparam ADDR_SHIFT      = 6'h14;
    localparam ADDR_ROWS_COLS  = 6'h18;
    localparam ADDR_VERSION    = 6'h1C;

    //========================================================================
    // Internal Registers
    //========================================================================
    logic [31:0] ctrl_reg;
    logic [31:0] status_reg;
    logic [31:0] accum_ctrl_reg;
    logic [31:0] quant_ctrl_reg;
    logic [31:0] scale_reg;
    logic [31:0] shift_reg;

    // Control signals
    logic enable;
    logic reset_core;
    logic start;
    logic accum_enable;
    logic accum_clear;
    logic quant_enable;
    logic [ACC_WIDTH-1:0] scale_factor;
    logic [7:0] shift_amount;

    // Status signals
    logic busy;
    logic done;
    logic overflow;

    //========================================================================
    // AXI4-Lite Write Logic
    //========================================================================
    logic axi_awready_i;
    logic axi_wready_i;
    logic axi_bvalid_i;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_latched;

    assign s_axi_awready = axi_awready_i;
    assign s_axi_wready  = axi_wready_i;
    assign s_axi_bvalid  = axi_bvalid_i;
    assign s_axi_bresp   = 2'b00; // OKAY response

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready_i <= 1'b1;
            axi_wready_i  <= 1'b1;
            axi_bvalid_i  <= 1'b0;
            axi_awaddr_latched <= '0;
            ctrl_reg       <= '0;
            accum_ctrl_reg <= '0;
            quant_ctrl_reg <= '0;
            scale_reg      <= 32'd128; // Default scale
            shift_reg      <= 32'd7;   // Default shift
        end else begin
            // Default: ready for new transaction
            if (axi_bvalid_i && s_axi_bready) begin
                axi_bvalid_i <= 1'b0;
                axi_awready_i <= 1'b1;
                axi_wready_i  <= 1'b1;
            end

            // Latch address
            if (s_axi_awvalid && axi_awready_i) begin
                axi_awaddr_latched <= s_axi_awaddr;
                axi_awready_i <= 1'b0;
            end

            // Write data
            if (s_axi_wvalid && axi_wready_i) begin
                axi_wready_i <= 1'b0;
                axi_bvalid_i <= 1'b1;

                case (axi_awaddr_latched)
                    ADDR_CTRL:       ctrl_reg       <= s_axi_wdata;
                    ADDR_ACCUM_CTRL: accum_ctrl_reg <= s_axi_wdata;
                    ADDR_QUANT_CTRL: quant_ctrl_reg <= s_axi_wdata;
                    ADDR_SCALE:      scale_reg      <= s_axi_wdata;
                    ADDR_SHIFT:      shift_reg      <= s_axi_wdata;
                    default: ; // Ignore writes to read-only or invalid addresses
                endcase
            end

            // Auto-clear start bit
            if (ctrl_reg[2]) begin
                ctrl_reg[2] <= 1'b0;
            end
        end
    end

    //========================================================================
    // AXI4-Lite Read Logic
    //========================================================================
    logic axi_arready_i;
    logic axi_rvalid_i;
    logic [31:0] axi_rdata_i;

    assign s_axi_arready = axi_arready_i;
    assign s_axi_rvalid  = axi_rvalid_i;
    assign s_axi_rdata   = axi_rdata_i;
    assign s_axi_rresp   = 2'b00; // OKAY response

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready_i <= 1'b1;
            axi_rvalid_i  <= 1'b0;
            axi_rdata_i   <= '0;
        end else begin
            if (axi_rvalid_i && s_axi_rready) begin
                axi_rvalid_i <= 1'b0;
                axi_arready_i <= 1'b1;
            end

            if (s_axi_arvalid && axi_arready_i) begin
                axi_arready_i <= 1'b0;
                axi_rvalid_i  <= 1'b1;

                case (s_axi_araddr)
                    ADDR_CTRL:       axi_rdata_i <= ctrl_reg;
                    ADDR_STATUS:     axi_rdata_i <= status_reg;
                    ADDR_ACCUM_CTRL: axi_rdata_i <= accum_ctrl_reg;
                    ADDR_QUANT_CTRL: axi_rdata_i <= quant_ctrl_reg;
                    ADDR_SCALE:      axi_rdata_i <= scale_reg;
                    ADDR_SHIFT:      axi_rdata_i <= shift_reg;
                    ADDR_ROWS_COLS:  axi_rdata_i <= {16'd0, COLS[15:0], ROWS[15:0]};
                    ADDR_VERSION:    axi_rdata_i <= VERSION;
                    default:         axi_rdata_i <= 32'hDEADBEEF;
                endcase
            end
        end
    end

    //========================================================================
    // Extract Control Signals
    //========================================================================
    assign enable        = ctrl_reg[0];
    assign reset_core    = ctrl_reg[1];
    assign start         = ctrl_reg[2];
    assign accum_enable  = accum_ctrl_reg[0];
    assign accum_clear   = accum_ctrl_reg[1];
    assign quant_enable  = quant_ctrl_reg[0];
    assign scale_factor  = scale_reg;
    assign shift_amount  = shift_reg[7:0];

    //========================================================================
    // Update Status Register
    //========================================================================
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            status_reg <= '0;
        end else begin
            status_reg <= {29'b0, overflow, done, busy};
        end
    end

    //========================================================================
    // AXI4-Stream Input FIFO & Control
    //========================================================================
    // Simplified: Direct connection (add FIFO for production)
    logic signed [DATA_WIDTH-1:0] a_in [ROWS-1:0];
    logic signed [DATA_WIDTH-1:0] b_in [COLS-1:0];
    logic stream_enable;

    // Simple input unpacking (128 bits = 16 x 8-bit values)
    // This is a simplified example - in production, add proper FSM
    logic [3:0] input_count;
    logic input_phase; // 0 = A matrix, 1 = B matrix

    assign s_axis_tready = enable; // Accept data when enabled

    always_ff @(posedge aclk) begin
        if (!aresetn || reset_core) begin
            input_count <= '0;
            input_phase <= 1'b0;
            stream_enable <= 1'b0;
        end else if (s_axis_tvalid && s_axis_tready) begin
            // Unpack input stream into a_in and b_in arrays
            // This is simplified - proper implementation needs buffering
            stream_enable <= 1'b1;

            for (int i = 0; i < 16; i++) begin
                if (!input_phase && i < ROWS) begin
                    a_in[i] <= s_axis_tdata[i*8 +: 8];
                end else if (input_phase && i < COLS) begin
                    b_in[i] <= s_axis_tdata[i*8 +: 8];
                end
            end

            if (s_axis_tlast) begin
                input_phase <= ~input_phase;
            end
        end else begin
            stream_enable <= 1'b0;
        end
    end

    //========================================================================
    // Systolic Array Core Instance
    //========================================================================
    logic signed [DATA_WIDTH-1:0] quant_out [ROWS-1:0][COLS-1:0];
    logic systolic_valid;
    logic accum_overflow;
    logic quant_valid;

    systolic_quant_32x16 #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .QUANT_UNITS(QUANT_UNITS)
    ) u_systolic_core (
        .clk           (aclk),
        .reset         (reset_core),
        .enable        (enable && stream_enable),
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

    //========================================================================
    // Status Signal Mapping
    //========================================================================
    assign busy     = enable;
    assign done     = quant_valid;
    assign overflow = accum_overflow;

    //========================================================================
    // AXI4-Stream Output FIFO & Packing
    //========================================================================
    logic [3:0] output_row, output_col;
    logic output_valid;

    assign m_axis_tvalid = output_valid;
    assign m_axis_tlast  = (output_row == ROWS-1) && (output_col == COLS-1);

    // Pack outputs into AXI stream (simplified)
    always_ff @(posedge aclk) begin
        if (!aresetn || reset_core) begin
            output_row <= '0;
            output_col <= '0;
            output_valid <= 1'b0;
            m_axis_tdata <= '0;
        end else if (quant_valid) begin
            output_valid <= 1'b1;

            // Pack 16 elements per transfer
            for (int i = 0; i < 16 && i < COLS; i++) begin
                m_axis_tdata[i*8 +: 8] <= quant_out[output_row][i];
            end

            if (m_axis_tready && output_valid) begin
                if (output_col == COLS-1) begin
                    output_col <= '0;
                    if (output_row == ROWS-1) begin
                        output_row <= '0;
                        output_valid <= 1'b0;
                    end else begin
                        output_row <= output_row + 1;
                    end
                end else begin
                    output_col <= output_col + 1;
                end
            end
        end
    end

    //========================================================================
    // Interrupt Generation
    //========================================================================
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            interrupt <= 1'b0;
        end else begin
            interrupt <= quant_valid; // Interrupt when computation done
        end
    end

endmodule
