module main(input wire clk, output wire out);

reg [2:0] cnt;

initial begin
    cnt = 3'b0;
end

assign out = cnt[2];

always @(posedge clk) begin
    cnt <= cnt + 1'b1;
end

endmodule
