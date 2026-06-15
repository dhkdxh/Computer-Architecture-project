`timescale 1ns / 1ps
`include "GLOBAL.v"

module CTRL(
	// input opcode and funct
	input [5:0] opcode,
	input [5:0] funct,
	input [2:0] state,


	// output various ports
	output reg IorD,
	output reg MemRead,
	output reg MemWrite,
	output reg IRWrite,
	output reg MemtoReg,
	output reg PCWrite,
	output reg PCWriteCond,
	output reg ALUSrcA,
	output reg RegWrite,
	output reg SavePC,
	output reg SignExtend,
	output reg RegDst,
	output reg [1:0] ALUSrcB,
	output reg [1:0] PCSource,
	output reg [3:0] ALUOp
    );

	localparam S_IF  = 3'd0;
    localparam S_ID  = 3'd1;
    localparam S_EX  = 3'd2;
    localparam S_MEM = 3'd3;
    localparam S_WB  = 3'd4;

	always @(*) begin
		//초기화부터
		IorD = 0;
        MemRead = 0;
        MemWrite = 0;
        IRWrite = 0;
        MemtoReg = 0;
        PCWrite = 0;
        PCWriteCond = 0;
        ALUSrcA = 0;
        RegDst = 0;
        RegWrite = 0;
        SavePC = 0;
        SignExtend = 0;
        ALUSrcB = 2'd0;
        PCSource = 2'd0;
        ALUOp = `ALU_ADDU;

		case (state)
			S_IF: begin
				MemRead = 1; IRWrite = 1; ALUSrcA = 0; ALUSrcB = 2'b01;
				PCWrite = 1; ALUOp = `ALU_ADDU; PCSource = 2'b00;
			end

			S_ID: begin
				ALUSrcA = 0; ALUSrcB = 2'b11;
				ALUOp = `ALU_ADDU;
			end

			S_EX: begin
				ALUSrcA = 1; ALUSrcB = 2'b00;
				case (opcode)
					`OP_RTYPE: begin
						case (funct)
							`FUNCT_ADDU: ALUOp = `ALU_ADDU;
                            `FUNCT_SUBU: ALUOp = `ALU_SUBU;
                            `FUNCT_AND : ALUOp = `ALU_AND;
                            `FUNCT_OR  : ALUOp = `ALU_OR;
                            `FUNCT_XOR : ALUOp = `ALU_XOR;
                            `FUNCT_NOR : ALUOp = `ALU_NOR;
                            `FUNCT_SLL : ALUOp = `ALU_SLL;
                            `FUNCT_SRL : ALUOp = `ALU_SRL;
                            `FUNCT_SRA : ALUOp = `ALU_SRA;
                            `FUNCT_SLT : ALUOp = `ALU_SLT;
                            `FUNCT_SLTU: ALUOp = `ALU_SLTU;
							`FUNCT_JR : begin PCSource = 2'b11; PCWrite = 1; ALUOp = `ALU_ADDU; ALUSrcB = 2'b00; end
						endcase
					end

					`OP_LW, `OP_SW: begin ALUSrcA = 1; ALUSrcB = 2'b10; ALUOp = `ALU_ADDU; SignExtend = 1; end
					`OP_ADDIU: begin ALUSrcA = 1; ALUSrcB = 2'b10; ALUOp = `ALU_ADDU; SignExtend = 1; end
					`OP_BEQ: begin ALUOp = `ALU_EQ;  PCWriteCond = 1; PCSource = 2'b01; end
					`OP_BNE: begin ALUOp = `ALU_NEQ; PCWriteCond = 1; PCSource = 2'b01; end
					`OP_J: begin PCWrite = 1; PCSource = 2'b10; end 
					`OP_JAL: begin PCWrite = 1; PCSource = 2'b10; RegWrite = 1; SavePC = 1;end 
					`OP_SLTI: begin ALUSrcB = 2'b10; ALUOp = `ALU_SLT; SignExtend = 1; end
					`OP_SLTIU: begin ALUSrcB = 2'b10; ALUOp = `ALU_SLTU; SignExtend = 1; end 
					`OP_ANDI: begin ALUSrcB = 2'b10;  ALUOp = `ALU_AND; end
					`OP_ORI: begin ALUSrcB = 2'b10;  ALUOp = `ALU_OR; end
					`OP_XORI: begin ALUSrcB = 2'b10;  ALUOp = `ALU_XOR; end
					`OP_LUI: begin ALUSrcB = 2'b10; ALUOp = `ALU_LUI; end
				endcase
			end

			S_MEM: begin 
				IorD = 1;
				if (opcode == `OP_LW) MemRead = 1;
                else if (opcode == `OP_SW) MemWrite = 1;
			end

			S_WB: begin
				case (opcode)
					`OP_RTYPE: begin
						if (funct != `FUNCT_JR) begin
							RegDst = 1; MemtoReg = 0; RegWrite = 1;
						end
					end

					`OP_LW: begin MemtoReg = 1; RegWrite = 1; end

					`OP_ADDIU,
					`OP_SLTI,
					`OP_SLTIU,
					`OP_ANDI,
					`OP_ORI,
					`OP_XORI,
					`OP_LUI: begin
						MemtoReg = 0;
						RegWrite = 1;
					end
				endcase
			end
		endcase
	end
endmodule
