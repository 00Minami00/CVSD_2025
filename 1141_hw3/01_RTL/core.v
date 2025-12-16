
module core (                       //Don't modify interface
	input      		i_clk,
	input      		i_rst_n,
	input    	  	i_in_valid,
	input 	[31: 0] i_in_data,

	output			o_in_ready,

	output	[ 7: 0]	o_out_data1,
	output	[ 7: 0]	o_out_data2,
	output	[ 7: 0]	o_out_data3,
	output	[ 7: 0]	o_out_data4,

	output	[11: 0] o_out_addr1,
	output	[11: 0] o_out_addr2,
	output	[11: 0] o_out_addr3,
	output	[11: 0] o_out_addr4,

	output 			o_out_valid1,
	output 			o_out_valid2,
	output 			o_out_valid3,
	output 			o_out_valid4,

	output 			o_exe_finish
);


// State machine
localparam S_IDLE    = 4'd0;
localparam S_WRITE   = 4'd1;
localparam S_BAR_OUT = 4'd2;
localparam S_WEIGHT  = 4'd3;
localparam S_CONV11  = 4'd4;
localparam S_CONV12  = 4'd5;
localparam S_CONV21  = 4'd6;
localparam S_CONV22  = 4'd7;
localparam S_DONE    = 4'd8;

reg [3:0] state, state_next;

//---------- Registers and wires ----------//
reg [10:0] data_cnt_r, data_cnt_w;
reg [8:0] sram_addr_r, sram_addr_w;
reg [31:0] data_buf_r, data_buf_w;


// SRAM
reg [8:0] sram1_addr, sram2_addr, sram3_addr, sram4_addr;
reg [8:0] sram5_addr, sram6_addr, sram7_addr, sram8_addr;
reg [7:0] sram1_din, sram2_din, sram3_din, sram4_din;
reg [7:0] sram5_din, sram6_din, sram7_din, sram8_din;
reg sram1_wen, sram2_wen, sram3_wen, sram4_wen;
reg sram5_wen, sram6_wen, sram7_wen, sram8_wen;
reg sram1_cen, sram2_cen, sram3_cen, sram4_cen;
reg sram5_cen, sram6_cen, sram7_cen, sram8_cen;

wire [7:0] sram1_dout, sram2_dout, sram3_dout, sram4_dout;
wire [7:0] sram5_dout, sram6_dout, sram7_dout, sram8_dout;

// SRAM CONV
reg [5:0] column_cnt_r, column_cnt_w;
reg [6:0] row_cnt_r, row_cnt_w;
reg row2_cnt_r, row2_cnt_w;

// Output
reg in_ready;
reg exe_finish;
reg [7:0]  out_data1_r, out_data2_r, out_data3_r;// out_data4_r;
reg [11:0] out_addr1_r, out_addr2_r;// out_addr3_r, out_addr4_r;
reg out_valid1_r, out_valid2_r, out_valid3_r; //out_valid4_r;

assign o_in_ready = in_ready;
assign o_out_data1 = out_data1_r;
assign o_out_data2 = out_data2_r;
assign o_out_data3 = out_data3_r;
assign o_out_data4 = 0;
assign o_out_addr1 = out_addr1_r;
assign o_out_addr2 = out_addr2_r;
assign o_out_addr3 = 0;
assign o_out_addr4 = 0;
assign o_out_valid1 = out_valid1_r;
assign o_out_valid2 = out_valid2_r;
assign o_out_valid3 = out_valid3_r;
assign o_out_valid4 = 0;
assign o_exe_finish = exe_finish;

// Bar code
reg [63:0] bar_r, bar_w, get_bar;
reg [3:0] bar_cnt_r, bar_cnt_w;
reg [56:0] bar_temp_r, bar_temp_w;

reg[3:0] bar_valid_cnt_r, bar_valid_cnt_w;
reg[2:0] bar_start_cnt_r, bar_start_cnt_w;
wire bar_valid = (bar_valid_cnt_r == 4'd10) ? 1'b1 : 1'b0;
reg [1:0] K_r, K_w, S_r, S_w, D_r, D_w;

// Weight Read
reg [2:0] weight_cnt_r, weight_cnt_w;
reg [7:0] W_r [0:8], W_w [0:8];

// Conv input
reg [7:0] conv1_in_r [0:8], conv1_in_w [0:8];
reg [7:0] conv2_in_r [0:8], conv2_in_w [0:8];
wire [7:0] conv1_out, conv2_out;
integer i;

//---------- bar code ----------//
// Bar get
always @(*) begin
    case(state)
        S_IDLE: begin
            bar_w = 64'd0;
            bar_cnt_w = 4'd0;
        end
        S_WRITE: begin
            bar_w = bar_r;
            bar_cnt_w = bar_cnt_r;
            if(data_cnt_r < 11'd1024) begin
                bar_w = {bar_r[59:0], data_buf_r[24], data_buf_r[16], data_buf_r[8], data_buf_r[0]};
                bar_cnt_w = (bar_cnt_r == 4'd15) ? 4'd0 : bar_cnt_r + 4'd1;
            end
        end
        default: begin
            bar_w = bar_r;
            bar_cnt_w = bar_cnt_r;
        end
    endcase
end

// Bar decode
always @(*) begin
    bar_temp_w = bar_temp_r;
    bar_valid_cnt_w = bar_valid_cnt_r;
    bar_start_cnt_w = bar_start_cnt_r;
    K_w = K_r;
    S_w = S_r;
    D_w = D_r;

    if(state == S_WRITE) begin
        case(bar_cnt_r)
            4'd0: begin
                if((bar_valid_cnt_r < 4'd10) && (bar_valid_cnt_r > 4'd0)) begin
                    bar_valid_cnt_w = 4'd0;
                    case(bar_start_cnt_r)
                        3'd7: if(get_bar[63:7] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd6: if(get_bar[62:6] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd5: if(get_bar[61:5] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd4: if(get_bar[60:4] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd3: if(get_bar[59:3] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd2: if(get_bar[58:2] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd1: if(get_bar[57:1] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                        3'd0: if(get_bar[56:0] == bar_temp_r) bar_valid_cnt_w = bar_valid_cnt_r + 4'd1;
                    endcase 
                end
            end
            4'd1:begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[63:53], get_bar[19:7]} == 24'b11010011100_1100011101011) begin // 7
                        bar_start_cnt_w = 3'd7;
                        case(get_bar[52:20])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[63:7];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[63:7];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[63:7];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[63:7];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd2: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[62:52], get_bar[18:6]} == 24'b11010011100_1100011101011) begin // 6
                        bar_start_cnt_w = 3'd6;
                        case(get_bar[51:19])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[62:6];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[62:6];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[62:6];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[62:6];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd3: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[61:51], get_bar[17:5]} == 24'b11010011100_1100011101011) begin // 5
                        bar_start_cnt_w = 3'd5;
                        case(get_bar[50:18])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[61:5];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[61:5];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[61:5];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[61:5];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd4: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[60:50], get_bar[16:4]} == 24'b11010011100_1100011101011) begin // 4
                        bar_start_cnt_w = 3'd4;
                        case(get_bar[49:17])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[60:4];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[60:4];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[60:4];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[60:4];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd5: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[59:49], get_bar[15:3]} == 24'b11010011100_1100011101011) begin // 3
                        bar_start_cnt_w = 3'd3;
                        case(get_bar[48:16])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[59:3];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[59:3];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[59:3];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[59:3];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd6: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[58:48], get_bar[14:2]} == 24'b11010011100_1100011101011) begin // 2
                        bar_start_cnt_w = 3'd2;
                        case(get_bar[47:15])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[58:2];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[58:2];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[58:2];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[58:2];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd7: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[57:47], get_bar[13:1]} == 24'b11010011100_1100011101011) begin // 1
                        bar_start_cnt_w = 3'd1;
                        case(get_bar[46:14])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[57:1];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[57:1];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[57:1];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[57:1];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            4'd8: begin
                if(!(|bar_valid_cnt_r)) begin
                    if({get_bar[56:46], get_bar[12:0]} == 24'b11010011100_1100011101011) begin // 0
                        bar_start_cnt_w = 3'd0;
                        case(get_bar[45:13])
                            33'b10010011000_11001101100_11001101100: begin // K=3 S=1 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 1;
                                bar_temp_w = get_bar[56:0];
                            end
                            33'b10010011000_11001101100_11001100110: begin // K=3 S=1 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 1; D_w = 2;
                                bar_temp_w = get_bar[56:0];
                            end
                            33'b10010011000_11001100110_11001101100: begin // K=3 S=2 D=1
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 1;
                                bar_temp_w = get_bar[56:0];
                            end
                            33'b10010011000_11001100110_11001100110: begin // K=3 S=2 D=2
                                bar_valid_cnt_w = 1;
                                K_w = 3; S_w = 2; D_w = 2;
                                bar_temp_w = get_bar[56:0];
                            end
                            default: begin
                                bar_valid_cnt_w = 0;
                            end
                        endcase
                    end
                end
            end
            default: begin end
        endcase
    end
end
// Bar sequential
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        bar_r <= 64'd0;
        bar_cnt_r <= 4'd0;
        get_bar <= 64'd0;
        bar_temp_r <= 57'd0;
        bar_valid_cnt_r <= 4'd0;
        bar_start_cnt_r <= 3'd0;
        K_r <= 3'd0;
        S_r <= 3'd0;
        D_r <= 3'd0;
    end else begin
        bar_r <= bar_w;
        bar_cnt_r <= bar_cnt_w;
        if(bar_cnt_r == 4'd15) get_bar <= bar_w;
        bar_temp_r <= bar_temp_w;
        bar_valid_cnt_r <= bar_valid_cnt_w;
        bar_start_cnt_r <= bar_start_cnt_w;
        K_r <= K_w;
        S_r <= S_w;
        D_r <= D_w;
    end
end
//---------- bar code end ----------//




//---------- FSM ----------//
// FSM sequential
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state <= S_IDLE;
        data_cnt_r <= 11'd0;
        sram_addr_r <= 9'd0;
        data_buf_r <= 32'd0;
        weight_cnt_r <= 2'd0;
        column_cnt_r <= 6'd0;
        row_cnt_r <= 7'd0;
        row2_cnt_r <= 1'd0;
        for(i = 0; i < 9; i = i + 1) W_r[i] <= 8'd0;
        for(i = 0; i < 9; i = i + 1) conv1_in_r[i] <= 8'd0;
        for(i = 0; i < 9; i = i + 1) conv2_in_r[i] <= 8'd0;
    end else begin
        state <= state_next;
        data_cnt_r <= data_cnt_w;
        sram_addr_r <= sram_addr_w;
        data_buf_r <= data_buf_w;
        weight_cnt_r <= weight_cnt_w;
        column_cnt_r <= column_cnt_w;
        row_cnt_r <= row_cnt_w;
        row2_cnt_r <= row2_cnt_w;
        for(i = 0; i < 9; i = i + 1) W_r[i] <= W_w[i];
        for(i = 0; i < 9; i = i + 1) conv1_in_r[i] <= conv1_in_w[i];
        for(i = 0; i < 9; i = i + 1) conv2_in_r[i] <= conv2_in_w[i];
    end
end

//---------- Next state logic ----------//
always @(*) begin
    state_next = state;
    data_cnt_w = data_cnt_r;
    sram_addr_w = sram_addr_r;
    data_buf_w = data_buf_r;
    weight_cnt_w = weight_cnt_r;
    column_cnt_w = column_cnt_r;
    row_cnt_w = row_cnt_r;
    row2_cnt_w = row2_cnt_r;
    in_ready = 1'b0;
    for(i = 0; i < 9; i = i + 1) W_w[i] = W_r[i];
    for(i = 6; i < 9; i = i + 1) conv1_in_w[i] = conv1_in_r[i];
    conv1_in_w[0] = conv1_in_r[3];
    conv1_in_w[1] = conv1_in_r[4];
    conv1_in_w[2] = conv1_in_r[5];
    conv1_in_w[3] = conv1_in_r[6];
    conv1_in_w[4] = conv1_in_r[7];
    conv1_in_w[5] = conv1_in_r[8];
    for(i = 6; i < 9; i = i + 1) conv2_in_w[i] = conv2_in_r[i];
    conv2_in_w[0] = conv2_in_r[3];
    conv2_in_w[1] = conv2_in_r[4];
    conv2_in_w[2] = conv2_in_r[5];
    conv2_in_w[3] = conv2_in_r[6];
    conv2_in_w[4] = conv2_in_r[7];
    conv2_in_w[5] = conv2_in_r[8];
    
    case (state)
        S_IDLE: begin
            in_ready = 1'b1;
            if (i_in_valid) begin
                state_next = S_WRITE;
                data_buf_w = i_in_data;
                data_cnt_w = 11'd0;
                sram_addr_w = 9'd0;
            end
        end
        
        S_WRITE: begin
            in_ready = 1'b1;
            if (data_cnt_r == 11'd1024) begin
                state_next = S_BAR_OUT;
            end  else begin
                data_buf_w = i_in_data;
                data_cnt_w = data_cnt_r + 11'd1;
                sram_addr_w = data_cnt_r + 1 >> 1;
            end
        end

        S_BAR_OUT: begin
            in_ready = 1'b1;
            state_next = (bar_valid) ? S_WEIGHT : S_DONE;
            //state_next = S_WEIGHT;
        end

        S_WEIGHT: begin
            in_ready = 1'b1;
            weight_cnt_w = weight_cnt_r + 2'd1;
            case(weight_cnt_r)
                3'd1: {W_w[0], W_w[1], W_w[2], W_w[3]} = i_in_data;
                3'd2: {W_w[4], W_w[5], W_w[6], W_w[7]} = i_in_data;
                3'd3: W_w[8] = i_in_data[31:24];
                3'd4: state_next = ({S_r, D_r} == 4'b0101) ? S_CONV11:
                                   ({S_r, D_r} == 4'b0110) ? S_CONV12:
                                   ({S_r, D_r} == 4'b1001) ? S_CONV21: S_CONV22;
                default: begin end
            endcase
        end

        S_CONV11: begin
            if(column_cnt_r == 6'd32) begin
                state_next = S_DONE;
            end else begin
                column_cnt_w = (row_cnt_r == 7'd67) ? column_cnt_r + 1 : column_cnt_r;
                row_cnt_w = (row_cnt_r == 7'd67) ? 7'd0 : row_cnt_r + 1;
                if((row_cnt_r == 7'd0) || (row_cnt_r >= 7'd65)) begin
                    conv1_in_w[6] = 0;
                    conv1_in_w[7] = 0;
                    conv1_in_w[8] = 0;

                    conv2_in_w[6] = 0;
                    conv2_in_w[7] = 0;
                    conv2_in_w[8] = 0;
                end else begin
                    case(column_cnt_r[1:0])
                        2'd0: begin
                            if(column_cnt_r == 0) begin
                                conv1_in_w[6] = 0;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram2_dout;

                                conv2_in_w[6] = sram1_dout;
                                conv2_in_w[7] = sram2_dout;
                                conv2_in_w[8] = sram3_dout;
                            end else begin
                                conv1_in_w[6] = sram8_dout;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram2_dout;

                                conv2_in_w[6] = sram1_dout;
                                conv2_in_w[7] = sram2_dout;
                                conv2_in_w[8] = sram3_dout;
                            end
                        end
                        2'd1: begin
                            conv1_in_w[6] = sram2_dout;
                            conv1_in_w[7] = sram3_dout;
                            conv1_in_w[8] = sram4_dout;

                            conv2_in_w[6] = sram3_dout;
                            conv2_in_w[7] = sram4_dout;
                            conv2_in_w[8] = sram5_dout;
                        end
                        2'd2: begin
                            conv1_in_w[6] = sram4_dout;
                            conv1_in_w[7] = sram5_dout;
                            conv1_in_w[8] = sram6_dout;

                            conv2_in_w[6] = sram5_dout;
                            conv2_in_w[7] = sram6_dout;
                            conv2_in_w[8] = sram7_dout;
                        end
                        2'd3: begin
                            if(column_cnt_r == 6'd31) begin
                                conv1_in_w[6] = sram6_dout;
                                conv1_in_w[7] = sram7_dout;
                                conv1_in_w[8] = sram8_dout;

                                conv2_in_w[6] = sram7_dout;
                                conv2_in_w[7] = sram8_dout;
                                conv2_in_w[8] = 0;
                            end else begin
                                conv1_in_w[6] = sram6_dout;
                                conv1_in_w[7] = sram7_dout;
                                conv1_in_w[8] = sram8_dout;

                                conv2_in_w[6] = sram7_dout;
                                conv2_in_w[7] = sram8_dout;
                                conv2_in_w[8] = sram1_dout;
                            end
                        end
                    endcase
                end
            end
        end
        
        S_CONV12: begin
            if(column_cnt_r == 6'd32) begin
                state_next = S_DONE;
            end else begin
                column_cnt_w = ((row2_cnt_r == 1'd1) && (row_cnt_r == 7'd35)) ? column_cnt_r + 1 : column_cnt_r;
                row_cnt_w = (row_cnt_r == 7'd35) ? 7'd0 : row_cnt_r + 1;
                row2_cnt_w = (row_cnt_r == 7'd35) ? (!row2_cnt_r) : row2_cnt_r;
                if((row_cnt_r == 7'd0) || (row_cnt_r >= 7'd33)) begin
                    conv1_in_w[6] = 0;
                    conv1_in_w[7] = 0;
                    conv1_in_w[8] = 0;

                    conv2_in_w[6] = 0;
                    conv2_in_w[7] = 0;
                    conv2_in_w[8] = 0;
                end else begin
                    case(column_cnt_r[1:0])
                        2'd0: begin
                            if(column_cnt_r == 0) begin
                                conv1_in_w[6] = 0;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram3_dout;

                                conv2_in_w[6] = 0;
                                conv2_in_w[7] = sram2_dout;
                                conv2_in_w[8] = sram4_dout;
                            end else begin
                                conv1_in_w[6] = sram7_dout;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram3_dout;

                                conv2_in_w[6] = sram8_dout;
                                conv2_in_w[7] = sram2_dout;
                                conv2_in_w[8] = sram4_dout;
                            end
                        end
                        2'd1: begin
                            conv1_in_w[6] = sram1_dout;
                            conv1_in_w[7] = sram3_dout;
                            conv1_in_w[8] = sram5_dout;

                            conv2_in_w[6] = sram2_dout;
                            conv2_in_w[7] = sram4_dout;
                            conv2_in_w[8] = sram6_dout;
                        end
                        2'd2: begin
                            conv1_in_w[6] = sram3_dout;
                            conv1_in_w[7] = sram5_dout;
                            conv1_in_w[8] = sram7_dout;

                            conv2_in_w[6] = sram4_dout;
                            conv2_in_w[7] = sram6_dout;
                            conv2_in_w[8] = sram8_dout;
                        end
                        2'd3: begin
                            if(column_cnt_r == 6'd31) begin
                                conv1_in_w[6] = sram5_dout;
                                conv1_in_w[7] = sram7_dout;
                                conv1_in_w[8] = 0;

                                conv2_in_w[6] = sram6_dout;
                                conv2_in_w[7] = sram8_dout;
                                conv2_in_w[8] = 0;
                            end else begin
                                conv1_in_w[6] = sram5_dout;
                                conv1_in_w[7] = sram7_dout;
                                conv1_in_w[8] = sram1_dout;

                                conv2_in_w[6] = sram6_dout;
                                conv2_in_w[7] = sram8_dout;
                                conv2_in_w[8] = sram2_dout;
                            end
                        end
                    endcase
                end
            end
        end

        S_CONV21: begin
            if(column_cnt_r == 6'd16) begin
                state_next = S_DONE;
            end else begin
                column_cnt_w = (row_cnt_r == 7'd66) ? column_cnt_r + 1 : column_cnt_r;
                row_cnt_w = (row_cnt_r == 7'd66) ? 7'd0 : row_cnt_r + 1;
                if((row_cnt_r == 7'd0) || (row_cnt_r >= 7'd65)) begin
                    conv1_in_w[6] = 0;
                    conv1_in_w[7] = 0;
                    conv1_in_w[8] = 0;

                    conv2_in_w[6] = 0;
                    conv2_in_w[7] = 0;
                    conv2_in_w[8] = 0;
                end else begin
                    case(column_cnt_r[0])
                        1'd0: begin
                            if(column_cnt_r == 0) begin
                                conv1_in_w[6] = 0;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram2_dout;

                                conv2_in_w[6] = sram2_dout;
                                conv2_in_w[7] = sram3_dout;
                                conv2_in_w[8] = sram4_dout;
                            end else begin
                                conv1_in_w[6] = sram8_dout;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram2_dout;

                                conv2_in_w[6] = sram2_dout;
                                conv2_in_w[7] = sram3_dout;
                                conv2_in_w[8] = sram4_dout;
                            end
                        end
                        1'd1: begin
                                conv1_in_w[6] = sram4_dout;
                                conv1_in_w[7] = sram5_dout;
                                conv1_in_w[8] = sram6_dout;

                                conv2_in_w[6] = sram6_dout;
                                conv2_in_w[7] = sram7_dout;
                                conv2_in_w[8] = sram8_dout;
                            end
                    endcase
                end
            end
        end

        S_CONV22: begin
            if(column_cnt_r == 6'd16) begin
                state_next = S_DONE;
            end else begin
                column_cnt_w = (row_cnt_r == 7'd35) ? column_cnt_r + 1 : column_cnt_r;
                row_cnt_w = (row_cnt_r == 7'd35) ? 7'd0 : row_cnt_r + 1;
                if((row_cnt_r == 7'd0) || (row_cnt_r >= 7'd33)) begin
                    conv1_in_w[6] = 0;
                    conv1_in_w[7] = 0;
                    conv1_in_w[8] = 0;

                    conv2_in_w[6] = 0;
                    conv2_in_w[7] = 0;
                    conv2_in_w[8] = 0;
                end else begin
                    case(column_cnt_r[0])
                        1'd0: begin
                            if(column_cnt_r == 6'd0) begin
                                conv1_in_w[6] = 0;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram3_dout;

                                conv2_in_w[6] = sram1_dout;
                                conv2_in_w[7] = sram3_dout;
                                conv2_in_w[8] = sram5_dout;
                            end else begin
                                conv1_in_w[6] = sram7_dout;
                                conv1_in_w[7] = sram1_dout;
                                conv1_in_w[8] = sram3_dout;

                                conv2_in_w[6] = sram1_dout;
                                conv2_in_w[7] = sram3_dout;
                                conv2_in_w[8] = sram5_dout;
                            end
                        end
                        1'd1: begin
                            if(column_cnt_r == 6'd15) begin
                                conv1_in_w[6] = sram3_dout;
                                conv1_in_w[7] = sram5_dout;
                                conv1_in_w[8] = sram7_dout;

                                conv2_in_w[6] = sram5_dout;
                                conv2_in_w[7] = sram7_dout;
                                conv2_in_w[8] = 0;
                            end else begin
                                conv1_in_w[6] = sram3_dout;
                                conv1_in_w[7] = sram5_dout;
                                conv1_in_w[8] = sram7_dout;

                                conv2_in_w[6] = sram5_dout;
                                conv2_in_w[7] = sram7_dout;
                                conv2_in_w[8] = sram1_dout;
                            end
                        end
                    endcase
                end
            end
        end

        S_DONE: begin
            state_next = S_DONE;
        end
    endcase
end



// Output Multiplexing
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        out_data1_r <= 8'd0;
        out_data2_r <= 8'd0;
        out_data3_r <= 8'd0;
        //out_data4_r <= 8'd0;
        out_addr1_r <= 12'd0;
        out_addr2_r <= 12'd0;
        //out_addr3_r <= 12'd0;
        //out_addr4_r <= 12'd0;
        out_valid1_r <= 1'b0;
        out_valid2_r <= 1'b0;
        out_valid3_r <= 1'b0;
        //out_valid4_r <= 1'b0;
    end else begin
        case (state)
            S_BAR_OUT: begin
                out_data1_r <= (bar_valid) ? {6'd0, K_r} : 8'd0;
                out_data2_r <= (bar_valid) ? {6'd0, S_r} : 8'd0;
                out_data3_r <= (bar_valid) ? {6'd0, D_r} : 8'd0;
                out_valid1_r <= 1'b1;
                out_valid2_r <= 1'b1;
                out_valid3_r <= 1'b1;
            end
            S_CONV11: begin
                if(column_cnt_r < 6'd32) begin
                    out_data1_r <= conv1_out;
                    out_data2_r <= conv2_out;
                    out_addr1_r <= row_cnt_r * 7'd64 + column_cnt_r[4:0] * 2'd2 - 9'd256;
                    out_addr2_r <= row_cnt_r * 7'd64 + column_cnt_r[4:0] * 2'd2 - 8'd255;
                    out_valid1_r <= 1'b1;
                    out_valid2_r <= 1'b1;
                end
            end
            S_CONV12: begin
                if(column_cnt_r < 6'd32) begin
                    out_data1_r <= conv1_out;
                    out_data2_r <= conv2_out;
                    out_addr1_r <= row_cnt_r * 8'd128 + row2_cnt_r * 7'd64 + column_cnt_r[4:0] * 2'd2 - 10'd512;
                    out_addr2_r <= row_cnt_r * 8'd128 + row2_cnt_r * 7'd64 + column_cnt_r[4:0] * 2'd2 - 9'd511;
                    out_valid1_r <= 1'b1;
                    out_valid2_r <= 1'b1;
                end
            end
            S_CONV21: begin
                if(column_cnt_r < 6'd16) begin
                    out_data1_r <= conv1_out;
                    out_data2_r <= conv2_out;
                    out_addr1_r <= row_cnt_r * 6'd16 + column_cnt_r[3:0] * 2'd2 - 7'd64;
                    out_addr2_r <= row_cnt_r * 6'd16 + column_cnt_r[3:0] * 2'd2 - 6'd63;
                    out_valid1_r <= (row_cnt_r[0]) ? 1'b0 : 1'b1;
                    out_valid2_r <= (row_cnt_r[0]) ? 1'b0 : 1'b1;
                end
            end
            S_CONV22: begin
                if(column_cnt_r < 6'd16) begin
                    out_data1_r <= conv1_out;
                    out_data2_r <= conv2_out;
                    out_addr1_r <= row_cnt_r * 6'd32 + column_cnt_r[3:0] * 2'd2 - 8'd128;
                    out_addr2_r <= row_cnt_r * 6'd32 + column_cnt_r[3:0] * 2'd2 - 7'd127;
                    out_valid1_r <= 1'b1;
                    out_valid2_r <= 1'b1;
                end
            end
            default: begin
                out_valid1_r <= 1'b0;
                out_valid2_r <= 1'b0;
                out_valid3_r <= 1'b0;
                //out_valid4_r <= 1'b0;
            end
        endcase
    end
end

// SRAM control
always @(*) begin
    exe_finish = 1'b0; 
    
    sram1_cen = 1'b1; sram2_cen = 1'b1; sram3_cen = 1'b1; sram4_cen = 1'b1;
    sram5_cen = 1'b1; sram6_cen = 1'b1; sram7_cen = 1'b1; sram8_cen = 1'b1;
    
    sram1_wen = 1'b1; sram2_wen = 1'b1; sram3_wen = 1'b1; sram4_wen = 1'b1;
    sram5_wen = 1'b1; sram6_wen = 1'b1; sram7_wen = 1'b1; sram8_wen = 1'b1;
    
    sram1_addr = 9'd0; sram2_addr = 9'd0; sram3_addr = 9'd0; sram4_addr = 9'd0;
    sram5_addr = 9'd0; sram6_addr = 9'd0; sram7_addr = 9'd0; sram8_addr = 9'd0;
    
    sram1_din = 8'd0; sram2_din = 8'd0; sram3_din = 8'd0; sram4_din = 8'd0;
    sram5_din = 8'd0; sram6_din = 8'd0; sram7_din = 8'd0; sram8_din = 8'd0;
    
    case (state)
        S_WRITE: begin
            if (data_cnt_r < 11'd1024) begin
                if (!data_cnt_r[0]) begin
                    // SRAM1-4
                    sram1_cen = 1'b0;
                    sram1_wen = 1'b0;
                    sram1_addr = sram_addr_r;
                    sram1_din = data_buf_r[31:24];
                    
                    sram2_cen = 1'b0;
                    sram2_wen = 1'b0;
                    sram2_addr = sram_addr_r;
                    sram2_din = data_buf_r[23:16];
                    
                    sram3_cen = 1'b0;
                    sram3_wen = 1'b0;
                    sram3_addr = sram_addr_r;
                    sram3_din = data_buf_r[15:8];
                    
                    sram4_cen = 1'b0;
                    sram4_wen = 1'b0;
                    sram4_addr = sram_addr_r;
                    sram4_din = data_buf_r[7:0];
                end else begin
                    // SRAM5-8
                    sram5_cen = 1'b0;
                    sram5_wen = 1'b0;
                    sram5_addr = sram_addr_r;
                    sram5_din = data_buf_r[31:24];
                    
                    sram6_cen = 1'b0;
                    sram6_wen = 1'b0;
                    sram6_addr = sram_addr_r;
                    sram6_din = data_buf_r[23:16];
                    
                    sram7_cen = 1'b0;
                    sram7_wen = 1'b0;
                    sram7_addr = sram_addr_r;
                    sram7_din = data_buf_r[15:8];
                    
                    sram8_cen = 1'b0;
                    sram8_wen = 1'b0;
                    sram8_addr = sram_addr_r;
                    sram8_din = data_buf_r[7:0];
                end
            end
        end
        S_CONV11: begin
            sram1_cen = 1'b0;
            sram2_cen = 1'b0;
            sram3_cen = 1'b0;
            sram4_cen = 1'b0;
            sram5_cen = 1'b0;
            sram6_cen = 1'b0;
            sram7_cen = 1'b0;
            sram8_cen = 1'b0;

            if(column_cnt_r < 6'd32) begin
                case(column_cnt_r[4:0])
                    5'd0: begin
                        sram1_wen = 1'b1; sram1_addr = row_cnt_r << 3;
                        sram2_wen = 1'b1; sram2_addr = row_cnt_r << 3;
                        sram3_wen = 1'b1; sram3_addr = row_cnt_r << 3;
                    end
                    5'd1: begin
                        sram2_wen = 1'b1; sram2_addr = row_cnt_r << 3;
                        sram3_wen = 1'b1; sram3_addr = row_cnt_r << 3;
                        sram4_wen = 1'b1; sram4_addr = row_cnt_r << 3;
                        sram5_wen = 1'b1; sram5_addr = row_cnt_r << 3;
                    end
                    5'd2: begin
                        sram4_wen = 1'b1; sram4_addr = row_cnt_r << 3;
                        sram5_wen = 1'b1; sram5_addr = row_cnt_r << 3;
                        sram6_wen = 1'b1; sram6_addr = row_cnt_r << 3;
                        sram7_wen = 1'b1; sram7_addr = row_cnt_r << 3;
                    end
                    5'd3: begin
                        sram6_wen = 1'b1; sram6_addr = row_cnt_r << 3;
                        sram7_wen = 1'b1; sram7_addr = row_cnt_r << 3;
                        sram8_wen = 1'b1; sram8_addr = row_cnt_r << 3;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 1;
                    end
                    5'd4: begin
                        sram8_wen = 1'b1; sram8_addr = row_cnt_r << 3;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 1;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 1;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 1;
                    end
                    5'd5: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 1;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 1;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 1;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 1;
                    end
                    5'd6: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 1;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 1;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 1;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 1;
                    end
                    5'd7: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 1;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 1;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 1;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 2;
                    end
                    5'd8: begin
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 1;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 2;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 2;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 2;
                    end
                    5'd9: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 2;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 2;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 2;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 2;
                    end
                    5'd10: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 2;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 2;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 2;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 2;
                    end
                    5'd11: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 2;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 2;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 2;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 3;
                    end
                    5'd12: begin
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 2;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 3;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 3;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 3;
                    end
                    5'd13: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 3;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 3;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 3;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 3;
                    end
                    5'd14: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 3;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 3;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 3;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 3;
                    end
                    5'd15: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 3;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 3;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 3;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 4;
                    end
                    5'd16: begin
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 3;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 4;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 4;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 4;
                    end
                    5'd17: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 4;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 4;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 4;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 4;
                    end
                    5'd18: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 4;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 4;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 4;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 4;
                    end
                    5'd19: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 4;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 4;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 4;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 5;
                    end
                    5'd20: begin
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 4;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 5;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 5;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 5;
                    end
                    5'd21: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 5;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 5;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 5;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 5;
                    end
                    5'd22: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 5;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 5;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 5;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 5;
                    end
                    5'd23: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 5;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 5;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 5;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 6;
                    end
                    5'd24: begin
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 5;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 6;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 6;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 6;
                    end
                    5'd25: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 6;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 6;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 6;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 6;
                    end
                    5'd26: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 6;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 6;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 6;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 6;
                    end
                    5'd27: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 6;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 6;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 6;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 7;
                    end
                    5'd28: begin
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 6;
                        sram1_wen = 1'b1; sram1_addr = (row_cnt_r << 3) + 7;
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 7;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 7;
                    end
                    5'd29: begin
                        sram2_wen = 1'b1; sram2_addr = (row_cnt_r << 3) + 7;
                        sram3_wen = 1'b1; sram3_addr = (row_cnt_r << 3) + 7;
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 7;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 7;
                    end
                    5'd30: begin
                        sram4_wen = 1'b1; sram4_addr = (row_cnt_r << 3) + 7;
                        sram5_wen = 1'b1; sram5_addr = (row_cnt_r << 3) + 7;
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 7;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 7;
                    end
                    5'd31: begin
                        sram6_wen = 1'b1; sram6_addr = (row_cnt_r << 3) + 7;
                        sram7_wen = 1'b1; sram7_addr = (row_cnt_r << 3) + 7;
                        sram8_wen = 1'b1; sram8_addr = (row_cnt_r << 3) + 7;
                    end
                endcase
            end
        end

        S_CONV12: begin
            sram1_cen = 1'b0;
            sram2_cen = 1'b0;
            sram3_cen = 1'b0;
            sram4_cen = 1'b0;
            sram5_cen = 1'b0;
            sram6_cen = 1'b0;
            sram7_cen = 1'b0;
            sram8_cen = 1'b0;

            if(column_cnt_r < 6'd32) begin
                case(column_cnt_r[4:0])
                    5'd0: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                    end
                    5'd1: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                    end
                    5'd2: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                    end
                    5'd3: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                    end
                    5'd4: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 8) : ((row_cnt_r) << 4);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                    end
                    5'd5: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                    end
                    5'd6: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                    end
                    5'd7: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                    end
                    5'd8: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 9) : (((row_cnt_r) << 4) + 1);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                    end
                    5'd9: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                    end
                    5'd10: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                    end
                    5'd11: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                    end
                    5'd12: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 10) : (((row_cnt_r) << 4) + 2);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                    end
                    5'd13: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                    end
                    5'd14: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                    end
                    5'd15: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                    end
                    5'd16: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 11) : (((row_cnt_r) << 4) + 3);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                    end
                    5'd17: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                    end
                    5'd18: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                    end
                    5'd19: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                    end
                    5'd20: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 12) : (((row_cnt_r) << 4) + 4);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                    end
                    5'd21: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                    end
                    5'd22: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                    end
                    5'd23: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                    end
                    5'd24: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 13) : (((row_cnt_r) << 4) + 5);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                    end
                    5'd25: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                    end
                    5'd26: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                    end
                    5'd27: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                    end
                    5'd28: begin
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 14) : (((row_cnt_r) << 4) + 6);
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                    end
                    5'd29: begin
                        sram1_wen = 1'b1; sram1_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram2_wen = 1'b1; sram2_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                    end
                    5'd30: begin
                        sram3_wen = 1'b1; sram3_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram4_wen = 1'b1; sram4_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                    end
                    5'd31: begin
                        sram5_wen = 1'b1; sram5_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram6_wen = 1'b1; sram6_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram7_wen = 1'b1; sram7_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                        sram8_wen = 1'b1; sram8_addr = row2_cnt_r ? (((row_cnt_r) << 4) + 15) : (((row_cnt_r) << 4) + 7);
                    end     
                endcase
            end 
        end

        S_CONV21: begin
            sram1_cen = 1'b0;
            sram2_cen = 1'b0;
            sram3_cen = 1'b0;
            sram4_cen = 1'b0;
            sram5_cen = 1'b0;
            sram6_cen = 1'b0;
            sram7_cen = 1'b0;
            sram8_cen = 1'b0;
            if(column_cnt_r < 6'd16) begin
                case(column_cnt_r[3:0])
                    4'd0: begin
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3);
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3);
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3);
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3);
                    end
                    4'd1: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3);
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3);
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3);
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3);
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3);
                    end
                    4'd2: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3);
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 1;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 1;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 1;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 1;
                    end
                    4'd3: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 1;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 1;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 1;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 1;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 1;
                    end
                    4'd4: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 1;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 2;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 2;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 2;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 2;
                    end
                    4'd5: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 2;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 2;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 2;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 2;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 2;
                    end
                    4'd6: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 2;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 3;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 3;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 3;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 3;
                    end
                    4'd7: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 3;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 3;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 3;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 3;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 3;
                    end
                    4'd8: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 3;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 4;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 4;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 4;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 4;
                    end
                    4'd9: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 4;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 4;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 4;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 4;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 4;
                    end
                    4'd10: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 4;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 5;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 5;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 5;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 5;
                    end
                    4'd11: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 5;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 5;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 5;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 5;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 5;
                    end
                    4'd12: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 5;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 6;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 6;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 6;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 6;
                    end
                    4'd13: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 6;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 6;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 6;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 6;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 6;
                    end
                    4'd14: begin
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 6;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 3) + 7;
                        sram2_wen = 1'b1; sram2_addr = ((row_cnt_r) << 3) + 7;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 3) + 7;
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 7;
                    end
                    4'd15: begin
                        sram4_wen = 1'b1; sram4_addr = ((row_cnt_r) << 3) + 7;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 3) + 7;
                        sram6_wen = 1'b1; sram6_addr = ((row_cnt_r) << 3) + 7;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 3) + 7;
                        sram8_wen = 1'b1; sram8_addr = ((row_cnt_r) << 3) + 7;
                    end
                endcase
            end
        end
        
        S_CONV22: begin
            sram1_cen = 1'b0;
            sram2_cen = 1'b0;
            sram3_cen = 1'b0;
            sram4_cen = 1'b0;
            sram5_cen = 1'b0;
            sram6_cen = 1'b0;
            sram7_cen = 1'b0;
            sram8_cen = 1'b0;
            if(column_cnt_r < 6'd16) begin
                case(column_cnt_r[3:0])
                    4'd0: begin
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4);
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4);
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4);
                    end
                    4'd1: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4);
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4);
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4);
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 1;
                    end
                    4'd2: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4);
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 1;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 1;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 1;
                    end
                    4'd3: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 1;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 1;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 1;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 2;
                    end
                    4'd4: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 1;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 2;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 2;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 2;
                    end
                    4'd5: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 2;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 2;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 2;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 3;
                    end
                    4'd6: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 2;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 3;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 3;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 3;
                    end
                    4'd7: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 3;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 3;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 3;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 4;
                    end
                    4'd8: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 3;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 4;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 4;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 4;
                    end
                    4'd9: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 4;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 4;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 4;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 5;
                    end
                    4'd10: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 4;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 5;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 5;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 5;
                    end
                    4'd11: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 5;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 5;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 5;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 6;
                    end
                    4'd12: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 5;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 6;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 6;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 6;
                    end
                    4'd13: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 6;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 6;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 6;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 7;
                    end
                    4'd14: begin
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 6;
                        sram1_wen = 1'b1; sram1_addr = ((row_cnt_r) << 4) + 7;
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 7;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 7;
                    end
                    4'd15: begin
                        sram3_wen = 1'b1; sram3_addr = ((row_cnt_r) << 4) + 7;
                        sram5_wen = 1'b1; sram5_addr = ((row_cnt_r) << 4) + 7;
                        sram7_wen = 1'b1; sram7_addr = ((row_cnt_r) << 4) + 7;
                    end
                endcase
            end
        end

        S_DONE: begin
            exe_finish = 1'b1;
        end
        default: begin end
    endcase
end

sram_512x8 sram1 (
    .Q(sram1_dout),
    .CLK(i_clk),
    .CEN(sram1_cen),
    .WEN(sram1_wen),
    .A(sram1_addr),
    .D(sram1_din)
);

sram_512x8 sram2 (
    .Q(sram2_dout),
    .CLK(i_clk),
    .CEN(sram2_cen),
    .WEN(sram2_wen),
    .A(sram2_addr),
    .D(sram2_din)
);

sram_512x8 sram3 (
    .Q(sram3_dout),
    .CLK(i_clk),
    .CEN(sram3_cen),
    .WEN(sram3_wen),
    .A(sram3_addr),
    .D(sram3_din)
);

sram_512x8 sram4 (
    .Q(sram4_dout),
    .CLK(i_clk),
    .CEN(sram4_cen),
    .WEN(sram4_wen),
    .A(sram4_addr),
    .D(sram4_din)
);

sram_512x8 sram5 (
    .Q(sram5_dout),
    .CLK(i_clk),
    .CEN(sram5_cen),
    .WEN(sram5_wen),
    .A(sram5_addr),
    .D(sram5_din)
);

sram_512x8 sram6 (
    .Q(sram6_dout),
    .CLK(i_clk),
    .CEN(sram6_cen),
    .WEN(sram6_wen),
    .A(sram6_addr),
    .D(sram6_din)
);

sram_512x8 sram7 (
    .Q(sram7_dout),
    .CLK(i_clk),
    .CEN(sram7_cen),
    .WEN(sram7_wen),
    .A(sram7_addr),
    .D(sram7_din)
);

sram_512x8 sram8 (
    .Q(sram8_dout),
    .CLK(i_clk),
    .CEN(sram8_cen),
    .WEN(sram8_wen),
    .A(sram8_addr),
    .D(sram8_din)
);

conv_mult u_conv_mult1 (
    .in1(conv1_in_r[0]),
    .in2(conv1_in_r[1]),
    .in3(conv1_in_r[2]),
    .in4(conv1_in_r[3]),
    .in5(conv1_in_r[4]),
    .in6(conv1_in_r[5]),
    .in7(conv1_in_r[6]),
    .in8(conv1_in_r[7]),
    .in9(conv1_in_r[8]),
    .w1(W_r[0]),
    .w2(W_r[1]),
    .w3(W_r[2]),
    .w4(W_r[3]),
    .w5(W_r[4]),
    .w6(W_r[5]),
    .w7(W_r[6]),
    .w8(W_r[7]),
    .w9(W_r[8]),
    .clk(i_clk),
    .rst_n(i_rst_n),
    .o_conv(conv1_out)
);

conv_mult u_conv_mult2 (
    .in1(conv2_in_r[0]),
    .in2(conv2_in_r[1]),
    .in3(conv2_in_r[2]),
    .in4(conv2_in_r[3]),
    .in5(conv2_in_r[4]),
    .in6(conv2_in_r[5]),
    .in7(conv2_in_r[6]),
    .in8(conv2_in_r[7]),
    .in9(conv2_in_r[8]),
    .w1(W_r[0]),
    .w2(W_r[1]),
    .w3(W_r[2]),
    .w4(W_r[3]),
    .w5(W_r[4]),
    .w6(W_r[5]),
    .w7(W_r[6]),
    .w8(W_r[7]),
    .w9(W_r[8]),
    .clk(i_clk),
    .rst_n(i_rst_n),
    .o_conv(conv2_out)
);

endmodule


module conv_mult( //2-pipeline
    input [7:0] in1,
    input [7:0] in2,
    input [7:0] in3,
    input [7:0] in4,
    input [7:0] in5,
    input [7:0] in6,
    input [7:0] in7,
    input [7:0] in8,
    input [7:0] in9,

    input signed [7:0] w1,
    input signed [7:0] w2,
    input signed [7:0] w3,
    input signed [7:0] w4,
    input signed [7:0] w5,
    input signed [7:0] w6,
    input signed [7:0] w7,
    input signed [7:0] w8,
    input signed [7:0] w9,

    input clk,
    input rst_n,

    output [7:0] o_conv
);

    wire signed [8:0] in1_s = {1'b0, in1};
    wire signed [8:0] in2_s = {1'b0, in2};
    wire signed [8:0] in3_s = {1'b0, in3};
    wire signed [8:0] in4_s = {1'b0, in4};
    wire signed [8:0] in5_s = {1'b0, in5};
    wire signed [8:0] in6_s = {1'b0, in6};
    wire signed [8:0] in7_s = {1'b0, in7};
    wire signed [8:0] in8_s = {1'b0, in8};
    wire signed [8:0] in9_s = {1'b0, in9};

    wire signed [16:0] mult1 = in1_s * w1;
    wire signed [16:0] mult2 = in2_s * w2;
    wire signed [16:0] mult3 = in3_s * w3;
    wire signed [16:0] mult4 = in4_s * w4;
    wire signed [16:0] mult5 = in5_s * w5;
    wire signed [16:0] mult6 = in6_s * w6;
    wire signed [16:0] mult7 = in7_s * w7;
    wire signed [16:0] mult8 = in8_s * w8;
    wire signed [16:0] mult9 = in9_s * w9;

    reg signed [16:0] mult1_r, mult2_r, mult3_r, mult4_r, mult5_r, mult6_r, mult7_r, mult8_r, mult9_r;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mult1_r <= 0;
            mult2_r <= 0;
            mult3_r <= 0;
            mult4_r <= 0;
            mult5_r <= 0;
            mult6_r <= 0;
            mult7_r <= 0;
            mult8_r <= 0;
            mult9_r <= 0;
        end else begin
            mult1_r <= mult1;
            mult2_r <= mult2;
            mult3_r <= mult3;
            mult4_r <= mult4;
            mult5_r <= mult5;
            mult6_r <= mult6;
            mult7_r <= mult7;
            mult8_r <= mult8;
            mult9_r <= mult9;
        end
    end

    wire signed [20:0] sum = ((mult1_r + mult2_r) + (mult3_r + mult4_r)) + ((mult5_r + mult6_r) + ((mult7_r + mult8_r) + mult9_r));
    wire signed [20:0] rounded_sum = sum + 21'sd64;
    wire signed [20:0] shifted_sum = rounded_sum >>> 7;
    
    assign o_conv = (shifted_sum < 0) ? 8'd0 :
                 (shifted_sum > 255) ? 8'd255 :
                 shifted_sum[7:0];
endmodule