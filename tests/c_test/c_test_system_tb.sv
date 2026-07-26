`timescale 1ns / 1ps

module c_test_system_tb;

    localparam integer CLKS_PER_BIT = 4;
    localparam integer MAX_TRANSCRIPT = 16384;

    reg fpga_clk = 1'b0;
    reg fpga_rst = 1'b1;
    reg [15:0] sw = 16'h0001;
    wire [15:0] led;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    reg rx = 1'b1;
    wire tx;

    integer cycle_count = 0;
    integer memory_read_count = 0;
    integer memory_write_count = 0;
    integer mmio_read_count = 0;
    integer mmio_write_count = 0;
    integer uart_read_count = 0;
    integer uart_write_count = 0;
    integer timer_read_count = 0;
    integer switch_read_count = 0;
    integer led_write_count = 0;
    integer display_write_count = 0;
    integer transcript_count = 0;
    integer driver_scan_position = 0;
    integer transcript_file;
    string transcript_path;
    reg [7:0] transcript [0:MAX_TRANSCRIPT-1];
    reg instruction_refill_seen = 1'b0;
    reg data_refill_seen = 1'b0;
    reg test0_a_seen = 1'b0;
    reg test0_b_seen = 1'b0;
    reg test1_negative_led_seen = 1'b0;
    reg test1_magnitude_seen = 1'b0;
    event tx_byte_received;

    always #10 fpga_clk = ~fpga_clk;

    miniRV_SoC dut (
        .fpga_clk (fpga_clk),
        .fpga_rst (fpga_rst),
        .sw       (sw),
        .led      (led),
        .dig_en   (dig_en),
        .dig_seg  (dig_seg),
        .dig_seg1 (dig_seg1),
        .rx       (rx),
        .tx       (tx)
    );

    // The pinned Trace RAM requires a power-of-two depth. C_TEST needs at
    // least 0x25800 bytes, so its simulation-only instance uses 256 KiB.
    defparam dut.U_bram.DATA_DEPTH = 65536;

    // Keep the register/FIFO/8N1 behavior and scale only the serial bit time.
    // The separate soc-smoke suite retains the 50 MHz / 115200 full-rate model.
    defparam dut.U_peripherals.CLOCK_FREQ = 460800;

    task automatic step;
        begin
            @(posedge fpga_clk);
            #1;
        end
    endtask

    task automatic check(input bit condition, input string message);
        begin
            if (!condition) begin
                $fatal(1, "%s", message);
            end
        end
    endtask

    task automatic send_rx_byte(input [7:0] value);
        integer bit_index;
        begin
            rx = 1'b0;
            repeat (CLKS_PER_BIT) step();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                rx = value[bit_index];
                repeat (CLKS_PER_BIT) step();
            end
            rx = 1'b1;
            repeat (CLKS_PER_BIT) step();
            repeat (12) step();
        end
    endtask

    task automatic send_rx_text(input string text);
        integer index;
        begin
            for (index = 0; index < text.len(); index = index + 1) begin
                send_rx_byte(text[index]);
            end
        end
    endtask

    task automatic receive_tx_byte(output [7:0] value);
        integer bit_index;
        begin
            @(negedge tx);
            repeat (CLKS_PER_BIT/2) step();
            check(tx == 1'b0, "UART TX start bit was not held");
            repeat (CLKS_PER_BIT/2) step();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                repeat (CLKS_PER_BIT/2) step();
                value[bit_index] = tx;
                repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) step();
            end
            repeat (CLKS_PER_BIT/2) step();
            check(tx == 1'b1, "UART TX stop bit was not high");
            repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) step();
        end
    endtask

    task automatic wait_for_text(input string expected);
        integer matched;
        reg [7:0] value;
        begin
            matched = 0;
            while (matched < expected.len()) begin
                while (driver_scan_position >= transcript_count) begin
                    @tx_byte_received;
                end
                value = transcript[driver_scan_position];
                driver_scan_position = driver_scan_position + 1;
                if (value == expected[matched]) begin
                    matched = matched + 1;
                end else if (value == expected[0]) begin
                    matched = 1;
                end else begin
                    matched = 0;
                end
            end
        end
    endtask

    always @(posedge fpga_clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 20000000) begin
            $fatal(1, "c_test_system_tb timed out (test %0d)", `C_TEST_ID);
        end

        if (!fpga_rst && dut.cpu_arvalid && dut.cpu_arready) begin
            if (dut.cpu_araddr[31:16] == 16'hffff) begin
                check(dut.cpu_arlen == 0,
                      "MMIO read was not an uncached single beat");
                mmio_read_count <= mmio_read_count + 1;
            end else begin
                check(dut.cpu_arlen == 3,
                      "cached memory miss was not a four-beat refill");
                memory_read_count <= memory_read_count + 1;
                if (dut.cpu_araddr < 32'h0000c800) begin
                    instruction_refill_seen <= 1'b1;
                end else begin
                    data_refill_seen <= 1'b1;
                end
            end
        end

        if (!fpga_rst && dut.cpu_awvalid && dut.cpu_awready) begin
            check(dut.cpu_awlen == 0, "CPU write was not a single beat");
            if (dut.cpu_awaddr[31:16] == 16'hffff) begin
                mmio_write_count <= mmio_write_count + 1;
            end else begin
                memory_write_count <= memory_write_count + 1;
            end
        end

        if (!fpga_rst && dut.mmio_rd_en) begin
            case (dut.mmio_rd_addr[31:12])
                20'hffff0: switch_read_count <= switch_read_count + 1;
                20'hffff3: uart_read_count <= uart_read_count + 1;
                20'hffff4: timer_read_count <= timer_read_count + 1;
            endcase
        end

        if (!fpga_rst && dut.mmio_wr_en) begin
            case (dut.mmio_wr_addr[31:12])
                20'hffff1: begin
                    led_write_count <= led_write_count + 1;
                    if (dut.mmio_wr_data == 32'h41) test0_a_seen <= 1'b1;
                    if (dut.mmio_wr_data == 32'h42) test0_b_seen <= 1'b1;
                    if (dut.mmio_wr_data == 32'h1) begin
                        test1_negative_led_seen <= 1'b1;
                    end
                end
                20'hffff2: begin
                    display_write_count <= display_write_count + 1;
                    if (dut.mmio_wr_data == 32'h41) test0_a_seen <= 1'b1;
                    if (dut.mmio_wr_data == 32'h42) test0_b_seen <= 1'b1;
                    if (dut.mmio_wr_data == 32'd42) begin
                        test1_magnitude_seen <= 1'b1;
                    end
                end
                20'hffff3: uart_write_count <= uart_write_count + 1;
            endcase
        end
    end

    initial begin
        check($value$plusargs("TRANSCRIPT=%s", transcript_path),
              "missing +TRANSCRIPT output path");
        transcript_file = $fopen(transcript_path, "w");
        check(transcript_file != 0, "could not open transcript output");
        repeat (6) step();
        fpga_rst = 1'b0;
    end

    initial begin
        reg [7:0] value;
        wait (!fpga_rst);
        forever begin
            receive_tx_byte(value);
            check(transcript_count < MAX_TRANSCRIPT, "UART transcript overflow");
            transcript[transcript_count] = value;
            transcript_count = transcript_count + 1;
            $fwrite(transcript_file, "%c", value);
            $fflush(transcript_file);
            ->tx_byte_received;
        end
    end

    initial begin
        wait (!fpga_rst);
        case (`C_TEST_ID)
            0: begin
                wait_for_text("Enter a char: ");
                send_rx_text("A");
                wait_for_text("Enter a char: ");
                sw = 16'h0000;
                send_rx_text("B");
                wait_for_text("Test ended.");
            end
            1: begin
                wait_for_text("Enter an integer, a char, and a string");
                send_rx_text("-42 x hello\n");
                wait_for_text("Enter an integer, a char, and a string");
                send_rx_text("7 q end\n");
                wait_for_text("Test ended.");
            end
            2: begin
                wait_for_text("Enter 8 integers:");
                send_rx_text("8 -1 5 3 0 5 2 1\n");
                wait_for_text("Enter the size of the array:");
                send_rx_text("8\n");
                wait_for_text("malloc released.");
                // The program has queued its final newline and carriage return.
                // Let both complete 8N1 frames reach the board-level monitor.
                repeat (100) step();
            end
            default: $fatal(1, "unknown C_TEST_ID");
        endcase

        repeat (40) step();
        check(instruction_refill_seen && data_refill_seen,
              "instruction/data Cache refills were not both observed");
        check(memory_read_count > 0 && memory_write_count > 0,
              "program did not exercise ordinary cached memory");
        check(uart_read_count > 0 && uart_write_count > 0,
              "program did not exercise UART through CPU MMIO");

        case (`C_TEST_ID)
            0: begin
                check(switch_read_count >= 2,
                      "C_TEST 0 did not observe continue and stop switches");
                check(led_write_count >= 2 && display_write_count >= 2 &&
                      test0_a_seen && test0_b_seen,
                      "C_TEST 0 ASCII LED/display writes were incomplete");
            end
            1: begin
                check(test1_negative_led_seen && test1_magnitude_seen,
                      "C_TEST 1 sign LED/absolute display writes were missing");
            end
            2: begin
                check(timer_read_count >= 12,
                      "C_TEST 2 did not perform both high-low-high timings");
            end
        endcase

        $fclose(transcript_file);
        $display("c_test_system_tb: PASS (test %0d)", `C_TEST_ID);
        $display("  CPU/Cache/AXI: instruction+data refill and writes observed");
        $display("  MMIO: reads=%0d writes=%0d, uncached single-beat",
                 mmio_read_count, mmio_write_count);
        $display("  UART: board-level 8N1 RX/TX transcript captured");
        $display("  FPGA/board: NOT RUN (RTL system simulation only)");
        $finish;
    end

endmodule
