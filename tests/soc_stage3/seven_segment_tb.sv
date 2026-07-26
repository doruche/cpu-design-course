`timescale 1ns / 1ps

module seven_segment_tb;

    reg         clk = 1'b0;
    reg         rst = 1'b0;
    reg  [31:0] value = 32'h7654_3210;
    wire [ 7:0] dig_en;
    wire [ 7:0] dig_seg;

    integer digit_index;
    integer slot_index;

    always #5 clk = ~clk;

    seven_segment dut (
        .clk     (clk),
        .rst     (rst),
        .value   (value),
        .dig_en  (dig_en),
        .dig_seg (dig_seg)
    );

    function automatic [7:0] expected_segments(input [3:0] digit_value);
        begin
            case (digit_value)
                4'h0: expected_segments = 8'b1111_1100;
                4'h1: expected_segments = 8'b0110_0000;
                4'h2: expected_segments = 8'b1101_1010;
                4'h3: expected_segments = 8'b1111_0010;
                4'h4: expected_segments = 8'b0110_0110;
                4'h5: expected_segments = 8'b1011_0110;
                4'h6: expected_segments = 8'b1011_1110;
                4'h7: expected_segments = 8'b1110_0000;
                4'h8: expected_segments = 8'b1111_1110;
                4'h9: expected_segments = 8'b1111_0110;
                4'ha: expected_segments = 8'b1110_1110;
                4'hb: expected_segments = 8'b0011_1110;
                4'hc: expected_segments = 8'b1001_1100;
                4'hd: expected_segments = 8'b0111_1010;
                4'he: expected_segments = 8'b1001_1110;
                4'hf: expected_segments = 8'b1000_1110;
                default: expected_segments = 8'h00;
            endcase
        end
    endfunction

    task automatic check(input logic condition, input string message);
        begin
            if (condition !== 1'b1) begin
                $fatal(1, "%s", message);
            end
        end
    endtask

    // The production divider needs 2^16 clocks per slot. Directly selecting
    // the counter's slot bits keeps this module test fast while preserving the
    // real combinational scan and segment-decode logic.
    task automatic select_slot(input integer selected_slot);
        begin
            @(negedge clk);
            dut.refresh_counter = selected_slot << 16;
            #1;
        end
    endtask

    initial begin
        #2000;
        $fatal(1, "seven_segment_tb timed out");
    end

    initial begin
        // Exercise the asynchronous reset from a known non-reset state. Reset
        // fixes the scan counter at slot zero, so the board-facing outputs are
        // deterministic for the current low nibble.
        #2;
        rst = 1'b1;
        #1;
        check(dut.refresh_counter === 19'h0,
              "reset did not clear the refresh counter");
        check(dig_en === 8'b0000_0001,
              "reset did not select the deterministic first scan slot");
        check(dig_seg === expected_segments(4'h0),
              "reset produced the wrong deterministic segment output");

        @(negedge clk);
        rst = 1'b0;

        // Each nibble is intentionally different, proving both the one-hot
        // slot enable and the nibble selected for all eight scan positions.
        for (slot_index = 0; slot_index < 8;
             slot_index = slot_index + 1) begin
            select_slot(slot_index);
            check(dig_en === (8'b0000_0001 << slot_index),
                  $sformatf("scan slot %0d enable mismatch", slot_index));
            check(dig_seg ===
                  expected_segments(value[slot_index*4 +: 4]),
                  $sformatf("scan slot %0d selected the wrong nibble",
                            slot_index));
        end

        // Hold the scan on slot zero and exhaustively cover the hexadecimal
        // decoder. DP remains low in every expected code.
        for (digit_index = 0; digit_index < 16;
             digit_index = digit_index + 1) begin
            value[3:0] = digit_index[3:0];
            select_slot(0);
            check(dig_en === 8'b0000_0001,
                  "hex decode test did not remain on slot zero");
            check(dig_seg === expected_segments(digit_index[3:0]),
                  $sformatf("hex digit %0h segment code mismatch",
                            digit_index[3:0]));
        end

        $display("seven_segment_tb: PASS");
        $finish;
    end

endmodule
