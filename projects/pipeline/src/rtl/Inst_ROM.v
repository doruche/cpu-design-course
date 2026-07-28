`timescale 1ns / 1ps

`include "defines.vh"

module Inst_ROM (
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // high active
    // Interface to CPU
    input  wire         inst_rreq,
    input  wire [31:0]  inst_addr,
    output wire         inst_ready,
    output reg          inst_valid,
    output wire [31:0]  inst_out
);

    // The ROM is a registered-output block RAM, so it accepts an address every
    // cycle and answers one cycle later. It is never busy.
    assign inst_ready = 1'b1;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        inst_valid <= cpu_rst ? 1'b0 : inst_rreq;
    end

    IROM U_irom (
        .clka   (cpu_clk),
        .addra  (inst_addr[31:2]),
        .douta  (inst_out)
    );

endmodule
