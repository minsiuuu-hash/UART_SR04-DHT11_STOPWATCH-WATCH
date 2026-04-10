`timescale 1ns / 1ps

module dht11_controller (
    input         clk,
    input         rst,
    input         start,
    output [15:0] humidity,
    output [15:0] temperature,
    output        dht11_done,
    output        dht11_valid,
    output [ 3:0] debug,
    inout         dhtio
);

    wire tick_10u;

    tick_gen_10u U_TICK_10u (
        .clk(clk),
        .rst(rst),
        .tick_10u(tick_10u)
    );

    // STATE
    parameter IDLE = 0, START = 1, WAIT = 2, SYNC_L = 3, SYNC_H = 4,
              DATA_SYNC = 5, DATA_C = 6, STOP = 7;

    reg [3:0] c_state, n_state;
    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;
    reg [$clog2(1900)-1:0] tick_cnt_reg, tick_cnt_next;  // slack time  > 18usec
    reg [5:0] bit_cnt_reg, bit_cnt_next;  // 40 time cnt
    reg [39:0] data_reg, data_next;  // 40 data

    wire [7:0] hum_int = data_reg[39:32];
    wire [7:0] hum_dec = data_reg[31:24];
    wire [7:0] temp_int = data_reg[23:16];
    wire [7:0] temp_dec = data_reg[15:8];
    wire [7:0] checksum = data_reg[7:0];

    // inout = wire type, inout type use mux to make sw
    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;  // dhtio_reg = output mode, 1'bz = input mode
    assign debug = c_state;

    // make 16bit
    assign humidity = {hum_int, hum_dec};
    assign temperature = {temp_int, temp_dec};

    assign dht11_done = (c_state == STOP && tick_10u && tick_cnt_reg == 5) ? 1'b1 : 1'b0;
    assign dht11_valid = ((hum_int + hum_dec + temp_int + temp_dec) == checksum) ? 1'b1 : 1'b0;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= 3'b000;
            dhtio_reg <= 1'b1;
            tick_cnt_reg <= 0;
            io_sel_reg <= 1'b1;
            bit_cnt_reg <= 0;
            data_reg <= 0;
        end else begin
            c_state <= n_state;
            dhtio_reg <= dhtio_next;
            tick_cnt_reg <= tick_cnt_next;
            io_sel_reg <= io_sel_next;
            bit_cnt_reg <= bit_cnt_next;
            data_reg <= data_next;
        end
    end

    always @(*) begin
        n_state       = c_state;
        tick_cnt_next = tick_cnt_reg;
        dhtio_next    = dhtio_reg;
        io_sel_next   = io_sel_reg;
        bit_cnt_next  = bit_cnt_reg;
        data_next     = data_reg;
        case (c_state)
            IDLE: begin
                if (start) begin
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900) begin  // sensor on > 18msec
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin  // 40usec delay
                        n_state = SYNC_L;
                        io_sel_next = 1'b0;  // to input mode
                    end
                end
            end
            SYNC_L: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        n_state = SYNC_H;
                    end
                end
            end
            SYNC_H: begin
                if (tick_10u) begin
                    if (dhtio == 0) begin
                        n_state = DATA_SYNC;
                    end
                end
            end
            DATA_SYNC: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        n_state = DATA_C;
                        tick_cnt_next = 0;
                    end
                end
            end
            DATA_C: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        if (tick_cnt_reg < 5) begin  // 50usec 
                            data_next = {data_reg[38:0], 1'b0};  // 26~28usec
                        end else begin
                            data_next = {data_reg[38:0], 1'b1};  // 70usec
                        end
                        if (bit_cnt_reg == 39) begin
                            n_state = STOP;
                            bit_cnt_next = 0;
                            tick_cnt_next = 0;
                        end else begin
                            n_state = DATA_SYNC;
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                end
            end
            STOP: begin
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 5) begin
                        dhtio_next = 1'b1;
                        io_sel_next = 1'b1;  // to output mode
                        n_state = IDLE;
                    end
                end
            end
        endcase
    end

endmodule

module tick_gen_10u (
    input clk,
    input rst,
    output reg tick_10u
);

    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1 : 0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10u <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10u <= 1'b1;
            end else begin
                tick_10u <= 1'b0;
            end
        end
    end

endmodule
