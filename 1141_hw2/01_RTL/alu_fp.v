module alu_fp (
    input [1:0] fp_aluop,
    input [31:0] f1,
    input [31:0] f2,
    output reg [31:0] o_fp_alu_result,
    output reg o_fp_invalid

);

localparam FP_ALU_FSUB = 2'd0;
localparam FP_ALU_FMUL = 2'd1;
localparam FP_ALU_FCVT = 2'd2;
localparam FP_ALU_FCLASS = 2'd3;

wire sign_1 = f1[31];
wire sign_2 = f2[31];
wire [7:0] exp_1 = f1[30:23];
wire [7:0] exp_2 = f2[30:23];
wire [23:0] mant_1 = (exp_1 == 8'b0) ? {1'b0, f1[22:0]} : {1'b1, f1[22:0]};
wire [23:0] mant_2 = (exp_2 == 8'b0) ? {1'b0, f2[22:0]} : {1'b1, f2[22:0]};



// special cases
wire is_zero_1 = (exp_1 == 8'b0) && (mant_1[22:0] == 23'b0);
wire is_zero_2 = (exp_2 == 8'b0) && (mant_2[22:0] == 23'b0);

wire is_inf_1 = (exp_1 == 8'd255) && (mant_1[22:0] == 23'b0);
//wire is_inf_2 = (exp_2 == 8'd255) && (mant_2[22:0] == 23'b0);

wire is_nan_1 = (exp_1 == 8'd255) && (mant_1[22:0] != 23'b0);
//wire is_nan_2 = (exp_2 == 8'd255) && (mant_2[22:0] != 23'b0);

wire is_subnormal_1 = (exp_1 == 8'b0) && (mant_1[22:0] != 23'b0);
//wire is_subnormal_2 = (exp_2 == 8'b0) && (mant_2[22:0] != 23'b0);

wire [31:0] fsub_result, fmul_result, fcvt_result, fclass_result;
reg fsub_invalid, fmul_invalid, fcvt_invalid;

always@(*) begin
    case (fp_aluop)
        FP_ALU_FSUB: begin
            o_fp_alu_result = fsub_result;
            o_fp_invalid = fsub_invalid;
        end
        FP_ALU_FMUL: begin
            o_fp_alu_result = fmul_result;
            o_fp_invalid = fmul_invalid;
        end
        FP_ALU_FCVT: begin
            o_fp_alu_result = fcvt_result;
            o_fp_invalid = fcvt_invalid;
        end
        FP_ALU_FCLASS: begin
            o_fp_alu_result = fclass_result;
            o_fp_invalid = 1'b0;
        end
        default: begin
            o_fp_alu_result = 32'b0;
            o_fp_invalid = 1'b0;
        end
    endcase
end

// FSUB

wire sign_2_sub = ~sign_2; // a + (-b)
wire [7:0] exp_diff = (exp_1 > exp_2) ? (exp_1 - exp_2) : (exp_2 - exp_1);
wire [7:0] exp_large = (exp_1 >= exp_2) ? exp_1 : exp_2;
wire [26:0] mant_1_ext = {mant_1, 3'b0};
wire [26:0] mant_2_ext = {mant_2, 3'b0};

// align mantissas
wire [26:0] mant_1_shift = (exp_1 >= exp_2) ? mant_1_ext : (mant_1_ext >> exp_diff);
wire [26:0] mant_2_shift = (exp_1 >= exp_2) ? (mant_2_ext >> exp_diff) : mant_2_ext;

reg [27:0] sub_mant_sum_r;
reg sub_sign_sum_r;
reg [26:0] sub_mant_normalized_r;
reg [7:0] sub_exp_r;
reg [4:0] leading_zeros;

// mantissa addition
always@(*) begin
    if(sign_1 == sign_2_sub) begin
        sub_sign_sum_r = sign_1;
        sub_mant_sum_r = mant_1_shift + mant_2_shift;
    end else begin
        if(mant_1_shift >= mant_2_shift) begin
            sub_sign_sum_r = sign_1;
            sub_mant_sum_r = mant_1_shift - mant_2_shift;
        end else begin
            sub_sign_sum_r = sign_2_sub;
            sub_mant_sum_r = mant_2_shift - mant_1_shift;            
        end
    end
end

// normalization
reg [26:0] sub_mant_normalized_temp;
reg [7:0] sub_exp_temp;
always@(*) begin
    sub_mant_normalized_r = 0;
    sub_mant_normalized_temp = sub_mant_sum_r[26:0];
    sub_exp_r = 0;
    sub_exp_temp = exp_large;
    leading_zeros = 5'd0;

    if(sub_mant_sum_r == 28'd0) begin
        sub_mant_normalized_temp = 27'd0;
        sub_exp_temp = 8'd0;
    end
    else if(sub_mant_sum_r[27]) begin
        sub_mant_normalized_temp = sub_mant_sum_r[27:1];
        sub_exp_temp = sub_exp_temp + 1;
    end else if(!sub_mant_sum_r[26]) begin
        if(sub_mant_normalized_temp[25])      leading_zeros = 5'd1;
        else if(sub_mant_normalized_temp[24]) leading_zeros = 5'd2;
        else if(sub_mant_normalized_temp[23]) leading_zeros = 5'd3;
        else if(sub_mant_normalized_temp[22]) leading_zeros = 5'd4;
        else if(sub_mant_normalized_temp[21]) leading_zeros = 5'd5;
        else if(sub_mant_normalized_temp[20]) leading_zeros = 5'd6;
        else if(sub_mant_normalized_temp[19]) leading_zeros = 5'd7;
        else if(sub_mant_normalized_temp[18]) leading_zeros = 5'd8;
        else if(sub_mant_normalized_temp[17]) leading_zeros = 5'd9;
        else if(sub_mant_normalized_temp[16]) leading_zeros = 5'd10;
        else if(sub_mant_normalized_temp[15]) leading_zeros = 5'd11;
        else if(sub_mant_normalized_temp[14]) leading_zeros = 5'd12;
        else if(sub_mant_normalized_temp[13]) leading_zeros = 5'd13;
        else if(sub_mant_normalized_temp[12]) leading_zeros = 5'd14;
        else if(sub_mant_normalized_temp[11]) leading_zeros = 5'd15;
        else if(sub_mant_normalized_temp[10]) leading_zeros = 5'd16;
        else if(sub_mant_normalized_temp[9])  leading_zeros = 5'd17;
        else if(sub_mant_normalized_temp[8])  leading_zeros = 5'd18;
        else if(sub_mant_normalized_temp[7])  leading_zeros = 5'd19;
        else if(sub_mant_normalized_temp[6])  leading_zeros = 5'd20;
        else if(sub_mant_normalized_temp[5])  leading_zeros = 5'd21;
        else if(sub_mant_normalized_temp[4])  leading_zeros = 5'd22;
        else if(sub_mant_normalized_temp[3])  leading_zeros = 5'd23;
        else if(sub_mant_normalized_temp[2])  leading_zeros = 5'd24;
        else if(sub_mant_normalized_temp[1])  leading_zeros = 5'd25;
        else if(sub_mant_normalized_temp[0])  leading_zeros = 5'd26;
        else leading_zeros = 5'd27;

        sub_mant_normalized_temp = sub_mant_normalized_temp << leading_zeros;
        sub_exp_temp = sub_exp_temp - leading_zeros;
    end
    sub_mant_normalized_r = sub_mant_normalized_temp;
    sub_exp_r = sub_exp_temp;
end

// grounding
wire [2:0] sub_grs = sub_mant_normalized_r[2:0];
wire [22:0] sub_mant = sub_mant_normalized_r[25:3];

reg [22:0] sub_mant_rounded_r;
reg [7:0] sub_exp_rounded_r;

always@(*) begin
    fsub_invalid = 1'b0;
    sub_mant_rounded_r = 23'd0;
    sub_exp_rounded_r = 8'd0;

    if(sub_exp_r >= 8'd255) begin // overflow
        sub_exp_rounded_r = 8'd255;
        sub_mant_rounded_r = 23'd0;
        fsub_invalid = 1'b1;
    end else if($signed({1'b0, sub_exp_r}) <= 0) begin // underflow
        if (sub_mant_normalized_r != 27'd0)  fsub_invalid = 1'b1;
        sub_exp_rounded_r = 8'd0;
        sub_mant_rounded_r = 23'd0;
    end else begin //rounding
        sub_mant_rounded_r = sub_mant;
        sub_exp_rounded_r = sub_exp_r;
        if(sub_grs > 3'b100) sub_mant_rounded_r = sub_mant + 1'b1;
        else if(sub_grs == 3'b100) begin
            if(sub_mant[0]) sub_mant_rounded_r = sub_mant + 1'b1;
        end
        //mantissa overflow after rounding
        if(sub_mant_rounded_r == 24'h800000) begin
            sub_mant_rounded_r = 23'd0;
            sub_exp_rounded_r = sub_exp_rounded_r + 1'b1;
        if (sub_exp_rounded_r >= 8'd255) begin
                fsub_invalid = 1'b1;
                sub_exp_rounded_r = 8'd255;
                sub_mant_rounded_r = 23'd0;
            end
        end
    end
    
end 

assign fsub_result = (sub_exp_rounded_r == 0 && sub_mant_rounded_r == 0) ? 
                     32'd0 : {sub_sign_sum_r, sub_exp_rounded_r, sub_mant_rounded_r};


// FMUL
reg mul_sign_r;
reg [9:0] mul_exp_r;
reg [7:0] mul_exp_rounded_r;
reg [47:0] mul_mant_r;
reg [26:0] mul_mant_normalized_r;
reg [22:0] mul_mant_rounded_r;
wire [2:0] mul_grs = mul_mant_normalized_r[2:0];

always@(*) begin
    mul_sign_r = 1'd0;
    mul_exp_r = 10'd0;
    mul_exp_rounded_r = 8'd0;
    mul_mant_r = 48'd0;
    mul_mant_normalized_r = 27'd0;
    mul_mant_rounded_r = 23'd0;
    fmul_invalid = 1'b0;
    if(is_zero_1 || is_zero_2) begin
        mul_sign_r = 1'd0;
        mul_exp_rounded_r = 8'd0;
        mul_mant_rounded_r = 23'd0;
    end
    else begin
        mul_sign_r = sign_1 ^ sign_2;
        mul_exp_r = {2'b0, exp_1} + {2'b0, exp_2} - 10'd127;
        mul_mant_r = mant_1 * mant_2;
        // normalization
        if(mul_mant_r[47]) begin
            mul_mant_normalized_r = mul_mant_r[47:21];
            mul_exp_r = mul_exp_r + 1;
        end else begin
            mul_mant_normalized_r = mul_mant_r[46:20];
        end
        // overflow/underflow before rounding
        if($signed(mul_exp_r) >= $signed(10'd255)) begin
            fmul_invalid = 1'b1;
            mul_exp_rounded_r = 8'd255;
            mul_mant_rounded_r = 23'd0;
        end
        else if($signed(mul_exp_r) <= $signed(10'd0)) begin
            if(mul_mant_normalized_r != 27'd0) begin
                fmul_invalid = 1'b1;
            end
            mul_exp_rounded_r = 8'd0;
            mul_mant_rounded_r = 23'd0;
        end
        else begin // normalization
            mul_exp_rounded_r = mul_exp_r[7:0];
            mul_mant_rounded_r = mul_mant_normalized_r[25:3];
            // rounding
            if(mul_grs > 3'b100) begin
                mul_mant_rounded_r = mul_mant_normalized_r[25:3] + 1;
            end
            else if(mul_grs == 3'b100) begin
                if(mul_mant_normalized_r[3]) begin
                    mul_mant_rounded_r = mul_mant_normalized_r[25:3] + 1;
                end
            end
            //overflow after rounding
            if(mul_mant_rounded_r == 24'h800000) begin
                mul_mant_rounded_r = 23'd0;
                mul_exp_rounded_r = mul_exp_rounded_r + 1'b1;

                if(mul_exp_rounded_r >= 8'd255) begin
                    fmul_invalid = 1'b1;
                    mul_exp_rounded_r = 8'd255;
                    mul_mant_rounded_r = 23'd0;
                end
            end
        end
    end
end

assign fmul_result = ((mul_exp_rounded_r == 8'd0) && (mul_mant_rounded_r == 23'd0)) ? 
                     32'd0 : {mul_sign_r, mul_exp_rounded_r, mul_mant_rounded_r};


// FCVTWS
wire signed [8:0] fcvt_exp_actual = $signed({1'b0, exp_1}) - $signed(9'd127);

reg signed [31:0] fcvt_result_r;
reg [63:0] fcvt_mant_shifted_r, fcvt_mant_extended_r;
reg [2:0] fcvt_grs;
reg [63:0] fcvt_rounded;
integer i;
reg signed [8:0] fcvt_shift_amount_temp;  
reg [5:0] fcvt_shift_amount; 

always@(*) begin
    fcvt_result_r = 32'd0;
    fcvt_invalid = 1'b0;
    fcvt_mant_shifted_r = 64'd0;
    fcvt_mant_extended_r = 64'd0;
    fcvt_grs = 3'b0;
    fcvt_rounded = 64'b0;
    if(is_nan_1 || is_inf_1) begin
        fcvt_invalid = 1'b1;
        if(f1[22:0] != 23'd0) begin // NaN
            fcvt_result_r = 32'h7FFFFFFF; // return invalid integer
        end else begin // Inf
            fcvt_result_r = sign_1 ? 32'sh80000000 : 32'sh7FFFFFFF; // +-inf
        end
    end
    else if(fcvt_exp_actual < 0) fcvt_result_r = 32'd0;
    else if(fcvt_exp_actual >= 31) begin
        fcvt_invalid = 1'd1;
        fcvt_result_r = sign_1 ? 32'sh80000000 : 32'sh7FFFFFFF;
    end
    //normal conv
    else begin
        fcvt_mant_extended_r = {8'b0, 1'b1, f1[22:0], 32'b0}; // 1.M * 2^32
        fcvt_shift_amount_temp = 55 - fcvt_exp_actual;
        if(fcvt_shift_amount_temp <= 0) begin
            fcvt_mant_shifted_r = fcvt_mant_extended_r;
            fcvt_grs = 3'b0;
        end else if(fcvt_shift_amount_temp >= 56) begin
            fcvt_mant_shifted_r = 64'd0;
            fcvt_grs = 3'b0;
        end
        else begin
            fcvt_shift_amount = fcvt_shift_amount_temp[5:0];
            fcvt_mant_shifted_r = fcvt_mant_extended_r >> fcvt_shift_amount;

            fcvt_grs[2] = fcvt_mant_extended_r[fcvt_shift_amount - 1];
            fcvt_grs[1] = (fcvt_shift_amount > 1) ? fcvt_mant_extended_r[fcvt_shift_amount - 2] : 1'b0;
            fcvt_grs[0] = 1'b0;
            for(i = 0; i < 64; i = i + 1) begin
                if(i < fcvt_shift_amount - 2) begin
                if(fcvt_mant_extended_r[i]) fcvt_grs[0] = 1'b1;                    
                end
            end
        end
        // rounding
        if(fcvt_grs > 3'b100) begin
            fcvt_rounded = fcvt_mant_shifted_r + 1'b1;
        end else if(fcvt_grs == 3'b100) begin
            if(fcvt_mant_shifted_r[0]) fcvt_rounded = fcvt_mant_shifted_r + 1'b1;
            else fcvt_rounded = fcvt_mant_shifted_r;
        end else begin
            fcvt_rounded = fcvt_mant_shifted_r;
        end
        // sign & overflow
        if(sign_1) begin
            if(fcvt_rounded[31:0] > 32'h80000000) begin
                fcvt_invalid = 1'b1;
                fcvt_result_r = 32'sh80000000;
            end else begin
                fcvt_result_r = -$signed(fcvt_rounded[31:0]);
            end
        end
        else begin
            if(fcvt_rounded[31]) begin
                fcvt_invalid = 1'b1;
                fcvt_result_r = 32'sh7FFFFFFF;
            end else begin
                fcvt_result_r = fcvt_rounded[31:0];
            end
        end
    end
end

assign fcvt_result = fcvt_result_r;

// FCLASS
reg [31:0] fclass_result_r;
always@(*) begin
    fclass_result_r = 32'd0;

    // NaN
    if (is_nan_1) begin
        if (mant_1[22]) fclass_result_r[9] = 1'b1;  // Quiet NaN
        else fclass_result_r[8] = 1'b1;              // Signaling NaN
    end
    // Infinity
    else if (is_inf_1) begin
        if (sign_1) fclass_result_r[0] = 1'b1;       // -Inf
        else fclass_result_r[7] = 1'b1;              // +Inf
    end
    // Zero
    else if (is_zero_1) begin
        if (sign_1) fclass_result_r[3] = 1'b1;       // -0
        else fclass_result_r[4] = 1'b1;              // +0
    end
    // Subnormal
    else if (is_subnormal_1) begin
        if (sign_1) fclass_result_r[2] = 1'b1;       // -Subnormal
        else fclass_result_r[5] = 1'b1;              // +Subnormal
    end
    // Normal numbers
    else begin
        if (sign_1) fclass_result_r[1] = 1'b1;       // -Normal
        else fclass_result_r[6] = 1'b1;              // +Normal
    end
end

assign fclass_result = fclass_result_r;

endmodule
