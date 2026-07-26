`timescale 1ns / 1ps

module soc_system_tb;

    localparam integer CLKS_PER_BIT = 434;
    localparam [31:0] PASS_SIGNATURE = 32'h600d600d;
    localparam [31:0] FAIL_SIGNATURE = 32'hdeaddead;
    localparam integer SIGNATURE_WORD = 32'h2020 / 4;

    reg fpga_clk = 1'b0;
    reg fpga_rst = 1'b1;
    reg [15:0] sw = 16'ha53c;
    wire [15:0] led;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    reg rx = 1'b1;
    wire tx;

    integer cycle_count = 0;
    integer mmio_read_count = 0;
    integer mmio_write_count = 0;
    integer memory_read_count = 0;
    integer memory_write_count = 0;
    reg instruction_refill_seen = 1'b0;
    reg data_refill_seen = 1'b0;
    reg led_switch_seen = 1'b0;
    reg display_programmed = 1'b0;
    reg [7:0] display_slots_seen = 8'h0;
    reg uart_tx_frame_seen = 1'b0;

    always #5 fpga_clk = ~fpga_clk;

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

    function automatic [7:0] segment_pattern(input [3:0] digit);
        begin
            case (digit)
                4'h0: segment_pattern = 8'b1111_1100;
                4'h1: segment_pattern = 8'b0110_0000;
                4'h2: segment_pattern = 8'b1101_1010;
                4'h3: segment_pattern = 8'b1111_0010;
                4'h4: segment_pattern = 8'b0110_0110;
                4'h5: segment_pattern = 8'b1011_0110;
                4'h6: segment_pattern = 8'b1011_1110;
                4'h7: segment_pattern = 8'b1110_0000;
                4'h8: segment_pattern = 8'b1111_1110;
                4'h9: segment_pattern = 8'b1111_0110;
                4'ha: segment_pattern = 8'b1110_1110;
                4'hb: segment_pattern = 8'b0011_1110;
                4'hc: segment_pattern = 8'b1001_1100;
                4'hd: segment_pattern = 8'b0111_1010;
                4'he: segment_pattern = 8'b1001_1110;
                4'hf: segment_pattern = 8'b1000_1110;
            endcase
        end
    endfunction

    function automatic [3:0] expected_digit(input [7:0] enable);
        begin
            case (enable)
                8'h01: expected_digit = 4'h8;
                8'h02: expected_digit = 4'h7;
                8'h04: expected_digit = 4'h6;
                8'h08: expected_digit = 4'h5;
                8'h10: expected_digit = 4'h4;
                8'h20: expected_digit = 4'h3;
                8'h40: expected_digit = 4'h2;
                8'h80: expected_digit = 4'h1;
                default: expected_digit = 4'hx;
            endcase
        end
    endfunction

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
            repeat (4) step();
        end
    endtask

    task automatic expect_tx_byte(input [7:0] expected);
        integer bit_index;
        begin
            @(negedge tx);
            repeat (CLKS_PER_BIT/2) step();
            check(tx == 1'b0, "UART TX start bit was not held");
            repeat (CLKS_PER_BIT/2) step();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                repeat (CLKS_PER_BIT/2) step();
                check(tx == expected[bit_index],
                      $sformatf("UART TX bit %0d mismatch", bit_index));
                repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) step();
            end
            repeat (CLKS_PER_BIT/2) step();
            check(tx == 1'b1, "UART TX stop bit was not high");
            repeat (CLKS_PER_BIT - CLKS_PER_BIT/2) step();
            uart_tx_frame_seen = 1'b1;
        end
    endtask

    always @(posedge fpga_clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 900000) begin
            $fatal(1, "soc_system_tb timed out");
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
                if (dut.cpu_araddr < 32'h00002000) begin
                    instruction_refill_seen <= 1'b1;
                end
                if (dut.cpu_araddr == 32'h00002000) begin
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

        if (led == sw) begin
            led_switch_seen <= 1'b1;
        end

        if (dut.mmio_wr_en && dut.mmio_wr_addr == 32'hffff2000) begin
            display_programmed <= 1'b1;
        end
        if (display_programmed) begin
            check((dig_en != 0) && ((dig_en & (dig_en - 1'b1)) == 0),
                  "display digit enable was not one-hot");
            check(dig_seg == segment_pattern(expected_digit(dig_en)),
                  "display segment pattern did not match its scan slot");
            check(dig_seg1 == dig_seg,
                  "the two EGO1 segment banks diverged");
            display_slots_seen <= display_slots_seen | dig_en;
        end
    end

    initial begin
        repeat (6) step();
        fpga_rst = 1'b0;
    end

    initial begin
        wait (!fpga_rst);
        repeat (20) step();
        send_rx_byte(8'h3c);
    end

    initial begin
        wait (!fpga_rst);
        expect_tx_byte(8'ha5);
    end

    initial begin
        reg [31:0] timer_early;
        reg [31:0] timer_late;
        wait (!fpga_rst);
        wait (dut.U_bram.mem[SIGNATURE_WORD] == PASS_SIGNATURE ||
              dut.U_bram.mem[SIGNATURE_WORD] == FAIL_SIGNATURE);
        check(dut.U_bram.mem[SIGNATURE_WORD] == PASS_SIGNATURE,
              "smoke program reported FAIL");

        wait (display_slots_seen == 8'hff && uart_tx_frame_seen);
        check(dut.U_bram.mem[32'h2000/4] == 32'h11223344,
              "ordinary memory write/read signature mismatch");
        check(dut.U_bram.mem[32'h2004/4] == 32'h11223344,
              "ordinary memory load result was not stored");
        check(dut.U_bram.mem[32'h2008/4][15:0] == sw,
              "CPU did not observe the testbench switch value");
        check(dut.U_bram.mem[32'h2010/4][7:0] == 8'h3c,
              "CPU did not consume the UART RX frame");
        timer_early = dut.U_bram.mem[32'h200c/4];
        timer_late = dut.U_bram.mem[32'h2014/4];
        check(timer_late > timer_early,
              "timer did not advance between CPU reads");
        check(led_switch_seen, "CPU switch value was not reflected on LEDs");
        check(instruction_refill_seen && data_refill_seen,
              "instruction/data four-beat Cache refills were not both seen");
        check(mmio_read_count >= 6 && mmio_write_count >= 3,
              "CPU did not exercise all expected MMIO operations");
        check(memory_read_count >= 2 && memory_write_count >= 7,
              "CPU did not exercise expected memory reads/writes");

        $display("soc_system_tb: PASS");
        $display("  CPU: reset PC=00000000, program completed by memory signature");
        $display("  Cache: instruction/data four-beat refills observed");
        $display("  Memory: write-through store and cached load verified");
        $display("  MMIO: reads=%0d writes=%0d, all single-beat",
                 mmio_read_count, mmio_write_count);
        $display("  I/O: switch, LED, 8 display slots, UART RX/TX, timer verified");
        $display("  FPGA/board: NOT RUN (RTL system simulation only)");
        $finish;
    end

endmodule
