`timescale 1ns / 1ps

// UART with the four-register layout used by AXI UARTLite and the course
// C_TEST programs. RX and TX FIFOs are 16 bytes deep; serial format is 8N1.
module uart_peripheral #(
    parameter integer CLOCK_FREQ = 50_000_000,
    parameter integer BAUD_RATE = 115_200,
    parameter integer FIFO_DEPTH = 16
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         rd_en,
    input  wire [11:0]  rd_offset,
    output reg  [31:0]  rd_data,
    output reg          rd_error,
    input  wire         wr_en,
    input  wire [11:0]  wr_offset,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0]  wr_data,
    input  wire [ 3:0]  wr_strb,
    /* verilator lint_on UNUSEDSIGNAL */
    output reg          wr_error,
    input  wire         rx,
    output reg          tx
);

    localparam integer CLKS_PER_BIT =
        (CLOCK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
    localparam integer HALF_CLKS = CLKS_PER_BIT / 2;
    localparam integer BAUD_COUNT_WIDTH = $clog2(CLKS_PER_BIT + 1);
    localparam integer FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);
    localparam integer FIFO_COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);
    // The parameter checks below prove that these constants fit their target
    // counters. Verilog-2001 has no width cast syntax for parameter integers.
    /* verilator lint_off WIDTHTRUNC */
    localparam [BAUD_COUNT_WIDTH-1:0] BIT_PERIOD_COUNT =
        CLKS_PER_BIT - 1;
    localparam [BAUD_COUNT_WIDTH-1:0] HALF_PERIOD_COUNT = HALF_CLKS - 1;
    localparam [FIFO_COUNT_WIDTH-1:0] FIFO_DEPTH_COUNT = FIFO_DEPTH;
    /* verilator lint_on WIDTHTRUNC */

    localparam TX_IDLE = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA = 2'd2;
    localparam TX_STOP = 2'd3;

    localparam RX_IDLE = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA = 2'd2;
    localparam RX_STOP = 2'd3;

    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_PTR_WIDTH-1:0] tx_write_ptr;
    reg [FIFO_PTR_WIDTH-1:0] tx_read_ptr;
    reg [FIFO_PTR_WIDTH-1:0] rx_write_ptr;
    reg [FIFO_PTR_WIDTH-1:0] rx_read_ptr;
    reg [FIFO_COUNT_WIDTH-1:0] tx_count;
    reg [FIFO_COUNT_WIDTH-1:0] rx_count;

    reg [1:0] tx_state;
    reg [1:0] rx_state;
    reg [BAUD_COUNT_WIDTH-1:0] tx_baud_count;
    reg [BAUD_COUNT_WIDTH-1:0] rx_baud_count;
    reg [2:0] tx_bit_index;
    reg [2:0] rx_bit_index;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg       rx_meta;
    reg       rx_sync;
    reg       interrupt_enable;

    wire tx_empty = tx_count == 0;
    wire tx_full = tx_count == FIFO_DEPTH_COUNT;
    wire rx_empty = rx_count == 0;
    wire rx_full = rx_count == FIFO_DEPTH_COUNT;

    wire control_write = wr_en && wr_offset == 12'h00c && wr_strb[0];
    wire clear_tx = control_write && wr_data[0];
    wire clear_rx = control_write && wr_data[1];
    wire tx_fifo_pop = tx_state == TX_IDLE && !tx_empty && !clear_tx;
    wire tx_fifo_write = wr_en && wr_offset == 12'h004 && wr_strb[0] &&
                         (!tx_full || tx_fifo_pop) && !clear_tx;
    wire rx_fifo_read = rd_en && rd_offset == 12'h000 && !rx_empty &&
                        !clear_rx;
    wire rx_fifo_write = rx_state == RX_STOP && rx_baud_count == 0 &&
                          rx_sync && (!rx_full || rx_fifo_read) && !clear_rx;

    initial begin
        if (CLKS_PER_BIT < 2) begin
            $error("UART CLOCK_FREQ/BAUD_RATE ratio must be at least two");
        end
        if (FIFO_DEPTH < 2 || (FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0) begin
            $error("UART FIFO_DEPTH must be a power of two");
        end
    end

    always @(*) begin
        rd_data = 32'h0;
        rd_error = 1'b0;
        case (rd_offset)
            12'h000: rd_data = rx_empty ? 32'h0 : {24'h0, rx_fifo[rx_read_ptr]};
            12'h004: rd_data = 32'h0;
            12'h008: rd_data = {27'h0, interrupt_enable, tx_full, tx_empty,
                                rx_full, !rx_empty};
            12'h00c: rd_data = {27'h0, interrupt_enable, 4'h0};
            default: rd_error = 1'b1;
        endcase
    end

    always @(*) begin
        case (wr_offset)
            12'h004, 12'h00c: wr_error = 1'b0;
            default: wr_error = 1'b1;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_write_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            tx_read_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            tx_count <= {FIFO_COUNT_WIDTH{1'b0}};
        end else if (clear_tx) begin
            tx_write_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            tx_read_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            tx_count <= {FIFO_COUNT_WIDTH{1'b0}};
        end else begin
            if (tx_fifo_write) begin
                tx_write_ptr <= tx_write_ptr + 1'b1;
            end
            if (tx_fifo_pop) begin
                tx_read_ptr <= tx_read_ptr + 1'b1;
            end
            case ({tx_fifo_write, tx_fifo_pop})
                2'b10: tx_count <= tx_count + 1'b1;
                2'b01: tx_count <= tx_count - 1'b1;
                default: tx_count <= tx_count;
            endcase
        end
    end

    // Keep FIFO payload storage out of the asynchronous-reset process so
    // Vivado can infer memory instead of expanding every bit into a flip-flop.
    always @(posedge clk) begin
        if (tx_fifo_write) begin
            tx_fifo[tx_write_ptr] <= wr_data[7:0];
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_baud_count <= {BAUD_COUNT_WIDTH{1'b0}};
            tx_bit_index <= 3'h0;
            tx_shift <= 8'h0;
            tx <= 1'b1;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                    if (tx_fifo_pop) begin
                        tx_shift <= tx_fifo[tx_read_ptr];
                        tx_baud_count <= BIT_PERIOD_COUNT;
                        tx_bit_index <= 3'h0;
                        tx <= 1'b0;
                        tx_state <= TX_START;
                    end
                end
                TX_START: begin
                    if (tx_baud_count == 0) begin
                        tx <= tx_shift[0];
                        tx_baud_count <= BIT_PERIOD_COUNT;
                        tx_state <= TX_DATA;
                    end else begin
                        tx_baud_count <= tx_baud_count - 1'b1;
                    end
                end
                TX_DATA: begin
                    if (tx_baud_count == 0) begin
                        tx_baud_count <= BIT_PERIOD_COUNT;
                        if (tx_bit_index == 3'd7) begin
                            tx <= 1'b1;
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_index <= tx_bit_index + 1'b1;
                            tx <= tx_shift[tx_bit_index + 1'b1];
                        end
                    end else begin
                        tx_baud_count <= tx_baud_count - 1'b1;
                    end
                end
                TX_STOP: begin
                    if (tx_baud_count == 0) begin
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_baud_count <= tx_baud_count - 1'b1;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_baud_count <= {BAUD_COUNT_WIDTH{1'b0}};
            rx_bit_index <= 3'h0;
            rx_shift <= 8'h0;
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    if (!rx_sync) begin
                        rx_baud_count <= HALF_PERIOD_COUNT;
                        rx_state <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_baud_count == 0) begin
                        if (!rx_sync) begin
                            rx_baud_count <= BIT_PERIOD_COUNT;
                            rx_bit_index <= 3'h0;
                            rx_state <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_baud_count <= rx_baud_count - 1'b1;
                    end
                end
                RX_DATA: begin
                    if (rx_baud_count == 0) begin
                        rx_shift[rx_bit_index] <= rx_sync;
                        rx_baud_count <= BIT_PERIOD_COUNT;
                        if (rx_bit_index == 3'd7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_index <= rx_bit_index + 1'b1;
                        end
                    end else begin
                        rx_baud_count <= rx_baud_count - 1'b1;
                    end
                end
                RX_STOP: begin
                    if (rx_baud_count == 0) begin
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_baud_count <= rx_baud_count - 1'b1;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_write_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            rx_read_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            rx_count <= {FIFO_COUNT_WIDTH{1'b0}};
        end else if (clear_rx) begin
            rx_write_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            rx_read_ptr <= {FIFO_PTR_WIDTH{1'b0}};
            rx_count <= {FIFO_COUNT_WIDTH{1'b0}};
        end else begin
            if (rx_fifo_write) begin
                rx_write_ptr <= rx_write_ptr + 1'b1;
            end
            if (rx_fifo_read) begin
                rx_read_ptr <= rx_read_ptr + 1'b1;
            end
            case ({rx_fifo_write, rx_fifo_read})
                2'b10: rx_count <= rx_count + 1'b1;
                2'b01: rx_count <= rx_count - 1'b1;
                default: rx_count <= rx_count;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rx_fifo_write) begin
            rx_fifo[rx_write_ptr] <= rx_shift;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            interrupt_enable <= 1'b0;
        end else if (control_write) begin
            interrupt_enable <= wr_data[4];
        end
    end

endmodule
