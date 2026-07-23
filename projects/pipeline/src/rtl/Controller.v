`timescale 1ns / 1ps

`include "defines.vh"

module Controller (
    input  wire [ 6:0]  opcode,
    input  wire [ 2:0]  funct3,
    input  wire [ 6:0]  funct7,
    output reg  [ 1:0]  npc_op,
    output reg  [ 2:0]  sext_op,
    output reg          alua_sel,
    output reg          alub_sel,
    output reg  [ 4:0]  alu_op,
    output reg          is_mul,
    output reg          is_div,
    output reg  [ 2:0]  ram_r_op,
    output reg  [ 3:0]  ram_w_op,
    output reg          rf_we,
    output reg  [ 1:0]  rf_wsel
);

    always @(*) begin
        // Unsupported encodings advance without architectural side effects.
        npc_op   = `NPC_PC4;
        sext_op  = `EXT_I;
        alua_sel = `ALU_A_RS1;
        alub_sel = `ALU_B_RS2;
        alu_op   = `ALU_ADD;
        is_mul   = 1'b0;
        is_div   = 1'b0;
        ram_r_op = `RAM_EXT_N;
        ram_w_op = `RAM_WE_N;
        rf_we    = 1'b0;
        rf_wsel  = `WB_ALU;

        case (opcode)
            7'b0010011: begin // I-type ALU
                case (funct3)
                    3'b000: begin // ADDI
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_ALU;
                    end
                    3'b001: begin
                        case (funct7)
                            7'b0000000: begin // SLLI
                                sext_op  = `EXT_I;
                                alub_sel = `ALU_B_EXT;
                                alu_op   = `ALU_SLL;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b010: begin // SLTI
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_SLT;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_ALU;
                    end
                    3'b011: begin // SLTIU
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_SLTU;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_ALU;
                    end
                    3'b100: begin // XORI
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_XOR;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_ALU;
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: begin // SRLI
                                sext_op  = `EXT_I;
                                alub_sel = `ALU_B_EXT;
                                alu_op   = `ALU_SRL;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0100000: begin // SRAI
                                sext_op  = `EXT_I;
                                alub_sel = `ALU_B_EXT;
                                alu_op   = `ALU_SRA;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b110: begin // ORI
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_OR;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_ALU;
                    end
                    3'b111: begin // ANDI
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_AND;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_ALU;
                    end
                    default: begin
                    end
                endcase
            end

            7'b0110011: begin // R-type ALU and M extension
                case (funct3)
                    3'b000: begin
                        case (funct7)
                            7'b0000000: begin // ADD
                                alu_op   = `ALU_ADD;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // MUL
                                alu_op   = `ALU_MUL;
                                is_mul   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0100000: begin // SUB
                                alu_op   = `ALU_SUB;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b001: begin
                        case (funct7)
                            7'b0000000: begin // SLL
                                alu_op   = `ALU_SLL;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // MULH
                                alu_op   = `ALU_MULH;
                                is_mul   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b010: begin
                        case (funct7)
                            7'b0000000: begin // SLT
                                alu_op   = `ALU_SLT;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b011: begin
                        case (funct7)
                            7'b0000000: begin // SLTU
                                alu_op   = `ALU_SLTU;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // MULHU
                                alu_op   = `ALU_MULHU;
                                is_mul   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b100: begin
                        case (funct7)
                            7'b0000000: begin // XOR
                                alu_op   = `ALU_XOR;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // DIV
                                alu_op   = `ALU_DIV;
                                is_div   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: begin // SRL
                                alu_op   = `ALU_SRL;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // DIVU
                                alu_op   = `ALU_DIVU;
                                is_div   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0100000: begin // SRA
                                alu_op   = `ALU_SRA;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b110: begin
                        case (funct7)
                            7'b0000000: begin // OR
                                alu_op   = `ALU_OR;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // REM
                                alu_op   = `ALU_REM;
                                is_div   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    3'b111: begin
                        case (funct7)
                            7'b0000000: begin // AND
                                alu_op   = `ALU_AND;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            7'b0000001: begin // REMU
                                alu_op   = `ALU_REMU;
                                is_div   = 1'b1;
                                rf_we    = 1'b1;
                                rf_wsel  = `WB_ALU;
                            end
                            default: begin
                            end
                        endcase
                    end
                    default: begin
                    end
                endcase
            end

            7'b0000011: begin // Load
                case (funct3)
                    3'b000: begin // LB
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_r_op = `RAM_EXT_B;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_RAM;
                    end
                    3'b001: begin // LH
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_r_op = `RAM_EXT_H;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_RAM;
                    end
                    3'b010: begin // LW
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_r_op = `RAM_EXT_W;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_RAM;
                    end
                    3'b100: begin // LBU
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_r_op = `RAM_EXT_BU;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_RAM;
                    end
                    3'b101: begin // LHU
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_r_op = `RAM_EXT_HU;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_RAM;
                    end
                    default: begin
                    end
                endcase
            end

            7'b0100011: begin // Store
                case (funct3)
                    3'b000: begin // SB
                        sext_op  = `EXT_S;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_w_op = `RAM_WE_B;
                    end
                    3'b001: begin // SH
                        sext_op  = `EXT_S;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_w_op = `RAM_WE_H;
                    end
                    3'b010: begin // SW
                        sext_op  = `EXT_S;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        ram_w_op = `RAM_WE_W;
                    end
                    default: begin
                    end
                endcase
            end

            7'b1100011: begin // Conditional branch
                case (funct3)
                    3'b000: begin // BEQ
                        npc_op   = `NPC_BRA;
                        sext_op  = `EXT_B;
                        alu_op   = `ALU_EQ;
                    end
                    3'b001: begin // BNE
                        npc_op   = `NPC_BRA;
                        sext_op  = `EXT_B;
                        alu_op   = `ALU_NE;
                    end
                    3'b100: begin // BLT
                        npc_op   = `NPC_BRA;
                        sext_op  = `EXT_B;
                        alu_op   = `ALU_SLT;
                    end
                    3'b101: begin // BGE
                        npc_op   = `NPC_BRA;
                        sext_op  = `EXT_B;
                        alu_op   = `ALU_GE;
                    end
                    3'b110: begin // BLTU
                        npc_op   = `NPC_BRA;
                        sext_op  = `EXT_B;
                        alu_op   = `ALU_SLTU;
                    end
                    3'b111: begin // BGEU
                        npc_op   = `NPC_BRA;
                        sext_op  = `EXT_B;
                        alu_op   = `ALU_GEU;
                    end
                    default: begin
                    end
                endcase
            end

            7'b0110111: begin // LUI
                sext_op = `EXT_U;
                rf_we   = 1'b1;
                rf_wsel = `WB_EXT;
            end

            7'b0010111: begin // AUIPC
                sext_op  = `EXT_U;
                alua_sel = `ALU_A_PC;
                alub_sel = `ALU_B_EXT;
                alu_op   = `ALU_ADD;
                rf_we    = 1'b1;
                rf_wsel  = `WB_ALU;
            end

            7'b1101111: begin // JAL
                npc_op   = `NPC_JMP;
                sext_op  = `EXT_J;
                alub_sel = `ALU_B_EXT;
                rf_we    = 1'b1;
                rf_wsel  = `WB_PC4;
            end

            7'b1100111: begin // JALR
                case (funct3)
                    3'b000: begin
                        npc_op   = `NPC_JALR;
                        sext_op  = `EXT_I;
                        alub_sel = `ALU_B_EXT;
                        alu_op   = `ALU_ADD;
                        rf_we    = 1'b1;
                        rf_wsel  = `WB_PC4;
                    end
                    default: begin
                    end
                endcase
            end

            default: begin
            end
        endcase
    end

endmodule
