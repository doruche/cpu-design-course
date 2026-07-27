`timescale 1ns / 1ps

module board_clock_reset_tb;

    reg fpga_clk = 1'b0;
    reg fpga_rst = 1'b0;
    reg [15:0] sw = 16'h0;
    reg rx = 1'b1;
    wire [15:0] led;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    wire tx;

    integer failures = 0;
    integer unlocked_edges = 0;

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

    always #5 fpga_clk = !fpga_clk;

    always @(posedge dut.sys_clk) begin
        if (!dut.pll_lock) begin
            unlocked_edges = unlocked_edges + 1;
        end
    end

    task automatic check;
        input condition;
        input [8*120-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        // PLL output remains a real clock before lock.  The product reset must
        // be asserted, while the clock itself must not be combinationally
        // gated by lock.
        repeat (8) @(posedge fpga_clk);
        #1;
        check(dut.sys_rst === 1'b1,
              "product reset was not asserted while board reset/PLL unlock was active");
        check(unlocked_edges >= 2,
              "product clock stopped while PLL lock was low");

        // Release board reset and acquire lock away from the product-clock
        // edge.  Reset release must occur only in the product clock domain:
        // held through the first product edge, released on the second.
        @(negedge dut.pll_clk1);
        #2;
        fpga_rst = 1'b1;
        dut.U_clkgen.locked_model = 1'b1;
        @(posedge dut.sys_clk);
        #1;
        check(dut.sys_rst === 1'b1,
              "product reset released before one complete product-clock edge");
        @(posedge dut.sys_clk);
        #1;
        check(dut.sys_rst === 1'b0,
              "product reset did not release after two product-clock edges");

        // Loss of lock is an asynchronous reset assertion condition.  It must
        // not wait for either the 100 MHz input or the 50 MHz product clock.
        @(negedge fpga_clk);
        #2;
        dut.U_clkgen.locked_model = 1'b0;
        #1;
        check(dut.sys_rst === 1'b1,
              "PLL lock loss did not assert product reset asynchronously");

        unlocked_edges = 0;
        repeat (8) @(posedge fpga_clk);
        #1;
        check(unlocked_edges >= 2,
              "product clock was gated off after PLL lock loss");

        if (failures != 0) begin
            $display("board_clock_reset_tb: FAIL (%0d checks)", failures);
            $fatal(1);
        end
        $display("board_clock_reset_tb: PASS");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "board_clock_reset_tb timeout");
    end

endmodule
