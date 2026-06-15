`timescale 1ns / 1ps
`include "GLOBAL.v"

//2'b00 = empty
//2'b01 = branch
//2'b10 = jump
//2'b11 = unused

module BP(
    input clk,
    input rst,

    //prediction
    input [31:0] pc,
    output [31:0] predicted_pc,

    //EX에 update
    input update,
    input [31:0] update_pc,
    input update_branch,
    input update_jump,
    input update_taken,
    input [31:0] update_target
);

    reg BTB_valid [0:63];
    reg [1:0] BTB_type [0:63];
    reg [23:0] BTB_tag [0:63];
    reg [31:0] BTB_target [0:63];

    reg [1:0] PHT [0:255];

    wire [5:0] BTB_idx = pc[7:2];
    wire [7:0] PHT_idx = pc[9:2];
    wire [23:0] tag = pc[31:8];

    //결과 저장용
    wire BTB_hit;
    wire predict_taken;

    assign BTB_hit = BTB_valid[BTB_idx] && (BTB_tag[BTB_idx] == tag);
    assign predict_taken = PHT[PHT_idx][1];

    assign predicted_pc = (BTB_hit && (BTB_type[BTB_idx] == 2'b10)) ? BTB_target[BTB_idx] :
                        (BTB_hit && (BTB_type[BTB_idx] == 2'b01) && predict_taken) ? BTB_target[BTB_idx]: pc+32'd4;

    //update
    wire [5:0] update_BTB_idx = update_pc[7:2];
    wire [7:0] update_PHT_idx = update_pc[9:2];
    wire [23:0] update_tag = update_pc[31:8];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for(i = 0; i < 64; i=i+1) begin
                BTB_valid[i] <= 1'b0;
                BTB_type[i] <= 2'b00;
                BTB_tag[i] <= 24'b0;
                BTB_target[i] <= 32'b0;
            end

            for(i=0; i<256; i=i+1) begin
                PHT[i] <= 2'b01;
            end
        end
        else if (update) begin
            BTB_valid[update_BTB_idx] <= 1'b1;
            BTB_tag[update_BTB_idx] <= update_tag;
            BTB_target[update_BTB_idx] <= update_target;

            if (update_branch) begin
                BTB_type[update_BTB_idx] <= 2'b01;

                if(update_taken && PHT[update_PHT_idx] != 2'b11)
                    PHT[update_PHT_idx] <= PHT[update_PHT_idx] + 2'b01;
                else if(!update_taken && PHT[update_PHT_idx] != 2'b00)
                    PHT[update_PHT_idx] <= PHT[update_PHT_idx] - 2'b01;
            end
            else if (update_jump) begin
                BTB_type[update_BTB_idx] <= 2'b10;
            end
        end
    end

endmodule
