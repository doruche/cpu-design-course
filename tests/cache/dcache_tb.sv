`timescale 1ns / 1ps

module dcache_tb;
    reg cpu_clk = 1'b0;
    reg cpu_rst = 1'b1;

    reg [3:0] data_ren = 4'h0;
    reg [31:0] data_addr = 32'h0;
    wire data_valid;
    wire [31:0] data_rdata;
    reg [3:0] data_wen = 4'h0;
    reg [31:0] data_wdata = 32'h0;
    wire data_wresp;

    reg dev_wrdy = 1'b0;
    wire [3:0] cpu_wen;
    wire [31:0] cpu_waddr;
    wire [31:0] cpu_wdata;

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

    DCache dut (
        .cpu_clk        (cpu_clk),
        .cpu_rst        (cpu_rst),
        .data_ren       (data_ren),
        .data_addr      (data_addr),
        .data_valid     (data_valid),
        .data_rdata     (data_rdata),
        .data_wen       (data_wen),
        .data_wdata     (data_wdata),
        .data_wresp     (data_wresp),
        .dev_wrdy       (dev_wrdy),
        .cpu_wen        (cpu_wen),
        .cpu_waddr      (cpu_waddr),
        .cpu_wdata      (cpu_wdata),
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
                $fatal(1, "DCache check failed: %s", message);
            end
        end
    endtask

    task automatic reset_dut;
        begin
            cpu_rst = 1'b1;
            data_ren = 4'h0;
            data_wen = 4'h0;
            dev_rrdy = 1'b0;
            dev_wrdy = 1'b0;
            dev_rvalid = 1'b0;
            repeat (2) @(posedge cpu_clk);
            @(negedge cpu_clk);
            cpu_rst = 1'b0;
        end
    endtask

    task automatic request_read;
        input [31:0] address;
        input [3:0] read_enable;
        begin
            @(negedge cpu_clk);
            data_addr = address;
            data_ren = read_enable;
            @(negedge cpu_clk);
            data_ren = 4'h0;
        end
    endtask

    task automatic accept_read_request;
        input [31:0] expected_address;
        input [3:0] expected_enable;
        begin
            wait (cpu_ren != 4'h0);
            #1;
            check(cpu_ren == expected_enable, "read enable mismatch");
            check(cpu_raddr == expected_address, "read address mismatch");

            @(negedge cpu_clk);
            check(cpu_ren == expected_enable, "read request must remain asserted under backpressure");
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
        input [31:0] expected_data;
        begin
            @(negedge cpu_clk);
            dev_rdata = line;
            dev_rvalid = 1'b1;
            #1;
            check(data_valid, "read response must produce valid data");
            check(data_rdata == expected_data, "returned read data mismatch");

            @(posedge cpu_clk);
            #1;
            dev_rvalid = 1'b0;
            dev_rdata = 128'h0;
            check(!data_valid, "read valid must be a single response pulse");
        end
    endtask

    task automatic request_write;
        input [31:0] address;
        input [3:0] write_enable;
        input [31:0] write_data;
        begin
            @(negedge cpu_clk);
            data_addr = address;
            data_wen = write_enable;
            data_wdata = write_data;
            @(negedge cpu_clk);
            data_wen = 4'h0;
        end
    endtask

    task automatic complete_write;
        input [31:0] expected_address;
        input [3:0] expected_enable;
        input [31:0] expected_data;
        begin
            wait (cpu_wen != 4'h0);
            #1;
            check(cpu_wen == expected_enable, "write enable mismatch");
            check(cpu_waddr == expected_address, "write address mismatch");
            check(cpu_wdata == expected_data, "write data mismatch");

            @(negedge cpu_clk);
            check(cpu_wen == expected_enable, "write request must remain asserted under backpressure");
            dev_wrdy = 1'b1;

            @(posedge cpu_clk);
            #1;
            dev_wrdy = 1'b0;
            check(cpu_wen == 4'h0, "accepted write request must be withdrawn");
            check(!data_wresp, "write must not complete before the bus becomes busy");

            @(posedge cpu_clk);
            #1;
            check(!data_wresp, "write must wait for bus completion");

            @(negedge cpu_clk);
            dev_wrdy = 1'b1;
            #1;
            check(data_wresp, "write response must follow bus completion");

            @(posedge cpu_clk);
            #1;
            dev_wrdy = 1'b0;
            check(!data_wresp, "write response must be a single pulse");
        end
    endtask

    initial begin
        reset_dut();

`ifdef ENABLE_DCACHE
        request_read(32'h0000_0044, 4'hf);
        accept_read_request(32'h0000_0040, 4'hf);
        return_read_data(LINE_A, 32'h2222_2222);

        request_read(32'h0000_0048, 4'hf);
        #1;
        check(data_valid, "cached data must hit without a bus request");
        check(data_rdata == 32'h3333_3333, "cache hit selected the wrong word");
        check(cpu_ren == 4'h0, "cache hit must not access the bus");
        @(posedge cpu_clk);

        // Store byte at byte offset one of the cached second word.
        request_write(32'h0000_0045, 4'b0010, 32'h0000_aa00);
        complete_write(32'h0000_0045, 4'b0010, 32'h0000_aa00);

        request_read(32'h0000_0044, 4'hf);
        #1;
        check(data_valid, "write hit must keep the line cached");
        check(data_rdata == 32'h2222_aa22, "write hit did not update the selected byte lane");
        check(cpu_ren == 4'h0, "write-hit readback must not access the bus");
        @(posedge cpu_clk);

        // Write miss is write-through/no-write-allocate and must not evict the old line.
        request_write(32'h0000_0445, 4'b0010, 32'h0000_bb00);
        complete_write(32'h0000_0445, 4'b0010, 32'h0000_bb00);

        request_read(32'h0000_0044, 4'hf);
        #1;
        check(data_valid, "write miss must not evict the resident line");
        check(data_rdata == 32'h2222_aa22, "write miss changed the resident line");
        @(posedge cpu_clk);

        // Peripheral reads bypass allocation and consume the low returned word.
        request_read(32'hffff_3004, 4'hf);
        accept_read_request(32'hffff_3004, 4'hf);
        return_read_data({96'hfeed_face_cafe_babe_1234_5678, 32'hdead_beef},
                         32'hdead_beef);

        request_read(32'hffff_3004, 4'hf);
        accept_read_request(32'hffff_3004, 4'hf);
        return_read_data({96'h0, 32'h7654_3210}, 32'h7654_3210);

        reset_dut();
        request_read(32'h0000_0044, 4'hf);
        accept_read_request(32'h0000_0040, 4'hf);
        return_read_data(LINE_A, 32'h2222_2222);
`else
        request_read(32'h0000_0044, 4'hf);
        accept_read_request(32'h0000_0044, 4'hf);
        return_read_data({96'hffff_ffff_eeee_eeee_dddd_dddd, 32'h1234_5678},
                         32'h1234_5678);

        // Bypass mode must not retain the previous read.
        request_read(32'h0000_0044, 4'hf);
        accept_read_request(32'h0000_0044, 4'hf);
        return_read_data({96'h0, 32'h8765_4321}, 32'h8765_4321);

        request_write(32'h0000_0045, 4'b0010, 32'h0000_aa00);
        complete_write(32'h0000_0045, 4'b0010, 32'h0000_aa00);
`endif

        $display("DCache test passed");
        $finish;
    end
endmodule
