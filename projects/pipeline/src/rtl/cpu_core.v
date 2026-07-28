`timescale 1ns / 1ps

`include "defines.vh"

// Five-stage pipeline: IF, ID, EX, MEM, WB.
//
// The stage registers, the forwarding network and the flow-control priority
// implemented here are the ones enumerated in design/pipeline/*.csv. Both
// memory interfaces have unbounded latency, so IF and MEM each own one
// outstanding request and stall the stages above them until it is answered.
module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    // Instruction Fetch Interface
    output wire         ifetch_req   /* verilator public */ ,
    output wire [31:0]  ifetch_addr  /* verilator public */ ,
    input  wire         ifetch_ready,
    input  wire         ifetch_valid /* verilator public */ ,
    input  wire [31:0]  ifetch_inst,

    // Data Access Interface
    output reg  [ 3:0]  daccess_ren,
    output reg  [31:0]  daccess_addr,
    input  wire         daccess_rvalid,
    input  wire [31:0]  daccess_rdata,
    output reg  [ 3:0]  daccess_wen,
    output reg  [31:0]  daccess_wdata,
    input  wire         daccess_wresp
);

    /************************ Stage registers *********************/
    reg         if_id_valid;
    reg  [31:0] if_id_pc;
    reg  [31:0] if_id_inst;

    reg         id_ex_valid;
    reg  [31:0] id_ex_pc;
    reg  [31:0] id_ex_rs1_value;
    reg  [31:0] id_ex_rs2_value;
    reg  [31:0] id_ex_imm;
    reg  [ 4:0] id_ex_rd;
    reg  [ 4:0] id_ex_rs1;
    reg  [ 4:0] id_ex_rs2;
    reg  [ 1:0] id_ex_npc_op;
    reg  [ 4:0] id_ex_alu_op;
    reg         id_ex_alua_sel;
    reg         id_ex_alub_sel;
    reg         id_ex_is_mul;
    reg         id_ex_is_div;
    reg  [ 2:0] id_ex_ram_rop;
    reg  [ 3:0] id_ex_ram_wop;
    reg         id_ex_rf_we;
    reg  [ 1:0] id_ex_rf_wsel;

    reg         ex_mem_valid;
    reg  [31:0] ex_mem_pc;
    reg  [31:0] ex_mem_alu_result;
    reg  [31:0] ex_mem_store_data;
    reg  [ 4:0] ex_mem_rd;
    reg         ex_mem_rf_we;
    reg         ex_mem_wb_from_ram;
    reg  [ 2:0] ex_mem_ram_rop;
    reg  [ 3:0] ex_mem_ram_wop;

    reg         mem_wb_valid;
    reg  [31:0] mem_wb_pc;
    reg  [31:0] mem_wb_result;
    reg  [ 4:0] mem_wb_rd;
    reg         mem_wb_rf_we;

    /********************* Flow control signals *******************/
    wire        flush;
    wire [31:0] redirect_pc;
    wire        mem_stall;
    wire        md_stall;
    wire        load_use_stall;

    // design/pipeline/flow_control.csv, highest priority first. A stall in a
    // later stage always subsumes the stalls above it.
    wire ex_mem_update = ~mem_stall;
    wire id_ex_update  = ~mem_stall & ~md_stall;
    wire if_id_advance = id_ex_update & ~load_use_stall;

    /***************************** IF *****************************/
    reg  [31:0] pc;
    reg         fetch_pending;    // one outstanding instruction fetch
    reg  [31:0] fetch_pc;         // pc that fetch was issued for
    reg         fetch_discard;    // outstanding fetch belongs to a flushed path

    // One-entry skid buffer behind IF_ID. Without it a fetch could only be
    // issued after the previous one had landed *and* IF_ID had drained, which
    // caps fetch throughput at one instruction every two cycles even when the
    // memory answers every cycle.
    reg         skid_valid;
    reg  [31:0] skid_pc;
    reg  [31:0] skid_inst;

    wire if_id_slot_free = ~if_id_valid | if_id_advance;
    wire fetch_return    = fetch_pending & ifetch_valid;
    wire fetch_keep      = fetch_return & ~fetch_discard & ~flush;

    // Where the two instruction slots end up this cycle. A fetch may only be
    // issued while at most one of them will be occupied, so the answer always
    // has somewhere to land however the pipeline stalls in the meantime.
    wire if_id_next_valid = flush            ? 1'b0
                          : if_id_slot_free  ? (skid_valid | fetch_keep)
                                             : 1'b1;
    wire skid_next_valid  = flush            ? 1'b0
                          : if_id_slot_free  ? (skid_valid & fetch_keep)
                                             : (skid_valid | fetch_keep);

    wire fetch_issue = ~cpu_rst & ~flush & ifetch_ready &
                       (~fetch_pending | fetch_return) &
                       ~(if_id_next_valid & skid_next_valid);

    assign ifetch_req  = fetch_issue;
    assign ifetch_addr = pc;

    // Static predict-not-taken: PC walks forward with each issued fetch and is
    // only redirected when EX resolves a taken transfer.
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)          pc <= `PC_INIT_VAL;
        else if (flush)       pc <= redirect_pc;
        else if (fetch_issue) pc <= pc + 32'h4;
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            fetch_pending <= 1'b0;
            fetch_pc      <= 32'h0;
            fetch_discard <= 1'b0;
        end else begin
            if (fetch_issue) begin
                fetch_pending <= 1'b1;
                fetch_pc      <= pc;
                fetch_discard <= 1'b0;
            end else if (fetch_return) begin
                fetch_pending <= 1'b0;
                fetch_discard <= 1'b0;
            end else if (flush & fetch_pending) begin
                fetch_discard <= 1'b1;
            end
        end
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst | flush) begin
            if_id_valid <= 1'b0;
            skid_valid  <= 1'b0;
        end else if (if_id_slot_free) begin
            if (skid_valid) begin
                if_id_valid <= 1'b1;
                if_id_pc    <= skid_pc;
                if_id_inst  <= skid_inst;
                skid_valid  <= fetch_keep;
                skid_pc     <= fetch_pc;
                skid_inst   <= ifetch_inst;
            end else begin
                if_id_valid <= fetch_keep;
                if_id_pc    <= fetch_pc;
                if_id_inst  <= ifetch_inst;
            end
        end else if (fetch_keep) begin
            skid_valid <= 1'b1;
            skid_pc    <= fetch_pc;
            skid_inst  <= ifetch_inst;
        end
    end

    /***************************** ID *****************************/
    wire [ 1:0] npc_op;
    wire [ 1:0] rf_wsel;
    wire [ 2:0] sext_op;
    wire [ 4:0] alu_op;
    wire        alua_sel;
    wire        alub_sel;
    wire [ 2:0] ram_rop;
    wire [ 3:0] ram_wop;
    wire        is_mul;
    wire        is_div;
    wire        rf_we;
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire [31:0] imm;

    Controller U_CU (
        .opcode         (if_id_inst[6:0]),
        .funct3         (if_id_inst[14:12]),
        .funct7         (if_id_inst[31:25]),
        .npc_op         (npc_op),
        .sext_op        (sext_op),
        .alu_op         (alu_op),
        .alua_sel       (alua_sel),
        .alub_sel       (alub_sel),
        .is_mul         (is_mul),
        .is_div         (is_div),
        .ram_r_op       (ram_rop),
        .ram_w_op       (ram_wop),
        .rf_we          (rf_we),
        .rf_wsel        (rf_wsel)
    );

    RF U_RF (
        .clk        (cpu_clk),
        .rR1        (if_id_inst[19:15]),
        .rR2        (if_id_inst[24:20]),
        .rD1        (rf_rd1),
        .rD2        (rf_rd2),
        .we         (mem_wb_valid & mem_wb_rf_we),
        .wR         (mem_wb_rd),
        .wD         (mem_wb_result)
    );

    SEXT U_SEXT (
        .op         (sext_op),
        .imm        (if_id_inst[31:7]),
        .ext        (imm)
    );

    // Instruction formats that leave rs1/rs2 unencoded still carry immediate
    // bits in those fields. Reporting x0 instead keeps them out of both the
    // forwarding comparators and the load-use detector.
    wire [6:0] opcode = if_id_inst[6:0];
    wire uses_rs1 = (opcode == 7'b0110011) | (opcode == 7'b0010011)
                  | (opcode == 7'b0000011) | (opcode == 7'b0100011)
                  | (opcode == 7'b1100011) | (opcode == 7'b1100111);
    wire uses_rs2 = (opcode == 7'b0110011) | (opcode == 7'b0100011)
                  | (opcode == 7'b1100011);

    wire [4:0] id_rs1 = uses_rs1 ? if_id_inst[19:15] : 5'h0;
    wire [4:0] id_rs2 = uses_rs2 ? if_id_inst[24:20] : 5'h0;

    // RF reads are combinational and WB commits on the same edge that ID_EX
    // latches, so ID has to see the value being written.
    wire wb_bypass_rs1 = mem_wb_valid & mem_wb_rf_we & (mem_wb_rd != 5'h0)
                       & (mem_wb_rd == id_rs1);
    wire wb_bypass_rs2 = mem_wb_valid & mem_wb_rf_we & (mem_wb_rd != 5'h0)
                       & (mem_wb_rd == id_rs2);

    wire [31:0] id_rs1_value = wb_bypass_rs1 ? mem_wb_result : rf_rd1;
    wire [31:0] id_rs2_value = wb_bypass_rs2 ? mem_wb_result : rf_rd2;

    // A load result is not available until it reaches MEM/WB, so the consumer
    // waits one cycle in ID and then takes the ordinary MEM->EX forward.
    wire id_ex_is_load = id_ex_ram_rop != `RAM_EXT_N;
    assign load_use_stall = if_id_valid & id_ex_valid & id_ex_is_load
                          & (id_ex_rd != 5'h0)
                          & ((id_ex_rd == id_rs1) | (id_ex_rd == id_rs2));

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst | flush) begin
            id_ex_valid <= 1'b0;
        end else if (id_ex_update) begin
            id_ex_valid     <= if_id_valid & ~load_use_stall;
            id_ex_pc        <= if_id_pc;
            id_ex_rs1_value <= id_rs1_value;
            id_ex_rs2_value <= id_rs2_value;
            id_ex_imm       <= imm;
            id_ex_rd        <= if_id_inst[11:7];
            id_ex_rs1       <= id_rs1;
            id_ex_rs2       <= id_rs2;
            id_ex_npc_op    <= npc_op;
            id_ex_alu_op    <= alu_op;
            id_ex_alua_sel  <= alua_sel;
            id_ex_alub_sel  <= alub_sel;
            id_ex_is_mul    <= is_mul;
            id_ex_is_div    <= is_div;
            id_ex_ram_rop   <= ram_rop;
            id_ex_ram_wop   <= ram_wop;
            id_ex_rf_we     <= rf_we;
            id_ex_rf_wsel   <= rf_wsel;
        end else begin
            // A held EX must capture the operands it can currently see. Its
            // producer keeps moving down the pipe while EX waits, so the
            // forward that satisfies this instruction can disappear before it
            // is allowed to leave.
            id_ex_rs1_value <= ex_rs1;
            id_ex_rs2_value <= ex_rs2;
        end
    end

    /***************************** EX *****************************/
    wire [31:0] alu_c;
    wire        alu_br;
    wire        mul_div_busy;
    wire [31:0] mem_result;

    // Forward the newest available result. EX/MEM never holds a pending load
    // value, because the load-use detector keeps such a consumer in ID until
    // the load has moved on to MEM/WB.
    wire fwd_ex_rs1 = ex_mem_valid & ex_mem_rf_we & (ex_mem_rd != 5'h0)
                    & (ex_mem_rd == id_ex_rs1);
    wire fwd_ex_rs2 = ex_mem_valid & ex_mem_rf_we & (ex_mem_rd != 5'h0)
                    & (ex_mem_rd == id_ex_rs2);
    wire fwd_wb_rs1 = mem_wb_valid & mem_wb_rf_we & (mem_wb_rd != 5'h0)
                    & (mem_wb_rd == id_ex_rs1);
    wire fwd_wb_rs2 = mem_wb_valid & mem_wb_rf_we & (mem_wb_rd != 5'h0)
                    & (mem_wb_rd == id_ex_rs2);

    wire [31:0] ex_rs1 = fwd_ex_rs1 ? ex_mem_alu_result :
                         fwd_wb_rs1 ? mem_wb_result     : id_ex_rs1_value;
    wire [31:0] ex_rs2 = fwd_ex_rs2 ? ex_mem_alu_result :
                         fwd_wb_rs2 ? mem_wb_result     : id_ex_rs2_value;

    // The multiplier and divider start on a level, so the op must be withdrawn
    // once the unit has been launched or it restarts while EX is still held.
    reg         md_launched;
    reg         md_captured;
    reg  [31:0] md_result;

    wire ex_is_md   = id_ex_valid & (id_ex_is_mul | id_ex_is_div);
    wire md_present = ex_is_md & ~md_launched & ~md_captured;
    wire md_capture = md_launched & ~mul_div_busy;

    assign md_stall = ex_is_md & ~md_captured;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)             md_launched <= 1'b0;
        else if (md_present)     md_launched <= 1'b1;
        else if (md_capture)     md_launched <= 1'b0;
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            md_captured <= 1'b0;
            md_result   <= 32'h0;
        end else if (md_capture) begin
            md_captured <= 1'b1;
            md_result   <= alu_c;
        end else if (id_ex_update) begin
            md_captured <= 1'b0;
        end
    end

    wire [31:0] alu_a = id_ex_alua_sel ? id_ex_pc  : ex_rs1;
    wire [31:0] alu_b = id_ex_alub_sel ? id_ex_imm : ex_rs2;
    // A bubble still carries the previous instruction's decode, so the op has
    // to be withdrawn on the id_ex_is_mul/id_ex_is_div fields alone. Gating on
    // ex_is_md would let an invalid stage restart the unit behind a live
    // operation and hand back its result.
    wire ex_holds_md_op = id_ex_is_mul | id_ex_is_div;
    wire [ 4:0] alu_op_in = (ex_holds_md_op & ~md_present) ? `ALU_ADD
                                                          : id_ex_alu_op;

    ALU U_ALU (
        .rst        (cpu_rst),
        .clk        (cpu_clk),
        .op         (alu_op_in),
        .a          (alu_a),
        .b          (alu_b),
        .br         (alu_br),
        .c          (alu_c),
        .busy       (mul_div_busy)
    );

    // Branches, jal and jalr all resolve here against the static
    // predict-not-taken fetch, so any taken transfer discards IF and ID.
    wire [31:0] npc;
    wire [31:0] pc4;
    wire [31:0] npc_offset = (id_ex_npc_op == `NPC_JALR) ? alu_c : id_ex_imm;

    NPC U_NPC (
        .op         (id_ex_npc_op),
        .pc         (id_ex_pc),
        .offset     (npc_offset),
        .br         (alu_br),
        .npc        (npc),
        .pc4        (pc4)
    );

    wire br_taken = id_ex_valid
                  & ((id_ex_npc_op == `NPC_JMP)
                   | (id_ex_npc_op == `NPC_JALR)
                   | ((id_ex_npc_op == `NPC_BRA) & alu_br));

    assign flush       = br_taken & id_ex_update;
    assign redirect_pc = npc;

    // Every writeback source except a load is already known here.
    reg [31:0] ex_result;
    always @(*) begin
        case (id_ex_rf_wsel)
            `WB_PC4: ex_result = pc4;
            `WB_EXT: ex_result = id_ex_imm;
            default: ex_result = ex_is_md ? md_result : alu_c;
        endcase
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            ex_mem_valid <= 1'b0;
        end else if (ex_mem_update) begin
            ex_mem_valid       <= id_ex_valid & ~md_stall;
            ex_mem_pc          <= id_ex_pc;
            ex_mem_alu_result  <= ex_result;
            ex_mem_store_data  <= ex_rs2;
            ex_mem_rd          <= id_ex_rd;
            ex_mem_rf_we       <= id_ex_rf_we;
            ex_mem_wb_from_ram <= id_ex_rf_wsel == `WB_RAM;
            ex_mem_ram_rop     <= id_ex_ram_rop;
            ex_mem_ram_wop     <= id_ex_ram_wop;
        end
    end

    /***************************** MEM ****************************/
    wire [ 3:0] da_ren;
    wire [31:0] da_addr;
    wire [ 3:0] da_wen;
    wire [31:0] da_wdata;
    wire [31:0] ram_ext;

    MREQ U_MEM_REQ (
        .ram_addr   (ex_mem_alu_result),

        .ram_rop    (ex_mem_ram_rop),
        .da_ren     (da_ren),
        .da_addr    (da_addr),

        .ram_wop    (ex_mem_ram_wop),
        .ram_wdata  (ex_mem_store_data),
        .da_wen     (da_wen),
        .da_wdata   (da_wdata)
    );

    MEXT U_MEM_EXT (
        .op         (ex_mem_ram_rop),
        .din        (daccess_rdata),
        .byte_offs  (ex_mem_alu_result[1:0]),
        .ext        (ram_ext)
    );

    // One outstanding data access, issued once and held in MEM until the
    // matching read or write response arrives.
    reg  mem_issued;
    wire mem_needs = ex_mem_valid & ((ex_mem_ram_rop != `RAM_EXT_N)
                                   | (ex_mem_ram_wop != `RAM_WE_N));
    wire mem_issue = mem_needs & ~mem_issued;
    wire mem_done  = mem_issued & (daccess_rvalid | daccess_wresp);

    assign mem_stall = mem_needs & ~mem_done;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            daccess_ren   <= 4'h0;
            daccess_wen   <= 4'h0;
            daccess_addr  <= 32'h0;
            daccess_wdata <= 32'h0;
            mem_issued    <= 1'b0;
        end else if (mem_issue) begin
            daccess_ren   <= da_ren;
            daccess_addr  <= da_addr;
            daccess_wen   <= da_wen;
            daccess_wdata <= da_wdata;
            mem_issued    <= 1'b1;
        end else begin
            daccess_ren <= 4'h0;
            daccess_wen <= 4'h0;
            if (mem_done) mem_issued <= 1'b0;
        end
    end

    assign mem_result = ex_mem_wb_from_ram ? ram_ext : ex_mem_alu_result;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            mem_wb_valid <= 1'b0;
        end else begin
            mem_wb_valid  <= ex_mem_valid & ~mem_stall;
            mem_wb_pc     <= ex_mem_pc;
            mem_wb_result <= mem_result;
            mem_wb_rd     <= ex_mem_rd;
            mem_wb_rf_we  <= ex_mem_rf_we;
        end
    end

    /********************* Your CPU ends here *********************/

`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc    /* verilator public */ ;     // WB阶段的PC
    wire        debug_wb_rf_we /* verilator public */ ;     // WB阶段的寄存器写使能
    wire [ 4:0] debug_wb_rf_wR /* verilator public */ ;     // WB阶段的目标寄存器   (若wb_rf_we为0，此项可为任意值)
    wire [31:0] debug_wb_rf_wD /* verilator public */ ;     // WB阶段写入寄存器的值 (若wb_rf_we为0，此项可为任意值)

    wire [31:0] debug_mem_pc    /* verilator public */ ;    // MEM阶段的PC
    wire [ 3:0] debug_mem_we    /* verilator public */ ;    // MEM阶段写访存时的写使能
    wire [31:0] debug_mem_waddr /* verilator public */ ;    // MEM阶段写访存时的写地址 (若mem_we为0，此项可为任意值)
    wire [31:0] debug_mem_wdata /* verilator public */ ;    // MEM阶段写访存时的写数据 (若mem_we为0，此项可为任意值)

    assign debug_wb_pc    = mem_wb_pc;
    assign debug_wb_rf_we = mem_wb_valid & mem_wb_rf_we;
    assign debug_wb_rf_wR = mem_wb_rd;
    assign debug_wb_rf_wD = mem_wb_result;

    assign debug_mem_pc    = ex_mem_pc;
    assign debug_mem_we    = daccess_wen;
    assign debug_mem_waddr = daccess_addr;
    assign debug_mem_wdata = daccess_wdata;
`endif


endmodule
