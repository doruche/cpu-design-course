`timescale 1ns / 1ps

`include "defines.vh"

module miniRV_SoC(
    input  wire         fpga_clk,
    input  wire         fpga_rst,   // Low Active on EGO1; high active in Trace
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [ 7:0]  dig_en,
    output wire [ 7:0]  dig_seg,    // {CA, CB, ..., CG, DP}
    output wire [ 7:0]  dig_seg1,
    input  wire         rx,
    output wire         tx
);

`ifdef SIMULATION_CLOCK
    wire sys_clk = fpga_clk;
    wire sys_rst = fpga_rst;
`else
    wire pll_clk1;
    wire pll_lock;
    wire sys_clk = pll_clk1;
    wire async_sys_rst = !fpga_rst | !pll_lock;

    // Assert reset immediately when the active-low board reset is pressed or
    // Clock Wizard lock is lost. Release is delayed for two complete product
    // clock edges so every 50 MHz consumer leaves reset in one clock domain.
    (* ASYNC_REG = "TRUE" *) reg [1:0] sys_rst_pipe;
    always @(posedge sys_clk or posedge async_sys_rst) begin
        if (async_sys_rst) begin
            sys_rst_pipe <= 2'b11;
        end else begin
            sys_rst_pipe <= {sys_rst_pipe[0], 1'b0};
        end
    end
    wire sys_rst = sys_rst_pipe[1];

    // EGO1 switches are asynchronous to the product clock. Synchronize each
    // stable level before exposing the bank through the MMIO register.
    (* ASYNC_REG = "TRUE" *) reg [15:0] sw_meta;
    (* ASYNC_REG = "TRUE" *) reg [15:0] sw_sync;
    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            sw_meta <= 16'h0;
            sw_sync <= 16'h0;
        end else begin
            sw_meta <= sw;
            sw_sync <= sw_meta;
        end
    end
    wire [15:0] peripheral_sw = sw_sync;

    clk_wiz_0 U_clkgen (
        .clk_in1    (fpga_clk),
        .locked     (pll_lock),
        .clk_out1   (pll_clk1)
    );
`endif

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

    cpu_top U_cpu (
        .cpu_clk        (sys_clk),
        .cpu_rst        (sys_rst),
        .m_axi_awaddr   (cpu_awaddr),
        .m_axi_awlen    (cpu_awlen),
        .m_axi_awsize   (cpu_awsize),
        .m_axi_awburst  (cpu_awburst),
        .m_axi_awvalid  (cpu_awvalid),
        .m_axi_awready  (cpu_awready),
        .m_axi_wdata    (cpu_wdata),
        .m_axi_wstrb    (cpu_wstrb),
        .m_axi_wlast    (cpu_wlast),
        .m_axi_wvalid   (cpu_wvalid),
        .m_axi_wready   (cpu_wready),
        .m_axi_bready   (cpu_bready),
        .m_axi_bresp    (cpu_bresp),
        .m_axi_bvalid   (cpu_bvalid),
        .m_axi_araddr   (cpu_araddr),
        .m_axi_arlen    (cpu_arlen),
        .m_axi_arsize   (cpu_arsize),
        .m_axi_arburst  (cpu_arburst),
        .m_axi_arvalid  (cpu_arvalid),
        .m_axi_arready  (cpu_arready),
        .m_axi_rready   (cpu_rready),
        .m_axi_rdata    (cpu_rdata),
        .m_axi_rresp    (cpu_rresp),
        .m_axi_rlast    (cpu_rlast),
        .m_axi_rvalid   (cpu_rvalid)
    );

// Canonical Vivado builds have physical clocking and always select the product
// fabric. Simulation configurations must name their topology explicitly.
`ifdef SOC_TOPOLOGY
`define MINI_RV_SOC_TOPOLOGY
`else
`ifndef SIMULATION_CLOCK
`define MINI_RV_SOC_TOPOLOGY
`endif
`endif

`ifdef BASIC_TRACE

    // The fixed Trace top-level exposes the board ports but does not model the
    // physical peripherals. Keep deterministic inactive outputs in either
    // Trace memory profile.
    assign led = 16'h0;
    assign dig_en = 8'h0;
    assign dig_seg = 8'h0;
    assign dig_seg1 = 8'h0;
    assign tx = 1'b1;

    /* verilator lint_off UNUSEDSIGNAL */
    wire unused_trace_inputs = &{1'b0, sw, rx};
    /* verilator lint_on UNUSEDSIGNAL */

    // The historical Basic Trace profile uses Inst_ROM/Data_RAM inside
    // cpu_top and deliberately leaves the AXI path inactive.
    assign cpu_awready = 1'b0;
    assign cpu_wready = 1'b0;
    assign cpu_bresp = 2'b00;
    assign cpu_bvalid = 1'b0;
    assign cpu_arready = 1'b0;
    assign cpu_rdata = 32'h0;
    assign cpu_rresp = 2'b00;
    assign cpu_rlast = 1'b0;
    assign cpu_rvalid = 1'b0;

    /* verilator lint_off UNUSEDSIGNAL */
    wire unused_basic_axi_outputs = &{1'b0, cpu_awaddr, cpu_awlen,
                                      cpu_awsize, cpu_awburst, cpu_awvalid,
                                      cpu_wdata, cpu_wstrb, cpu_wlast,
                                      cpu_wvalid, cpu_bready, cpu_araddr,
                                      cpu_arlen, cpu_arsize, cpu_arburst,
                                      cpu_arvalid, cpu_rready};
    /* verilator lint_on UNUSEDSIGNAL */

`elsif AXI_DIRECT_TOPOLOGY

    // AXI-direct simulation deliberately bypasses the product fabric so Cache
    // and AXI-master behavior can be diagnosed independently of MMIO routing.
    assign led = 16'h0;
    assign dig_en = 8'h0;
    assign dig_seg = 8'h0;
    assign dig_seg1 = 8'h0;
    assign tx = 1'b1;

    /* verilator lint_off UNUSEDSIGNAL */
    wire unused_direct_inputs = &{1'b0, sw, rx};
    /* verilator lint_on UNUSEDSIGNAL */

    // The pinned Trace framework supplies this behavioral AXI RAM. Keep the
    // simulation model outside canonical product RTL.
    wire [3:0] unused_bram_bid;
    wire [3:0] unused_bram_rid;

    bram_axi U_bram (
        .s_aclk         (sys_clk),
        .s_aresetn      (!sys_rst),
        .s_axi_awid     (4'h6),
        .s_axi_awaddr   (cpu_awaddr),
        .s_axi_awlen    (cpu_awlen),
        .s_axi_awsize   (cpu_awsize),
        .s_axi_awburst  (cpu_awburst),
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'h0),
        .s_axi_awprot   (3'h0),
        .s_axi_awvalid  (cpu_awvalid),
        .s_axi_awready  (cpu_awready),
        .s_axi_wdata    (cpu_wdata),
        .s_axi_wstrb    (cpu_wstrb),
        .s_axi_wlast    (cpu_wlast),
        .s_axi_wvalid   (cpu_wvalid),
        .s_axi_wready   (cpu_wready),
        .s_axi_bid      (unused_bram_bid),
        .s_axi_bresp    (cpu_bresp),
        .s_axi_bvalid   (cpu_bvalid),
        .s_axi_bready   (cpu_bready),
        .s_axi_arid     (4'h6),
        .s_axi_araddr   (cpu_araddr),
        .s_axi_arlen    (cpu_arlen),
        .s_axi_arsize   (cpu_arsize),
        .s_axi_arburst  (cpu_arburst),
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'h0),
        .s_axi_arprot   (3'h0),
        .s_axi_arvalid  (cpu_arvalid),
        .s_axi_arready  (cpu_arready),
        .s_axi_rid      (unused_bram_rid),
        .s_axi_rdata    (cpu_rdata),
        .s_axi_rresp    (cpu_rresp),
        .s_axi_rlast    (cpu_rlast),
        .s_axi_rvalid   (cpu_rvalid),
        .s_axi_rready   (cpu_rready)
    );

`elsif MINI_RV_SOC_TOPOLOGY

    // The product topology is the default for the canonical Vivado build and
    // is selected explicitly by SOC_TOPOLOGY in repository simulations. The
    // same interconnect/peripheral owners are therefore used in both cases.

`ifdef SIMULATION_CLOCK
    wire [15:0] peripheral_sw = sw;
`endif

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

    soc_interconnect U_interconnect (
        .aclk           (sys_clk),
        .areset         (sys_rst),
        .s_axi_awaddr   (cpu_awaddr),
        .s_axi_awlen    (cpu_awlen),
        .s_axi_awsize   (cpu_awsize),
        .s_axi_awburst  (cpu_awburst),
        .s_axi_awvalid  (cpu_awvalid),
        .s_axi_awready  (cpu_awready),
        .s_axi_wdata    (cpu_wdata),
        .s_axi_wstrb    (cpu_wstrb),
        .s_axi_wlast    (cpu_wlast),
        .s_axi_wvalid   (cpu_wvalid),
        .s_axi_wready   (cpu_wready),
        .s_axi_bresp    (cpu_bresp),
        .s_axi_bvalid   (cpu_bvalid),
        .s_axi_bready   (cpu_bready),
        .s_axi_araddr   (cpu_araddr),
        .s_axi_arlen    (cpu_arlen),
        .s_axi_arsize   (cpu_arsize),
        .s_axi_arburst  (cpu_arburst),
        .s_axi_arvalid  (cpu_arvalid),
        .s_axi_arready  (cpu_arready),
        .s_axi_rdata    (cpu_rdata),
        .s_axi_rresp    (cpu_rresp),
        .s_axi_rlast    (cpu_rlast),
        .s_axi_rvalid   (cpu_rvalid),
        .s_axi_rready   (cpu_rready),
        .m_axi_awaddr   (mem_awaddr),
        .m_axi_awlen    (mem_awlen),
        .m_axi_awsize   (mem_awsize),
        .m_axi_awburst  (mem_awburst),
        .m_axi_awvalid  (mem_awvalid),
        .m_axi_awready  (mem_awready),
        .m_axi_wdata    (mem_wdata),
        .m_axi_wstrb    (mem_wstrb),
        .m_axi_wlast    (mem_wlast),
        .m_axi_wvalid   (mem_wvalid),
        .m_axi_wready   (mem_wready),
        .m_axi_bresp    (mem_bresp),
        .m_axi_bvalid   (mem_bvalid),
        .m_axi_bready   (mem_bready),
        .m_axi_araddr   (mem_araddr),
        .m_axi_arlen    (mem_arlen),
        .m_axi_arsize   (mem_arsize),
        .m_axi_arburst  (mem_arburst),
        .m_axi_arvalid  (mem_arvalid),
        .m_axi_arready  (mem_arready),
        .m_axi_rdata    (mem_rdata),
        .m_axi_rresp    (mem_rresp),
        .m_axi_rlast    (mem_rlast),
        .m_axi_rvalid   (mem_rvalid),
        .m_axi_rready   (mem_rready),
        .mmio_rd_en     (mmio_rd_en),
        .mmio_rd_addr   (mmio_rd_addr),
        .mmio_rd_data   (mmio_rd_data),
        .mmio_rd_error  (mmio_rd_error),
        .mmio_wr_en     (mmio_wr_en),
        .mmio_wr_addr   (mmio_wr_addr),
        .mmio_wr_data   (mmio_wr_data),
        .mmio_wr_strb   (mmio_wr_strb),
        .mmio_wr_error  (mmio_wr_error)
    );

    soc_peripherals U_peripherals (
        .clk            (sys_clk),
        .rst            (sys_rst),
        .mmio_rd_en     (mmio_rd_en),
        .mmio_rd_addr   (mmio_rd_addr),
        .mmio_rd_data   (mmio_rd_data),
        .mmio_rd_error  (mmio_rd_error),
        .mmio_wr_en     (mmio_wr_en),
        .mmio_wr_addr   (mmio_wr_addr),
        .mmio_wr_data   (mmio_wr_data),
        .mmio_wr_strb   (mmio_wr_strb),
        .mmio_wr_error  (mmio_wr_error),
        .sw             (peripheral_sw),
        .led            (led),
        .dig_en         (dig_en),
        .dig_seg        (dig_seg),
        .rx             (rx),
        .tx             (tx)
    );

    // EGO1 has two segment buses for its two groups of four digits. The
    // course contract permits both groups to share the same segment pattern.
    assign dig_seg1 = dig_seg;

    // Vivado supplies the canonical Block Memory Generator AXI4 IP. Optional
    // AXI lock/cache/protection ports are disabled in that IP configuration.
    wire [3:0] unused_bram_bid;
    wire [3:0] unused_bram_rid;

    bram_axi U_bram (
        .s_aclk         (sys_clk),
        .s_aresetn      (!sys_rst),
        .s_axi_awid     (4'h6),
        .s_axi_awaddr   (mem_awaddr),
        .s_axi_awlen    (mem_awlen),
        .s_axi_awsize   (mem_awsize),
        .s_axi_awburst  (mem_awburst),
`ifdef BEHAVIORAL_MEMORY
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'h0),
        .s_axi_awprot   (3'h0),
`endif
        .s_axi_awready  (mem_awready),
        .s_axi_awvalid  (mem_awvalid),
        .s_axi_wdata    (mem_wdata),
        .s_axi_wstrb    (mem_wstrb),
        .s_axi_wvalid   (mem_wvalid),
        .s_axi_wlast    (mem_wlast),
        .s_axi_wready   (mem_wready),
        .s_axi_bid      (unused_bram_bid),
        .s_axi_bready   (mem_bready),
        .s_axi_bresp    (mem_bresp),
        .s_axi_bvalid   (mem_bvalid),
        .s_axi_arid     (4'h6),
        .s_axi_araddr   (mem_araddr),
        .s_axi_arlen    (mem_arlen),
        .s_axi_arsize   (mem_arsize),
        .s_axi_arburst  (mem_arburst),
`ifdef BEHAVIORAL_MEMORY
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'h0),
        .s_axi_arprot   (3'h0),
`endif
        .s_axi_arready  (mem_arready),
        .s_axi_arvalid  (mem_arvalid),
        .s_axi_rid      (unused_bram_rid),
        .s_axi_rdata    (mem_rdata),
        .s_axi_rvalid   (mem_rvalid),
        .s_axi_rlast    (mem_rlast),
        .s_axi_rready   (mem_rready),
        .s_axi_rresp    (mem_rresp)
    );

`endif

`ifdef MINI_RV_SOC_TOPOLOGY
`undef MINI_RV_SOC_TOPOLOGY
`endif

endmodule
