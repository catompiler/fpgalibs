//
module spi_master_baud_gen
    #(parameter PSC=1)
    (input wire i_clk,
     input wire i_rst,
     output wire o_udf,
     output wire o_ovf,
     output wire o_udf_div2,
     output wire o_ovf_div2,
     output wire o_period);
//
    
    localparam PSC_TOP = PSC;
    
    localparam BITS = $clog2(PSC_TOP+1);
    
    /*
    integer b = BITS;
    integer b0 = $clog2(0);//0
    integer b1 = $clog2(1);//0
    integer b2 = $clog2(2);//1
    integer b3 = $clog2(3);//2
    integer b4 = $clog2(4);//2
    integer b5 = $clog2(5);//3
    integer b6 = $clog2(6);//3
    integer b7 = $clog2(7);//3
    integer b8 = $clog2(8);//3
    integer b9 = $clog2(9);//4
    */
    
    reg[BITS-1:0] count;
    
    wire count_is_zero = count == 0;
    wire count_is_top = count == PSC_TOP;
    
    reg period;
    
    assign o_period = period;

    initial begin
        count = 'd0;
        period = 'd0;
    end
    
    assign o_udf = i_rst & count_is_zero;
    assign o_ovf = i_rst & count_is_top;
    
    assign o_udf_div2 = i_rst & count_is_zero & !period;
    assign o_ovf_div2 = i_rst & count_is_top & period;

    // counter
    always @(posedge i_clk or negedge i_rst) begin
        if(!i_rst) begin
            count <= #1 'd0;
        end else begin
            if(count_is_top) begin
                count <= #1 'd0;
            end else begin
                count <= #1 count + 'd1;
            end
        end
    end
    
    // period.
    always @(posedge i_clk or negedge i_rst) begin
        if(!i_rst) begin
            period <= #1 'd0;
        end else begin
            if(count_is_top) begin
                period <= #1 !period;
            end else begin
                period <= #1 period;
            end
        end
    end

endmodule


//
module spi_master_sck_gen
    #(parameter CPOL = 0,
      parameter CPHA = 0)
    (input wire i_period,
     input wire i_xfer,
     output wire o_sck);
//
localparam mode = {CPOL[0], CPHA[0]};
generate
if(mode == 0) begin
    assign o_sck = i_period & i_xfer;
end else if(mode == 1) begin
    assign o_sck = ~i_period & i_xfer;
end else if(mode == 2) begin
    assign o_sck = ~i_period | ~i_xfer;
end else begin
    assign o_sck = i_period | ~i_xfer;
end
endgenerate
endmodule


// SPI Master
module spi_master
    #(parameter PSC=0,
      parameter BITS=8,
      parameter CPOL=0,
      parameter CPHA=0,
      parameter BEG_TICKS=0,
      parameter END_TICKS=0)
    (input wire i_clk,
     input wire i_rst,
     input wire[BITS-1:0] i_data,
     input wire i_stb,
     output wire o_empty,
     output wire o_busy,
     output wire[BITS-1:0] o_data,
     output wire o_stb,
     input wire i_miso,
     output wire o_mosi,
     output wire o_sck,
     output wire o_cs);
//

// Состояния.
localparam STATE_BITS = 2;
localparam[STATE_BITS-1:0] STATE_IDLE = 'd0;
localparam[STATE_BITS-1:0] STATE_BWAIT = 'd1;
localparam[STATE_BITS-1:0] STATE_XFER = 'd2;
localparam[STATE_BITS-1:0] STATE_EWAIT = 'd3;
// Текущее состояние.
reg[STATE_BITS-1:0] state;
// Следующее состояние.
reg[STATE_BITS-1:0] next_state;

// Счётчики тиков до и после передачи.
// Начало передачи.
localparam CNT_BWAIT_BITS = $clog2(BEG_TICKS+1);
localparam CNT_BWAIT_TOP = BEG_TICKS;
// Счётчик.
reg[CNT_BWAIT_BITS-1:0] bwait_count;
// Флаг окончания счёта.
wire bwait_end = bwait_count == CNT_BWAIT_TOP;
// Окончание передачи.
localparam CNT_EWAIT_BITS = $clog2(END_TICKS+1);
localparam CNT_EWAIT_TOP = END_TICKS;
// Счётчик.
reg[CNT_EWAIT_BITS-1:0] ewait_count;
// Флаг окончания счёта.
wire ewait_end = ewait_count == CNT_EWAIT_TOP;
// Флаг перезапуска передачи - при получении запуска передачи во время ожидания после передачи.
wire xfer_restart = data_xmit_valid & (state == STATE_EWAIT);

// Параметры для счётчика бит.
localparam CNT_BITS = $clog2(BITS+1);
localparam CNT_BITS_TOP = BITS - 1;
// Счётчик бит.
reg[CNT_BITS-1:0] bit_count;
// Флаги значений счётчика.
wire xfer_first_bit = bit_count == 'd0;
wire xfer_last_bit = bit_count == CNT_BITS_TOP;

// Последний импульс baud последнего бита.
wire last_bit_clk = bit_clk & xfer_last_bit;

// Флаг передачи.
wire xfer = state == STATE_XFER;

// Флаг работы.
wire running = state != STATE_IDLE;

// Теневой регистр передаваемых данных.
reg[BITS-1:0] data_xmit;
// Флаг наличия данных для передачи.
reg data_xmit_valid;
// Сдвиговый регистр.
reg[BITS-1:0] data_shift;
// Теневой регистр принятых данных.
reg[BITS-1:0] data_recv;
// Флаг наличия принятых данных.
reg data_recv_valid;

assign o_data = data_recv;
assign o_mosi = data_shift[BITS-1];

assign o_cs = ~running;

assign o_busy = running;
assign o_empty = ~data_xmit_valid;
assign o_stb = data_recv_valid;

// Сигналы генератора SCK.
wire front_clk;
wire bit_clk;
wire period_clk;


initial begin
    state = STATE_IDLE;
    next_state = STATE_IDLE;
    bwait_count <= 'd0;
    ewait_count <= 'd0;
    bit_count <= 'd0;
    data_xmit <= 'd0;
    data_xmit_valid <= 'd0;
    data_shift <= 'd0;
    data_recv <= 'd0;
    data_recv_valid <= 'd0;
end

// Генератор сигнала потока бит.
spi_master_baud_gen #(PSC) bg(.i_clk(i_clk), .i_rst(running & i_rst & ~xfer_restart),
                       .o_udf(front_clk), .o_ovf(),
                       .o_udf_div2(), .o_ovf_div2(bit_clk),
                       .o_period(period_clk));
//

// Генерация сигнала SCK.
spi_master_sck_gen #(CPOL, CPHA) sg (.i_period(period_clk), .i_xfer(xfer), .o_sck(o_sck));
//

// Процесс текущего состояния.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        state <= #1 STATE_IDLE;
    end else begin
        state <= #1 next_state;
    end
end

// Процесс выбора следующего состояния.
always @(*) begin
    case(state)
    STATE_IDLE: begin
        if(i_stb) begin
            if(bwait_end) begin
                next_state = STATE_XFER;
            end else begin
                next_state = STATE_BWAIT;
            end
        end else begin
            next_state = STATE_IDLE;
        end
    end
    STATE_BWAIT: begin
        if(bwait_end) begin
            next_state = STATE_XFER;
        end else begin
            next_state = STATE_BWAIT;
        end
    end
    STATE_XFER: begin
        if(last_bit_clk & ~data_xmit_valid) begin
            if(ewait_end) begin
                next_state = STATE_IDLE;
            end else begin
                next_state = STATE_EWAIT;
            end
        end else begin
            next_state = STATE_XFER;
        end
    end
    STATE_EWAIT: begin
        if(data_xmit_valid) begin
            next_state = STATE_XFER;
        end else begin
            if(ewait_end) begin
                next_state = STATE_IDLE;
            end else begin
                next_state = STATE_EWAIT;
            end
        end
    end
    default: begin
        next_state = STATE_IDLE;
    end
    endcase
end

// Процесс счётчика до передачи.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        bwait_count <= #1 'd0;
    end else begin
        case(state)
        default: begin
            bwait_count <= #1 'd0;
        end
        STATE_BWAIT: begin
            if(bit_clk) begin
                if(bwait_end) begin
                    bwait_count <= #1 'd0;
                end else begin
                    bwait_count <= #1 bwait_count + 'd1;
                end
            end else begin
                bwait_count <= #1 bwait_count;
            end
        end
        endcase
    end
end

// Процесс счётчика после передачи.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        ewait_count <= #1 'd0;
    end else begin
        case(state)
        default: begin
            ewait_count <= #1 'd0;
        end
        STATE_EWAIT: begin
            if(bit_clk) begin
                if(ewait_end) begin
                    ewait_count <= #1 'd0;
                end else begin
                    ewait_count <= #1 ewait_count + 'd1;
                end
            end else begin
                ewait_count <= #1 ewait_count;
            end
        end
        endcase
    end
end

// Процесс счётчика.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        bit_count <= #1 'd0;
    end else begin
        case(state)
        default: begin
            bit_count <= #1 'd0;
        end
        STATE_XFER: begin
            if(bit_clk) begin
                if(xfer_last_bit) begin
                    bit_count <= #1 'd0;
                end else begin
                    bit_count <= #1 bit_count + 'd1;
                end
            end else begin
                bit_count <= #1 bit_count;
            end
        end
        endcase
    end
end

// Процесс сдвигового регистра.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        data_shift <= 'd0;
    end else begin
        case(state)
        default: begin
            data_shift <= #1 data_shift;
        end
        STATE_IDLE: begin
            if(i_stb) begin
                data_shift <= #1 i_data;
            end else begin
                data_shift <= #1 data_shift;
            end
        end
        STATE_XFER: begin
            if(bit_clk) begin
                if(xfer_last_bit & data_xmit_valid) begin
                    data_shift <= #1 data_xmit;
                end else begin
                    data_shift <= #1 {data_shift[BITS-2:0], i_miso};
                end
            end else begin
                data_shift <= #1 data_shift;
            end
        end
        STATE_EWAIT: begin
            if(data_xmit_valid) begin
                data_shift <= #1 data_xmit;
            end else begin
                data_shift <= #1 data_shift;
            end
        end
        endcase
    end
end

// Процесс теневого регистра передачи.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        data_xmit <= #1 'd0;
    end else begin
        case(state)
        STATE_IDLE: begin
            data_xmit <= #1 data_xmit;
        end
        default: begin
            if(i_stb) begin
                data_xmit <= #1 i_data;
            end else begin
                data_xmit <= #1 data_xmit;
            end
        end
        endcase
    end
end

// Процесс флага теневого регистра передачи.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        data_xmit_valid <= #1 'd0;
    end else begin
        case(state)
        STATE_IDLE: begin
            data_xmit_valid <= #1 'd0;
        end
        default: begin
            if(i_stb) begin
                data_xmit_valid <= #1 'd1;
            end else if(last_bit_clk) begin
                data_xmit_valid <= #1 'd0;
            end else begin
                data_xmit_valid <= #1 data_xmit_valid;
            end
        end
        STATE_EWAIT: begin
            if(i_stb) begin
                data_xmit_valid <= #1 'd1;
            end else begin
                data_xmit_valid <= #1 'd0;
            end
        end
        endcase
    end
end

// Процесс теневого регистра приёма.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        data_recv <= #1 'd0;
    end else begin
        case(state)
        default: begin
            data_recv <= #1 data_recv;
        end
        STATE_XFER: begin
            if(last_bit_clk) begin
                data_recv <= #1 {data_shift[BITS-2:0], i_miso};
            end else begin
                data_recv <= #1 data_recv;
            end
        end
        endcase
    end
end

// Процесс флага теневого регистра приёма.
always @(posedge i_clk or negedge i_rst) begin
    if(!i_rst) begin
        data_recv_valid <= #1 'd0;
    end else begin
        case(state)
        default: begin
            data_recv_valid <= #1 'd0;
        end
        STATE_XFER: begin
            if(last_bit_clk) begin
                data_recv_valid <= #1 'd1;
            end else begin
                data_recv_valid <= #1 'd0;
            end
        end
        endcase
    end
end

endmodule
