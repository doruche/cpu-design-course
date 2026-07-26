`timescale 1ns / 1ps

module timer_peripheral_tb;

    reg         clk = 1'b0;
    reg         rst = 1'b0;
    reg         mmio_rd_en = 1'b0;
    reg  [31:0] mmio_rd_addr = 32'h0;
    wire [31:0] mmio_rd_data;
    wire        mmio_rd_error;
    reg         mmio_wr_en = 1'b0;
    reg  [31:0] mmio_wr_addr = 32'h0;
    reg  [31:0] mmio_wr_data = 32'h0;
    reg  [ 3:0] mmio_wr_strb = 4'h0;
    wire        mmio_wr_error;
    reg  [15:0] sw = 16'h0;
    wire [15:0] led;
    wire [ 7:0] dig_en;
    wire [ 7:0] dig_seg;
    reg         rx = 1'b1;
    wire        tx;

    reg  [63:0] previous_timer;
    reg  [31:0] low_before_rollover;
    reg  [31:0] high_after_rollover;
    integer cycle_index;
    integer byte_offset;

    always #5 clk = ~clk;

    soc_peripherals #(
        .CLOCK_FREQ    (40),
        .UART_BAUD_RATE(10)
    ) dut (
        .clk           (clk),
        .rst           (rst),
        .mmio_rd_en    (mmio_rd_en),
        .mmio_rd_addr  (mmio_rd_addr),
        .mmio_rd_data  (mmio_rd_data),
        .mmio_rd_error (mmio_rd_error),
        .mmio_wr_en    (mmio_wr_en),
        .mmio_wr_addr  (mmio_wr_addr),
        .mmio_wr_data  (mmio_wr_data),
        .mmio_wr_strb  (mmio_wr_strb),
        .mmio_wr_error (mmio_wr_error),
        .sw            (sw),
        .led           (led),
        .dig_en        (dig_en),
        .dig_seg       (dig_seg),
        .rx            (rx),
        .tx            (tx)
    );

    task automatic check(input logic condition, input string message);
        begin
            if (condition !== 1'b1) begin
                $fatal(1, "%s", message);
            end
        end
    endtask

    task automatic check_read(
        input [31:0] address,
        input [31:0] expected_data,
        input        expected_error
    );
        begin
            mmio_rd_addr = address;
            mmio_rd_en = 1'b1;
            #1;
            check(mmio_rd_error === expected_error,
                  $sformatf("read error mismatch at %08h", address));
            check(mmio_rd_data === expected_data,
                  $sformatf("read data mismatch at %08h", address));
            mmio_rd_en = 1'b0;
        end
    endtask

    task automatic check_rejected_write(input [31:0] address);
        reg [63:0] timer_before_write;
        begin
            @(negedge clk);
            timer_before_write = dut.timer;
            mmio_wr_addr = address;
            mmio_wr_data = 32'hdead_beef;
            mmio_wr_strb = 4'hf;
            mmio_wr_en = 1'b1;
            #1;
            check(mmio_wr_error === 1'b1,
                  $sformatf("timer write at %08h was not rejected", address));
            @(posedge clk);
            #1;
            check(dut.timer === timer_before_write + 64'd1,
                  "rejected timer write changed timer state");
            mmio_wr_en = 1'b0;
        end
    endtask

    initial begin
        #2000;
        $fatal(1, "timer_peripheral_tb timed out");
    end

    initial begin
        // Assert reset after time zero so the asynchronous-reset behavior is
        // observed rather than relying on simulator register initialization.
        #2;
        rst = 1'b1;
        #1;
        check(dut.timer === 64'h0, "reset did not clear the timer");
        check_read(32'hffff_4000, 32'h0, 1'b0);
        check_read(32'hffff_4008, 32'h0, 1'b0);

        @(negedge clk);
        rst = 1'b0;
        previous_timer = dut.timer;

        // The free-running timer must advance exactly once on every clock.
        for (cycle_index = 0; cycle_index < 4;
             cycle_index = cycle_index + 1) begin
            @(posedge clk);
            #1;
            check(dut.timer === previous_timer + 64'd1,
                  $sformatf("timer increment mismatch on cycle %0d",
                            cycle_index));
            previous_timer = dut.timer;
        end

        // Both canonical ports and every byte address within their 32-bit
        // words return the same live half of the timer.
        for (byte_offset = 0; byte_offset < 4;
             byte_offset = byte_offset + 1) begin
            check_read(32'hffff_4000 + byte_offset,
                       dut.timer[31:0], 1'b0);
            check_read(32'hffff_4008 + byte_offset,
                       dut.timer[63:32], 1'b0);
        end

        // Offsets between/after the two ports are invalid and return no data.
        check_read(32'hffff_4004, 32'h0, 1'b1);
        check_read(32'hffff_400c, 32'h0, 1'b1);

        // The timer is read-only at both documented addresses. Also prove a
        // rejected write has no effect beyond the normal clock increment.
        check_rejected_write(32'hffff_4000);
        check_rejected_write(32'hffff_4008);

        // Accelerate to the carry boundary through the testbench hierarchy.
        // The first clock reaches ...FFFFFFFF; the second wraps the low word
        // to zero and carries into the high word.
        @(negedge clk);
        dut.timer = 64'h0000_0000_ffff_fffe;
        #1;
        check_read(32'hffff_4000, 32'hffff_fffe, 1'b0);
        check_read(32'hffff_4008, 32'h0000_0000, 1'b0);

        @(posedge clk);
        #1;
        check(dut.timer === 64'h0000_0000_ffff_ffff,
              "timer did not reach the final low-word value");
        check_read(32'hffff_4000, 32'hffff_ffff, 1'b0);
        low_before_rollover = mmio_rd_data;

        @(posedge clk);
        #1;
        check(dut.timer === 64'h0000_0001_0000_0000,
              "low-word rollover did not carry into the high word");
        check_read(32'hffff_4000, 32'h0000_0000, 1'b0);
        check_read(32'hffff_4008, 32'h0000_0001, 1'b0);
        high_after_rollover = mmio_rd_data;

        // Low/high reads are independent live observations, not an atomic
        // 64-bit snapshot. A low read before rollover followed by a high read
        // after rollover therefore forms a mixed value distinct from the
        // timer value at the second read.
        check({high_after_rollover, low_before_rollover} ===
              64'h0000_0001_ffff_ffff,
              "cross-boundary reads did not expose independent live halves");
        check({high_after_rollover, low_before_rollover} !== dut.timer,
              "timer low/high reads unexpectedly behaved as an atomic snapshot");

        $display("timer_peripheral_tb: PASS (low/high reads are non-atomic)");
        $finish;
    end

endmodule
