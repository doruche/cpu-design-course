`timescale 1ns / 1ps

`include "defines.vh"

// Bridge the cache-side request protocol to one AXI4 master port. Reads are
// serialized because ICache and DCache share the AXI read channels; DCache
// reads win arbitration. A DCache write wins over either read when the bridge
// is idle. AXI write address and data handshakes are tracked independently.
module axi_master(
    input  wire         aclk,
    input  wire         areset,     // high active

    // ICache read interface
    output reg          ic_dev_rrdy,
    input  wire [ 3:0]  ic_cpu_ren,
    input  wire [31:0]  ic_cpu_raddr,
    output reg          ic_dev_rvalid,
    output reg  [127:0] ic_dev_rdata,

    // DCache write interface
    output reg          dc_dev_wrdy,
    input  wire [ 3:0]  dc_cpu_wen,
    input  wire [31:0]  dc_cpu_waddr,
    input  wire [31:0]  dc_cpu_wdata,

    // DCache read interface
    output reg          dc_dev_rrdy,
    input  wire [ 3:0]  dc_cpu_ren,
    input  wire [31:0]  dc_cpu_raddr,
    output reg          dc_dev_rvalid,
    output reg  [127:0] dc_dev_rdata,

    // AXI4 write address channel
    output reg  [31:0]  m_axi_awaddr,
    output reg  [ 7:0]  m_axi_awlen,
    output reg  [ 2:0]  m_axi_awsize,
    output reg  [ 1:0]  m_axi_awburst,
    output reg          m_axi_awvalid,
    input  wire         m_axi_awready,

    // AXI4 write data channel
    output reg  [31:0]  m_axi_wdata,
    output reg  [ 3:0]  m_axi_wstrb,
    output reg          m_axi_wlast,
    output reg          m_axi_wvalid,
    input  wire         m_axi_wready,

    // AXI4 write response channel
    output reg          m_axi_bready,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [ 1:0]  m_axi_bresp,
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire         m_axi_bvalid,

    // AXI4 read address channel
    output reg  [31:0]  m_axi_araddr,
    output reg  [ 7:0]  m_axi_arlen,
    output reg  [ 2:0]  m_axi_arsize,
    output reg  [ 1:0]  m_axi_arburst,
    output reg          m_axi_arvalid,
    input  wire         m_axi_arready,

    // AXI4 read data channel
    output reg          m_axi_rready,
    input  wire [31:0]  m_axi_rdata,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [ 1:0]  m_axi_rresp,
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid
);

    localparam READ_IDLE = 2'd0;
    localparam READ_ADDR = 2'd1;
    localparam READ_DATA = 2'd2;
    localparam READ_RESP = 2'd3;

    localparam WRITE_IDLE = 2'd0;
    localparam WRITE_SEND = 2'd1;
    localparam WRITE_RESP = 2'd2;

    localparam READ_SOURCE_ICACHE = 1'b0;
    localparam READ_SOURCE_DCACHE = 1'b1;

    reg [1:0] read_state;
    reg [1:0] read_next_state;
    reg [1:0] write_state;
    reg [1:0] write_next_state;

    reg        read_source;
    reg [31:0] read_addr;
    reg [ 7:0] read_len;
    reg [ 1:0] read_beat;
    reg [127:0] read_data;

    reg [31:0] write_addr;
    reg [31:0] write_data;
    reg [ 3:0] write_strobe;
    reg        write_addr_done;
    reg        write_data_done;

    wire bridge_idle = read_state == READ_IDLE && write_state == WRITE_IDLE;
    wire write_request = |dc_cpu_wen;
    wire dcache_read_request = |dc_cpu_ren;
    wire icache_read_request = |ic_cpu_ren;

    wire accept_write = bridge_idle && write_request;
    wire accept_dcache_read = bridge_idle && !write_request &&
                              dcache_read_request;
    wire accept_icache_read = bridge_idle && !write_request &&
                              !dcache_read_request && icache_read_request;

    wire write_addr_handshake = m_axi_awvalid && m_axi_awready;
    wire write_data_handshake = m_axi_wvalid && m_axi_wready;

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            read_state <= READ_IDLE;
            read_source <= READ_SOURCE_ICACHE;
            read_addr <= 32'h0;
            read_len <= 8'h0;
            read_beat <= 2'h0;
            read_data <= 128'h0;
        end else begin
            read_state <= read_next_state;

            if (accept_dcache_read) begin
                read_source <= READ_SOURCE_DCACHE;
                read_addr <= dc_cpu_raddr;
                read_len <= `DC_BLK_LEN - 1;
                read_beat <= 2'h0;
                read_data <= 128'h0;
            end else if (accept_icache_read) begin
                read_source <= READ_SOURCE_ICACHE;
                read_addr <= ic_cpu_raddr;
                read_len <= `IC_BLK_LEN - 1;
                read_beat <= 2'h0;
                read_data <= 128'h0;
            end else if (read_state == READ_DATA &&
                         m_axi_rvalid && m_axi_rready) begin
                case (read_beat)
                    2'd0: read_data[31:0]   <= m_axi_rdata;
                    2'd1: read_data[63:32]  <= m_axi_rdata;
                    2'd2: read_data[95:64]  <= m_axi_rdata;
                    2'd3: read_data[127:96] <= m_axi_rdata;
                    default: begin
                    end
                endcase
                read_beat <= read_beat + 1'b1;
            end
        end
    end

    always @(*) begin
        read_next_state = read_state;
        case (read_state)
            READ_IDLE: begin
                if (accept_dcache_read || accept_icache_read) begin
                    read_next_state = READ_ADDR;
                end
            end
            READ_ADDR: begin
                if (m_axi_arready) begin
                    read_next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                if (m_axi_rvalid && m_axi_rlast) begin
                    read_next_state = READ_RESP;
                end
            end
            READ_RESP: read_next_state = READ_IDLE;
            default: read_next_state = READ_IDLE;
        endcase
    end

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            write_state <= WRITE_IDLE;
            write_addr <= 32'h0;
            write_data <= 32'h0;
            write_strobe <= 4'h0;
            write_addr_done <= 1'b0;
            write_data_done <= 1'b0;
        end else begin
            write_state <= write_next_state;

            if (accept_write) begin
                write_addr <= dc_cpu_waddr;
                write_data <= dc_cpu_wdata;
                write_strobe <= dc_cpu_wen;
                write_addr_done <= 1'b0;
                write_data_done <= 1'b0;
            end else if (write_state == WRITE_SEND) begin
                if (write_addr_handshake) begin
                    write_addr_done <= 1'b1;
                end
                if (write_data_handshake) begin
                    write_data_done <= 1'b1;
                end
            end
        end
    end

    always @(*) begin
        write_next_state = write_state;
        case (write_state)
            WRITE_IDLE: begin
                if (accept_write) begin
                    write_next_state = WRITE_SEND;
                end
            end
            WRITE_SEND: begin
                if ((write_addr_done || write_addr_handshake) &&
                    (write_data_done || write_data_handshake)) begin
                    write_next_state = WRITE_RESP;
                end
            end
            WRITE_RESP: begin
                if (m_axi_bvalid) begin
                    write_next_state = WRITE_IDLE;
                end
            end
            default: write_next_state = WRITE_IDLE;
        endcase
    end

    always @(*) begin
        ic_dev_rrdy = bridge_idle && !write_request &&
                      !dcache_read_request;
        dc_dev_rrdy = bridge_idle && !write_request;
        dc_dev_wrdy = bridge_idle;

        ic_dev_rvalid = 1'b0;
        ic_dev_rdata = 128'h0;
        dc_dev_rvalid = 1'b0;
        dc_dev_rdata = 128'h0;

        m_axi_awaddr = write_addr;
        m_axi_awlen = 8'h0;
        m_axi_awsize = 3'd2;
        m_axi_awburst = 2'b01;
        m_axi_awvalid = write_state == WRITE_SEND && !write_addr_done;

        m_axi_wdata = write_data;
        m_axi_wstrb = write_strobe;
        m_axi_wlast = 1'b1;
        m_axi_wvalid = write_state == WRITE_SEND && !write_data_done;

        m_axi_bready = write_state == WRITE_RESP;

        m_axi_araddr = read_addr;
        m_axi_arlen = read_len;
        m_axi_arsize = 3'd2;
        m_axi_arburst = 2'b01;
        m_axi_arvalid = read_state == READ_ADDR;

        m_axi_rready = read_state == READ_DATA;

        if (read_state == READ_RESP) begin
            if (read_source == READ_SOURCE_DCACHE) begin
                dc_dev_rvalid = 1'b1;
                dc_dev_rdata = read_data;
            end else begin
                ic_dev_rvalid = 1'b1;
                ic_dev_rdata = read_data;
            end
        end
    end

endmodule
