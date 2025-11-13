`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Lydia Obeng
// 
// Create Date: 11/10/2025 11:29:37 AM
// Design Name: Processing Elements
// Module Name: pe
// Project Name: Efficient transformer accelerator
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pe(
    input clk,
    input reset, 
    input signed [7:0] in_a,
    input signed [7:0] in_b,
    output reg signed [7:0] out_a,
    output reg signed [7:0] out_b,
    output reg signed [31:0] out_c
);
    always @(posedge clk) begin
        if (reset) begin
            out_a <= 8'd0;
            out_b <= 8'd0;
            out_c <= 32'd0;
        end else begin
            out_a <= in_a;
            out_b <= in_b;
            out_c <= out_c + (in_a * in_b); // MAC operation
        end
    end
endmodule
