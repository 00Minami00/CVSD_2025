//`include "../00_TB/define.v"
module control (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,

    output reg [1:0] branch,  // beq/blt
    output reg memread,  //lw
    output reg memwrite,  //sw
    //output reg memtoreg,  //lw
    output reg [1:0] aluop, 
    output reg alusrc,  // ALU imm
    output reg regwrite,

    output reg [1:0] fp_aluop, // fsub, fmul, fcvt, fclass
    output reg fp_regwrite,
    output reg fp_memtoreg,
    output reg fp_memwrite,

    output reg jump_jalr,
    //output reg useimu,  // auipc use imm_U
    output reg eof, //EOF
    //output reg valid,  // invalid instruction = 0
    output reg [2:0] wb_src,

    output reg [2:0] insttype
);
localparam WB_ALU = 3'd0;
localparam WB_MEM = 3'd1;
localparam WB_PC4 = 3'd2;
localparam WB_PC_U = 3'd3;
localparam WB_FP_ALU = 3'd4;

localparam BR_NONE = 2'd0;
localparam BR_BEQ = 2'd1;
localparam BR_BLT = 2'd2;

localparam ALU_ADD = 2'd0;
localparam ALU_SUB = 2'd1;
localparam ALU_SLT = 2'd2;
localparam ALU_SRL = 2'd3;

localparam FP_ALU_FSUB = 2'd0;
localparam FP_ALU_FMUL = 2'd1;
localparam FP_ALU_FCVT = 2'd2;
localparam FP_ALU_FCLASS = 2'd3;

always @(*) begin
    branch = BR_NONE;
    memread = 1'b0;
    memwrite = 1'b0;
    //memtoreg = 1'b0;
    aluop = ALU_ADD;
    alusrc = 1'b0;
    regwrite = 1'b0;
    jump_jalr = 1'b0;
    //useimu = 1'b0;
    eof = 1'b0;
    //valid = 1'b1;
    wb_src = WB_ALU;
    fp_aluop = FP_ALU_FSUB;
    fp_regwrite = 1'b0;
    fp_memtoreg = 1'b0;
    fp_memwrite = 1'b0;
    insttype = `INVALID_TYPE;
    case (opcode)
        `OP_SUB: begin //, `OP_SLT, `OP_SRL
            if((funct3 == `FUNCT3_SUB) && (funct7 == `FUNCT7_SUB)) begin
                regwrite = 1; aluop = ALU_SUB; insttype = `R_TYPE;
            end else if((funct3 == `FUNCT3_SLT) && (funct7 == `FUNCT7_SLT)) begin
                regwrite = 1; aluop = ALU_SLT; insttype = `R_TYPE;
            end else begin
                regwrite = 1; aluop = ALU_SRL; insttype = `R_TYPE;
            end
        end
            `OP_ADDI: begin
                regwrite = 1; aluop = ALU_ADD; alusrc = 1; insttype = `I_TYPE;
            end
        // lw
        `OP_LW: begin
            memread = 1; aluop = ALU_ADD; alusrc = 1; wb_src = WB_MEM;
            //memtoreg = 1;
             regwrite = 1; insttype = `I_TYPE;
        end
        // sw
        `OP_SW: begin
            memwrite = 1; aluop = ALU_ADD; alusrc = 1; insttype = `S_TYPE;
        end
        // beq / blt
        `OP_BEQ: begin //, `OP_BLT
            insttype = `B_TYPE;
            if(funct3 == `FUNCT3_BEQ) branch = BR_BEQ;
            else branch = BR_BLT;
        end
        // jalr
        `OP_JALR: begin
            regwrite = 1; wb_src = WB_PC4; jump_jalr = 1; aluop = ALU_ADD;
            alusrc = 1; insttype = `I_TYPE;
        end
        //auipc
        `OP_AUIPC: begin
            regwrite = 1; wb_src = WB_PC_U; aluop = ALU_ADD; insttype = `U_TYPE; //useimu = 1;
        end
        // EOF
        `OP_EOF: begin
            eof = 1'b1;
            insttype = `EOF_TYPE;
        end
        // flw
        `OP_FLW: begin
            memread = 1; aluop = ALU_ADD; alusrc = 1;
            fp_memtoreg = 1; fp_regwrite = 1; insttype = `I_TYPE;
        end
        `OP_FSW: begin
            fp_memwrite = 1; aluop = ALU_ADD; alusrc = 1; insttype = `S_TYPE;
        end
        `OP_FSUB: begin //, `OP_FMUL, `OP_FCVTWS, `OP_FCLASS
            if((funct3 == `FUNCT3_FSUB) && (funct7 == `FUNCT7_FSUB)) begin    
                fp_aluop = FP_ALU_FSUB; fp_regwrite = 1; insttype = `R_TYPE;
            end else if((funct3 == `FUNCT3_FMUL) && (funct7 == `FUNCT7_FMUL)) begin
                fp_aluop = FP_ALU_FMUL; fp_regwrite = 1; insttype = `R_TYPE;
            end else if((funct3 == `FUNCT3_FCVTWS) && (funct7 == `FUNCT7_FCVTWS)) begin
                fp_aluop = FP_ALU_FCVT; regwrite = 1; wb_src = WB_FP_ALU; insttype = `R_TYPE;
            end else begin
                fp_aluop = FP_ALU_FCLASS; regwrite = 1; wb_src = WB_FP_ALU; insttype = `R_TYPE;
            end
        end 
        default: begin
            //valid = 1'b0;
            insttype = `INVALID_TYPE;
        end
    endcase
end
endmodule
