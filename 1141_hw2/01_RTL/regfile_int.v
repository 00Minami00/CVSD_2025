module regfile_int #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) ( 
    input i_clk,
    input i_rst_n,

    input [4:0] i_read_addr1,
    input [4:0] i_read_addr2,
    input i_wen,
    input [4:0] i_write_addr,
    input [31:0] i_write_data,

    output [31:0] o_r1,
    output [31:0] o_r2
);

integer i;
reg[DATA_WIDTH-1:0] reg_int [0:31];

assign o_r1 = reg_int[i_read_addr1];
assign o_r2 = reg_int[i_read_addr2];

always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        for(i = 0; i < 32; i = i + 1) reg_int[i] <= {DATA_WIDTH{1'b0}};
    end else begin
        if(i_wen) reg_int[i_write_addr] <= i_write_data;
    end
end
endmodule

