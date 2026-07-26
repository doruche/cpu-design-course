`timescale 1ns / 1ps

module uart_peripheral_tb;

    localparam integer CLKS_PER_BIT = 434;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    reg         rd_en = 1'b0;
    reg  [11:0] rd_offset = 12'h0;
    wire [31:0] rd_data;
    wire        rd_error;
    reg         wr_en = 1'b0;
    reg  [11:0] wr_offset = 12'h0;
    reg  [31:0] wr_data = 32'h0;
    reg  [ 3:0] wr_strb = 4'h0;
    wire        wr_error;
    reg         rx = 1'b1;
    wire        tx;

    uart_peripheral dut (
        .clk(clk), .rst(rst),
        .rd_en(rd_en), .rd_offset(rd_offset),
        .rd_data(rd_data), .rd_error(rd_error),
        .wr_en(wr_en), .wr_offset(wr_offset),
        .wr_data(wr_data), .wr_strb(wr_strb),
        .wr_error(wr_error), .rx(rx), .tx(tx)
    );

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check(input bit condition, input string message);
        begin
            if (!condition) $fatal(1, "%s", message);
        end
    endtask

    task automatic write_register(
        input [11:0] offset,
        input [31:0] value,
        input [ 3:0] strobes,
        input bit expected_error
    );
        begin
            wr_offset = offset;
            wr_data = value;
            wr_strb = strobes;
            wr_en = 1'b1;
            #1;
            check(wr_error == expected_error, "UART write decode mismatch");
            step();
            wr_en = 1'b0;
        end
    endtask

    task automatic read_register(
        input [11:0] offset,
        output [31:0] value,
        input bit expected_error
    );
        begin
            rd_offset = offset;
            rd_en = 1'b1;
            #1;
            check(rd_error == expected_error, "UART read decode mismatch");
            value = rd_data;
            step();
            rd_en = 1'b0;
        end
    endtask

    task automatic expect_tx_byte(input [7:0] expected);
        integer bit_index;
        begin
            @(negedge tx);
            repeat (CLKS_PER_BIT/2) step();
            check(tx == 1'b0, "UART TX start bit was not held for one bit");
            repeat (CLKS_PER_BIT/2) step();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                repeat (CLKS_PER_BIT/2) step();
                check(tx == expected[bit_index],
                      "UART TX data bit/order mismatch");
                repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) step();
            end
            repeat (CLKS_PER_BIT/2) step();
            check(tx == 1'b1, "UART TX stop bit was not high");
            repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) step();
        end
    endtask

    task automatic send_rx_byte(
        input [7:0] value,
        input bit valid_stop
    );
        integer bit_index;
        begin
            rx = 1'b0;
            repeat (CLKS_PER_BIT) step();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                rx = value[bit_index];
                repeat (CLKS_PER_BIT) step();
            end
            rx = valid_stop;
            repeat (CLKS_PER_BIT) step();
            rx = 1'b1;
            repeat (4) step();
        end
    endtask

    initial begin
        integer cycles;
        cycles = 0;
        forever begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > 250000) $fatal(1, "UART default-parameter test timed out");
        end
    end

    initial begin
        reg [31:0] value;
        integer index;

        repeat (3) step();
        check(tx == 1'b1, "UART TX must be idle-high during reset");
        rst = 1'b0;
        step();

        read_register(12'h008, value, 1'b0);
        check(value[3:0] == 4'b0100,
              "UART reset status must be TX-empty/RX-empty");
        write_register(12'h020, 32'h1, 4'hf, 1'b1);
        read_register(12'h020, value, 1'b1);

        // Default 50 MHz / 115200 baud: verify complete 8N1 frames and FIFO
        // ordering for four deliberately different bit patterns.
        fork
            begin
                expect_tx_byte(8'h00);
                expect_tx_byte(8'h55);
                expect_tx_byte(8'haa);
                expect_tx_byte(8'hff);
            end
            begin
                write_register(12'h004, 32'h00, 4'h1, 1'b0);
                write_register(12'h004, 32'h55, 4'h1, 1'b0);
                write_register(12'h004, 32'haa, 4'h1, 1'b0);
                write_register(12'h004, 32'hff, 4'h1, 1'b0);
            end
        join
        read_register(12'h008, value, 1'b0);
        check(value[2], "UART TX FIFO was not empty after four frames");

        // A rapid producer fills all 16 queued entries while one byte is in
        // flight. An additional write must not increase or wrap the FIFO.
        for (index = 0; index < 17; index = index + 1) begin
            write_register(12'h004, index, 4'h1, 1'b0);
        end
        read_register(12'h008, value, 1'b0);
        check(value[3], "UART TX FIFO did not report full at depth 16");
        write_register(12'h004, 32'h0000_00ee, 4'h1, 1'b0);
        check(dut.tx_count == 16, "UART TX overflow changed FIFO count");
        write_register(12'h00c, 32'h0000_0001, 4'h1, 1'b0);
        read_register(12'h008, value, 1'b0);
        check(value[2] && !value[3], "UART TX clear did not empty the FIFO");

        // RX accepts complete 8N1 frames in order.
        send_rx_byte(8'h00, 1'b1);
        send_rx_byte(8'h55, 1'b1);
        send_rx_byte(8'haa, 1'b1);
        send_rx_byte(8'hff, 1'b1);
        read_register(12'h008, value, 1'b0);
        check(value[0] && !value[1], "UART RX status mismatch after four bytes");
        read_register(12'h000, value, 1'b0);
        check(value[7:0] == 8'h00, "UART RX FIFO lost byte 0");
        read_register(12'h000, value, 1'b0);
        check(value[7:0] == 8'h55, "UART RX FIFO lost byte 1");
        read_register(12'h000, value, 1'b0);
        check(value[7:0] == 8'haa, "UART RX FIFO lost byte 2");
        read_register(12'h000, value, 1'b0);
        check(value[7:0] == 8'hff, "UART RX FIFO lost byte 3");

        // A bad stop bit is discarded, and the receiver recovers for the next
        // legal frame.
        send_rx_byte(8'h33, 1'b0);
        read_register(12'h008, value, 1'b0);
        check(!value[0], "UART accepted a frame with a low stop bit");
        send_rx_byte(8'hc3, 1'b1);
        read_register(12'h000, value, 1'b0);
        check(value[7:0] == 8'hc3, "UART did not recover after a bad stop bit");

        // Fill RX to its exact boundary; the 17th byte is dropped without
        // overwriting the oldest entry.
        for (index = 0; index < 17; index = index + 1) begin
            send_rx_byte(index[7:0], 1'b1);
        end
        read_register(12'h008, value, 1'b0);
        check(value[1], "UART RX FIFO did not report full");

        // At the full boundary, a CPU pop and serial push in the same clock
        // replace the oldest entry without dropping the arriving byte.
        fork
            begin
                send_rx_byte(8'hf0, 1'b1);
            end
            begin
                wait (dut.rx_state == 2'd3 && dut.rx_baud_count == 0 &&
                      dut.rx_sync);
                rd_offset = 12'h000;
                rd_en = 1'b1;
                #1;
                check(rd_data[7:0] == 8'h00,
                      "UART full-boundary pop returned the wrong head");
                step();
                rd_en = 1'b0;
            end
        join
        read_register(12'h008, value, 1'b0);
        check(value[1],
              "UART full-boundary simultaneous pop/push changed occupancy");
        for (index = 1; index < 16; index = index + 1) begin
            read_register(12'h000, value, 1'b0);
            check(value[7:0] == index[7:0],
                  "UART RX overflow changed FIFO order/content");
        end
        read_register(12'h000, value, 1'b0);
        check(value[7:0] == 8'hf0,
              "UART full-boundary simultaneous push was dropped");
        read_register(12'h008, value, 1'b0);
        check(!value[0] && !value[1], "UART RX FIFO did not drain to empty");

        send_rx_byte(8'h5a, 1'b1);
        write_register(12'h00c, 32'h0000_0002, 4'h1, 1'b0);
        read_register(12'h008, value, 1'b0);
        check(!value[0], "UART RX clear did not empty the FIFO");

        write_register(12'h00c, 32'h0000_0010, 4'h1, 1'b0);
        read_register(12'h008, value, 1'b0);
        check(value[4], "UART interrupt-enable control bit did not persist");

        $display("uart_peripheral_tb: PASS");
        $finish;
    end

endmodule
