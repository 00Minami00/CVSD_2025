module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,
    parameter FRAC_W = 10,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                      i_clk,
    input                      i_rst_n,

    input                      i_in_valid,
    output                     o_busy,
    input         [INST_W-1:0] i_inst,
    input  signed [DATA_W-1:0] i_data_a,
    input  signed [DATA_W-1:0] i_data_b,

    output                     o_out_valid,
    output        [DATA_W-1:0] o_data
);


parameter IDLE = 2'b00;
parameter MAT_INPUT = 2'b01;
parameter MAT_OUTPUT = 2'b10;

reg [1:0] state, next_state;
wire [INST_W-1:0] inst = i_inst;
wire signed [DATA_W-1:0] a = i_data_a;
wire signed [DATA_W-1:0] b = i_data_b;
reg busy;
reg out_valid;
reg [DATA_W-1:0] data;
reg [35:0] data_acc_r;
reg [3:0] cnt;
reg [1:0] mat [0:7][0:7];
integer i, j;

assign o_busy = busy;
assign o_out_valid = out_valid;
assign o_data = data;

// addition
function automatic signed [DATA_W-1:0] add;
    input signed [DATA_W-1:0] a, b;
    reg signed [DATA_W:0] sum;
    begin
        sum = a + b;
        if(sum > $signed({2'b00, {(DATA_W-1){1'b1}}})) begin
            add = {1'b0, {(DATA_W-1){1'b1}}};
        end else if(sum < $signed({2'b11, {(DATA_W-1){1'b0}}})) begin
            add = {1'b1, {(DATA_W-1){1'b0}}};
        end else begin
            add = sum[DATA_W-1:0];
        end
    end
endfunction

// subtraction
function automatic signed [DATA_W-1:0] sub;
    input signed [DATA_W-1:0] a, b;
    reg signed [DATA_W:0] diff;
    begin
        diff = a - b;
        if(diff > $signed({2'b00, {(DATA_W-1){1'b1}}})) begin
            sub = {1'b0, {(DATA_W-1){1'b1}}};
        end else if(diff < $signed({2'b11, {(DATA_W-1){1'b0}}})) begin
            sub = {1'b1, {(DATA_W-1){1'b0}}};
        end else begin
            sub = diff[DATA_W-1:0];
        end
    end
endfunction

wire signed [35:0] data_acc_w = data_acc_r;
wire signed [36:0] mac_w = a * b + data_acc_w;
wire signed [26:0] mac_res_w = (mac_w + (1 <<< 9)) >>> 10;

function automatic signed [DATA_W-1:0] MAC;
    input signed [26:0] a;
        begin
        if (a > $signed({2'b00, {(DATA_W-1){1'b1}}})) begin
            MAC = {1'b0, {(DATA_W-1){1'b1}}};
        end
        else if (a < $signed({2'b11, {(DATA_W-1){1'b0}}})) begin
            MAC = {1'b1, {(DATA_W-1){1'b0}}};
        end
        else begin
            MAC = a[15:0];
        end
    end  
endfunction

// MAC
function automatic signed [35:0] acc;
    input signed [36:0] mac;
    begin
        if(mac > $signed({2'b00, {(35){1'b1}}})) begin
            acc = {1'b0, {(35){1'b1}}};
        end else if(mac < $signed({2'b11, {(35){1'b0}}})) begin
            acc = {1'b1, {(35){1'b0}}};
        end else begin
            acc = mac[35:0];
        end
    end
endfunction

// Sin
function automatic signed [DATA_W-1:0] sin_taylor;
    input signed [15:0] a;
    reg signed [31:0] a2;
    reg signed [47:0] a3;
    reg signed [79:0] a5;
    reg signed [96:0] sin0, sin1, sin2;
    reg signed [96:0] sin_res;
    reg signed [DATA_W:0] sin;
    begin
        a2 = a * a;
        a3 = a2 * a;
        a5 = a3 * a2;
        sin0 = a <<< 50;
        sin1 = (16'sh00ab * a3) <<< 20;
        sin2 = 16'sh0009 * a5;
        sin_res = sin0 - sin1 + sin2 + (1 <<< 49);
        sin = sin_res[66:50];
        if(sin > $signed({2'b00, {(DATA_W-1){1'b1}}})) begin
            sin_taylor = {1'b0, {(DATA_W-1){1'b1}}};
        end else if(sin < $signed({2'b11, {(DATA_W-1){1'b0}}})) begin
            sin_taylor = {1'b1, {(DATA_W-1){1'b0}}};
        end else begin
            sin_taylor = sin[DATA_W-1:0];
        end      
    end
endfunction 

// Binary to Gray Code
function automatic [DATA_W-1:0] B2G;
    input [DATA_W-1:0] a;
    reg [DATA_W-1:0] temp;
    begin
        temp = a >> 1'b1;
        B2G = temp ^ a;
    end
endfunction    

// LRCW
function automatic [DATA_W-1:0] LRCW;
    input [DATA_W-1:0] a, b;
    integer i;
    reg [DATA_W-1:0] temp;
    begin
        temp = b;
        for(i = 0; i < DATA_W; i = i + 1) begin
            temp = a[i] ? {temp[DATA_W-2:0], ~temp[DATA_W-1]} : temp;
        end
        LRCW = temp;
    end
endfunction

// Right Rotation
function automatic [DATA_W-1:0] RROT;
    input [DATA_W-1:0] a, b;
    integer i;
    reg [3:0] count, bb;
    reg [DATA_W-1:0] temp;
    begin
        temp = a;
        bb = b[3:0];
        count = 4'b0;
        for(i = 0; i < DATA_W; i = i + 1) begin
            temp = (count < bb) ? {temp[0], temp[DATA_W-1:1]} : temp;
            count = (count < bb) ? count + 1 : count;
        end
        RROT = temp;
    end
endfunction

//  Count Leading Zero
function automatic [DATA_W-1:0] CLZ;
    input [DATA_W-1:0] a;
    integer i;
    reg stop;
    begin
        CLZ = 0;
        stop = 0;
        for(i = DATA_W - 1; i >= 0; i = i - 1) begin
            if(!stop) begin
                CLZ = a[i] ? CLZ : CLZ + 1;
                stop = a[i] ? 1 : 0;
            end
        end
    end
endfunction

// Reverse Match4
function automatic [DATA_W-1:0] RM4;
    input [DATA_W-1:0] a, b;
    integer i;
    begin
        RM4 = 0;
        for(i = 0; i < 13; i = i + 1) begin
            RM4[i] = (a[i +: 4] == b[15-i -: 4]);
        end
    end    
endfunction

// FSM
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case(state)
        IDLE: begin
            if(i_in_valid) begin
                case(i_inst)
                    4'b1001: next_state = MAT_INPUT;
                    default: next_state = IDLE;
                endcase
            end
        end
        MAT_INPUT: begin
            if(cnt == 7 && i_in_valid) next_state = MAT_OUTPUT;
            else next_state = MAT_INPUT;
        end
        MAT_OUTPUT: begin
            if(cnt == 8) next_state = IDLE;
            else next_state = MAT_OUTPUT;
        end
    endcase
end

always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        busy <= 0;
        out_valid <=0;
        data <= 0;
        data_acc_r <= 0;
        cnt <= 0;
        for(i = 0; i < 8; i = i + 1) begin
            for(j = 0; j < 8; j = j + 1) begin
                mat[i][j] <= 0;
            end
        end
    end else begin
        case(state)
            IDLE:begin
                out_valid <= 0;
                busy <= 0;
                if(i_in_valid) begin
                    case (inst)
                        4'b0000: data <= add(a, b);
                        4'b0001: data <= sub(a, b);
                        4'b0010: begin
                            data <= MAC(mac_res_w);
                            data_acc_r <= acc(mac_w);
                        end
                        4'b0011: data <= sin_taylor(a);
                        4'b0100: data <= B2G(a);
                        4'b0101: data <= LRCW(a, b);
                        4'b0110: data <= RROT(a, b);
                        4'b0111: data <= CLZ(a);
                        4'b1000: data <= RM4(a, b);
                        4'b1001: begin
                            for(i = 0; i < 8; i = i + 1) begin
                                mat[0][i] <= i_data_a[(i << 1) +:2];
                            end
                            cnt <= 1;
                        end
                        default: data <= {DATA_W{1'b0}};
                    endcase    
                    out_valid <= (inst != 4'b1001) ? 1'b1 : 0;
                    busy <= (inst != 4'b1001) ? 1'b1 : 0;
                end else begin
                    out_valid <= 1'b0;
                end
            end
            MAT_INPUT: begin // Matrix Transpose
                if(i_in_valid) begin
                        for(i = 0; i < 8; i = i + 1) begin
                            mat[cnt[2:0]][i] <= i_data_a[(i << 1) +:2];
                        end
                        cnt <= (cnt == 7) ? 0 : cnt + 1;
                        busy <= (cnt == 7) ? 1 : 0;
                end
            end
            MAT_OUTPUT: begin
                if(cnt < 8) begin
                    data <= {mat[0][7-cnt], mat[1][7-cnt], mat[2][7-cnt], mat[3][7-cnt],
                            mat[4][7-cnt], mat[5][7-cnt], mat[6][7-cnt], mat[7][7-cnt]};
                    cnt <= cnt + 1;
                    out_valid <= 1'b1;
                    busy <= 1'b1;
                end else begin
                    cnt <= 0;
                    out_valid <= 0;
                    busy <= 0;                    
                end
            end
            default: begin
                
            end
        endcase
    end 
end

endmodule