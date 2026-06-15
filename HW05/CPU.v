`timescale 1ns / 1ps
`include "GLOBAL.v"

module CPU(
	input		clk,
	input		rst,
	output 		halt
	);
	
	reg [31:0] PC;

	wire [31:0] fetched_inst;

	//control
	wire        RegDst;
	wire       	ALUSrc;
	wire        MemRead;
	wire        MemWrite;
	wire        MemtoReg;
	wire        RegWrite;
	wire        Branch;
	wire        Jump;
	wire        JAL;
	wire        JR;
	wire        SavePC;
	wire        SignExtend;
	wire [3:0]  ALUOp;

	//IF-ID
	reg [31:0] IFID_PC, IFID_inst;
	reg IFID_valid;

	//ID-EX
	reg [31:0] IDEX_PC, IDEX_rd_data1, IDEX_rd_data2, IDEX_ext_imm;
	reg [4:0] IDEX_rs, IDEX_rt, IDEX_rd, IDEX_shamt;
	reg [5:0] IDEX_opcode, IDEX_funct;
	reg [25:0] IDEX_immj;
	reg IDEX_valid;
	reg        IDEX_RegDst,IDEX_ALUSrc,IDEX_MemRead,IDEX_MemWrite, IDEX_MemtoReg;
  	reg        IDEX_RegWrite,IDEX_Branch,IDEX_Jump, IDEX_JAL;
  	reg        IDEX_JR,IDEX_SavePC;
  	reg [3:0]  IDEX_ALUOp;
	reg [31:0] IDEX_inst;

	//EX-MEM
	reg [31:0] EXMEM_alu_result, EXMEM_write_data, EXMEM_PC;
	reg [4:0] EXMEM_dest_reg;
	reg 		EXMEM_valid;
	reg 		EXMEM_RegWrite,EXMEM_MemtoReg,EXMEM_MemRead, EXMEM_MemWrite, EXMEM_SavePC;
	reg [31:0] EXMEM_inst;

	//MEM-WB
	reg [31:0] MEMWB_alu_result, MEMWB_PC, MEMWB_mem_read_data;
	reg [4:0] MEMWB_dest_reg;
	reg MEMWB_valid;
	reg  		MEMWB_RegWrite, MEMWB_MemtoReg, MEMWB_SavePC;
	reg [31:0] MEMWB_inst;
	
	// Instruction-related wires
	wire [5:0] opcode = IFID_inst[31:26];
	wire [4:0] rs     = IFID_inst[25:21];
	wire [4:0] rt     = IFID_inst[20:16];
	wire [4:0] rd     = IFID_inst[15:11];
	wire [4:0] shamt  = IFID_inst[10:6];
	wire [5:0] funct  = IFID_inst[5:0];
	wire [15:0] immi  = IFID_inst[15:0];
	wire [25:0] immj  = IFID_inst[25:0];

	// Sign extend the immediate
	wire [31:0]		ext_imm;

	// RF-related wires
	wire [31:0]		rd_data1;
	wire [31:0]		rd_data2;
	reg [4:0]		wr_addr;
	reg [31:0]		wr_data;

	// MEM-related wires
	wire [31:0]		mem_read_data;

	// ALU-related wires
	wire [31:0]		operand1;
	wire [31:0]		operand2;
	wire [31:0]		alu_result;

	assign halt = MEMWB_valid && (MEMWB_inst == 32'b0);

	//control signal
	CTRL ctrl (
      .opcode(opcode),
      .funct(funct),
      .RegDst(RegDst),
      .ALUSrc(ALUSrc),
      .MemRead(MemRead),
      .MemWrite(MemWrite),
      .MemtoReg(MemtoReg),
      .RegWrite(RegWrite),
      .Branch(Branch),
      .Jump(Jump),
      .JAL(JAL),
      .JR(JR),
      .SavePC(SavePC),
      .SignExtend(SignExtend),
      .ALUOp(ALUOp)
  	);

	//register file
	RF rf (
		.clk(clk),
		.rst(rst),
		.rd_addr1(rs),
		.rd_addr2(rt),
		.rd_data1(rd_data1),
		.rd_data2(rd_data2),
		.RegWrite(MEMWB_valid && MEMWB_RegWrite),
		.wr_addr(wr_addr),
		.wr_data(wr_data)
	);

	//memory
	MEM mem (
		.clk(clk),
		.rst(rst),
		.inst_addr(PC),
		.inst(fetched_inst),
		.mem_addr(EXMEM_alu_result),
		.MemWrite(EXMEM_valid && EXMEM_MemWrite),
		.mem_write_data(EXMEM_write_data),
		.mem_read_data(mem_read_data)
	);

	//sign-extension (sign check!)
	assign ext_imm = (SignExtend && immi[15]==1'b1) ? {16'hffff, immi} : {16'h0000, immi};
	
	//ALU
	assign operand1 = IDEX_rd_data1;
	assign operand2 = IDEX_ALUSrc? IDEX_ext_imm : IDEX_rd_data2;

	wire [4:0] dest_reg;
	assign dest_reg = IDEX_SavePC ? 5'd31 : IDEX_RegDst? IDEX_rd : IDEX_rt;

	//branch와 jump
	wire [31:0] branch_target;
  	wire [31:0] jump_target;
  	wire        branch_taken;
  	wire        jump_taken;
  	wire [31:0] next_PC;

	assign branch_target = IDEX_PC + (IDEX_ext_imm << 2);
  	assign jump_target   = {IDEX_PC[31:28], IDEX_immj, 2'b00};

  	assign branch_taken = IDEX_valid && IDEX_Branch && (alu_result == 32'b1);
  	assign jump_taken   = IDEX_valid && (IDEX_Jump || IDEX_JR);

  	assign next_PC = (jump_taken && IDEX_JR) ? IDEX_rd_data1 :(branch_taken ? branch_target : (jump_taken ? jump_target : PC + 32'd4));

	//flush
	wire flush;
	assign flush = branch_taken || jump_taken;

	ALU alu (
		.operand1(operand1), 
		.operand2(operand2), 
		.shamt(IDEX_shamt),
		.funct(IDEX_ALUOp),
		.alu_result(alu_result)
	);

	//stall
	wire stall;

  	HAZARD hazard (
      .IFID_opcode(opcode),
      .IFID_funct(funct),
      .IFID_rs(rs),
      .IFID_rt(rt),

      .IDEX_dest_reg(dest_reg),
      .IDEX_RegWrite(IDEX_RegWrite),

      .EXMEM_dest_reg(EXMEM_dest_reg),
      .EXMEM_RegWrite(EXMEM_RegWrite),

      .MEMWB_dest_reg(MEMWB_dest_reg),
      .MEMWB_RegWrite(MEMWB_RegWrite),

      .stall(stall)
  	);


	always @(*) begin
		wr_addr = MEMWB_dest_reg;
		wr_data = (MEMWB_SavePC) ? MEMWB_PC :
            	(MEMWB_MemtoReg) ? MEMWB_mem_read_data : MEMWB_alu_result;
	end


	// Update the Clock
	always @(posedge clk) begin
      if (rst) begin
          // PC
          PC <= 32'b0;

          // IF-ID
          IFID_PC <= 32'b0;
          IFID_inst <= 32'b0;
          IFID_valid <= 1'b0;

          // ID-EX 
          IDEX_PC <= 32'b0;
          IDEX_rd_data1 <= 32'b0;
          IDEX_rd_data2 <= 32'b0;
          IDEX_ext_imm <= 32'b0;
          IDEX_rs <= 5'b0;
          IDEX_rt <= 5'b0;
          IDEX_rd <= 5'b0;
          IDEX_shamt <= 5'b0;
          IDEX_opcode <= 6'b0;
          IDEX_funct <= 6'b0;
          IDEX_immj <= 26'b0;
          IDEX_inst <= 32'b0;
          IDEX_valid <= 1'b0;

          // ID-EX control
          IDEX_RegDst <= 1'b0;
          IDEX_ALUSrc <= 1'b0;
          IDEX_MemRead <= 1'b0;
          IDEX_MemWrite <= 1'b0;
          IDEX_MemtoReg <= 1'b0;
          IDEX_RegWrite <= 1'b0;
          IDEX_Branch <= 1'b0;
          IDEX_Jump <= 1'b0;
          IDEX_JAL <= 1'b0;
          IDEX_JR <= 1'b0;
          IDEX_SavePC <= 1'b0;
          IDEX_ALUOp <= `ALU_ADDU;

          // EX-MEM 
          EXMEM_alu_result <= 32'b0;
          EXMEM_write_data <= 32'b0;
          EXMEM_PC <= 32'b0;
          EXMEM_inst <= 32'b0;
          EXMEM_dest_reg <= 5'b0;
          EXMEM_valid <= 1'b0;

          // EX-MEM control
          EXMEM_RegWrite <= 1'b0;
          EXMEM_MemtoReg <= 1'b0;
          EXMEM_MemRead <= 1'b0;
          EXMEM_MemWrite <= 1'b0;
          EXMEM_SavePC <= 1'b0;

          // MEM-WB 
          MEMWB_alu_result <= 32'b0;
          MEMWB_PC <= 32'b0;
          MEMWB_mem_read_data <= 32'b0;
          MEMWB_inst <= 32'b0;
          MEMWB_dest_reg <= 5'b0;
          MEMWB_valid <= 1'b0;

          // MEM-WB control
          MEMWB_RegWrite <= 1'b0;
          MEMWB_MemtoReg <= 1'b0;
          MEMWB_SavePC <= 1'b0;
      end
      else begin
        //IF
		if(stall && !flush) PC <= PC;
		else PC <= next_PC;

        // IF -> ID 
        if (flush) begin
			IFID_PC <= 32'b0;
			IFID_inst <= 32'b0;
			IFID_valid <= 1'b0;
		end
		else if (stall) begin
			IFID_PC <= IFID_PC;
			IFID_inst <= IFID_inst;
			IFID_valid <= IFID_valid;
		end
		else begin
			IFID_PC <= PC + 32'd4;
			IFID_inst <= fetched_inst;
			IFID_valid <= 1'b1;
		end


          // ID -> EX 
          if(flush || stall) begin
			IDEX_PC <= 32'b0; IDEX_rd_data1 <= 32'b0; IDEX_rd_data2 <= 32'b0; IDEX_ext_imm <= 32'b0;
			IDEX_rs <= 5'b0; IDEX_rt <= 5'b0; IDEX_rd <= 5'b0;IDEX_shamt <= 5'b0;
			IDEX_opcode <= 6'b0; IDEX_funct <= 6'b0;
			IDEX_immj <= 26'b0; IDEX_inst <= 32'b0;
			IDEX_valid <= 1'b0;

			IDEX_RegDst <= 1'b0; IDEX_ALUSrc <= 1'b0; IDEX_MemRead <= 1'b0;
			IDEX_MemWrite <= 1'b0; IDEX_MemtoReg <= 1'b0; IDEX_RegWrite <= 1'b0;
			IDEX_Branch <= 1'b0; IDEX_Jump <= 1'b0; IDEX_JAL <= 1'b0;
			IDEX_JR <= 1'b0; IDEX_SavePC <= 1'b0; IDEX_ALUOp <= `ALU_ADDU;
		  end
		  else begin
			IDEX_PC <= IFID_PC;
			IDEX_rd_data1 <= rd_data1;
			IDEX_rd_data2 <= rd_data2;
			IDEX_ext_imm <= ext_imm;
			IDEX_rs <= rs;
			IDEX_rt <= rt;
			IDEX_rd <= rd;
			IDEX_shamt <= shamt;
			IDEX_opcode <= opcode;
			IDEX_funct <= funct;
			IDEX_immj <= immj;
			IDEX_inst <= IFID_inst;
			IDEX_valid <= IFID_valid;

			//control
			IDEX_RegDst <= RegDst;
			IDEX_ALUSrc <= ALUSrc;
			IDEX_MemRead <= MemRead;
			IDEX_MemWrite <= MemWrite;
			IDEX_MemtoReg <= MemtoReg;
			IDEX_RegWrite <= RegWrite;
			IDEX_Branch <= Branch;
			IDEX_Jump <= Jump;
			IDEX_JAL <= JAL;
			IDEX_JR <= JR;
			IDEX_SavePC <= SavePC;
			IDEX_ALUOp <= ALUOp;
		  end

          // EX -> MEM 
          EXMEM_alu_result <= alu_result;
          EXMEM_write_data <= IDEX_rd_data2;
          EXMEM_PC <= IDEX_PC;
          EXMEM_inst <= IDEX_inst;
          EXMEM_dest_reg <= dest_reg;
          EXMEM_valid <= IDEX_valid;

          // EX -> MEM control
          EXMEM_RegWrite <= IDEX_RegWrite;
          EXMEM_MemtoReg <= IDEX_MemtoReg;
          EXMEM_MemRead <= IDEX_MemRead;
          EXMEM_MemWrite <= IDEX_MemWrite;
          EXMEM_SavePC <= IDEX_SavePC;

          // MEM -> WB
          MEMWB_alu_result <= EXMEM_alu_result;
          MEMWB_PC <= EXMEM_PC;
          MEMWB_mem_read_data <= mem_read_data;
          MEMWB_inst <= EXMEM_inst;
          MEMWB_dest_reg <= EXMEM_dest_reg;
          MEMWB_valid <= EXMEM_valid;

          // MEM -> WB control
          MEMWB_RegWrite <= EXMEM_RegWrite;
          MEMWB_MemtoReg <= EXMEM_MemtoReg;
          MEMWB_SavePC <= EXMEM_SavePC;
      end
  end
	
endmodule
