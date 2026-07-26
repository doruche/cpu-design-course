`timescale 1ns / 1ps

// Eight-digit hexadecimal display driver for EGO1. Both the digit enables and
// segment outputs are active high on this board.
module seven_segment(
    input  wire         clk,
    input  wire         rst,
    input  wire [31:0]  value,
    output reg  [ 7:0]  dig_en,
    output reg  [ 7:0]  dig_seg
);

    reg [18:0] refresh_counter;
    reg [ 3:0] digit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            refresh_counter <= 19'h0;
        end else begin
            refresh_counter <= refresh_counter + 1'b1;
        end
    end

    always @(*) begin
        case (refresh_counter[18:16])
            3'd0: digit = value[3:0];
            3'd1: digit = value[7:4];
            3'd2: digit = value[11:8];
            3'd3: digit = value[15:12];
            3'd4: digit = value[19:16];
            3'd5: digit = value[23:20];
            3'd6: digit = value[27:24];
            3'd7: digit = value[31:28];
            default: digit = 4'h0;
        endcase

        dig_en = 8'b0000_0001 << refresh_counter[18:16];
        case (digit)
            4'h0: dig_seg = 8'b1111_1100;
            4'h1: dig_seg = 8'b0110_0000;
            4'h2: dig_seg = 8'b1101_1010;
            4'h3: dig_seg = 8'b1111_0010;
            4'h4: dig_seg = 8'b0110_0110;
            4'h5: dig_seg = 8'b1011_0110;
            4'h6: dig_seg = 8'b1011_1110;
            4'h7: dig_seg = 8'b1110_0000;
            4'h8: dig_seg = 8'b1111_1110;
            4'h9: dig_seg = 8'b1111_0110;
            4'ha: dig_seg = 8'b1110_1110;
            4'hb: dig_seg = 8'b0011_1110;
            4'hc: dig_seg = 8'b1001_1100;
            4'hd: dig_seg = 8'b0111_1010;
            4'he: dig_seg = 8'b1001_1110;
            4'hf: dig_seg = 8'b1000_1110;
            default: dig_seg = 8'h00;
        endcase
    end

endmodule
