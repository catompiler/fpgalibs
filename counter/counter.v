module counter #(parameter BITS = 1)
        (input wire clk, input wire rst, input wire ena,
         input wire updown, input wire [BITS - 1:0] top,
         input wire [BITS - 1:0] value, input wire load,
         output wire [BITS - 1:0] out, output wire ovf);

reg [BITS - 1:0] cnt;
wire [BITS:0] enable_wires;

wire end_up_count = (cnt == top) & updown;
wire end_down_count = (cnt == {(BITS){1'b0}}) & ~updown;

initial begin
    cnt <= {(BITS){1'b0}};
end


assign ovf = (end_up_count | end_down_count) & ena;// & clk;
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
                cnt [i] <= top [i];
        end else if(load) begin
            cnt [i] <= value [i];
        end else if(ena) begin
            if(end_up_count) begin
                cnt [i] <= 1'b0;
            end else if(end_down_count) begin
                cnt [i] <= top [i];
            end else if(enable_wires[i]) begin
                cnt [i] <= ~cnt[i];
            end
        end
    end
end
endgenerate

endmodule
