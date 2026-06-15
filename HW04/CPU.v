`timescale 1ns / 1ps
`include "GLOBAL.v"

module CPU(
	input		clk,
	input		rst,
	output 		halt
	);
	reg [2:0] state, next_state;
	reg [31:0] PC, IR, MDR, A, B, ALUOut, return_address;

	localparam S_IF  = 3'd0;
	localparam S_ID  = 3'd1;
	localparam S_EX  = 3'd2;
	localparam S_MEM = 3'd3;
	localparam S_WB  = 3'd4;
	

	// Instruction-related wires
	wire [5:0]		opcode = IR[31:26];
	wire [4:0]		rs = IR[25:21];
	wire [4:0]		rt = IR[20:16];
	wire [4:0]		rd = IR[15:11];
	wire [4:0]		shamt = IR[10:6];
	wire [5:0]		funct = IR[5:0];
	wire [15:0]		immi = IR[15:0];
	wire [25:0]		immj = IR[25:0];

	// Control-related wires
	wire        IorD;
	wire        MemRead;
	wire        MemtoReg;
	wire        MemWrite;
	wire        IRWrite;
	wire        PCWrite;
	wire        PCWriteCond;
	wire        ALUSrcA;
	wire        RegDst;
	wire        RegWrite;
	wire        SavePC;
	wire        SignExtend;
	wire [1:0]  ALUSrcB;
	wire [1:0]  PCSource;
	wire [3:0]  ALUOp;

	// Sign extend the immediate
	wire [31:0]		ext_imm;

	// RF-related wires
	wire [31:0]		rd_data1;
	wire [31:0]		rd_data2;
	reg [4:0]		wr_addr;
	reg [31:0]		wr_data;

	// MEM-related wires
	wire [31:0]		mem_addr;
	wire [31:0]		mem_read_data;

	// ALU-related wires
	wire [31:0]		operand1;
	wire [31:0]		operand2;
	wire [31:0]		alu_result;

	// Define PC
	reg [31:0]	PC_next;

	assign halt				= (IR == 32'b0);

	//control signal
	CTRL ctrl (
      .opcode(opcode),
      .funct(funct),
      .state(state),
      .IorD(IorD),
      .MemRead(MemRead),
      .MemWrite(MemWrite),
      .IRWrite(IRWrite),
      .MemtoReg(MemtoReg),
      .PCWrite(PCWrite),
      .PCWriteCond(PCWriteCond),
      .ALUSrcA(ALUSrcA),
      .RegWrite(RegWrite),
      .SavePC(SavePC),
      .SignExtend(SignExtend),
      .RegDst(RegDst),
      .ALUSrcB(ALUSrcB),
      .PCSource(PCSource),
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
		.RegWrite(RegWrite),
		.wr_addr(wr_addr),
		.wr_data(wr_data)
	);

	assign mem_addr = (IorD) ? ALUOut : PC;

	//memory
	MEM mem (
		.clk(clk),
		.rst(rst),
		.mem_addr(mem_addr),
		.MemWrite(MemWrite),
		.mem_write_data(B),
		.mem_read_data(mem_read_data)
	);

	//sign-extension (sign check!)
	assign ext_imm = (SignExtend && immi[15]==1'b1) ? {16'hffff, immi} : {16'h0000, immi};
	
	//ALU
	assign operand1 = (ALUSrcA)? A : PC;
	assign operand2 = (ALUSrcB == 2'b00) ? B:
						(ALUSrcB == 2'b01) ? 32'd4:
						(ALUSrcB == 2'b10) ? ext_imm:
						(ext_imm << 2);

	ALU alu (
		.operand1(operand1), //shamt or rd_data1
		.operand2(operand2), //immediate or rd_data2
		.shamt(shamt),
		.funct(ALUOp),
		.alu_result(alu_result)
	);

	wire [31:0] jump_addr = {return_address[31:28], immj , 2'b00};

	always @(*) begin
		//RF부터
		wr_addr = (SavePC) ? 5'd31 : ((RegDst) ? rd : rt);
		wr_data = (SavePC) ? return_address : ((MemtoReg) ? MDR : ALUOut);

		//PCSource 기준으로
		case (PCSource) 
			2'b00: PC_next = alu_result;
			2'b01: PC_next = ALUOut;
			2'b10: PC_next = jump_addr;
			2'b11: PC_next = A; //jr
			default: PC_next = alu_result;
		endcase

		//state update(next_state)
		case (state) 
			S_IF: next_state = S_ID;
			S_ID: next_state = S_EX;

			S_EX: begin 
				if (opcode == `OP_LW || opcode == `OP_SW)
                  	next_state = S_MEM;
              	else if (opcode == `OP_BEQ || opcode == `OP_BNE ||
                       opcode == `OP_J || opcode == `OP_JAL ||
                       (opcode == `OP_RTYPE && funct == `FUNCT_JR))
                  	next_state = S_IF;
              	else
                  	next_state = S_WB;
			end

			S_MEM: begin 
				if (opcode == `OP_LW) next_state = S_WB;
              	else next_state = S_IF;
			end

			S_WB: next_state = S_IF;
          	default: next_state = S_IF;
		endcase
	end


	// Update the Clock
	always @(posedge clk) begin
		if (rst) begin 
			PC <= 0;
			state <= S_IF;
			IR <= 0;
			MDR <= 0;
			A <= 0;
			B <= 0;
			ALUOut <= 0;
		end
		else begin
			state <= next_state;
			ALUOut <= alu_result;

			if (IRWrite) IR <= mem_read_data;
			if (state == S_ID) begin 
				A <= rd_data1;
				B <= rd_data2;
			end

			if(state == S_IF) return_address <= alu_result;

			if(state == S_MEM && MemRead) MDR <= mem_read_data;

			if(PCWrite || (PCWriteCond && alu_result == 32'b1)) PC <= PC_next;
		end
	end
	
endmodule
