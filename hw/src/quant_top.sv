module quant_top (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,

    input  logic [31:0] data_in,
    input  logic [31:0] scale_factor,
    input  logic [7:0]  shift_amount,

    output logic [7:0]  data_out
);

    // Instantiate the requantization module
    requant u_requant (
        .clk          (clk),
        .rst          (rst),
        .en           (en),
        .in           (data_in),
        .b            (scale_factor),
        .shift_factor (shift_amount),
        .out          (data_out)
    );

endmodule
