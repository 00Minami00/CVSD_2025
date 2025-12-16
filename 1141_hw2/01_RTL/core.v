//`include "../00_TB/define.v"
module core #( // DO NOT MODIFY INTERFACE!!!
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) ( 
    input i_clk,
    input i_rst_n,

    // Testbench IOs
    output [2:0] o_status, 
    output       o_status_valid,

    // Memory IOs
    output [ADDR_WIDTH-1:0] o_addr,
    output [DATA_WIDTH-1:0] o_wdata,
    output                  o_we,
    input  [DATA_WIDTH-1:0] i_rdata
);

// FSM 
localparam S_IDLE = 3'd0; 
localparam S_IF = 3'd1;
localparam S_ID = 3'd2;
localparam S_EX = 3'd3;
localparam S_MEM = 3'd4;
localparam S_NEXTPC = 3'd5;
localparam S_END = 3'd6;

reg [2:0] state, next_state;

// PC and instruction
reg [ADDR_WIDTH-1:0] PC, NEXT_PC, pc_plus4_r, pc_base_r;
reg [DATA_WIDTH-1:0] inst_r;
//reg [DATA_WIDTH-1:0] load_data_r;

// instruction decode
wire [6:0] opcode = inst_r[6:0];
wire [6:0] funct7 = inst_r[31:25];
wire [2:0] funct3 = inst_r[14:12];
wire [4:0] r1 = inst_r[19:15];
wire [4:0] r2 = inst_r[24:20];
wire [4:0] rd = inst_r[11:7];
wire [31:0] im_I = {{20{inst_r[31]}}, inst_r[31:20]};
wire [31:0] im_S = {{20{inst_r[31]}}, inst_r[31:25], inst_r[11:7]};
wire [31:0] im_B = {{20{inst_r[31]}}, inst_r[7], inst_r[30:25], inst_r[11:8], 1'b0};
wire [31:0] im_U = {inst_r[31:12], 12'b0};

// regfile
wire [DATA_WIDTH-1:0] r1_data, r2_data;
reg rf_int_wen;
reg [4:0] rf_int_waddr;
reg [DATA_WIDTH-1:0] rf_int_wdata;

regfile_int u_rf_int(
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_read_addr1(r1), .i_read_addr2(r2),
    .i_wen(rf_int_wen), .i_write_addr(rf_int_waddr), .i_write_data(rf_int_wdata),
    .o_r1(r1_data), .o_r2(r2_data)
);

wire [DATA_WIDTH-1:0] f1_data, f2_data;
reg rf_fp_wen;
reg [4:0] rf_fp_waddr;
reg [DATA_WIDTH-1:0] rf_fp_wdata;

regfile_fp u_rf_fp(
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_read_addr1(r1), .i_read_addr2(r2),
    .i_wen(rf_fp_wen), .i_write_addr(rf_fp_waddr), .i_write_data(rf_fp_wdata),
    .o_f1(f1_data), .o_f2(f2_data)
);

// ALU

reg [DATA_WIDTH-1:0] alu_in1, alu_in2;
wire [DATA_WIDTH-1:0] alu_result;
wire alu_overflow;//, alu_eq, alu_lt;
wire [1:0] aluop; 

alu_int u_alu_int(
    .aluop(aluop), .r1(alu_in1), .r2(alu_in2),
    .o_alu_result(alu_result), .o_overflow(alu_overflow)//, .o_eq(), .o_lt()
);

reg [DATA_WIDTH-1:0] fp_alu_in1, fp_alu_in2;
wire [DATA_WIDTH-1:0] fp_alu_result;
wire fp_alu_invalid;
wire [1:0] fp_aluop;

alu_fp u_alu_fp(
    .fp_aluop(fp_aluop), .f1(fp_alu_in1), .f2(fp_alu_in2),
    .o_fp_alu_result(fp_alu_result), .o_fp_invalid(fp_alu_invalid)
);

// control
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

// control
wire [1:0] branch;
wire memread;
wire memwrite;
//wire memtoreg;
//wire [1:0] aluop; 
wire alusrc;
wire regwrite;
wire fp_regwrite;
wire fp_memtoreg;
wire fp_memwrite;
wire jump_jalr;
//wire useimu;
wire eof;
//wire valid;
wire [2:0] wb_src;
wire [2:0] insttype;



control u_control(
    .opcode(opcode), .funct3(funct3), .funct7(funct7),
    .branch(branch), .memread(memread), .memwrite(memwrite),
    //.memtoreg(memtoreg),
    .aluop(aluop), .alusrc(alusrc),
    .regwrite(regwrite), 
    .fp_aluop(fp_aluop), .fp_regwrite(fp_regwrite), .fp_memtoreg(fp_memtoreg), .fp_memwrite(fp_memwrite), 
    .jump_jalr(jump_jalr),// .useimu(useimu),
    .eof(eof),// .valid(valid),
    .wb_src(wb_src), .insttype(insttype)
);

// mem addr
reg [ADDR_WIDTH-1:0] eff_addr;
reg [DATA_WIDTH-1:0] store_data;
reg [ADDR_WIDTH-1:0] o_addr_r;
reg [DATA_WIDTH-1:0] o_wdata_r;
reg o_we_r;

assign o_addr = o_addr_r;
assign o_wdata = o_wdata_r;
assign o_we = o_we_r;

// status 
reg [2:0] status_r;
assign o_status = status_r;
reg status_valid_r;
assign o_status_valid = status_valid_r;

reg invalid, invalid_r;

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        invalid_r <= 1'b0;
    end else begin
        if (state == S_EX && invalid)
        invalid_r <= 1'b1;
    end
end

// Next state Logic
always@(*) begin
    case(state)
        S_IDLE: next_state = S_IF;
        S_IF: next_state = S_ID;
        S_ID: next_state = eof? S_END : S_EX;
        S_EX: next_state = (invalid) ? S_END : S_MEM;
        S_MEM: next_state = S_NEXTPC;
        S_NEXTPC: next_state = S_IF;
        S_END: next_state = S_END;
        default: next_state = S_IDLE;
    endcase
end

always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) state <= S_IDLE;
    else state <= next_state;
end


//combinational
always@(*) begin
    NEXT_PC = PC;
    alu_in1   = r1_data;
    alu_in2   = alusrc ? im_I : r2_data;
    fp_alu_in1 = f1_data;
    fp_alu_in2 = f2_data;
    eff_addr  = 32'd0;
    store_data= 32'd0;
    invalid = 1'b0;
    case(state)
        S_IDLE: begin                
            end
        S_IF: begin                
            end
        S_ID: begin                
            end
        S_EX: begin
            NEXT_PC = PC + 32'd4;
            //branch
            if(branch == BR_BEQ) begin
                if(r1_data == r2_data) NEXT_PC = PC + im_B;
            end else if(branch == BR_BLT) begin
                if($signed(r1_data) < $signed(r2_data)) NEXT_PC = PC + im_B;
            end
            //jump
            if(jump_jalr) begin
                NEXT_PC = ($signed(r1_data) + $signed(im_I)) & ~32'd1;
            end
            //alu
            alu_in1 = r1_data;
            alu_in2 = alusrc ? im_I : r2_data;
            if(memread) begin
                eff_addr = r1_data + im_I;
            end
            if(memwrite || fp_memwrite) begin
                eff_addr = r1_data + im_S;
                store_data = memwrite ? r2_data : f2_data;
            end
            
            //invalid
            if (!in_instr(NEXT_PC)) invalid = 1'b1;
            if (memread && (!in_data(eff_addr))) invalid = 1'b1;
            if ((memwrite || fp_memwrite) &&(!in_data(eff_addr))) invalid = 1'b1;
            if (regwrite && (wb_src==WB_ALU) &&
            ((aluop==ALU_ADD) || (aluop==ALU_SUB)) &&
            alu_overflow) invalid = 1'b1;
            if(fp_alu_invalid) invalid = 1'b1;
        end
        S_MEM: begin
        end
        S_NEXTPC: begin
        end
        S_END: begin
        end
        default: begin
        end
    endcase
end

//sequential
always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        inst_r <= 32'd0; PC <= 32'd0;
        rf_int_wen <= 1'd0; rf_int_waddr <= 5'd0; rf_int_wdata <= 32'd0;
        rf_fp_wen <= 1'd0; rf_fp_waddr <= 5'd0; rf_fp_wdata <= 32'd0;
        o_we_r <= 1'd0; o_addr_r <= 32'd0; o_wdata_r <= 32'd0;
        status_r <= 3'd0; status_valid_r <= 1'd0;
        pc_plus4_r <= 32'd0; pc_base_r <= 32'd0;
    end else begin
        o_we_r <= 1'd0;
        rf_int_wen <= 1'd0;
        rf_fp_wen <= 1'd0;
        status_r <= 3'd0;
        PC <= NEXT_PC;
        case(state)
            S_IDLE: begin
                PC <= 32'b0;
                o_addr_r <= 32'b0;
            end
            S_IF: begin
                inst_r <= i_rdata;
            end
            S_ID: begin

            end
            S_EX: begin
                if (!invalid) begin
                    if (memread) begin
                        o_we_r   <= 1'b0;
                        o_addr_r <= eff_addr;         // r1 + im_I
                    end
                    else if (memwrite || fp_memwrite) begin
                        o_we_r    <= 1'b1;
                        o_addr_r  <= eff_addr;        // r1 + im_S
                        o_wdata_r <= store_data;      // r2_data
                    end
                end 
                pc_plus4_r <= PC + 32'd4;
                pc_base_r  <= PC;   
            end
            S_MEM: begin
                o_we_r    <= 1'b0;
                status_valid_r <= 1'b1;
                status_r <= insttype;
                o_addr_r <= PC;
            end
            S_NEXTPC: begin
                status_valid_r <= 1'b0;
                if (regwrite) begin
                    rf_int_wen   <= 1'b1;
                    rf_int_waddr <= rd;
                    case (wb_src)
                        WB_ALU  : rf_int_wdata <= alu_result;
                        WB_MEM  : rf_int_wdata <= i_rdata;
                        WB_PC4  : rf_int_wdata <= pc_plus4_r;
                        WB_PC_U : rf_int_wdata <= pc_base_r + im_U;
                        WB_FP_ALU: rf_int_wdata <= fp_alu_result;
                        default : rf_int_wdata <= alu_result;
                    endcase
                end
                if(fp_regwrite) begin
                    rf_fp_wen   <= 1'b1;
                    rf_fp_waddr <= rd;
                    if(fp_memtoreg) begin
                        rf_fp_wdata <= i_rdata;
                    end
                    else begin
                        rf_fp_wdata <= fp_alu_result;
                    end
                end
            end
            S_END: begin
                status_valid_r <= 1'b1;
                status_r <= (invalid_r) ? `INVALID_TYPE : `EOF_TYPE;
            end
            default: begin                
            end
        endcase
    end 
end

function automatic in_instr;
    input signed [31:0] a;
    begin
        in_instr = (a <= 32'd4095);
    end
endfunction

function automatic in_data;
    input signed [31:0] a;
    begin
        in_data = (a >= 32'd4096) && (a <= 32'd8191);
    end
endfunction

endmodule


