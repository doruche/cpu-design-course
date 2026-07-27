`timescale 1ns / 1ps

// Behavioral Clock Wizard boundary for the Stage 5 board-clock test.  The
// generated clock deliberately keeps running while lock is low: lock is a
// reset qualification signal, not a clock gate.
module clk_wiz_0(
    input  wire clk_in1,
    output wire locked,
    output wire clk_out1
);

    reg locked_model = 1'b0;
    reg divided_clock = 1'b0;

    always @(posedge clk_in1) begin
        divided_clock <= !divided_clock;
    end

    assign locked = locked_model;
    assign clk_out1 = divided_clock;

endmodule
