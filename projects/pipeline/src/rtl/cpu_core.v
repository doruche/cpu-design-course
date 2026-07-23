`timescale 1ns / 1ps

`include "defines.vh"

module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    // Instruction Fetch Interface
    output wire         ifetch_req   /* verilator public */ ,
    output wire [31:0]  ifetch_addr  /* verilator public */ ,
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

    // PC and NPC
    wire [31:0] pc;
    wire [31:0] npc;
    wire [31:0] pc4;
    wire [31:0] npc_offset;
    wire [31:0] inst;

    // Controller
    wire [ 1:0] npc_op;
    wire [ 1:0] rf_wsel;
    wire [ 2:0] sext_op;
    wire [ 4:0] alu_op;
    wire        alua_sel;
    wire        alub_sel;
    wire [ 2:0] ram_rop;
    reg  [ 2:0] captured_load_op;
    wire [ 3:0] ram_wop;
    wire        is_mul;
    wire        is_div;
    wire        mul_div_start;
    reg         mul_div_pending;

    // Register File
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire        rf_we;
    wire        commit_rf_we;
    reg  [ 4:0] captured_rf_waddr;
    wire [ 4:0] rf_wR;
    reg  [31:0] rf_wD;

    // Signed Extension
    wire [31:0] ext;

    // ALU
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_c;
    reg  [ 1:0] captured_mem_offset;
    wire        br;
    wire        mul_div_busy;
    
    // Memory Access
    wire [ 3:0] da_ren;
    wire [31:0] da_addr;
    wire [ 3:0] da_wen;
    wire [31:0] da_wdata;
    wire [31:0] ram_ext;
    wire        mem_start;
    reg         mem_pending;

    // Completion and commit events. Pending state owns multi-cycle operations;
    // response and busy inputs only qualify completion while that state is set.
    wire        normal_done;
    wire        mem_done;
    wire        mul_div_done;
    wire        inst_done;
    reg         inst_done_r;

    /***************************** IF *****************************/
    reg rst_r;
    wire first_req = rst_r & !cpu_rst;
    always @(posedge cpu_clk) rst_r <= cpu_rst;

    // 复位信号发生边沿变化时首次取指; 当前指令执行完毕后取下一条指令
    assign ifetch_req  = first_req | inst_done_r;
    assign ifetch_addr = pc;

    assign npc_offset = (npc_op == `NPC_JALR) ? alu_c : ext;

    NPC U_NPC (
        .op         (npc_op),
        .pc         (pc),
        .offset     (npc_offset),
        .br         (br),
        .npc        (npc),
        .pc4        (pc4)
    );

    PC U_PC (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .npc        (npc),
        .fetch      (inst_done),
        .pc         (pc)
    );
    
    /***************************** ID *****************************/
    // 按照约定的时序，ifetch_inst只在ifetch_valid有效时有效，且它们仅有效1个时钟.
    // 此处是为了避免ifetch_valid撤销后，ifetch_inst发生变化从而导致指令执行出错.
    assign inst = ifetch_valid ? ifetch_inst : 32'h13 /* NOP */ ;

    Controller U_CU (
        // input
        .opcode         (inst[6:0]),
        .funct3         (inst[14:12]),
        .funct7         (inst[31:25]),
        // output
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
        .rR1        (inst[19:15]),
        .rR2        (inst[24:20]),
        .rD1        (rf_rd1),
        .rD2        (rf_rd2),
        .we         (commit_rf_we),
        .wR         (rf_wR),
        .wD         (rf_wD)
    );

    SEXT U_SEXT (
        .op         (sext_op),
        .imm        (inst[31:7]),
        .ext        (ext)
    );
    
    // Memory request state remains owned here until the matching read or write
    // response completes the single outstanding operation.
    assign mem_start = (ram_rop != `RAM_EXT_N) | (ram_wop != `RAM_WE_N);
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if      (cpu_rst)  mem_pending <= 1'b0;
        else if (mem_start) mem_pending <= 1'b1;
        else if (mem_done)  mem_pending <= 1'b0;
    end

    // Multiply/divide state remains pending until the ALU drops busy.
    assign mul_div_start = is_mul | is_div;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if      (cpu_rst)      mul_div_pending <= 1'b0;
        else if (mul_div_start) mul_div_pending <= 1'b1;
        else if (mul_div_done)  mul_div_pending <= 1'b0;
    end

    // Capture values that must survive after ifetch_valid is withdrawn.
    always @(posedge cpu_clk) begin
        if (mem_start | mul_div_start) captured_rf_waddr <= inst[11:7];
    end

    /***************************** EX *****************************/
    assign alu_a = alua_sel ? pc  : rf_rd1;
    assign alu_b = alub_sel ? ext : rf_rd2;

    ALU U_ALU (
        .rst        (cpu_rst),
        .clk        (cpu_clk),
        .op         (alu_op),
        .a          (alu_a),
        .b          (alu_b),
        .br         (br),
        .c          (alu_c),
        .busy       (mul_div_busy)
    );

    /***************************** MEM *****************************/
    MREQ U_MEM_REQ (
        .ram_addr   (alu_c),

        .ram_rop    (ram_rop),
        .da_ren     (da_ren),
        .da_addr    (da_addr),

        .ram_wop    (ram_wop),
        .ram_wdata  (rf_rd2),
        .da_wen     (da_wen),
        .da_wdata   (da_wdata)
    );

    MEXT U_MEM_EXT (
        .op             (captured_load_op),
        .din            (daccess_rdata),
        .byte_offs      (captured_mem_offset),
        .ext            (ram_ext)
    );

    always @(posedge cpu_clk) if (mem_start) captured_mem_offset <= alu_c[1:0];
    always @(posedge cpu_clk) if (mem_start) captured_load_op    <= ram_rop;

    // Interface to Bus
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            daccess_ren   <= 4'h0;
            daccess_wen   <= 4'h0;
        end else begin
            daccess_ren   <= da_ren;
            daccess_addr  <= da_addr;
            daccess_wen   <= da_wen;
            daccess_wdata <= da_wdata;
        end
    end

    /***************************** WB *****************************/
    assign normal_done  = ifetch_valid & !mem_start & !mul_div_start;
    assign mem_done     = mem_pending & (daccess_rvalid | daccess_wresp);
    assign mul_div_done = mul_div_pending & !mul_div_busy;
    assign inst_done    = normal_done | mem_done | mul_div_done;

    assign commit_rf_we = normal_done & rf_we |
                          mem_pending & daccess_rvalid |
                          mul_div_done;

    assign rf_wR = mem_pending | mul_div_pending
                 ? captured_rf_waddr : inst[11:7];

    always @(*) begin
        if (mem_pending) begin
            rf_wD = ram_ext;
        end else begin
            case (rf_wsel)
                `WB_ALU:  rf_wD = alu_c;
                `WB_PC4:  rf_wD = pc4;
                `WB_EXT:  rf_wD = ext;
                default:  rf_wD = 32'h0;
            endcase
        end
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        inst_done_r <= cpu_rst ? 1'b0 : inst_done;
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

    assign debug_wb_pc    = pc;
    assign debug_wb_rf_we = commit_rf_we;
    assign debug_wb_rf_wR = rf_wR;
    assign debug_wb_rf_wD = rf_wD;

    assign debug_mem_pc    = pc;
    assign debug_mem_we    = daccess_wen;
    assign debug_mem_waddr = daccess_addr;
    assign debug_mem_wdata = daccess_wdata;
`endif

endmodule
