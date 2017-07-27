module binary_updown_counter #(parameter BITS = 1)
        (input wire clk, input wire rst, input wire ena,
         input wire updown, output wire [BITS - 1:0] out, output wire ovf);

reg [BITS - 1:0] cnt;
wire [BITS:0] enable_wires;

initial begin
    cnt <= {(BITS){1'b0}};
end


assign ovf = enable_wires[BITS] & ena;// & clk;
assign out = cnt;

assign enable_wires[0] = ena;

genvar i;
generate
for(i = 0; i < BITS; i = i + 1) begin: gen_cnt
    
    assign enable_wires[i + 1] = (cnt[i] & enable_wires[i] & updown) |
                                 (~cnt[i] & enable_wires[i] & ~updown);
    
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            if(updown)
                cnt [i] <= 1'b0;
            else
                cnt [i] <= 1'b1;
        end else if(ena) begin
            if(enable_wires[i]) begin
                cnt [i] <= ~cnt[i];
            end
        end
    end
end
endgenerate

endmodule
