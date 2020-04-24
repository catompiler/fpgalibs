module crc
    #(parameter BITS=8, parameter POLY=7, parameter INIT=0)
    (input wire i_clk, input wire i_rst, input wire i_stb, input wire i_bit, output wire[BITS-1:0] o_crc);
//
// Сдвиговый регистр контрольной суммы.
reg[BITS-1:0] crcreg;

// Провода между регистрами.
wire[BITS-1:0] crcwires;

// Выходное значение CRC.
assign o_crc = crcreg;

initial begin
    crcreg <= INIT[BITS-1:0];
end

// Выбор режима сдвига - с XOR или без.
assign sel = crcreg[BITS-1] ^ i_bit;

// Нулевой провод.
assign crcwires[0] = POLY[0] ? sel : 0;

genvar i;
generate
for(i = 1; i < BITS; i = i + 1) begin: gen_crc_wires
    assign crcwires[i] = POLY[i] ? crcreg[i - 1] ^ sel : crcreg[i - 1];
end
endgenerate

// Процесс регистра.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        crcreg <= #1 INIT[BITS-1:0];
    end else begin
        if(i_stb) begin
            crcreg <= #1 crcwires;
        end else begin
            crcreg <= #1 crcreg;
        end
    end
end

endmodule
