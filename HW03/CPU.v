`timescale 1ns / 1ps


module CPU(
	input		clk,
	input		rst,
	output 		halt
	);
	
	// Split the instructions
	// Instruction-related wires
	wire [31:0]		inst;
	wire [5:0]		opcode = inst[31:26];
	wire [4:0]		rs = inst[25:21];
	wire [4:0]		rt = inst[20:16];
	wire [4:0]		rd = inst[15:11];
	wire [4:0]		shamt = inst[10:6];
	wire [5:0]		funct = inst[5:0];
	wire [15:0]		immi = inst[15:0];
	wire [25:0]		immj = inst[25:0];

	// Control-related wires
	wire			RegDst;
	wire			Jump;
	wire 			Branch;
	wire 			JR;
	wire			MemRead;
	wire			MemtoReg;
	wire 			MemWrite;
	wire			ALUSrc;
	wire			SignExtend;
	wire			RegWrite;
	wire [3:0]		ALUOp;
	wire			SavePC;

	// Sign extend the immediate
	wire [31:0]		ext_imm;

	// RF-related wires
	wire [4:0]		rd_addr1;
	wire [4:0]		rd_addr2;
	wire [31:0]		rd_data1;
	wire [31:0]		rd_data2;
	reg [4:0]		wr_addr;
	reg [31:0]		wr_data;

	// MEM-related wires
	wire [31:0]		mem_addr;
	wire [31:0]		mem_write_data;
	wire [31:0]		mem_read_data;

	// ALU-related wires
	wire [31:0]		operand1;
	wire [31:0]		operand2;
	wire [31:0]		alu_result;

	// Define PC
	reg [31:0]	PC = 0;
	reg [31:0]	PC_next;

	assign halt				= (inst == 32'b0);

	//control signal
	CTRL ctrl (
		.opcode(opcode),
		.funct(funct),
		.RegDst(RegDst),
		.Jump(Jump),
		.Branch(Branch),
		.JR(JR),
		.MemRead(MemRead),
		.MemtoReg(MemtoReg),
		.MemWrite(MemWrite),
		.ALUSrc(ALUSrc),
		.SignExtend(SignExtend),
		.RegWrite(RegWrite),
		.ALUOp(ALUOp),
		.SavePC(SavePC)
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

	//memory
	MEM mem (
		.clk(clk),
		.rst(rst),
		.inst_addr(PC),
		.inst(inst),
		.mem_addr(alu_result),
		.MemWrite(MemWrite),
		.mem_write_data(rd_data2),
		.mem_read_data(mem_read_data)
	);

	//sign-extension (sign check!)
	assign ext_imm = (SignExtend && immi[15]==1'b1) ? {16'hffff, immi} : {16'h0000, immi};
	
	//ALU
	assign operand1 = rd_data1;
	assign operand2 = (ALUSrc) ? ext_imm : rd_data2;
	ALU alu (
		.operand1(operand1), //shamt or rd_data1
		.operand2(operand2), //immediate or rd_data2
		.shamt(shamt),
		.funct(ALUOp),
		.alu_result(alu_result)
	);

	always @(*) begin
		//RF부터
		wr_addr = (SavePC) ? 5'd31 : ((RegDst) ? rd : rt);
		wr_data = (SavePC) ? (PC + 4) : ((MemtoReg) ? mem_read_data : alu_result);

		//PC 결정
		if(Jump && JR) begin
			PC_next = rd_data1;
		end else if(Jump && !JR) begin
			PC_next = {PC[31:28], immj , 2'b00};	
		end else if(Branch && ((ALUOp == 4'b1011 && alu_result == 1) || (ALUOp == 4'b1100 && alu_result == 1))) begin
			PC_next = (PC + 4)+(ext_imm << 2);//beq and bne
		end else begin
			PC_next = PC+4;
		end
	end


	// Update the Clock
	always @(posedge clk) begin
		if (rst)	PC <= 0;
		else begin
			PC <= PC_next;
		end
	end
	
endmodule
