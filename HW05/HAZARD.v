`timescale 1ns / 1ps
`include "GLOBAL.v"

module HAZARD(
    input [5:0] IFID_opcode,
    input [5:0] IFID_funct,
    input [4:0] IFID_rs,
    input [4:0] IFID_rt,
  
    input [4:0] IDEX_dest_reg,
    input       IDEX_RegWrite,

    input [4:0] EXMEM_dest_reg,
    input       EXMEM_RegWrite,

    input [4:0] MEMWB_dest_reg,
    input       MEMWB_RegWrite,

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

    assign stall =
        (use_rs && IDEX_RegWrite && (IDEX_dest_reg != 5'd0) && (IDEX_dest_reg == IFID_rs)) ||

        (use_rt && IDEX_RegWrite && (IDEX_dest_reg != 5'd0) && (IDEX_dest_reg == IFID_rt)) ||

        (use_rs && EXMEM_RegWrite && (EXMEM_dest_reg != 5'd0) && (EXMEM_dest_reg == IFID_rs)) ||

        (use_rt && EXMEM_RegWrite && (EXMEM_dest_reg != 5'd0) && (EXMEM_dest_reg == IFID_rt)) ||

        (use_rs && MEMWB_RegWrite && (MEMWB_dest_reg != 5'd0) && (MEMWB_dest_reg == IFID_rs)) ||

        (use_rt && MEMWB_RegWrite && (MEMWB_dest_reg != 5'd0) && (MEMWB_dest_reg == IFID_rt));

  endmodule  