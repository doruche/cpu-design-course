`timescale 1ns / 1ps

module soc_stage3_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    reg  [31:0] s_awaddr = 32'h0;
    reg  [ 7:0] s_awlen = 8'h0;
    reg  [ 2:0] s_awsize = 3'd2;
    reg  [ 1:0] s_awburst = 2'b01;
    reg         s_awvalid = 1'b0;
    wire        s_awready;
    reg  [31:0] s_wdata = 32'h0;
    reg  [ 3:0] s_wstrb = 4'h0;
    reg         s_wlast = 1'b1;
    reg         s_wvalid = 1'b0;
    wire        s_wready;
    wire [ 1:0] s_bresp;
    wire        s_bvalid;
    reg         s_bready = 1'b0;
    reg  [31:0] s_araddr = 32'h0;
    reg  [ 7:0] s_arlen = 8'h0;
    reg  [ 2:0] s_arsize = 3'd2;
    reg  [ 1:0] s_arburst = 2'b01;
    reg         s_arvalid = 1'b0;
    wire        s_arready;
    wire [31:0] s_rdata;
    wire [ 1:0] s_rresp;
    wire        s_rlast;
    wire        s_rvalid;
    reg         s_rready = 1'b0;

    wire [31:0] m_awaddr;
    wire [ 7:0] m_awlen;
    wire [ 2:0] m_awsize;
    wire [ 1:0] m_awburst;
    wire        m_awvalid;
    reg         m_awready = 1'b0;
    wire [31:0] m_wdata;
    wire [ 3:0] m_wstrb;
    wire        m_wlast;
    wire        m_wvalid;
    reg         m_wready = 1'b0;
    reg  [ 1:0] m_bresp = 2'b00;
    reg         m_bvalid = 1'b0;
    wire        m_bready;
    wire [31:0] m_araddr;
    wire [ 7:0] m_arlen;
    wire [ 2:0] m_arsize;
    wire [ 1:0] m_arburst;
    wire        m_arvalid;
    reg         m_arready = 1'b0;
    reg  [31:0] m_rdata = 32'h0;
    reg  [ 1:0] m_rresp = 2'b00;
    reg         m_rlast = 1'b0;
    reg         m_rvalid = 1'b0;
    wire        m_rready;

    wire        mmio_rd_en;
    wire [31:0] mmio_rd_addr;
    wire [31:0] mmio_rd_data;
    wire        mmio_rd_error;
    wire        mmio_wr_en;
    wire [31:0] mmio_wr_addr;
    wire [31:0] mmio_wr_data;
    wire [ 3:0] mmio_wr_strb;
    wire        mmio_wr_error;

    reg  [15:0] sw = 16'ha55a;
    wire [15:0] led;
    wire [ 7:0] dig_en;
    wire [ 7:0] dig_seg;
    reg         rx = 1'b1;
    wire        tx;

    integer mmio_read_count = 0;
    integer mmio_write_count = 0;

    soc_interconnect U_interconnect (
        .aclk(clk), .areset(rst),
        .s_axi_awaddr(s_awaddr), .s_axi_awlen(s_awlen),
        .s_axi_awsize(s_awsize), .s_axi_awburst(s_awburst),
        .s_axi_awvalid(s_awvalid), .s_axi_awready(s_awready),
        .s_axi_wdata(s_wdata), .s_axi_wstrb(s_wstrb),
        .s_axi_wlast(s_wlast), .s_axi_wvalid(s_wvalid),
        .s_axi_wready(s_wready), .s_axi_bresp(s_bresp),
        .s_axi_bvalid(s_bvalid), .s_axi_bready(s_bready),
        .s_axi_araddr(s_araddr), .s_axi_arlen(s_arlen),
        .s_axi_arsize(s_arsize), .s_axi_arburst(s_arburst),
        .s_axi_arvalid(s_arvalid), .s_axi_arready(s_arready),
        .s_axi_rdata(s_rdata), .s_axi_rresp(s_rresp),
        .s_axi_rlast(s_rlast), .s_axi_rvalid(s_rvalid),
        .s_axi_rready(s_rready),
        .m_axi_awaddr(m_awaddr), .m_axi_awlen(m_awlen),
        .m_axi_awsize(m_awsize), .m_axi_awburst(m_awburst),
        .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb),
        .m_axi_wlast(m_wlast), .m_axi_wvalid(m_wvalid),
        .m_axi_wready(m_wready), .m_axi_bresp(m_bresp),
        .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_araddr(m_araddr), .m_axi_arlen(m_arlen),
        .m_axi_arsize(m_arsize), .m_axi_arburst(m_arburst),
        .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp),
        .m_axi_rlast(m_rlast), .m_axi_rvalid(m_rvalid),
        .m_axi_rready(m_rready),
        .mmio_rd_en(mmio_rd_en), .mmio_rd_addr(mmio_rd_addr),
        .mmio_rd_data(mmio_rd_data), .mmio_rd_error(mmio_rd_error),
        .mmio_wr_en(mmio_wr_en), .mmio_wr_addr(mmio_wr_addr),
        .mmio_wr_data(mmio_wr_data), .mmio_wr_strb(mmio_wr_strb),
        .mmio_wr_error(mmio_wr_error)
    );

    soc_peripherals #(
        .CLOCK_FREQ(40),
        .UART_BAUD_RATE(10)
    ) U_peripherals (
        .clk(clk), .rst(rst),
        .mmio_rd_en(mmio_rd_en), .mmio_rd_addr(mmio_rd_addr),
        .mmio_rd_data(mmio_rd_data), .mmio_rd_error(mmio_rd_error),
        .mmio_wr_en(mmio_wr_en), .mmio_wr_addr(mmio_wr_addr),
        .mmio_wr_data(mmio_wr_data), .mmio_wr_strb(mmio_wr_strb),
        .mmio_wr_error(mmio_wr_error),
        .sw(sw), .led(led), .dig_en(dig_en), .dig_seg(dig_seg),
        .rx(rx), .tx(tx)
    );

    always @(posedge clk) begin
        if (mmio_rd_en) mmio_read_count <= mmio_read_count + 1;
        if (mmio_wr_en) mmio_write_count <= mmio_write_count + 1;
    end

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

    function automatic bit cpu_strobe_is_valid(
        input [1:0] address_offset,
        input [3:0] strobes
    );
        begin
            case (address_offset)
                2'd0: cpu_strobe_is_valid = strobes == 4'b0001 ||
                                              strobes == 4'b0011 ||
                                              strobes == 4'b1111;
                2'd1: cpu_strobe_is_valid = strobes == 4'b0010;
                2'd2: cpu_strobe_is_valid = strobes == 4'b0100 ||
                                              strobes == 4'b1100;
                2'd3: cpu_strobe_is_valid = strobes == 4'b1000;
            endcase
        end
    endfunction

    function automatic [31:0] merge_bytes(
        input [31:0] old_value,
        input [31:0] new_value,
        input [ 3:0] strobes
    );
        integer byte_index;
        begin
            merge_bytes = old_value;
            for (byte_index = 0; byte_index < 4;
                 byte_index = byte_index + 1) begin
                if (strobes[byte_index]) begin
                    merge_bytes[byte_index*8 +: 8] =
                        new_value[byte_index*8 +: 8];
                end
            end
        end
    endfunction

    task automatic mmio_read(
        input [31:0] address,
        input [ 1:0] expected_resp,
        output [31:0] value
    );
        begin
            s_araddr = address;
            s_arlen = 8'h0;
            s_arvalid = 1'b1;
            s_rready = 1'b0;
            #1;
            check(s_arready, "MMIO AR channel was not ready");
            step();
            s_arvalid = 1'b0;
            #1;
            check(s_rvalid && s_rlast, "MMIO read response was not held");
            check(s_rresp == expected_resp, "MMIO read response code mismatch");
            value = s_rdata;
            s_rready = 1'b1;
            step();
            s_rready = 1'b0;
            check(!s_rvalid, "MMIO read response did not retire");
        end
    endtask

    task automatic mmio_write(
        input [31:0] address,
        input [31:0] data,
        input [ 3:0] strobes,
        input [ 1:0] expected_resp
    );
        begin
            s_awaddr = address;
            s_awlen = 8'h0;
            s_awvalid = 1'b1;
            s_wdata = data;
            s_wstrb = strobes;
            s_wlast = 1'b1;
            s_wvalid = 1'b1;
            s_bready = 1'b0;
            #1;
            check(s_awready && !s_wready,
                  "MMIO write must capture AW before accepting W");
            step();
            s_awvalid = 1'b0;
            #1;
            check(s_wready, "MMIO W channel was not ready after AW");
            step();
            s_wvalid = 1'b0;
            #1;
            check(s_bvalid, "MMIO write response was not held");
            check(s_bresp == expected_resp, "MMIO write response code mismatch");
            s_bready = 1'b1;
            step();
            s_bready = 1'b0;
            check(!s_bvalid, "MMIO write response did not retire");
        end
    endtask

    task automatic rejected_mmio_read_burst(input [31:0] address);
        integer beat;
        integer reads_before;
        begin
            reads_before = mmio_read_count;
            s_araddr = address;
            s_arlen = 8'd1;
            s_arsize = 3'd2;
            s_arburst = 2'b01;
            s_arvalid = 1'b1;
            s_rready = 1'b0;
            #1;
            check(s_arready, "rejected MMIO burst address was not accepted");
            step();
            s_arvalid = 1'b0;
            check(mmio_read_count == reads_before,
                  "rejected MMIO read caused a peripheral side effect");

            repeat (2) begin
                step();
                check(s_rvalid && s_rresp == 2'b11 && !s_rlast,
                      "rejected MMIO R response changed under backpressure");
            end
            s_rready = 1'b1;
            for (beat = 0; beat < 2; beat = beat + 1) begin
                #1;
                check(s_rvalid && s_rresp == 2'b11,
                      "rejected MMIO read did not return DECERR");
                check(s_rlast == (beat == 1),
                      "rejected MMIO read returned the wrong RLAST shape");
                step();
            end
            s_rready = 1'b0;
            check(!s_rvalid, "rejected MMIO read response did not retire");
            check(mmio_read_count == reads_before,
                  "rejected MMIO read touched the peripheral");
        end
    endtask

    task automatic rejected_mmio_write_burst(input [31:0] address);
        integer writes_before;
        reg [15:0] led_before;
        begin
            writes_before = mmio_write_count;
            led_before = led;
            s_awaddr = address;
            s_awlen = 8'd1;
            s_awsize = 3'd2;
            s_awburst = 2'b01;
            s_awvalid = 1'b1;
            s_wdata = 32'h0000_cafe;
            s_wstrb = 4'hf;
            s_wlast = 1'b0;
            s_wvalid = 1'b1;
            s_bready = 1'b0;
            #1;
            check(s_awready && !s_wready,
                  "rejected MMIO write did not capture AW first");
            step();
            s_awvalid = 1'b0;

            #1;
            check(s_wready, "rejected MMIO write did not consume first W beat");
            step();
            s_wdata = 32'h0000_dead;
            s_wlast = 1'b1;
            #1;
            check(s_wready, "rejected MMIO write did not consume final W beat");
            step();
            s_wvalid = 1'b0;

            check(mmio_write_count == writes_before && led == led_before,
                  "rejected MMIO write changed peripheral state");
            #1;
            check(s_bvalid && s_bresp == 2'b11,
                  "rejected MMIO write did not return DECERR");
            repeat (2) begin
                step();
                check(s_bvalid && s_bresp == 2'b11,
                      "rejected MMIO B response changed under backpressure");
            end
            s_bready = 1'b1;
            step();
            s_bready = 1'b0;
            check(!s_bvalid, "rejected MMIO write response did not retire");
        end
    endtask

    task automatic reset_inflight_paths;
        begin
            // Reset with a valid MMIO R response held by backpressure.
            s_araddr = 32'hffff_0000;
            s_arlen = 8'h0;
            s_arsize = 3'd2;
            s_arburst = 2'b01;
            s_arvalid = 1'b1;
            s_rready = 1'b0;
            step();
            s_arvalid = 1'b0;
            check(s_rvalid, "reset READ_MMIO setup failed");
            rst = 1'b1;
            step();
            check(!s_rvalid, "reset did not discard held MMIO R response");
            rst = 1'b0;
            step();

            // Reset after AW but before W: no write pulse or response may
            // survive the reset.
            s_awaddr = 32'hffff_1000;
            s_awlen = 8'h0;
            s_awsize = 3'd2;
            s_awburst = 2'b01;
            s_awvalid = 1'b1;
            s_wvalid = 1'b0;
            step();
            s_awvalid = 1'b0;
            check(s_wready, "reset WRITE_DATA setup failed");
            rst = 1'b1;
            step();
            check(!s_bvalid && s_awready,
                  "reset did not discard the partial MMIO write");
            rst = 1'b0;
            step();

            // Reset while B is held after a legal side effect.
            s_awaddr = 32'hffff_1000;
            s_awvalid = 1'b1;
            s_wdata = 32'h0000_4321;
            s_wstrb = 4'hf;
            s_wlast = 1'b1;
            s_wvalid = 1'b1;
            s_bready = 1'b0;
            step();
            s_awvalid = 1'b0;
            step();
            s_wvalid = 1'b0;
            check(s_bvalid, "reset WRITE_MMIO_RESP setup failed");
            rst = 1'b1;
            step();
            check(!s_bvalid && s_awready,
                  "reset did not discard the held MMIO B response");
            rst = 1'b0;
            step();
        end
    endtask

    task automatic parallel_memory_read_write;
        begin
            // AR and AW are independent AXI channels and may be accepted in
            // the same cycle even though the current cpu master serializes.
            s_araddr = 32'h0000_0080;
            s_arlen = 8'h0;
            s_arvalid = 1'b1;
            s_awaddr = 32'h0000_0100;
            s_awlen = 8'h0;
            s_awvalid = 1'b1;
            m_arready = 1'b1;
            #1;
            check(s_arready && s_awready && m_arvalid,
                  "parallel memory AR/AW were not independently accepted");
            step();
            s_arvalid = 1'b0;
            s_awvalid = 1'b0;
            m_arready = 1'b0;

            s_wdata = 32'hfeed_cafe;
            s_wstrb = 4'hf;
            s_wlast = 1'b1;
            s_wvalid = 1'b1;
            m_awready = 1'b1;
            m_wready = 1'b1;
            m_rdata = 32'h1357_9bdf;
            m_rresp = 2'b00;
            m_rlast = 1'b1;
            m_rvalid = 1'b1;
            s_rready = 1'b1;
            #1;
            check(m_awvalid && m_wvalid && s_wready,
                  "parallel memory write channels were not forwarded");
            check(s_rvalid && s_rdata == 32'h1357_9bdf && s_rlast,
                  "parallel memory read response was not forwarded");
            step();
            s_wvalid = 1'b0;
            m_awready = 1'b0;
            m_wready = 1'b0;
            m_rvalid = 1'b0;
            m_rlast = 1'b0;
            s_rready = 1'b0;

            m_bresp = 2'b00;
            m_bvalid = 1'b1;
            s_bready = 1'b1;
            #1;
            check(s_bvalid && m_bready,
                  "parallel memory write response was not forwarded");
            step();
            m_bvalid = 1'b0;
            s_bready = 1'b0;
        end
    endtask

    task automatic send_uart_byte(input [7:0] value);
        integer bit_index;
        begin
            rx = 1'b0;
            repeat (4) step();
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                rx = value[bit_index];
                repeat (4) step();
            end
            rx = 1'b1;
            repeat (8) step();
        end
    endtask

    initial begin
        integer cycles;
        cycles = 0;
        forever begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > 1000) $fatal(1, "Stage 3 test timed out");
        end
    end

    initial begin
        reg [31:0] value;
        reg [31:0] expected_value;
        integer reads_before;
        integer writes_before;
        integer address_offset;
        integer strobe_value;

        repeat (3) step();
        rst = 1'b0;
        step();

        // Unsupported MMIO bursts are consumed with a correctly shaped
        // DECERR response and must never touch destructive device ports.
        rejected_mmio_read_burst(32'hffff_3000);
        rejected_mmio_write_burst(32'hffff_1000);

        reads_before = mmio_read_count;
        s_arsize = 3'd1;
        mmio_read(32'hffff_3000, 2'b11, value);
        check(mmio_read_count == reads_before,
              "unsupported MMIO ARSIZE touched the peripheral");
        s_arsize = 3'd2;
        s_arburst = 2'b00;
        mmio_read(32'hffff_3000, 2'b11, value);
        check(mmio_read_count == reads_before,
              "unsupported MMIO ARBURST touched the peripheral");
        s_arburst = 2'b01;

        writes_before = mmio_write_count;
        s_awsize = 3'd1;
        mmio_write(32'hffff_1000, 32'hffff_ffff, 4'hf, 2'b11);
        check(mmio_write_count == writes_before && led == 16'h0,
              "unsupported MMIO AWSIZE touched the peripheral");
        s_awsize = 3'd2;
        s_awburst = 2'b00;
        mmio_write(32'hffff_1000, 32'hffff_ffff, 4'hf, 2'b11);
        check(mmio_write_count == writes_before && led == 16'h0,
              "unsupported MMIO AWBURST touched the peripheral");
        s_awburst = 2'b01;

        reset_inflight_paths();
        parallel_memory_read_write();

        // Main-memory reads must bypass MMIO and preserve AXI burst metadata.
        reads_before = mmio_read_count;
        s_araddr = 32'h0000_0040;
        s_arlen = 8'd1;
        s_arvalid = 1'b1;
        #1;
        check(m_arvalid && !s_arready,
              "memory AR request did not reach the memory port");
        check(m_araddr == 32'h0000_0040 && m_arlen == 8'd1 &&
              m_arsize == 3'd2 && m_arburst == 2'b01,
              "memory AR metadata changed in the interconnect");
        m_arready = 1'b1;
        step();
        s_arvalid = 1'b0;
        m_arready = 1'b0;
        m_rdata = 32'h1122_3344;
        m_rvalid = 1'b1;
        m_rlast = 1'b0;
        s_rready = 1'b1;
        #1;
        check(s_rvalid && s_rdata == 32'h1122_3344 && m_rready,
              "first memory read beat was not forwarded");
        step();
        m_rdata = 32'h5566_7788;
        m_rlast = 1'b1;
        #1;
        check(s_rvalid && s_rdata == 32'h5566_7788 && s_rlast,
              "last memory read beat was not forwarded");
        step();
        m_rvalid = 1'b0;
        m_rlast = 1'b0;
        s_rready = 1'b0;
        check(mmio_read_count == reads_before,
              "memory read incorrectly generated an MMIO request");

        // Main-memory writes retain independent AW/W handshakes.
        writes_before = mmio_write_count;
        s_awaddr = 32'h0000_0104;
        s_awvalid = 1'b1;
        s_wdata = 32'ha5a5_5a5a;
        s_wstrb = 4'b0101;
        s_wvalid = 1'b1;
        #1;
        check(s_awready && !s_wready,
              "memory write address was not captured first");
        step();
        s_awvalid = 1'b0;
        m_wready = 1'b1;
        #1;
        check(m_awvalid && m_wvalid && s_wready,
              "memory AW/W requests were not exposed independently");
        check(m_awaddr == 32'h0000_0104 && m_wdata == 32'ha5a5_5a5a &&
              m_wstrb == 4'b0101 && m_wlast,
              "memory write payload changed in the interconnect");
        step();
        s_wvalid = 1'b0;
        m_wready = 1'b0;
        repeat (2) begin
            step();
            check(m_awvalid, "memory AWVALID dropped under backpressure");
        end
        m_awready = 1'b1;
        step();
        m_awready = 1'b0;
        m_bvalid = 1'b1;
        s_bready = 1'b1;
        #1;
        check(s_bvalid && m_bready, "memory B response was not forwarded");
        step();
        m_bvalid = 1'b0;
        s_bready = 1'b0;
        check(mmio_write_count == writes_before,
              "memory write incorrectly generated an MMIO request");

        mmio_read(32'hffff_0000, 2'b00, value);
        check(value == 32'h0000_a55a, "switch register read mismatch");

        mmio_write(32'hffff_1000, 32'h0000_0078, 4'b0001, 2'b00);
        mmio_write(32'hffff_1001, 32'h0000_5600, 4'b0010, 2'b00);
        check(led == 16'h5678,
              "LED CPU-shaped byte address/strobes were not honored");
        mmio_write(32'hffff_1000, 32'h0000_beef, 4'b1111, 2'b00);
        check(led == 16'hbeef, "LED register write mismatch");

        mmio_write(32'hffff_2000, 32'h1234_abcd, 4'b1111, 2'b00);
        mmio_read(32'hffff_2000, 2'b00, value);
        check(value == 32'h1234_abcd, "seven-segment register readback mismatch");
        check(dig_en == 8'b0000_0001 && dig_seg == 8'b0111_1010,
              "EGO1 active-high seven-segment scan output mismatch");

        // Exhaustively classify all address-low-bit/strobe combinations that
        // MREQ can (or cannot) produce for byte/halfword/word stores.
        for (address_offset = 0; address_offset < 4;
             address_offset = address_offset + 1) begin
            for (strobe_value = 0; strobe_value < 16;
                 strobe_value = strobe_value + 1) begin
                mmio_write(32'hffff_2000, 32'h1122_3344, 4'hf, 2'b00);
                if (cpu_strobe_is_valid(address_offset[1:0],
                                        strobe_value[3:0])) begin
                    expected_value = merge_bytes(32'h1122_3344,
                                                 32'ha5b6_c7d8,
                                                 strobe_value[3:0]);
                    mmio_write(32'hffff_2000 + address_offset,
                               32'ha5b6_c7d8, strobe_value[3:0], 2'b00);
                end else begin
                    expected_value = 32'h1122_3344;
                    mmio_write(32'hffff_2000 + address_offset,
                               32'ha5b6_c7d8, strobe_value[3:0], 2'b11);
                end
                mmio_read(32'hffff_2000, 2'b00, value);
                check(value == expected_value,
                      "MMIO subword address/strobe matrix mismatch");
            end
        end

        mmio_read(32'hffff_4000, 2'b00, value);
        check(value != 32'h0, "timer did not advance after reset");
        mmio_read(32'hffff_4008, 2'b00, value);
        check(value == 32'h0, "timer high word advanced unexpectedly in test");

        mmio_read(32'hffff_3008, 2'b00, value);
        check(value[3:0] == 4'b0100,
              "UART reset status must report TX empty and RX empty");
        mmio_write(32'hffff_300c, 32'h0000_0003, 4'b0001, 2'b00);
        mmio_write(32'hffff_3004, 32'h0000_0041, 4'b0001, 2'b00);
        check(tx == 1'b0, "UART did not emit a start bit");
        repeat (4) step();
        check(tx == 1'b1, "UART transmitted the wrong first data bit");

        // Wait until the current TX frame is done, then inject one RX frame.
        repeat (40) step();
        send_uart_byte(8'h5a);
        mmio_read(32'hffff_3008, 2'b00, value);
        check(value[0], "UART RX status did not report buffered data");
        mmio_read(32'hffff_3000, 2'b00, value);
        check(value[7:0] == 8'h5a, "UART RX FIFO returned the wrong byte");
        mmio_read(32'hffff_3008, 2'b00, value);
        check(!value[0], "UART RX FIFO read did not pop the byte");

        mmio_read(32'hffff_5000, 2'b11, value);
        mmio_write(32'hffff_0000, 32'h1, 4'hf, 2'b11);

        $display("soc_stage3_tb: PASS");
        $finish;
    end

endmodule
