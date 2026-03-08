`timescale 1ns / 1ps


module watch_datapath (
    input        clk,
    input        rst,
    input        sel_display,  // hour,min/sec,msec select
    input        up_l,         // hour, sec change
    input        up_r,         // min , msec change
    input        down_l,       
    input        down_r,       
    input        change,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    wire w_hour_tick, w_min_tick, w_sec_tick, w_tick_100hz;

    tick_counter_watch #(
        .BIT_WIDTH(5),
        .TIMES(24),
        .FIRST(12)
    ) hour_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_hour_tick),
        .change(change & sel_display),
        .up_l(up_l),
        .up_r(0),
        .down_l(down_l), 
        .down_r(1'b0),
        .o_tick(),
        .o_count(hour)
    );

    tick_counter_watch #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .FIRST(0)
    ) min_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_min_tick),
        .change(change & sel_display),
        .up_l(0),
        .up_r(up_r),
        .down_l(1'b0),
        .down_r(down_r),
        .o_tick(w_hour_tick),
        .o_count(min)
    );
    tick_counter_watch #(
        .BIT_WIDTH(6),
        .TIMES(60),
        .FIRST(0)
    ) sec_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_sec_tick),
        .change(change & !sel_display),
        .up_l(up_l),
        .up_r(0),
        .down_l(down_l), 
        .down_r(1'b0),
        .o_tick(w_min_tick),
        .o_count(sec)
    );

    tick_counter_watch #(
        .BIT_WIDTH(7),
        .TIMES(100),
        .FIRST(0)
    ) msec_counter (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_100hz),
        .change(change & !sel_display),
        .up_l(0),
        .up_r(up_r),
        .down_l(1'b0),
        .down_r(down_r),
        .o_tick(w_sec_tick),
        .o_count(msec)
    );

    tick_gen_100hz u_TICK (
        .clk(clk),
        .rst(rst),
        .run_stop(!change),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module tick_counter_watch #(
    parameter BIT_WIDTH = 7,
    TIMES = 100,
    FIRST = 12
) (
    input                         clk,
    input                         rst,
    input                         i_tick,
    input                         change,
    input                         up_l,
    input                         up_r,
    input                         down_l,
    input                         down_r,
    output reg                    o_tick,
    output     [BIT_WIDTH -1 : 0] o_count
);

    reg [BIT_WIDTH -1:0] counter_reg, counter_next;
    assign o_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= FIRST;
        end else counter_reg <= counter_next;
    end



    always @(*) begin
        counter_next = counter_reg;
        o_tick = 0;
        if ((i_tick && !change) || (change && (up_l || up_r))) begin
            if (counter_reg == (TIMES - 1)) begin
                o_tick = 1;
                counter_next = 0;
            end else begin
                counter_next = counter_reg + 1;
                o_tick = 0;
            end
        end else if (change && (down_l || down_r)) begin
            o_tick = 0;
            if (counter_reg == 0) begin
                counter_next = TIMES - 1;
            end else begin
                counter_next = counter_reg - 1;
            end
        end else begin
            counter_next = counter_reg;
            o_tick = 0;
        end
    end
endmodule

module tick_gen_100hz (
    input clk,
    input rst,
    input run_stop,
    output reg o_tick_100hz
);
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            o_tick_100hz <= 0;
        end else begin
            if (run_stop) begin
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    r_counter <= r_counter + 1;
                    o_tick_100hz <= 1'b0;
                end
            end else begin
                o_tick_100hz <= 1'b0;

            end
        end
    end



endmodule
