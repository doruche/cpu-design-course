`timescale 1ns / 1ps

`include "defines.vh"

// Direct-mapped 1 KiB instruction cache with 16-byte lines.
// The disabled configuration keeps the same CPU/bus contract and bypasses
// storage so the AXI path can be brought up independently in Stage 2.
module ICache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,

    // CPU instruction-fetch interface
    input  wire         inst_rreq,
    // Fetch addresses are word aligned; bits [1:0] are intentionally ignored.
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0]  inst_addr,
    /* verilator lint_on UNUSEDSIGNAL */
    output reg          inst_ready,
    output reg          inst_valid,
    output reg  [31:0]  inst_out,

    // Read-bus interface
    input  wire         dev_rrdy,
    output reg  [ 3:0]  cpu_ren,
    output reg  [31:0]  cpu_raddr,
    input  wire         dev_rvalid,
    // Bypass mode consumes only the returned low word.
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [127:0] dev_rdata
    /* verilator lint_on UNUSEDSIGNAL */
);

`ifdef ENABLE_ICACHE

    localparam STATE_IDLE         = 2'd0;
    localparam STATE_LOOKUP       = 2'd1;
    localparam STATE_REFILL_REQ   = 2'd2;
    localparam STATE_REFILL_WAIT  = 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;

    // Instruction addresses are word aligned. Keeping only address[31:2]
    // makes the alignment contract explicit and avoids carrying dead bits.
    reg [29:0] req_word_addr;

    reg [127:0] cache_data  [0:63];
    reg [ 21:0] cache_tag   [0:63];
    reg         cache_valid [0:63];

    wire [21:0] req_tag    = req_word_addr[29:8];
    wire [ 5:0] req_index  = req_word_addr[7:2];
    wire [ 1:0] req_offset = req_word_addr[1:0];
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

    integer index;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= STATE_IDLE;
            req_word_addr <= 30'h0;
            for (index = 0; index < 64; index = index + 1) begin
                cache_valid[index] <= 1'b0;
            end
        end else begin
            state <= next_state;

            if (inst_ready && inst_rreq) begin
                req_word_addr <= inst_addr[31:2];
            end

            if (state == STATE_REFILL_WAIT && dev_rvalid) begin
                cache_valid[req_index] <= 1'b1;
            end
        end
    end

    // Keep payload/tag storage out of the asynchronous-reset process so Vivado
    // can infer on-chip RAM instead of expanding both arrays into registers.
    always @(posedge cpu_clk) begin
        if (state == STATE_REFILL_WAIT && dev_rvalid) begin
            cache_data[req_index] <= dev_rdata;
            cache_tag[req_index] <= req_tag;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (inst_rreq) begin
                    next_state = STATE_LOOKUP;
                end
            end
            STATE_LOOKUP: begin
                if (!cache_hit) begin
                    next_state = STATE_REFILL_REQ;
                end else begin
                    // A hit answers in one cycle, so the next fetch can be
                    // looked up back to back instead of idling for a cycle.
                    next_state = inst_rreq ? STATE_LOOKUP : STATE_IDLE;
                end
            end
            STATE_REFILL_REQ: begin
                if (dev_rrdy) begin
                    next_state = STATE_REFILL_WAIT;
                end
            end
            STATE_REFILL_WAIT: begin
                if (dev_rvalid) begin
                    next_state = inst_rreq ? STATE_LOOKUP : STATE_IDLE;
                end
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    always @(*) begin
        inst_ready = 1'b0;
        inst_valid = 1'b0;
        inst_out = 32'h0;
        cpu_ren = 4'h0;
        cpu_raddr = 32'h0;

        case (state)
            STATE_IDLE: begin
                inst_ready = 1'b1;
            end
            STATE_LOOKUP: begin
                if (cache_hit) begin
                    inst_ready = 1'b1;
                    inst_valid = 1'b1;
                    inst_out = select_word(cache_data[req_index], req_offset);
                end
            end
            STATE_REFILL_REQ: begin
                cpu_ren = 4'hf;
                cpu_raddr = {req_word_addr[29:2], 4'h0};
            end
            STATE_REFILL_WAIT: begin
                if (dev_rvalid) begin
                    inst_ready = 1'b1;
                    inst_valid = 1'b1;
                    inst_out = select_word(dev_rdata, req_offset);
                end
            end
            default: begin
            end
        endcase
    end

`else

    localparam STATE_IDLE        = 2'd0;
    localparam STATE_BYPASS_REQ  = 2'd1;
    localparam STATE_BYPASS_WAIT = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [29:0] req_word_addr;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= STATE_IDLE;
            req_word_addr <= 30'h0;
        end else begin
            state <= next_state;
            if (inst_ready && inst_rreq) begin
                req_word_addr <= inst_addr[31:2];
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (inst_rreq) begin
                    next_state = STATE_BYPASS_REQ;
                end
            end
            STATE_BYPASS_REQ: begin
                if (dev_rrdy) begin
                    next_state = STATE_BYPASS_WAIT;
                end
            end
            STATE_BYPASS_WAIT: begin
                if (dev_rvalid) begin
                    next_state = inst_rreq ? STATE_BYPASS_REQ : STATE_IDLE;
                end
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    always @(*) begin
        inst_ready = 1'b0;
        inst_valid = 1'b0;
        inst_out = 32'h0;
        cpu_ren = 4'h0;
        cpu_raddr = 32'h0;

        case (state)
            STATE_IDLE: begin
                inst_ready = 1'b1;
            end
            STATE_BYPASS_REQ: begin
                cpu_ren = 4'hf;
                cpu_raddr = {req_word_addr, 2'b00};
            end
            STATE_BYPASS_WAIT: begin
                if (dev_rvalid) begin
                    inst_ready = 1'b1;
                    inst_valid = 1'b1;
                    inst_out = dev_rdata[31:0];
                end
            end
            default: begin
            end
        endcase
    end

`endif

endmodule
