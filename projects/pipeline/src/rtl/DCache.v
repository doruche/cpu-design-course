`timescale 1ns / 1ps

`include "defines.vh"

// Direct-mapped 1 KiB write-through data cache with 16-byte lines and no
// write allocation. The disabled configuration bypasses cache storage while
// preserving the CPU and bus request/response contracts.
module DCache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,

    // CPU data-access interface
    input  wire [ 3:0]  data_ren,
    input  wire [31:0]  data_addr,
    output reg          data_valid,
    output reg  [31:0]  data_rdata,
    input  wire [ 3:0]  data_wen,
    input  wire [31:0]  data_wdata,
    output reg          data_wresp,

    // Write-bus interface
    input  wire         dev_wrdy,
    output reg  [ 3:0]  cpu_wen,
    output reg  [31:0]  cpu_waddr,
    output reg  [31:0]  cpu_wdata,

    // Read-bus interface
    input  wire         dev_rrdy,
    output reg  [ 3:0]  cpu_ren,
    output reg  [31:0]  cpu_raddr,
    input  wire         dev_rvalid,
    // Bypass and uncached reads consume only the returned low word.
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [127:0] dev_rdata
    /* verilator lint_on UNUSEDSIGNAL */
);

    localparam STATE_IDLE            = 3'd0;
    localparam STATE_READ_LOOKUP     = 3'd1;
    localparam STATE_READ_REQ        = 3'd2;
    localparam STATE_READ_WAIT       = 3'd3;
    localparam STATE_WRITE_REQ       = 3'd4;
    localparam STATE_WRITE_WAIT_BUSY = 3'd5;
    localparam STATE_WRITE_WAIT_DONE = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    reg [31:0] req_addr;
    reg [ 3:0] req_ren;
    reg [ 3:0] req_wen;
    reg [31:0] req_wdata;

`ifdef ENABLE_DCACHE

    wire req_uncached = req_addr[31:16] == 16'hffff;

    reg [127:0] cache_data  [0:63];
    reg [ 21:0] cache_tag   [0:63];
    reg         cache_valid [0:63];

    wire [21:0] req_tag    = req_addr[31:10];
    wire [ 5:0] req_index  = req_addr[9:4];
    wire [ 1:0] req_offset = req_addr[3:2];
    wire        cache_hit  = cache_valid[req_index] &&
                             cache_tag[req_index] == req_tag;

    function [31:0] select_word;
        input [127:0] line;
        input [1:0] word_offset;
        begin
            case (word_offset)
                2'd0: select_word = line[31:0];
                2'd1: select_word = line[63:32];
                2'd2: select_word = line[95:64];
                2'd3: select_word = line[127:96];
                default: select_word = 32'h0;
            endcase
        end
    endfunction

    function [127:0] apply_write_mask;
        input [127:0] line;
        input [31:0] write_data;
        input [3:0] write_enable;
        input [1:0] word_offset;
        reg [31:0] word_data;
        begin
            word_data = select_word(line, word_offset);
            if (write_enable[0]) word_data[7:0]   = write_data[7:0];
            if (write_enable[1]) word_data[15:8]  = write_data[15:8];
            if (write_enable[2]) word_data[23:16] = write_data[23:16];
            if (write_enable[3]) word_data[31:24] = write_data[31:24];

            apply_write_mask = line;
            case (word_offset)
                2'd0: apply_write_mask[31:0]   = word_data;
                2'd1: apply_write_mask[63:32]  = word_data;
                2'd2: apply_write_mask[95:64]  = word_data;
                2'd3: apply_write_mask[127:96] = word_data;
                default: apply_write_mask = line;
            endcase
        end
    endfunction

`endif

`ifdef ENABLE_DCACHE
    integer index;
`endif
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= STATE_IDLE;
            req_addr <= 32'h0;
            req_ren <= 4'h0;
            req_wen <= 4'h0;
            req_wdata <= 32'h0;
`ifdef ENABLE_DCACHE
            for (index = 0; index < 64; index = index + 1) begin
                cache_valid[index] <= 1'b0;
            end
`endif
        end else begin
            state <= next_state;

            if (state == STATE_IDLE) begin
                if (|data_wen) begin
                    req_addr <= data_addr;
                    req_wen <= data_wen;
                    req_wdata <= data_wdata;
                end else if (|data_ren) begin
                    req_addr <= data_addr;
                    req_ren <= data_ren;
                end
            end

`ifdef ENABLE_DCACHE
            if (state == STATE_READ_WAIT && dev_rvalid && !req_uncached) begin
                cache_valid[req_index] <= 1'b1;
            end
`endif
        end
    end

`ifdef ENABLE_DCACHE
    // Payload/tag arrays are intentionally not part of the asynchronous-reset
    // process. Only valid bits need reset; separating these writes preserves
    // RAM inference for the cache storage.
    always @(posedge cpu_clk) begin
        if (state == STATE_READ_WAIT && dev_rvalid && !req_uncached) begin
            cache_data[req_index] <= dev_rdata;
            cache_tag[req_index] <= req_tag;
        end else if (state == STATE_WRITE_REQ && dev_wrdy &&
                     !req_uncached && cache_hit) begin
            cache_data[req_index] <= apply_write_mask(
                cache_data[req_index], req_wdata, req_wen, req_offset
            );
        end
    end
`endif

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (|data_wen) begin
                    next_state = STATE_WRITE_REQ;
                end else if (|data_ren) begin
`ifdef ENABLE_DCACHE
                    next_state = data_addr[31:16] == 16'hffff
                               ? STATE_READ_REQ : STATE_READ_LOOKUP;
`else
                    next_state = STATE_READ_REQ;
`endif
                end
            end
            STATE_READ_LOOKUP: begin
`ifdef ENABLE_DCACHE
                next_state = cache_hit ? STATE_IDLE : STATE_READ_REQ;
`else
                next_state = STATE_READ_REQ;
`endif
            end
            STATE_READ_REQ: begin
                if (dev_rrdy) begin
                    next_state = STATE_READ_WAIT;
                end
            end
            STATE_READ_WAIT: begin
                if (dev_rvalid) begin
                    next_state = STATE_IDLE;
                end
            end
            STATE_WRITE_REQ: begin
                if (dev_wrdy) begin
                    next_state = STATE_WRITE_WAIT_BUSY;
                end
            end
            STATE_WRITE_WAIT_BUSY: begin
                if (!dev_wrdy) begin
                    next_state = STATE_WRITE_WAIT_DONE;
                end
            end
            STATE_WRITE_WAIT_DONE: begin
                if (dev_wrdy) begin
                    next_state = STATE_IDLE;
                end
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    always @(*) begin
        data_valid = 1'b0;
        data_rdata = 32'h0;
        data_wresp = 1'b0;

        cpu_wen = 4'h0;
        cpu_waddr = 32'h0;
        cpu_wdata = 32'h0;
        cpu_ren = 4'h0;
        cpu_raddr = 32'h0;

        case (state)
            STATE_READ_LOOKUP: begin
`ifdef ENABLE_DCACHE
                if (cache_hit) begin
                    data_valid = 1'b1;
                    data_rdata = select_word(cache_data[req_index], req_offset);
                end
`endif
            end
            STATE_READ_REQ: begin
`ifdef ENABLE_DCACHE
                cpu_ren = req_uncached ? req_ren : 4'hf;
                cpu_raddr = req_uncached ? req_addr : {req_addr[31:4], 4'h0};
`else
                cpu_ren = req_ren;
                cpu_raddr = req_addr;
`endif
            end
            STATE_READ_WAIT: begin
                if (dev_rvalid) begin
                    data_valid = 1'b1;
`ifdef ENABLE_DCACHE
                    data_rdata = req_uncached
                               ? dev_rdata[31:0]
                               : select_word(dev_rdata, req_offset);
`else
                    data_rdata = dev_rdata[31:0];
`endif
                end
            end
            STATE_WRITE_REQ: begin
                cpu_wen = req_wen;
                cpu_waddr = req_addr;
                cpu_wdata = req_wdata;
            end
            STATE_WRITE_WAIT_DONE: begin
                data_wresp = dev_wrdy;
            end
            default: begin
            end
        endcase
    end

endmodule
