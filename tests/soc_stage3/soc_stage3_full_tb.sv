`timescale 1ns / 1ps

`include "defines.vh"

// Board-product data path, without cpu_core: the CPU-side requests below pass
// through the enabled DCache, axi_master, SoC interconnect, and peripherals.
module soc_stage3_full_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    reg  [ 3:0] data_ren = 4'h0;
    reg  [31:0] data_addr = 32'h0;
    wire        data_valid;
    wire [31:0] data_rdata;
    reg  [ 3:0] data_wen = 4'h0;
    reg  [31:0] data_wdata = 32'h0;
    wire        data_wresp;

    wire        dc_dev_wrdy;
    wire [ 3:0] dc_cpu_wen;
    wire [31:0] dc_cpu_waddr;
    wire [31:0] dc_cpu_wdata;
    wire        dc_dev_rrdy;
    wire [ 3:0] dc_cpu_ren;
    wire [31:0] dc_cpu_raddr;
    wire        dc_dev_rvalid;
    wire [127:0] dc_dev_rdata;

    wire [31:0] cpu_awaddr;
    wire [ 7:0] cpu_awlen;
    wire [ 2:0] cpu_awsize;
    wire [ 1:0] cpu_awburst;
    wire        cpu_awvalid;
    wire        cpu_awready;
    wire [31:0] cpu_wdata;
    wire [ 3:0] cpu_wstrb;
    wire        cpu_wlast;
    wire        cpu_wvalid;
    wire        cpu_wready;
    wire        cpu_bready;
    wire [ 1:0] cpu_bresp;
    wire        cpu_bvalid;
    wire [31:0] cpu_araddr;
    wire [ 7:0] cpu_arlen;
    wire [ 2:0] cpu_arsize;
    wire [ 1:0] cpu_arburst;
    wire        cpu_arvalid;
    wire        cpu_arready;
    wire        cpu_rready;
    wire [31:0] cpu_rdata;
    wire [ 1:0] cpu_rresp;
    wire        cpu_rlast;
    wire        cpu_rvalid;

    wire [31:0] mem_awaddr;
    wire [ 7:0] mem_awlen;
    wire [ 2:0] mem_awsize;
    wire [ 1:0] mem_awburst;
    wire        mem_awvalid;
    wire        mem_awready;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire        mem_wlast;
    wire        mem_wvalid;
    wire        mem_wready;
    wire [ 1:0] mem_bresp;
    wire        mem_bvalid;
    wire        mem_bready;
    wire [31:0] mem_araddr;
    wire [ 7:0] mem_arlen;
    wire [ 2:0] mem_arsize;
    wire [ 1:0] mem_arburst;
    wire        mem_arvalid;
    wire        mem_arready;
    wire [31:0] mem_rdata;
    wire [ 1:0] mem_rresp;
    wire        mem_rlast;
    wire        mem_rvalid;
    wire        mem_rready;

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

    integer memory_read_count = 0;
    integer mmio_read_count = 0;
    integer mmio_write_count = 0;

    DCache U_dcache (
        .cpu_clk(clk), .cpu_rst(rst),
        .data_ren(data_ren), .data_addr(data_addr),
        .data_valid(data_valid), .data_rdata(data_rdata),
        .data_wen(data_wen), .data_wdata(data_wdata),
        .data_wresp(data_wresp),
        .dev_wrdy(dc_dev_wrdy), .cpu_wen(dc_cpu_wen),
        .cpu_waddr(dc_cpu_waddr), .cpu_wdata(dc_cpu_wdata),
        .dev_rrdy(dc_dev_rrdy), .cpu_ren(dc_cpu_ren),
        .cpu_raddr(dc_cpu_raddr), .dev_rvalid(dc_dev_rvalid),
        .dev_rdata(dc_dev_rdata)
    );

    axi_master U_axi_master (
        .aclk(clk), .areset(rst),
        .ic_dev_rrdy(), .ic_cpu_ren(4'h0), .ic_cpu_raddr(32'h0),
        .ic_dev_rvalid(), .ic_dev_rdata(),
        .dc_dev_wrdy(dc_dev_wrdy), .dc_cpu_wen(dc_cpu_wen),
        .dc_cpu_waddr(dc_cpu_waddr), .dc_cpu_wdata(dc_cpu_wdata),
        .dc_dev_rrdy(dc_dev_rrdy), .dc_cpu_ren(dc_cpu_ren),
        .dc_cpu_raddr(dc_cpu_raddr), .dc_dev_rvalid(dc_dev_rvalid),
        .dc_dev_rdata(dc_dev_rdata),
        .m_axi_awaddr(cpu_awaddr), .m_axi_awlen(cpu_awlen),
        .m_axi_awsize(cpu_awsize), .m_axi_awburst(cpu_awburst),
        .m_axi_awvalid(cpu_awvalid), .m_axi_awready(cpu_awready),
        .m_axi_wdata(cpu_wdata), .m_axi_wstrb(cpu_wstrb),
        .m_axi_wlast(cpu_wlast), .m_axi_wvalid(cpu_wvalid),
        .m_axi_wready(cpu_wready), .m_axi_bready(cpu_bready),
        .m_axi_bresp(cpu_bresp), .m_axi_bvalid(cpu_bvalid),
        .m_axi_araddr(cpu_araddr), .m_axi_arlen(cpu_arlen),
        .m_axi_arsize(cpu_arsize), .m_axi_arburst(cpu_arburst),
        .m_axi_arvalid(cpu_arvalid), .m_axi_arready(cpu_arready),
        .m_axi_rready(cpu_rready), .m_axi_rdata(cpu_rdata),
        .m_axi_rresp(cpu_rresp), .m_axi_rlast(cpu_rlast),
        .m_axi_rvalid(cpu_rvalid)
    );

    soc_interconnect U_interconnect (
        .aclk(clk), .areset(rst),
        .s_axi_awaddr(cpu_awaddr), .s_axi_awlen(cpu_awlen),
        .s_axi_awsize(cpu_awsize), .s_axi_awburst(cpu_awburst),
        .s_axi_awvalid(cpu_awvalid), .s_axi_awready(cpu_awready),
        .s_axi_wdata(cpu_wdata), .s_axi_wstrb(cpu_wstrb),
        .s_axi_wlast(cpu_wlast), .s_axi_wvalid(cpu_wvalid),
        .s_axi_wready(cpu_wready), .s_axi_bresp(cpu_bresp),
        .s_axi_bvalid(cpu_bvalid), .s_axi_bready(cpu_bready),
        .s_axi_araddr(cpu_araddr), .s_axi_arlen(cpu_arlen),
        .s_axi_arsize(cpu_arsize), .s_axi_arburst(cpu_arburst),
        .s_axi_arvalid(cpu_arvalid), .s_axi_arready(cpu_arready),
        .s_axi_rdata(cpu_rdata), .s_axi_rresp(cpu_rresp),
        .s_axi_rlast(cpu_rlast), .s_axi_rvalid(cpu_rvalid),
        .s_axi_rready(cpu_rready),
        .m_axi_awaddr(mem_awaddr), .m_axi_awlen(mem_awlen),
        .m_axi_awsize(mem_awsize), .m_axi_awburst(mem_awburst),
        .m_axi_awvalid(mem_awvalid), .m_axi_awready(mem_awready),
        .m_axi_wdata(mem_wdata), .m_axi_wstrb(mem_wstrb),
        .m_axi_wlast(mem_wlast), .m_axi_wvalid(mem_wvalid),
        .m_axi_wready(mem_wready), .m_axi_bresp(mem_bresp),
        .m_axi_bvalid(mem_bvalid), .m_axi_bready(mem_bready),
        .m_axi_araddr(mem_araddr), .m_axi_arlen(mem_arlen),
        .m_axi_arsize(mem_arsize), .m_axi_arburst(mem_arburst),
        .m_axi_arvalid(mem_arvalid), .m_axi_arready(mem_arready),
        .m_axi_rdata(mem_rdata), .m_axi_rresp(mem_rresp),
        .m_axi_rlast(mem_rlast), .m_axi_rvalid(mem_rvalid),
        .m_axi_rready(mem_rready),
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

    wire [3:0] unused_bid;
    wire [3:0] unused_rid;
    bram_axi #(.DATA_DEPTH(256)) U_bram (
        .s_aclk(clk), .s_aresetn(!rst),
        .s_axi_awid(4'h6), .s_axi_awaddr(mem_awaddr),
        .s_axi_awlen(mem_awlen), .s_axi_awsize(mem_awsize),
        .s_axi_awburst(mem_awburst), .s_axi_awlock(1'b0),
        .s_axi_awcache(4'h0), .s_axi_awprot(3'h0),
        .s_axi_awvalid(mem_awvalid), .s_axi_awready(mem_awready),
        .s_axi_wdata(mem_wdata), .s_axi_wstrb(mem_wstrb),
        .s_axi_wlast(mem_wlast), .s_axi_wvalid(mem_wvalid),
        .s_axi_wready(mem_wready), .s_axi_bid(unused_bid),
        .s_axi_bresp(mem_bresp), .s_axi_bvalid(mem_bvalid),
        .s_axi_bready(mem_bready), .s_axi_arid(4'h6),
        .s_axi_araddr(mem_araddr), .s_axi_arlen(mem_arlen),
        .s_axi_arsize(mem_arsize), .s_axi_arburst(mem_arburst),
        .s_axi_arlock(1'b0), .s_axi_arcache(4'h0),
        .s_axi_arprot(3'h0), .s_axi_arvalid(mem_arvalid),
        .s_axi_arready(mem_arready), .s_axi_rid(unused_rid),
        .s_axi_rdata(mem_rdata), .s_axi_rresp(mem_rresp),
        .s_axi_rlast(mem_rlast), .s_axi_rvalid(mem_rvalid),
        .s_axi_rready(mem_rready)
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

    task automatic cpu_read(
        input [31:0] address,
        output [31:0] value
    );
        integer timeout;
        begin
            data_addr = address;
            data_ren = 4'hf;
            step();
            data_ren = 4'h0;
            timeout = 0;
            while (!data_valid && timeout < 100) begin
                step();
                timeout = timeout + 1;
            end
            check(data_valid, "DCache read timed out");
            value = data_rdata;
            step();
        end
    endtask

    task automatic cpu_write(
        input [31:0] address,
        input [ 3:0] strobes,
        input [31:0] value
    );
        integer timeout;
        begin
            data_addr = address;
            data_wen = strobes;
            data_wdata = value;
            step();
            data_wen = 4'h0;
            timeout = 0;
            while (!data_wresp && timeout < 100) begin
                step();
                timeout = timeout + 1;
            end
            check(data_wresp, "DCache write timed out");
            step();
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

    always @(posedge clk) begin
        if (mem_arvalid && mem_arready) begin
            memory_read_count <= memory_read_count + 1;
        end
        if (mmio_rd_en) mmio_read_count <= mmio_read_count + 1;
        if (mmio_wr_en) mmio_write_count <= mmio_write_count + 1;

        if (cpu_arvalid && cpu_arready &&
            cpu_araddr[31:16] == 16'hffff) begin
            check(cpu_arlen == 0, "legal MMIO read must be a single AXI beat");
            check(cpu_arsize == 3'd2 && cpu_arburst == 2'b01,
                  "legal MMIO read metadata mismatch");
        end
        if (cpu_rvalid && cpu_rready &&
            U_interconnect.read_state == 2'd2) begin
            check(cpu_rresp == 2'b00,
                  "legal product MMIO read returned an AXI error");
        end
        if (cpu_awvalid && cpu_awready &&
            cpu_awaddr[31:16] == 16'hffff) begin
            check(cpu_awlen == 0 && cpu_awsize == 3'd2 &&
                  cpu_awburst == 2'b01,
                  "legal MMIO write metadata mismatch");
        end
        if (cpu_bvalid && cpu_bready && U_interconnect.write_is_mmio) begin
            check(cpu_bresp == 2'b00,
                  "legal product MMIO write returned an AXI error");
        end
    end

    initial begin
        integer cycles;
        cycles = 0;
        forever begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles > 3000) $fatal(1, "full Stage 3 chain timed out");
        end
    end

    initial begin
        reg [31:0] value;
        integer reads_before;

        repeat (3) step();
        rst = 1'b0;
        U_bram.mem[16] = 32'h1111_0000;
        U_bram.mem[17] = 32'h2222_0001;
        U_bram.mem[18] = 32'h3333_0002;
        U_bram.mem[19] = 32'h4444_0003;
        step();

        // A memory miss refills exactly one four-beat line; the second access
        // is a cache hit and must not reach the AXI memory again.
        cpu_read(32'h0000_0044, value);
        check(value == 32'h2222_0001, "memory refill returned the wrong word");
        check(memory_read_count == 1, "memory miss was not one AXI request");
        cpu_read(32'h0000_0048, value);
        check(value == 32'h3333_0002, "cache hit returned the wrong word");
        check(memory_read_count == 1, "cache hit issued another memory read");

        // MMIO reads are uncached: both accesses traverse the complete chain.
        reads_before = mmio_read_count;
        cpu_read(32'hffff_0000, value);
        check(value == 32'h0000_a55a, "switch read mismatch");
        sw = 16'h5aa5;
        cpu_read(32'hffff_0000, value);
        check(value == 32'h0000_5aa5, "second switch read was cached");
        check(mmio_read_count == reads_before + 2,
              "MMIO reads did not bypass DCache allocation");

        cpu_write(32'hffff_1000, 4'hf, 32'h0000_1234);
        check(led == 16'h1234, "LED word write failed through product chain");
        cpu_write(32'hffff_1001, 4'b0010, 32'h0000_ab00);
        check(led == 16'hab34, "LED byte write did not use the CPU address lane");

        cpu_write(32'hffff_2000, 4'hf, 32'h89ab_cdef);
        cpu_read(32'hffff_2000, value);
        check(value == 32'h89ab_cdef, "seven-segment readback mismatch");

        cpu_read(32'hffff_3008, value);
        check(value[3:0] == 4'b0100, "UART reset status mismatch");
        cpu_write(32'hffff_3004, 4'hf, 32'h0000_0041);
        check(tx == 1'b0, "UART TX did not start through product chain");
        repeat (45) step();
        send_uart_byte(8'h5a);
        cpu_read(32'hffff_3008, value);
        check(value[0], "UART RX status did not report data");
        cpu_read(32'hffff_3000, value);
        check(value[7:0] == 8'h5a, "UART RX FIFO order/value mismatch");

        cpu_read(32'hffff_4000, value);
        check(value != 0, "timer low word did not advance");
        cpu_read(32'hffff_4008, value);
        check(value == 0, "timer high word advanced unexpectedly");

        check(mmio_write_count >= 3,
              "product writes did not reach the peripheral boundary");
        $display("soc_stage3_full_tb: PASS");
        $finish;
    end

endmodule
