`timescale 1ns / 1ps

module stopwatch_datapath (
    input clk,
    input rst,
    input mode,
    input clear,
    input run_stop,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_tick_100hz, w_msec_tick;
    wire w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) hour_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_hour_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(hour),
        .o_tick()
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_min_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(min),
        .o_tick(w_hour_tick)
    );
    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_sec_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(sec),
        .o_tick(w_min_tick)
    );
    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );
    tick_gen_100hz u_TICK (
        .clk(clk),
        .rst(rst),
        .run_stop(run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule

module tick_counter #(
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (
    input clk,
    input rst,
    input i_tick,
    input mode,
    input clear,
    input run_stop,
    output [BIT_WIDTH -1 : 0] o_count,
    output reg o_tick
);

    reg [BIT_WIDTH-1:0] counter_reg, counter_next;
    assign o_count = counter_reg;
    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        o_tick = 0;
        if (i_tick & run_stop) begin
            if (mode) begin  //down count
                if (counter_reg == 0) begin
                    counter_next = TIMES - 1;
                    o_tick = 1;
                end else begin
                    o_tick = 0;
                    counter_next = counter_reg - 1;
                end
            end else begin  //up count
                if (counter_reg == TIMES - 1) begin
                    counter_next = 0;
                    o_tick = 1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick = 0;
                end
            end
        end
    end


endmodule
