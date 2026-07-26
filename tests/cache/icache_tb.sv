`timescale 1ns / 1ps

module icache_tb;
    reg cpu_clk = 1'b0;
    reg cpu_rst = 1'b1;

    reg inst_rreq = 1'b0;
    reg [31:0] inst_addr = 32'h0;
    wire inst_valid;
    wire [31:0] inst_out;

    reg dev_rrdy = 1'b0;
    wire [3:0] cpu_ren;
    wire [31:0] cpu_raddr;
    reg dev_rvalid = 1'b0;
    reg [127:0] dev_rdata = 128'h0;

    localparam [127:0] LINE_A = {
        32'h4444_4444,
        32'h3333_3333,
        32'h2222_2222,
        32'h1111_1111
    };
    localparam [127:0] LINE_B = {
        32'hdddd_dddd,
        32'hcccc_cccc,
        32'hbbbb_bbbb,
        32'haaaa_aaaa
    };

    ICache dut (
        .cpu_clk        (cpu_clk),
        .cpu_rst        (cpu_rst),
        .inst_rreq      (inst_rreq),
        .inst_addr      (inst_addr),
        .inst_valid     (inst_valid),
        .inst_out       (inst_out),
        .dev_rrdy       (dev_rrdy),
        .cpu_ren        (cpu_ren),
        .cpu_raddr      (cpu_raddr),
        .dev_rvalid     (dev_rvalid),
        .dev_rdata      (dev_rdata)
    );

    always #5 cpu_clk = ~cpu_clk;

    task automatic check;
        input logic condition;
        input string message;
        begin
            if (!condition) begin
                $fatal(1, "ICache check failed: %s", message);
            end
        end
    endtask

    task automatic reset_dut;
        begin
            cpu_rst = 1'b1;
            inst_rreq = 1'b0;
            dev_rrdy = 1'b0;
            dev_rvalid = 1'b0;
            repeat (2) @(posedge cpu_clk);
            @(negedge cpu_clk);
            cpu_rst = 1'b0;
        end
    endtask

    task automatic request_instruction;
        input [31:0] address;
        begin
            @(negedge cpu_clk);
            inst_addr = address;
            inst_rreq = 1'b1;
            @(negedge cpu_clk);
            inst_rreq = 1'b0;
        end
    endtask

    task automatic accept_read_request;
        input [31:0] expected_address;
        begin
            wait (cpu_ren != 4'h0);
            #1;
            check(cpu_ren == 4'hf, "read enable must request one full word/line");
            check(cpu_raddr == expected_address, "read address mismatch");

            @(negedge cpu_clk);
            check(cpu_ren == 4'hf, "read request must remain asserted under backpressure");
            check(cpu_raddr == expected_address, "read address must remain stable");
            dev_rrdy = 1'b1;

            @(posedge cpu_clk);
            #1;
            dev_rrdy = 1'b0;
            check(cpu_ren == 4'h0, "accepted read request must be withdrawn");
        end
    endtask

    task automatic return_read_data;
        input [127:0] line;
        input [31:0] expected_instruction;
        begin
            @(negedge cpu_clk);
            dev_rdata = line;
            dev_rvalid = 1'b1;
            #1;
            check(inst_valid, "read response must produce an instruction");
            check(inst_out == expected_instruction, "returned instruction mismatch");

            @(posedge cpu_clk);
            #1;
            dev_rvalid = 1'b0;
            dev_rdata = 128'h0;
            check(!inst_valid, "instruction valid must be a single response pulse");
        end
    endtask

    initial begin
        reset_dut();

`ifdef ENABLE_ICACHE
        request_instruction(32'h0000_0024);
        accept_read_request(32'h0000_0020);
        return_read_data(LINE_A, 32'h2222_2222);

        request_instruction(32'h0000_0028);
        #1;
        check(inst_valid, "cached instruction must hit without a bus request");
        check(inst_out == 32'h3333_3333, "cache hit selected the wrong word");
        check(cpu_ren == 4'h0, "cache hit must not access the bus");
        @(posedge cpu_clk);

        // Same index, different tag: the old line must be replaced.
        request_instruction(32'h0000_0424);
        accept_read_request(32'h0000_0420);
        return_read_data(LINE_B, 32'hbbbb_bbbb);

        request_instruction(32'h0000_0024);
        accept_read_request(32'h0000_0020);
        return_read_data(LINE_A, 32'h2222_2222);

        reset_dut();
        request_instruction(32'h0000_0024);
        accept_read_request(32'h0000_0020);
        return_read_data(LINE_A, 32'h2222_2222);
`else
        request_instruction(32'h0000_0024);
        accept_read_request(32'h0000_0024);
        return_read_data(LINE_A, 32'h1111_1111);

        // Bypass mode must issue the same request again instead of retaining it.
        request_instruction(32'h0000_0024);
        accept_read_request(32'h0000_0024);
        return_read_data(LINE_B, 32'haaaa_aaaa);
`endif

        $display("ICache test passed");
        $finish;
    end
endmodule
