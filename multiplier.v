`timescale 1ns / 1ps

module multiplier (
    input  wire        clk,
	input  wire        rst,     // high active
	input  wire [ 7:0] x,       // multiplicand
	input  wire [ 7:0] y,       // multiplier
	input  wire        start,   // 1 - multiplication should begin
	output reg  [15:0] z,       // product
	output wire        busy     // 1 - performing multiplication; 0 - multiplication ends
);
    reg[3:0] acc;
    
    // partial product
    reg[16:0] P;
    reg[7:0] x_reg;
    reg[7:0] x_comp;
    wire [16:0] shifted_P;
    
    assign shifted_P = {P[16], P[16:1]};
    
    // state machine related
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam ADD_SUB = 2'd1;
    localparam SHIFT = 2'd2;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            acc <= 0;
            P <= 0;
            x_reg <= 0;
            x_comp <= 0;
            state <= IDLE;
            z <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        x_reg <= x;
                        x_comp <= ~x + 1;
                        P <= {8'b0, y, 1'b0};
                        state <= ADD_SUB;
                        acc <= 0;
                    end
                end
                ADD_SUB: begin
                    case (P[1:0])
                        2'b01: P <= { P[16:9] + x_reg, P[8:0] };
                        2'b10: P <= { P[16:9] + x_comp, P[8:0] };
                        default: P <= P;
                    endcase
                    state <= SHIFT;
                end
                SHIFT: begin
                    // arithmetic shift right
                    P <= shifted_P;
                    acc <= acc + 1;
                    
                    // check if we're done.
                    if (acc == 7) begin
                        state <= IDLE;
                        z <= shifted_P[16:1];
                    end else begin
                        state <= ADD_SUB;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
    
    assign busy = (state != IDLE);

endmodule
