module alu_int (
    input [1:0] aluop,
    input signed [31:0] r1,
    input signed [31:0] r2,
    output reg signed [31:0] o_alu_result,
    output reg o_overflow
    //output reg o_eq,
    //output reg o_lt
);

localparam ALU_ADD = 2'd0;
localparam ALU_SUB = 2'd1;
localparam ALU_SLT = 2'd2;
localparam ALU_SRL = 2'd3;

wire signed [32:0] sum  = {r1[31], r1} + {r2[31], r2};
wire signed [32:0] diff = {r1[31], r1} - {r2[31], r2};

always @(*) begin
    o_alu_result = 32'sb0;
    o_overflow = 1'b0;
    //o_eq = (r1 == r2);
    //o_lt = (r1 < r2);
    case (aluop)
        ALU_ADD: begin
            o_alu_result = sum[31:0];
            o_overflow = (sum[32] ^ sum[31]);
        end
        ALU_SUB: begin
            o_alu_result = diff[31:0];
            o_overflow = (diff[32] ^ diff[31]);
        end
        ALU_SLT: begin
            o_alu_result = {31'd0, (r1 < r2)};
        end
        ALU_SRL: begin
            o_alu_result = r1 >> r2[4:0];
        end
    endcase
end
endmodule