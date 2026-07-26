`timescale 1ns / 1ps

`include "defines.vh"

module soc_peripherals #(
    parameter integer CLOCK_FREQ = 50_000_000,
    parameter integer UART_BAUD_RATE = 115_200
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         mmio_rd_en,
    input  wire [31:0]  mmio_rd_addr,
    output reg  [31:0]  mmio_rd_data,
    output reg          mmio_rd_error,
    input  wire         mmio_wr_en,
    input  wire [31:0]  mmio_wr_addr,
    input  wire [31:0]  mmio_wr_data,
    input  wire [ 3:0]  mmio_wr_strb,
    output reg          mmio_wr_error,
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [ 7:0]  dig_en,
    output wire [ 7:0]  dig_seg,
    input  wire         rx,
    output wire         tx
);

    reg [31:0] led_value;
    reg [31:0] digled_value;
    reg [63:0] timer;

    wire uart_rd_select = mmio_rd_addr[31:12] == 20'hffff3;
    wire uart_wr_select = mmio_wr_addr[31:12] == 20'hffff3;
    wire [31:0] uart_rd_data;
    wire uart_rd_error;
    wire uart_wr_error;

    function [31:0] merge_bytes;
        input [31:0] old_value;
        input [31:0] new_value;
        input [ 3:0] strobes;
        integer byte_index;
        begin
            merge_bytes = old_value;
            for (byte_index = 0; byte_index < 4;
                 byte_index = byte_index + 1) begin
                if (strobes[byte_index]) begin
                    merge_bytes[byte_index*8 +: 8] =
                        new_value[byte_index*8 +: 8];
                end
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led_value <= 32'h0;
            digled_value <= 32'h0;
            timer <= 64'h0;
        end else begin
            timer <= timer + 1'b1;
            if (mmio_wr_en && mmio_wr_addr == `PERI_ADDR_LED) begin
                led_value <= merge_bytes(led_value, mmio_wr_data,
                                         mmio_wr_strb);
            end
            if (mmio_wr_en && mmio_wr_addr == `PERI_ADDR_DIGLED) begin
                digled_value <= merge_bytes(digled_value, mmio_wr_data,
                                            mmio_wr_strb);
            end
        end
    end

    always @(*) begin
        mmio_rd_data = 32'h0;
        mmio_rd_error = 1'b0;
        case (mmio_rd_addr[31:12])
            20'hffff0: begin
                if (mmio_rd_addr[11:0] == 12'h000) begin
                    mmio_rd_data = {16'h0, sw};
                end else begin
                    mmio_rd_error = 1'b1;
                end
            end
            20'hffff1: begin
                if (mmio_rd_addr[11:0] == 12'h000) begin
                    mmio_rd_data = led_value;
                end else begin
                    mmio_rd_error = 1'b1;
                end
            end
            20'hffff2: begin
                if (mmio_rd_addr[11:0] == 12'h000) begin
                    mmio_rd_data = digled_value;
                end else begin
                    mmio_rd_error = 1'b1;
                end
            end
            20'hffff3: begin
                mmio_rd_data = uart_rd_data;
                mmio_rd_error = uart_rd_error;
            end
            20'hffff4: begin
                case (mmio_rd_addr[11:0])
                    12'h000: mmio_rd_data = timer[31:0];
                    12'h008: mmio_rd_data = timer[63:32];
                    default: mmio_rd_error = 1'b1;
                endcase
            end
            default: mmio_rd_error = 1'b1;
        endcase
    end

    always @(*) begin
        case (mmio_wr_addr[31:12])
            20'hffff1:
                mmio_wr_error = mmio_wr_addr[11:0] != 12'h000;
            20'hffff2:
                mmio_wr_error = mmio_wr_addr[11:0] != 12'h000;
            20'hffff3: mmio_wr_error = uart_wr_error;
            default: mmio_wr_error = 1'b1;
        endcase
    end

    assign led = led_value[15:0];

    seven_segment U_seven_segment (
        .clk        (clk),
        .rst        (rst),
        .value      (digled_value),
        .dig_en     (dig_en),
        .dig_seg    (dig_seg)
    );

    uart_peripheral #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD_RATE  (UART_BAUD_RATE)
    ) U_uart (
        .clk        (clk),
        .rst        (rst),
        .rd_en      (mmio_rd_en && uart_rd_select),
        .rd_offset  (mmio_rd_addr[11:0]),
        .rd_data    (uart_rd_data),
        .rd_error   (uart_rd_error),
        .wr_en      (mmio_wr_en && uart_wr_select),
        .wr_offset  (mmio_wr_addr[11:0]),
        .wr_data    (mmio_wr_data),
        .wr_strb    (mmio_wr_strb),
        .wr_error   (uart_wr_error),
        .rx         (rx),
        .tx         (tx)
    );

endmodule
