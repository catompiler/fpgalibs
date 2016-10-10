module ind7seg #(parameter BITS = 3, parameter COUNT = 8)
                (input wire clk, input wire rst,
                 input wire strobe, input wire[(COUNT)*8-1:0] data,
                 output wire[COUNT-1:0] sel, output wire[7:0] out);

localparam TOP_VAL = COUNT-1;
localparam[BITS-1:0] TOP = TOP_VAL[BITS-1:0];

wire[7:0] out_wires[COUNT-1:0];

genvar i;
generate
for(i = 0; i < COUNT; i = i + 1) begin: gen
    assign out_wires[i][7:0] = data[(i + 1) * 8 - 1 : i * 8];
end
endgenerate

wire[BITS-1:0] cnt_value;
counter #(BITS) cnt(.clk(clk), .rst(rst), .ena(strobe), .updown(1'b1),
                    .top(TOP), .value({BITS{1'b0}}), .load(1'b0),
                    .out(cnt_value), .ovf());

decoder #(BITS, COUNT) sel_d(.addr(cnt_value), .ena(~strobe), .out(sel));

assign out = out_wires[cnt_value];

endmodule
