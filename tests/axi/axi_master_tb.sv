`timescale 1ns / 1ps

`include "defines.vh"

module axi_master_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    wire        ic_dev_rrdy;
    reg  [ 3:0] ic_cpu_ren = 4'h0;
    reg  [31:0] ic_cpu_raddr = 32'h0;
    wire        ic_dev_rvalid;
    wire [127:0] ic_dev_rdata;

    wire        dc_dev_wrdy;
    reg  [ 3:0] dc_cpu_wen = 4'h0;
    reg  [31:0] dc_cpu_waddr = 32'h0;
    reg  [31:0] dc_cpu_wdata = 32'h0;
    wire        dc_dev_rrdy;
    reg  [ 3:0] dc_cpu_ren = 4'h0;
    reg  [31:0] dc_cpu_raddr = 32'h0;
    wire        dc_dev_rvalid;
    wire [127:0] dc_dev_rdata;

    wire [31:0] m_axi_awaddr;
    wire [ 7:0] m_axi_awlen;
    wire [ 2:0] m_axi_awsize;
    wire [ 1:0] m_axi_awburst;
    wire        m_axi_awvalid;
    reg         m_axi_awready = 1'b0;
    wire [31:0] m_axi_wdata;
    wire [ 3:0] m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    reg         m_axi_wready = 1'b0;
    wire        m_axi_bready;
    reg  [ 1:0] m_axi_bresp = 2'b00;
    reg         m_axi_bvalid = 1'b0;
    wire [31:0] m_axi_araddr;
    wire [ 7:0] m_axi_arlen;
    wire [ 2:0] m_axi_arsize;
    wire [ 1:0] m_axi_arburst;
    wire        m_axi_arvalid;
    reg         m_axi_arready = 1'b0;
    wire        m_axi_rready;
    reg  [31:0] m_axi_rdata = 32'h0;
    reg  [ 1:0] m_axi_rresp = 2'b00;
    reg         m_axi_rlast = 1'b0;
    reg         m_axi_rvalid = 1'b0;

    axi_master dut (
        .aclk           (clk),
        .areset         (rst),
        .ic_dev_rrdy    (ic_dev_rrdy),
        .ic_cpu_ren     (ic_cpu_ren),
        .ic_cpu_raddr   (ic_cpu_raddr),
        .ic_dev_rvalid  (ic_dev_rvalid),
        .ic_dev_rdata   (ic_dev_rdata),
        .dc_dev_wrdy    (dc_dev_wrdy),
        .dc_cpu_wen     (dc_cpu_wen),
        .dc_cpu_waddr   (dc_cpu_waddr),
        .dc_cpu_wdata   (dc_cpu_wdata),
        .dc_dev_rrdy    (dc_dev_rrdy),
        .dc_cpu_ren     (dc_cpu_ren),
        .dc_cpu_raddr   (dc_cpu_raddr),
        .dc_dev_rvalid  (dc_dev_rvalid),
        .dc_dev_rdata   (dc_dev_rdata),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid)
    );

    task automatic step;
        begin
            @(posedge clk);
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

    function automatic [127:0] expected_line(
        input [31:0] first_word,
        input integer beat_count
    );
        integer beat;
        begin
            expected_line = 128'h0;
            for (beat = 0; beat < beat_count; beat = beat + 1) begin
                expected_line[beat*32 +: 32] = first_word + beat;
            end
        end
    endfunction

    task automatic complete_read(
        input bit dcache_source,
        input [31:0] expected_addr,
        input integer beat_count,
        input [31:0] first_word
    );
        integer beat;
        begin
            check(m_axi_arvalid, "ARVALID must assert after accepting a cache request");
            check(m_axi_araddr == expected_addr, "read address changed before AR handshake");
            check(m_axi_arlen == beat_count - 1, "ARLEN does not match cache line length");
            check(m_axi_arsize == 3'd2, "AXI reads must use four-byte beats");
            check(m_axi_arburst == 2'b01, "AXI reads must use INCR bursts");

            // Hold off the address channel and verify that the request persists.
            repeat (2) begin
                step();
                check(m_axi_arvalid, "ARVALID dropped under address backpressure");
                check(m_axi_araddr == expected_addr, "ARADDR changed under backpressure");
            end

            m_axi_arready = 1'b1;
            step();
            m_axi_arready = 1'b0;
            check(!m_axi_arvalid && m_axi_rready,
                  "read FSM did not advance from AR to R channel");

            for (beat = 0; beat < beat_count; beat = beat + 1) begin
                // Insert one idle cycle before every beat.
                step();
                check(m_axi_rready, "RREADY dropped while a burst was pending");
                m_axi_rdata = first_word + beat;
                m_axi_rresp = 2'b00;
                m_axi_rlast = beat == beat_count - 1;
                m_axi_rvalid = 1'b1;
                step();
                check(m_axi_rresp == 2'b00,
                      "legal cache read received a non-OKAY response");
                m_axi_rvalid = 1'b0;
                m_axi_rlast = 1'b0;
            end

            if (dcache_source) begin
                check(dc_dev_rvalid && !ic_dev_rvalid,
                      "DCache read response was delivered to the wrong source");
                check(dc_dev_rdata == expected_line(first_word, beat_count),
                      "DCache read burst was assembled in the wrong word order");
            end else begin
                check(ic_dev_rvalid && !dc_dev_rvalid,
                      "ICache read response was delivered to the wrong source");
                check(ic_dev_rdata == expected_line(first_word, beat_count),
                      "ICache read burst was assembled in the wrong word order");
            end

            step();
            check(!ic_dev_rvalid && !dc_dev_rvalid,
                  "cache read response must be a one-cycle pulse");
        end
    endtask

    initial begin
        integer cycles;
        cycles = 0;
        forever begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > 500) begin
                $fatal(1, "AXI master test timed out");
            end
        end
    end

    initial begin
        repeat (3) step();
        rst = 1'b0;
        step();
        check(ic_dev_rrdy && dc_dev_rrdy && dc_dev_wrdy,
              "all cache-side ready signals must be high when idle");

        // A DCache read wins over a simultaneous ICache request. Keep the
        // ICache request asserted so it is accepted after the DCache response.
        ic_cpu_ren = 4'hf;
        ic_cpu_raddr = 32'h0000_0040;
        dc_cpu_ren = 4'hf;
        dc_cpu_raddr = 32'h0000_0080;
        #1;
        check(dc_dev_rrdy && !ic_dev_rrdy,
              "DCache read must have priority over ICache read");
        step();
        dc_cpu_ren = 4'h0;
        complete_read(1'b1, 32'h0000_0080, `DC_BLK_LEN, 32'hd000_0000);

        // Even with DCache enabled, uncached MMIO retains its byte address and
        // is always one 32-bit AXI beat rather than a cache-line refill.
        dc_cpu_ren = 4'hf;
        dc_cpu_raddr = 32'hffff_1001;
        step();
        dc_cpu_ren = 4'h0;
        complete_read(1'b1, 32'hffff_1001, 1, 32'h4433_2211);

        check(ic_dev_rrdy, "pending ICache request was not exposed after DCache read");
        step();
        ic_cpu_ren = 4'h0;
        complete_read(1'b0, 32'h0000_0040, `IC_BLK_LEN, 32'h1000_0000);

        // A write blocks both read request classes. AW and W may be accepted in
        // either order; here W completes first to exercise independent flags.
        ic_cpu_ren = 4'hf;
        ic_cpu_raddr = 32'h0000_00c0;
        dc_cpu_wen = 4'b0101;
        dc_cpu_waddr = 32'h0000_0104;
        dc_cpu_wdata = 32'ha5a5_5a5a;
        #1;
        check(dc_dev_wrdy && !ic_dev_rrdy && !dc_dev_rrdy,
              "DCache write must have priority while the bridge is idle");
        step();
        dc_cpu_wen = 4'h0;

        check(m_axi_awvalid && m_axi_wvalid && !dc_dev_wrdy,
              "write request did not enter AXI send state");
        check(m_axi_awaddr == 32'h0000_0104 && m_axi_awlen == 8'h0,
              "write address metadata is incorrect");
        check(m_axi_awsize == 3'd2 && m_axi_awburst == 2'b01,
              "write transfer shape is incorrect");
        check(m_axi_wdata == 32'ha5a5_5a5a && m_axi_wstrb == 4'b0101 &&
              m_axi_wlast, "write data or byte strobes are incorrect");

        m_axi_wready = 1'b1;
        step();
        m_axi_wready = 1'b0;
        check(m_axi_awvalid && !m_axi_wvalid,
              "WVALID must clear independently of AWVALID");

        repeat (2) begin
            step();
            check(m_axi_awvalid && m_axi_awaddr == 32'h0000_0104,
                  "AW request changed under backpressure");
        end
        m_axi_awready = 1'b1;
        step();
        m_axi_awready = 1'b0;
        check(m_axi_bready && !m_axi_awvalid && !m_axi_wvalid,
              "write FSM did not wait for the B response");

        repeat (2) begin
            step();
            check(m_axi_bready && !dc_dev_wrdy,
                  "bridge became ready before write response");
        end
        m_axi_bvalid = 1'b1;
        step();
        m_axi_bvalid = 1'b0;
        check(dc_dev_wrdy, "write completion did not restore DCache ready");

        // The ICache request held across the write must now be accepted.
        check(ic_dev_rrdy, "pending ICache request was lost behind a write");
        step();
        ic_cpu_ren = 4'h0;
        complete_read(1'b0, 32'h0000_00c0, `IC_BLK_LEN, 32'hc000_0000);

        // Reset must abandon every partially accepted transaction and restore
        // all cache-side ready signals without a late completion pulse.
        dc_cpu_ren = 4'hf;
        dc_cpu_raddr = 32'h0000_0200;
        step();
        dc_cpu_ren = 4'h0;
        check(m_axi_arvalid, "reset READ_ADDR setup failed");
        rst = 1'b1;
        step();
        check(!m_axi_arvalid && !m_axi_rready &&
              ic_dev_rrdy && dc_dev_rrdy && dc_dev_wrdy,
              "reset did not clear READ_ADDR");
        rst = 1'b0;
        step();

        dc_cpu_ren = 4'hf;
        dc_cpu_raddr = 32'h0000_0240;
        step();
        dc_cpu_ren = 4'h0;
        m_axi_arready = 1'b1;
        step();
        m_axi_arready = 1'b0;
        check(m_axi_rready, "reset READ_DATA setup failed");
        rst = 1'b1;
        step();
        check(!m_axi_rready && ic_dev_rrdy && dc_dev_rrdy && dc_dev_wrdy,
              "reset did not clear READ_DATA");
        rst = 1'b0;
        step();

        dc_cpu_wen = 4'hf;
        dc_cpu_waddr = 32'h0000_0300;
        dc_cpu_wdata = 32'h1234_5678;
        step();
        dc_cpu_wen = 4'h0;
        check(m_axi_awvalid && m_axi_wvalid,
              "reset WRITE_SEND setup failed");
        rst = 1'b1;
        step();
        check(!m_axi_awvalid && !m_axi_wvalid && !m_axi_bready && dc_dev_wrdy,
              "reset did not clear WRITE_SEND");
        rst = 1'b0;
        step();

        dc_cpu_wen = 4'hf;
        dc_cpu_waddr = 32'h0000_0340;
        dc_cpu_wdata = 32'h89ab_cdef;
        step();
        dc_cpu_wen = 4'h0;
        m_axi_awready = 1'b1;
        m_axi_wready = 1'b1;
        step();
        m_axi_awready = 1'b0;
        m_axi_wready = 1'b0;
        check(m_axi_bready, "reset WRITE_RESP setup failed");
        rst = 1'b1;
        step();
        check(!m_axi_bready && dc_dev_wrdy,
              "reset did not clear WRITE_RESP");
        rst = 1'b0;
        step();

        $display("axi_master_tb: PASS (IC beats=%0d, DC beats=%0d)",
                 `IC_BLK_LEN, `DC_BLK_LEN);
        $finish;
    end

endmodule
