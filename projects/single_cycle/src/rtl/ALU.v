`timescale 1ns / 1ps

`include "defines.vh"

module ALU (
    input  wire         rst,
    input  wire         clk,
    input  wire [ 4:0]  op,
    input  wire [31:0]  a,
    input  wire [31:0]  b,
    
    output reg  [31:0]  c,
    output reg          br,
    output wire         busy
);

    wire        mul_flag, mulu_flag;
    wire [63:0] mul_res;
    wire [31:0] mulu_res;
    wire        mul_busy, mulu_busy;
    wire        div_flag, divu_flag;
    wire [32:0] div_quo_sm, divu_quo_sm;
    wire [32:0] div_rem_sm, divu_rem_sm;
    wire [31:0] div_quo, divu_quo;
    wire [31:0] div_rem, divu_rem;
    wire        div_busy, divu_busy;
    wire [31:0] div_a_mag, div_b_mag;
    reg  [ 4:0] op_r;
    reg  [31:0] dividend_r;
    reg         div_by_zero_r;

    assign div_a_mag = a[31] ? ~a + 32'h1 : a;
    assign div_b_mag = b[31] ? ~b + 32'h1 : b;
    assign div_quo = div_quo_sm[32] ? ~div_quo_sm[31:0] + 32'h1 : div_quo_sm[31:0];
    assign div_rem = div_rem_sm[32] ? ~div_rem_sm[31:0] + 32'h1 : div_rem_sm[31:0];
    assign divu_quo = divu_quo_sm[32] ? ~divu_quo_sm[31:0] + 32'h1 : divu_quo_sm[31:0];
    assign divu_rem = divu_rem_sm[32] ? ~divu_rem_sm[31:0] + 32'h1 : divu_rem_sm[31:0];

    always @(*) begin
        case (op_r != 5'h0 ? op_r : op)
            `ALU_ADD  : c = a + b;
            `ALU_SUB  : c = a - b;
            `ALU_AND  : c = a & b;
            `ALU_OR   : c = a | b;
            `ALU_XOR  : c = a ^ b;
            `ALU_SLL  : c = a << b[4:0];
            `ALU_SRL  : c = a >> b[4:0];
            `ALU_SRA  : c = $signed(a) >>> b[4:0];
            `ALU_SLT  : c = {31'h0, $signed(a) < $signed(b)};
            `ALU_SLTU : c = {31'h0, a < b};
            `ALU_MUL  : c = mul_res[31:0];
            `ALU_MULH : c = mul_res[63:32];
            `ALU_MULHU: c = mulu_res;
            `ALU_DIV  : c = div_by_zero_r ? 32'hffff_ffff : div_quo;
            `ALU_DIVU : c = div_by_zero_r ? 32'hffff_ffff : divu_quo;
            `ALU_REM  : c = div_by_zero_r ? dividend_r : div_rem;
            `ALU_REMU : c = div_by_zero_r ? dividend_r : divu_rem;
            default   : c = 32'h0;
        endcase
    end

    always @(*) begin
        case (op)
            `ALU_EQ  : br = a == b;
            `ALU_NE  : br = a != b;
            `ALU_SLT : br = $signed(a) < $signed(b);
            `ALU_SLTU: br = a < b;
            `ALU_GE  : br = $signed(a) >= $signed(b);
            `ALU_GEU : br = a >= b;
            default  : br = 1'b0;
        endcase
    end

    assign mul_flag  = (op == `ALU_MUL) | (op == `ALU_MULH);
    assign mulu_flag = (op == `ALU_MULHU);
    assign div_flag  = (op == `ALU_DIV) | (op == `ALU_REM);
    assign divu_flag = (op == `ALU_DIVU) | (op == `ALU_REMU);
    assign busy      = mul_busy | mulu_busy | div_busy | divu_busy;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            op_r          <= 5'h0;
            dividend_r    <= 32'h0;
            div_by_zero_r <= 1'b0;
        end else begin
            if (mul_flag | mulu_flag | div_flag | divu_flag)
                op_r <= op;
            else if (!busy)
                op_r <= 5'h0;

            if (div_flag | divu_flag) begin
                dividend_r    <= a;
                div_by_zero_r <= b == 32'h0;
            end
        end
    end

    multiplier #(32) U_mul (
        .clk    (clk),
        .rst    (rst),
        .x      (a),
        .y      (b),
        .start  (mul_flag),
        .z      (mul_res),
        .busy   (mul_busy)
    );

    multiplier #(
        .WIDTH        (33),
        .RESULT_WIDTH (32),
        .RESULT_LSB   (32)
    ) U_mulu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (mulu_flag),
        .z      (mulu_res),
        .busy   (mulu_busy)
    );

    divider #(
        .WIDTH  (33)
    ) U_div (
        .clk    (clk),
        .rst    (rst),
        .x      ({a[31], div_a_mag}),
        .y      ({b[31], div_b_mag}),
        .start  (div_flag),
        .z      (div_quo_sm),
        .r      (div_rem_sm),
        .busy   (div_busy)
    );

    divider #(
        .WIDTH  (33)
    ) U_divu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (divu_flag),
        .z      (divu_quo_sm),
        .r      (divu_rem_sm),
        .busy   (divu_busy)
    );

endmodule
