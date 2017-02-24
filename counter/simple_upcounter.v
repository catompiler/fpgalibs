module simple_upcounter #(parameter BITS = 1)
        (input wire clk, input wire rst,
         input wire ena, input wire [BITS - 1:0] top,
         output wire [BITS - 1:0] out, output wire ovf);

reg [BITS - 1:0] cnt;
wire [BITS:0] enable_wires;

wire end_count = (cnt == top);

initial begin
    cnt <= {(BITS){1'b0}};
end

assign ovf = end_count & ena;// & clk;
assign out = cnt;

assign enable_wires[0] = ena;

genvar i;
generate
for(i = 0; i < BITS; i = i + 1) begin: gen_cnt
    
    assign enable_wires[i + 1] = cnt[i] & enable_wires[i];
    
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            cnt [i] <= 1'b0;
        end else if(ena) begin
            if(end_count) begin
                cnt [i] <= 1'b0;
            end else if(enable_wires[i]) begin
                cnt [i] <= ~cnt[i];
            end
        end
    end
end
endgenerate

endmodule
