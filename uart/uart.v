`include "counter/simple_upcounter.v"
`include "counter/binary_upcounter.v"
`include "counter/simple_binary_upcounter.v"
`include "shift_reg/simple_shift_reg.v"
`include "shift_reg/shift_reg.v"
`include "majority/majority3.v"



/**
 * Генератор частоты передачи данных.
 * Параметр BAUD_RATE_BITS - число бит делителя.
 * @param clk Вход тактирования.
 * @param rst Вход сброса.
 * @param ena Вход разрешения.
 * @param baud_rate_div Значение делителя частоты.
 * baud_rate_div = F_CLK / (16 * BAUD) - 1,
 * где F_CLK - частота тактирования,
 *     BAUD - скорость обмена данными.
 * @param out Выход генератора.
 */
module uart_baud_gen #(parameter BAUD_RATE_BITS=16)
                      (input wire clk, input wire rst, input wire ena,
                       input wire[BAUD_RATE_BITS-1:0] baud_rate_div, output wire out);
//
// Простой счётчик от 0 до top (от 0 до baud_rate_div).
simple_upcounter #(BAUD_RATE_BITS) cnt_baud(.clk(clk), .rst(rst), .ena(ena),
                                            .top(baud_rate_div), .out(), .ovf(out));
//
endmodule



/**
 * Передатчик UART.
 * @param clk Вход тактирования.
 * @param rst Вход сброса.
 * @param ena Вход разрешения.
 * @param baud_rate_clk Вход сигнала генератора частоты.
 * @param parity_ena Разрешение контроля чётности.
 * @param parity_type Тип контроля чётности.
 * 0 - Even (Чётный),
 * 1 - Odd (Не чётный).
 * @param stop_size Размер стоп бита.
 * 0 - 1 бит,
 * 1 - 2 бита.
 * @param data Данные для передачи.
 * @param start Вход запуска передачи.
 * @param busy Выход флага занятости передатчика.
 * @param tx Выход передатчика.
 */
module uart_tx (input wire clk, input wire rst, input wire ena, input wire baud_rate_clk,
                input wire parity_ena, input wire parity_type, input wire stop_size,
                input wire[7:0] data, input wire start, output wire busy, output wire tx);
//
// Регистры.
//
// Состояние.
// Бит 3 - передача байта данных.
// Бит 2 - общий бит.
// Бит 1 - биты индекса в массиве специальных бит (передача бит старта, чётности, стопа).
// Бит 0 /
// 0 - IDLE.
reg[3:0] state;
//
// Общие провода.
//
// Флаг работы передатчика (state != 0).
wire running = |state;
// Флаг передачи байта данных (state[3] == 1).
wire transmit_data = state[3];
// Флаг синхронизации с генератором частоты.
wire baud_clk_sync = (~state[3] & state[2] & ~state[1] & ~state[0]);
// Специальные биты (idle, старт, чётность, стоп) для передачи.
wire[3:0] spec_bits = {1'b1, data_parity, 1'b0, 1'b1};
// Данные младшим битом вперёд для передачи.
wire[7:0] reversed_data;
//
// Генерация частоты передатчика.
//
// Сброс генератора частоты.
wire baud_gen_rst = rst & running & ~baud_clk_sync;
// Разрешение генератора частоты.
wire baud_gen_ena = ena & running & baud_rate_clk;
// Тик генератора частоты.
wire baud_tick;
//
// Сдвиговый регистр передаваемых данных.
//
// Флаг загрузки данных в регистр.
wire shift_reg_load = start & ~running;
// Флаг разрешения сдвига регистра.
wire shift_reg_ena = ena & baud_tick & transmit_data;
// Выход сдвигового регистра.
wire shift_reg_out;
// Выход данных сдвигового регистра.
wire[7:0] shift_reg_data_out;
//
// Чётность.
//
// Значение чётности данных по принципу "чётный".
wire data_parity_even = ^shift_reg_data_out;
// Значение чётности данных в зависимости от выбранного режима.
wire data_parity = (~parity_type & data_parity_even) | (parity_type & ~data_parity_even);
//
//
// Инициализация.
// Начальное состояние - 0 (IDLE).
initial begin
    state <= 4'b0;
end
//
//
// Реверсирование данных.
genvar i;
generate
for(i = 0; i <= 7; i = i + 1) begin: gen_reverse
    assign reversed_data[i] = data[7 - i];
end
endgenerate
//
// Выходные линии.
//
// Флаг занятости.
assign busy = running;
// Линия передачи.
assign tx = (transmit_data & shift_reg_out) | (~transmit_data & spec_bits[state[1:0]]);
//
//
// Модули.
//
// Сдвиговый регистр данных для передачи.
shift_reg #(8) sh_reg(.clk(clk), .rst(rst), .ena(shift_reg_ena),
                      .load(shift_reg_load), .load_data(reversed_data), .in(shift_reg_out),
                      .out_data(shift_reg_data_out), .out(shift_reg_out));
//
// Делитель входной частоты на 16.
// Синхронизируется по ближайшему тику генератора частоты после старта передачи.
simple_binary_upcounter #(4) baud_gen(.clk(clk), .rst(baud_gen_rst), .ena(baud_gen_ena),
                                      .out(), .ovf(baud_tick));
//
//
always @(posedge clk or negedge rst) begin
    if(!rst) begin
        state <= 4'b0;
    end else begin
        case (state)
            4'b0000: if(start) state <= 4'b0100;     // idle
            4'b0100: if(baud_rate_clk) state <= 4'b0001; // Ожидание синхронизации с генератором частоты.
            4'b0001: if(baud_tick) state <= 4'b1000; // Стартовый бит.
            4'b1000: if(baud_tick) state <= 4'b1001; // Бит 0
            4'b1001: if(baud_tick) state <= 4'b1010; // Бит 1
            4'b1010: if(baud_tick) state <= 4'b1011; // Бит 2
            4'b1011: if(baud_tick) state <= 4'b1100; // Бит 3
            4'b1100: if(baud_tick) state <= 4'b1101; // Бит 4
            4'b1101: if(baud_tick) state <= 4'b1110; // Бит 5
            4'b1110: if(baud_tick) state <= 4'b1111; // Бит 6
            4'b1111: if(baud_tick) begin             // Бит 7
                         // Если разрешена передача
                         // бита чётности.
                         if(parity_ena) begin
                            state <= 4'b0010; // -> Чётность.
                         end else begin
                            state <= 4'b0011; // -> Стоповый бит 1.
                         end
                     end
            4'b0010: if(baud_tick) state <= 4'b0011; // Бит чётности.
            4'b0011: if(baud_tick) begin             // Стоповый бит 1.
                         // Если длина стопового бита
                         // равна двум.
                         if(stop_size) begin
                            state <= 4'b0111; // -> Стоповый бит 2.
                         end else begin
                            state <= 4'b0000; // -> idle
                         end
                     end
            4'b0111: if(baud_tick) state <= 4'b0000; // Стоповый бит 2.
            default: state <= 4'b0000; // -> idle.
        endcase
    end
end

//
endmodule



/**
 * Приёмник UART.
 * @param clk Вход тактирования.
 * @param rst Вход сброса.
 * @param ena Вход разрешения.
 * @param baud_rate_clk Вход сигнала генератора частоты.
 * @param parity_ena Разрешение контроля чётности.
 * @param parity_type Тип контроля чётности.
 * 0 - Even (Чётный),
 * 1 - Odd (Не чётный).
 * @param rx Вход приёмника.
 * @param data Принятые данные.
 * @param ready Флаг готовности принятых данных.
 * @param parity_err Флаг ошибки чётности.
 * @param frame_err Флаг ошибки кадра.
 */
module uart_rx (input wire clk, input wire rst, input wire ena,
                input wire baud_rate_clk,
                input wire parity_ena, input wire parity_type,
                input wire rx, output wire[7:0] data, output wire ready,
                output wire parity_err, output wire frame_err);
//
// Регистры.
//
// Состояние.
// Бит 3 - передача байта данных.
// Бит 2 \
// Бит 1 - Общие биты.
// Бит 0 /
// 0 - IDLE.
reg[3:0] state;
//
// Флаг ошибки чётности.
reg parity_err_flag;
// Флаг ошибки кадра.
reg frame_err_flag;
//
// Общие провода.
//
// Флаг работы передатчика (state != 0).
wire running = |state;
// Флаг приёма байта данных (state[3] == 1).
wire receive_data = state[3];
// Данные младшим битом вперёд для передачи.
wire[7:0] reversed_data;
// Значения линии приёма данных каждый тик генератора частоты.
wire[15:0] samples;
//
// Чётность.
//
// Значение чётности данных по принципу "чётный".
wire data_parity_even = ^data;
// Значение чётности данных в зависимости от выбранного режима.
wire data_parity = (~parity_type & data_parity_even) | (parity_type & ~data_parity_even);
//
// Поиск ниспадающего фронта.
//
// Выход мажоритарного элемента нахождения ниспадающего фронта.
wire falling_edge_detect_front;
// Мажоритарный элемент нахождения ниспадающего фронта.
majority3 falling_edge_detect_front_maj({samples[10], samples[8], samples[6]}, falling_edge_detect_front);
// Выход мажоритарного элемента нахождения центра стопового бита.
wire falling_edge_detect_center;
// Мажоритарный элемент нахождения центра стопового бита.
majority3 falling_edge_detect_center_maj(samples[5:3], falling_edge_detect_center);
// В выборке (samples) ищется последовательность 1110X|0X0X0|000.
wire falling_edge = &samples[15:13] & ~samples[12] & ~falling_edge_detect_front & ~falling_edge_detect_center;
// Флаг нахождения стартового бита.
wire start_bit = falling_edge & ~running;
//
// Полученный бит.
//
// Выход мажоритарного элемента цента выборки - полученный бит.
wire sampled_bit;
// Мажоритарный элемент цента выборки - полученный бит.
majority3 sampled_bit_maj(samples[8:6], sampled_bit);
//
// Сдвиговый регистр выборки.
//
// Разрешение сдвига выборки.
wire samples_sh_reg_ena = ena & baud_rate_clk;
//
// Генератор частоты следования бит (делитель частоты генератора на 16).
//
// Разрешения деления частоты.
wire baud_gen_ena = ena & running & baud_rate_clk;
// Выход генератора частоты следования бит.
wire baud_tick;
//
// Сдвиговый регистр получаемых данных.
//
// Разрешение сдвига данных.
wire data_sh_reg_ena = ena & receive_data & baud_tick;
//
//
// Инициализация.
// Начальное состояние - 0 (IDLE).
initial begin
    state <= 4'b0;
    parity_err_flag <= 1'b0;
    frame_err_flag <= 1'b0;
end
//
//
// Реверсирование данных.
genvar i;
generate
for(i = 0; i <= 7; i = i + 1) begin: gen_reverse
    assign data[i] = reversed_data[7 - i];
end
endgenerate
//
//
// Выходные линии.
//
// Флаг доступности данных.
assign ready = ~running;
// Флаг ошибки чётности.
assign parity_err = parity_err_flag;
// Флаг ошибки кадра.
assign frame_err = frame_err_flag;
//
//
// Модули.
//
// Сдвиговый регистр выборки.
simple_shift_reg #(16) samples_sh_reg(.clk(clk), .rst(rst), .ena(samples_sh_reg_ena),
                                      .in(rx), .out_data(samples), .out());
//
// Генератор частоты следования бит (делитель на 16).
// Синхронизируется по текущей позиции при получении стартового бита.
binary_upcounter #(4) baud_gen(.clk(clk), .rst(rst), .ena(baud_gen_ena),
                               .value(4'hc), .load(start_bit), .out(), .ovf(baud_tick));
//
// Сдвиговй регистр бит данных.
simple_shift_reg #(8) data_sh_reg(.clk(clk), .rst(rst), .ena(data_sh_reg_ena),
                                  .in(sampled_bit), .out_data(reversed_data), .out());
//
//
always @(posedge clk or negedge rst) begin
    if(!rst) begin
        state <= 4'b0;
        parity_err_flag <= 1'b0;
        frame_err_flag <= 1'b0;
    end else begin
        case (state)
            4'b0000: if(start_bit) begin             // idle
                         parity_err_flag <= 1'b0;
                         frame_err_flag <= 1'b0;
                         state <= 4'b0001; // -> Стартовый бит.
                     end
            4'b0001: if(baud_tick) state <= 4'b1000; // Стартовый бит.
            4'b1000: if(baud_tick) state <= 4'b1001; // Бит 0
            4'b1001: if(baud_tick) state <= 4'b1010; // Бит 1
            4'b1010: if(baud_tick) state <= 4'b1011; // Бит 2
            4'b1011: if(baud_tick) state <= 4'b1100; // Бит 3
            4'b1100: if(baud_tick) state <= 4'b1101; // Бит 4
            4'b1101: if(baud_tick) state <= 4'b1110; // Бит 5
            4'b1110: if(baud_tick) state <= 4'b1111; // Бит 6
            4'b1111: if(baud_tick) begin             // Бит 7
                         // Если разрешена передача
                         // бита чётности.
                         if(parity_ena) begin
                            state <= 4'b0010; // -> Чётность.
                         end else begin
                            state <= 4'b0011; // -> Стоповый бит.
                         end
                     end
            4'b0010: if(baud_tick) begin             // Бит чётности.
                         parity_err_flag <= parity_ena & (sampled_bit ^ data_parity);
                         state <= 4'b0011; // -> Стоповый бит.
                     end
            4'b0011: if(baud_tick) begin             // Стоповый бит.
                         // Если принятый стоповый бит
                         // имеет низкий логический уровень.
                         if(~sampled_bit) begin
                             // Установим ошибку кадра.
                             frame_err_flag <= 1'b1;
                         end
                         state <= 4'b0000; // -> idle.
                     end
            default: state <= 4'b0000; // -> idle.
        endcase
    end
end
//
endmodule



/**
 * Передатчик / приёмник UART.
 * Параметр F_CLK - частота тактирования.
 * Параметр BAUD - скорость передачи данных.
 * @param clk Вход тактирования.
 * @param rst Вход сброса.
 * @param ena Вход разрешения.
 * @param parity_ena Разрешение контроля чётности.
 * @param parity_type Тип контроля чётности.
 * 0 - Even (Чётный),
 * 1 - Odd (Не чётный).
 * @param stop_size Размер стоп бита.
 * 0 - 1 бит,
 * 1 - 2 бита.
 * @param tx_data Данные для передачи.
 * @param tx_start Вход запуска передачи.
 * @param tx_busy Выход флага занятости передатчика.
 * @param tx Выход передатчика.
 * @param rx Вход приёмника.
 * @param rx_data Принятые данные.
 * @param rx_ready Флаг готовности принятых данных.
 * @param parity_err Флаг ошибки чётности.
 * @param frame_err Флаг ошибки кадра.
 */
module uart #(parameter F_CLK=50_000_000, parameter BAUD=9600)
             (input wire clk, input wire rst, input wire ena,
              input wire parity_ena, input wire parity_type, input wire stop_size,
              input wire[7:0] tx_data, input wire tx_start, output wire tx_busy, output wire tx,
              input wire rx, output wire[7:0] rx_data, output wire rx_ready,
              output wire parity_err, output wire frame_err);
//
// Значение делителя частоты генератора.
localparam BAUD_GEN_DIV = F_CLK / (16 * BAUD) - 1;
localparam BAUD_GEN_DIV_BITS = $clog2(BAUD_GEN_DIV);
localparam BAUD_GEN_DIV_VAL = BAUD_GEN_DIV[BAUD_GEN_DIV_BITS-1:0];
//
// Провода.
//
// Выход генератора частоты.
wire baud_rate_clk;
//
// Модули.
//
// Генератор частоты.
uart_baud_gen #(BAUD_GEN_DIV_BITS) baud_gen(.clk(clk), .rst(rst), .ena(ena),
                                            .baud_rate_div(BAUD_GEN_DIV_VAL), .out(baud_rate_clk));
// Передатчик.
uart_tx transmitter (.clk(clk), .rst(rst), .ena(rst), .baud_rate_clk(baud_rate_clk),
                     .parity_ena(parity_ena), .parity_type(parity_type), .stop_size(stop_size),
                     .data(tx_data), .start(tx_start), .busy(tx_busy), .tx(tx));
// Приёмник.
uart_rx receiver (.clk(clk), .rst(rst), .ena(ena), .baud_rate_clk(baud_rate_clk),
                  .parity_ena(parity_ena), .parity_type(parity_type),
                  .rx(rx), .data(rx_data), .ready(rx_ready),
                  .parity_err(parity_err), .frame_err(frame_err));
//
endmodule
