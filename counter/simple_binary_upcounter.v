module simple_binary_upcounter #(parameter BITS = 1)
                (input wire clk, input wire rst, input wire ena,
                output wire [BITS - 1:0] out, output wire ovf);

reg [BITS - 1:0] cnt;
wire [BITS:0] enable_wires;

initial begin
    cnt <= 0;
end

assign out = cnt;
assign enable_wires[0] = ena;
assign ovf = enable_wires[BITS];// & clk;

genvar i;
generate
for(i = 0; i < BITS; i = i + 1) begin: gen_cnt
    
    assign enable_wires[i + 1] = cnt[i] & enable_wires[i];
    
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            cnt [i] <= 1'b0;
        end else if(enable_wires[i]) begin
            cnt [i] <= ~cnt[i];
        end
    end
end
endgenerate

endmodule
