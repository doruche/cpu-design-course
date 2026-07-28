`timescale 1ns / 1ps

module multiplier #(
    parameter WIDTH = 32,
    parameter RESULT_WIDTH = WIDTH + WIDTH,
    parameter RESULT_LSB = 0
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire [WIDTH-1:0]     x,
    input  wire [WIDTH-1:0]     y,
    input  wire                 start,
    output reg  [RESULT_WIDTH-1:0] z,
    output wire                 busy
);

    localparam PRODUCT_WIDTH = WIDTH + WIDTH;
    localparam COUNT_WIDTH = (WIDTH <= 1) ? 1 : $clog2(WIDTH);
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] RUNNING = 2'd1;
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

    localparam [COUNT_WIDTH-1:0] LAST_COUNT = count_cast(WIDTH - 1);

    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] count;
    reg [PRODUCT_WIDTH+1:0] product;
    reg [WIDTH:0] multiplicand;
    reg [WIDTH:0] multiplicand_neg;

    // One Booth step: the recode add/sub and the arithmetic right shift are
    // combined so a step costs one cycle instead of two. The shift reads the
    // added value directly rather than waiting for it to be registered.
    reg [PRODUCT_WIDTH+1:0] added_product;
    always @(*) begin
        case (product[1:0])
            2'b01: added_product = {
                product[PRODUCT_WIDTH+1:WIDTH+1] + multiplicand,
                product[WIDTH:0]
            };
            2'b10: added_product = {
                product[PRODUCT_WIDTH+1:WIDTH+1] + multiplicand_neg,
                product[WIDTH:0]
            };
            default: added_product = product;
        endcase
    end

    wire [PRODUCT_WIDTH+1:0] stepped_product =
        {added_product[PRODUCT_WIDTH+1], added_product[PRODUCT_WIDTH+1:1]};

    assign busy = state != IDLE;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= IDLE;
            count            <= {COUNT_WIDTH{1'b0}};
            product          <= {(PRODUCT_WIDTH+2){1'b0}};
            multiplicand     <= {(WIDTH+1){1'b0}};
            multiplicand_neg <= {(WIDTH+1){1'b0}};
            z                <= {RESULT_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        count            <= {COUNT_WIDTH{1'b0}};
                        product          <= {{(WIDTH+1){1'b0}}, y, 1'b0};
                        multiplicand     <= {x[WIDTH-1], x};
                        multiplicand_neg <= ~{x[WIDTH-1], x} + 1'b1;
                        state            <= RUNNING;
                    end
                end
                RUNNING: begin
                    product <= stepped_product;
                    if (count == LAST_COUNT) begin
                        z     <= stepped_product[RESULT_LSB+RESULT_WIDTH:RESULT_LSB+1];
                        state <= IDLE;
                    end else begin
                        count <= count + 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
