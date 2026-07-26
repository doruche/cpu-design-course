`timescale 1ns / 1ps

// Route the CPU AXI master to either the shared block memory or the local
// memory-mapped I/O bus. The highest 64 KiB is the I/O window; all other
// addresses remain on the memory AXI port. The current CPU master serializes
// requests, while the read and write paths here remain independently legal.
module soc_interconnect(
    input  wire         aclk,
    input  wire         areset,

    // CPU-facing AXI4 slave port
    input  wire [31:0]  s_axi_awaddr,
    input  wire [ 7:0]  s_axi_awlen,
    input  wire [ 2:0]  s_axi_awsize,
    input  wire [ 1:0]  s_axi_awburst,
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [ 3:0]  s_axi_wstrb,
    input  wire         s_axi_wlast,
    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,
    output reg  [ 1:0]  s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [31:0]  s_axi_araddr,
    input  wire [ 7:0]  s_axi_arlen,
    input  wire [ 2:0]  s_axi_arsize,
    input  wire [ 1:0]  s_axi_arburst,
    input  wire         s_axi_arvalid,
    output reg          s_axi_arready,
    output reg  [31:0]  s_axi_rdata,
    output reg  [ 1:0]  s_axi_rresp,
    output reg          s_axi_rlast,
    output reg          s_axi_rvalid,
    input  wire         s_axi_rready,

    // Memory-facing AXI4 master port
    output reg  [31:0]  m_axi_awaddr,
    output reg  [ 7:0]  m_axi_awlen,
    output reg  [ 2:0]  m_axi_awsize,
    output reg  [ 1:0]  m_axi_awburst,
    output reg          m_axi_awvalid,
    input  wire         m_axi_awready,
    output reg  [31:0]  m_axi_wdata,
    output reg  [ 3:0]  m_axi_wstrb,
    output reg          m_axi_wlast,
    output reg          m_axi_wvalid,
    input  wire         m_axi_wready,
    input  wire [ 1:0]  m_axi_bresp,
    input  wire         m_axi_bvalid,
    output reg          m_axi_bready,
    output reg  [31:0]  m_axi_araddr,
    output reg  [ 7:0]  m_axi_arlen,
    output reg  [ 2:0]  m_axi_arsize,
    output reg  [ 1:0]  m_axi_arburst,
    output reg          m_axi_arvalid,
    input  wire         m_axi_arready,
    input  wire [31:0]  m_axi_rdata,
    input  wire [ 1:0]  m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output reg          m_axi_rready,

    // Local single-beat MMIO interface
    output wire         mmio_rd_en,
    output wire [31:0]  mmio_rd_addr,
    input  wire [31:0]  mmio_rd_data,
    input  wire         mmio_rd_error,
    output wire         mmio_wr_en,
    output wire [31:0]  mmio_wr_addr,
    output wire [31:0]  mmio_wr_data,
    output wire [ 3:0]  mmio_wr_strb,
    input  wire         mmio_wr_error
);

    localparam READ_IDLE = 2'd0;
    localparam READ_MEMORY = 2'd1;
    localparam READ_MMIO = 2'd2;

    localparam WRITE_ADDR = 2'd0;
    localparam WRITE_DATA = 2'd1;
    localparam WRITE_MEMORY_RESP = 2'd2;
    localparam WRITE_MMIO_RESP = 2'd3;

    reg [1:0] read_state;
    reg [1:0] write_state;

    reg [31:0] mmio_read_data;
    reg [ 1:0] mmio_read_resp;
    reg [ 1:0] mmio_write_resp;

    reg [31:0] write_addr;
    reg [ 7:0] write_len;
    reg [ 2:0] write_size;
    reg [ 1:0] write_burst;
    reg        write_is_mmio;
    reg        memory_aw_done;
    reg        memory_w_done;

    wire read_address_is_mmio = s_axi_araddr[31:16] == 16'hffff;
    wire write_address_is_mmio = s_axi_awaddr[31:16] == 16'hffff;

    wire read_address_handshake = s_axi_arvalid && s_axi_arready;
    wire write_address_handshake = s_axi_awvalid && s_axi_awready;
    wire write_data_handshake = s_axi_wvalid && s_axi_wready;
    wire memory_aw_handshake = m_axi_awvalid && m_axi_awready;
    wire memory_w_handshake = m_axi_wvalid && m_axi_wready;

    assign mmio_rd_en = read_state == READ_IDLE && read_address_handshake &&
                        read_address_is_mmio;
    assign mmio_rd_addr = s_axi_araddr;
    assign mmio_wr_en = write_state == WRITE_DATA && write_is_mmio &&
                        write_data_handshake;
    assign mmio_wr_addr = write_addr;
    assign mmio_wr_data = s_axi_wdata;
    assign mmio_wr_strb = s_axi_wstrb;

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            read_state <= READ_IDLE;
            mmio_read_data <= 32'h0;
            mmio_read_resp <= 2'b00;
        end else begin
            case (read_state)
                READ_IDLE: begin
                    if (read_address_handshake) begin
                        if (read_address_is_mmio) begin
                            mmio_read_data <= mmio_rd_data;
                            mmio_read_resp <= (s_axi_arlen != 8'h0 ||
                                               mmio_rd_error) ? 2'b11 : 2'b00;
                            read_state <= READ_MMIO;
                        end else begin
                            read_state <= READ_MEMORY;
                        end
                    end
                end
                READ_MEMORY: begin
                    if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                        read_state <= READ_IDLE;
                    end
                end
                READ_MMIO: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        read_state <= READ_IDLE;
                    end
                end
                default: read_state <= READ_IDLE;
            endcase
        end
    end

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            write_state <= WRITE_ADDR;
            write_addr <= 32'h0;
            write_len <= 8'h0;
            write_size <= 3'h0;
            write_burst <= 2'h0;
            write_is_mmio <= 1'b0;
            memory_aw_done <= 1'b0;
            memory_w_done <= 1'b0;
            mmio_write_resp <= 2'b00;
        end else begin
            case (write_state)
                WRITE_ADDR: begin
                    if (write_address_handshake) begin
                        write_addr <= s_axi_awaddr;
                        write_len <= s_axi_awlen;
                        write_size <= s_axi_awsize;
                        write_burst <= s_axi_awburst;
                        write_is_mmio <= write_address_is_mmio;
                        memory_aw_done <= 1'b0;
                        memory_w_done <= 1'b0;
                        write_state <= WRITE_DATA;
                    end
                end
                WRITE_DATA: begin
                    if (write_is_mmio) begin
                        if (write_data_handshake) begin
                            mmio_write_resp <= (write_len != 8'h0 ||
                                                !s_axi_wlast ||
                                                mmio_wr_error) ? 2'b11 : 2'b00;
                            write_state <= WRITE_MMIO_RESP;
                        end
                    end else begin
                        if (memory_aw_handshake) begin
                            memory_aw_done <= 1'b1;
                        end
                        if (memory_w_handshake) begin
                            memory_w_done <= 1'b1;
                        end
                        if ((memory_aw_done || memory_aw_handshake) &&
                            (memory_w_done || memory_w_handshake)) begin
                            write_state <= WRITE_MEMORY_RESP;
                        end
                    end
                end
                WRITE_MEMORY_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        write_state <= WRITE_ADDR;
                    end
                end
                WRITE_MMIO_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        write_state <= WRITE_ADDR;
                    end
                end
                default: write_state <= WRITE_ADDR;
            endcase
        end
    end

    always @(*) begin
        s_axi_awready = write_state == WRITE_ADDR;
        s_axi_wready = 1'b0;
        s_axi_bresp = 2'b00;
        s_axi_bvalid = 1'b0;
        s_axi_arready = 1'b0;
        s_axi_rdata = 32'h0;
        s_axi_rresp = 2'b00;
        s_axi_rlast = 1'b0;
        s_axi_rvalid = 1'b0;

        m_axi_awaddr = write_addr;
        m_axi_awlen = write_len;
        m_axi_awsize = write_size;
        m_axi_awburst = write_burst;
        m_axi_awvalid = 1'b0;
        m_axi_wdata = s_axi_wdata;
        m_axi_wstrb = s_axi_wstrb;
        m_axi_wlast = s_axi_wlast;
        m_axi_wvalid = 1'b0;
        m_axi_bready = 1'b0;
        m_axi_araddr = s_axi_araddr;
        m_axi_arlen = s_axi_arlen;
        m_axi_arsize = s_axi_arsize;
        m_axi_arburst = s_axi_arburst;
        m_axi_arvalid = 1'b0;
        m_axi_rready = 1'b0;

        case (read_state)
            READ_IDLE: begin
                if (read_address_is_mmio) begin
                    s_axi_arready = 1'b1;
                end else begin
                    m_axi_arvalid = s_axi_arvalid;
                    s_axi_arready = m_axi_arready;
                end
            end
            READ_MEMORY: begin
                s_axi_rdata = m_axi_rdata;
                s_axi_rresp = m_axi_rresp;
                s_axi_rlast = m_axi_rlast;
                s_axi_rvalid = m_axi_rvalid;
                m_axi_rready = s_axi_rready;
            end
            READ_MMIO: begin
                s_axi_rdata = mmio_read_data;
                s_axi_rresp = mmio_read_resp;
                s_axi_rlast = 1'b1;
                s_axi_rvalid = 1'b1;
            end
            default: begin
            end
        endcase

        case (write_state)
            WRITE_DATA: begin
                if (write_is_mmio) begin
                    s_axi_wready = 1'b1;
                end else begin
                    m_axi_awvalid = !memory_aw_done;
                    m_axi_wvalid = s_axi_wvalid && !memory_w_done;
                    s_axi_wready = m_axi_wready && !memory_w_done;
                end
            end
            WRITE_MEMORY_RESP: begin
                s_axi_bresp = m_axi_bresp;
                s_axi_bvalid = m_axi_bvalid;
                m_axi_bready = s_axi_bready;
            end
            WRITE_MMIO_RESP: begin
                s_axi_bresp = mmio_write_resp;
                s_axi_bvalid = 1'b1;
            end
            default: begin
            end
        endcase
    end

endmodule
