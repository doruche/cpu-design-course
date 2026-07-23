`timescale 1ns / 1ps

module divider #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             start,
    output reg  [WIDTH-1:0] z,
    output reg  [WIDTH-1:0] r,
    output reg              busy
);

    localparam MAG_WIDTH = WIDTH - 1;
    localparam COUNT_WIDTH = (MAG_WIDTH <= 1) ? 1 : $clog2(MAG_WIDTH);

    function [COUNT_WIDTH-1:0] count_cast;
        input integer value;
        begin
            if (value < 0)
                count_cast = {COUNT_WIDTH{1'b0}};
            else if (value >= (1 << COUNT_WIDTH))
                count_cast = {COUNT_WIDTH{1'b1}};
            else
                count_cast = value[COUNT_WIDTH-1:0];
        end
    endfunction

    localparam [COUNT_WIDTH-1:0] LAST_COUNT = count_cast(MAG_WIDTH - 1);

    reg [COUNT_WIDTH-1:0] count;
    reg [MAG_WIDTH-1:0]   quotient_mag;
    reg [MAG_WIDTH-1:0]   remainder_mag;
    reg [MAG_WIDTH-1:0]   divisor_mag;
    reg                   quotient_sign;
    reg                   remainder_sign;

    wire [MAG_WIDTH:0] shifted_remainder = {
        remainder_mag, quotient_mag[MAG_WIDTH-1]
    };
    wire [MAG_WIDTH:0] extended_divisor = {1'b0, divisor_mag};
    wire quotient_bit = shifted_remainder >= extended_divisor;
    wire [MAG_WIDTH-1:0] next_remainder = quotient_bit
        ? shifted_remainder[MAG_WIDTH-1:0] - divisor_mag
        : shifted_remainder[MAG_WIDTH-1:0];
    wire [MAG_WIDTH-1:0] next_quotient =
        (quotient_mag << 1) | {{(MAG_WIDTH-1){1'b0}}, quotient_bit};
    wire quotient_is_zero = next_quotient == {MAG_WIDTH{1'b0}};
    wire remainder_is_zero = next_remainder == {MAG_WIDTH{1'b0}};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count          <= {COUNT_WIDTH{1'b0}};
            quotient_mag   <= {MAG_WIDTH{1'b0}};
            remainder_mag  <= {MAG_WIDTH{1'b0}};
            divisor_mag    <= {MAG_WIDTH{1'b0}};
            quotient_sign  <= 1'b0;
            remainder_sign <= 1'b0;
            z              <= {WIDTH{1'b0}};
            r              <= {WIDTH{1'b0}};
            busy           <= 1'b0;
        end else if (!busy) begin
            if (start) begin
                count          <= {COUNT_WIDTH{1'b0}};
                quotient_mag   <= x[MAG_WIDTH-1:0];
                remainder_mag  <= {MAG_WIDTH{1'b0}};
                divisor_mag    <= y[MAG_WIDTH-1:0];
                quotient_sign  <= x[WIDTH-1] ^ y[WIDTH-1];
                remainder_sign <= x[WIDTH-1];
                busy           <= 1'b1;
            end else begin
                busy <= 1'b0;
            end
        end else begin
            quotient_mag  <= next_quotient;
            remainder_mag <= next_remainder;

            if (count == LAST_COUNT) begin
                z <= quotient_is_zero
                    ? {WIDTH{1'b0}}
                    : {quotient_sign, next_quotient};
                r <= remainder_is_zero
                    ? {WIDTH{1'b0}}
                    : {remainder_sign, next_remainder};
                busy <= 1'b0;
            end else begin
                count <= count + 1'b1;
                busy  <= 1'b1;
            end
        end
    end

endmodule
