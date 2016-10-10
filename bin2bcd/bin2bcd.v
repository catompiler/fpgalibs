module add3gt4(input wire[3:0] in_val, output reg[3:0] out_val);
always @(in_val) begin
    case (in_val)
        4'b0101: out_val <= 4'b1000;
        4'b0110: out_val <= 4'b1001;
        4'b0111: out_val <= 4'b1010;
        4'b1000: out_val <= 4'b1011;
        4'b1001: out_val <= 4'b1100;
        4'b1010: out_val <= 4'b1101;
        4'b1011: out_val <= 4'b1110;
        4'b1100: out_val <= 4'b1111;
        default: out_val <= in_val;
    endcase
end
endmodule

module add3gt4_n #(parameter N = 1)
            (input wire [4 * N - 1 : 0] in_val,
             output wire [4 * N - 1 : 0] out_val);

genvar i;
generate
for(i = 0; i < N; i = i + 1) begin: gen_add3
    add3gt4 add3(in_val[4 * (i + 1) - 1: 4 * i], out_val[4 * (i + 1) - 1: 4 * i]);
end
endgenerate

endmodule

module bin2bcd #(parameter IN_BITS = 8,
                 parameter OUT_BITS = 10)
            (input wire [IN_BITS-1:0] bin_number,
             output wire [OUT_BITS-1:0] bcd_number);


genvar bits_shifted;
generate
for (bits_shifted = 3; bits_shifted < IN_BITS; bits_shifted = bits_shifted + 1) begin : gen

    wire [IN_BITS + bits_shifted / 3 - 1 : 0] out_wires;
    
    if(bits_shifted == 3) begin
    
        add3gt4_n #(bits_shifted / 3) add3n(
                        {1'b0, bin_number[IN_BITS - 1 : IN_BITS - 3]},
                        out_wires[IN_BITS : IN_BITS - 3]
                    );
        assign out_wires[IN_BITS - 4: 0] = bin_number[IN_BITS - 4:0];
        
    end else if(bits_shifted % 3 == 0) begin
    
        add3gt4_n #(bits_shifted / 3) add3n(
                        {1'b0, gen[bits_shifted - 1].out_wires[IN_BITS + (bits_shifted - 1) / 3 - 1 : IN_BITS - (bits_shifted / 3) * 3]},
                        out_wires[IN_BITS + bits_shifted / 3 - 1 : IN_BITS - (bits_shifted / 3) * 3]
                    );
        assign out_wires[IN_BITS - (bits_shifted / 3) * 3 - 1: 0] = bin_number[IN_BITS - (bits_shifted / 3) * 3 - 1:0];
        
    end else begin
    
        add3gt4_n #(bits_shifted / 3) add3n(
                        {gen[bits_shifted - 1].out_wires[IN_BITS + bits_shifted / 3 - 1 - bits_shifted % 3 : IN_BITS - (bits_shifted / 3) * 3 - bits_shifted % 3]},
                        out_wires[IN_BITS + bits_shifted / 3 - 1 - bits_shifted % 3 : IN_BITS - (bits_shifted / 3) * 3 - bits_shifted % 3]
                    );
        assign out_wires[IN_BITS + bits_shifted / 3 - 1: IN_BITS + bits_shifted / 3 - bits_shifted % 3] = gen[bits_shifted - 1].out_wires[IN_BITS + bits_shifted / 3 - 1 : IN_BITS + bits_shifted / 3 - bits_shifted % 3];
        assign out_wires[IN_BITS - (bits_shifted / 3) * 3 - bits_shifted % 3 - 1: 0] = bin_number[IN_BITS - (bits_shifted / 3) * 3 - bits_shifted % 3 - 1:0];
        
    end
end

assign bcd_number = gen[IN_BITS - 1].out_wires;

endgenerate

endmodule
