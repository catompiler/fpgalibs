module decoder #(parameter N = 2, parameter M = 3)
            (input wire [N-1:0] addr, input wire ena, output wire [M-1:0] out);

wire [N-1:0] not_addr = ~addr;

genvar i, j;
generate
for(i = 0; i < M; i = i + 1) begin: gen_out
    wire [N-1:0] in_addr;
    
    for(j = 0; j < N; j = j + 1) begin: gen_in
        if(i & (1 << j)) begin
            assign in_addr [j] = addr[j];
        end else begin
            assign in_addr [j] = not_addr[j];
        end
    end
    
    assign out[i] = &in_addr & ena;
end
endgenerate

endmodule
