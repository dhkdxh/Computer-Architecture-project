`timescale 1ns / 1ps
`include "GLOBAL.v"

module HAZARD(
    input [5:0] IFID_opcode,
    input [5:0] IFID_funct,
    input [4:0] IFID_rs,
    input [4:0] IFID_rt,
  
    input [4:0] IDEX_dest_reg,
    input       IDEX_RegWrite,
    input       IDEX_MemRead, //lw 확인 위해
    
    output      stall
    );

    wire use_rs;
    wire use_rt;

    assign use_rs =
        (IFID_opcode == `OP_RTYPE) ||
        (IFID_opcode == `OP_LW)    ||
        (IFID_opcode == `OP_SW)    ||
        (IFID_opcode == `OP_BEQ)   ||
        (IFID_opcode == `OP_BNE)   ||
        (IFID_opcode == `OP_ADDIU) ||
        (IFID_opcode == `OP_SLTI)  ||
        (IFID_opcode == `OP_SLTIU) ||
        (IFID_opcode == `OP_ANDI)  ||
        (IFID_opcode == `OP_ORI)   ||
        (IFID_opcode == `OP_XORI);

    assign use_rt =
        (IFID_opcode == `OP_RTYPE && IFID_funct != `FUNCT_JR) ||
        (IFID_opcode == `OP_SW)    ||
        (IFID_opcode == `OP_BEQ)   ||
        (IFID_opcode == `OP_BNE);

    assign stall = IDEX_MemRead && (IDEX_dest_reg != 5'd0) && 
                ( (use_rs && (IDEX_dest_reg == IFID_rs)) || (use_rt && (IDEX_dest_reg == IFID_rt)));

  endmodule  