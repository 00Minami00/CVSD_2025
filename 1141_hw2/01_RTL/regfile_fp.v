module regfile_fp #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input i_clk,
    input i_rst_n,

    input [4:0] i_read_addr1,
    input [4:0] i_read_addr2,
    input i_wen,
    input [4:0] i_write_addr,
    input [DATA_WIDTH-1:0] i_write_data,

    output [DATA_WIDTH-1:0] o_f1,
    output [DATA_WIDTH-1:0] o_f2
);

reg [DATA_WIDTH-1:0] reg_fp [0:31];
integer i;

assign o_f1 = reg_fp[i_read_addr1];
assign o_f2 = reg_fp[i_read_addr2];

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        for (i = 0; i < 32; i = i + 1) reg_fp[i] <= {DATA_WIDTH{1'b0}};
    end else begin
        if (i_wen) reg_fp[i_write_addr] <= i_write_data;
    end
end
endmodule