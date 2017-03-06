`timescale 1us/1us



module test();

reg clk;
wire out;

main m(.clk(clk), .out(out));

always #1 clk <= ~clk;

initial begin

    $dumpfile("test.vcd");
    $dumpvars(0, test);
    
    clk <= 1'b0;
    
    #1000 $finish();
end

endmodule
