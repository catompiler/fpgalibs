module simple_shift_reg #(parameter N = 1)
                (input wire clk, input wire rst, input wire ena,
                 input wire in, output wire[N-1:0] out_data, output wire out);

reg [N-1:0] sreg = {N{1'b0}};

wire [N:0] data_wires;

assign data_wires[0] = in;
assign out_data = data_wires[N:1];
assign out = data_wires[N];

genvar i;
generate
for(i = 0; i < N; i = i + 1) begin: gen

assign data_wires[i + 1] = sreg[i];

always @(negedge rst or posedge clk) begin
    if(!rst) begin
        sreg[i] <= 1'b0;
    end else if(ena) begin
        sreg[i] <= data_wires[i];
    end
end

end

endgenerate

endmodule
