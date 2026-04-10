`timescale 1ns / 1ps

module sr04_controller (
    input         clk,   
    input         rst,
    input         start,    
    input         echo,       
    output        trigger,    
    output [15:0] dist_data, 
    output        done       
);

    localparam IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, DIST = 3'd3, AG_IDLE = 3'd4;
    parameter BIT_WIDTH = 60_000;

    wire w_1us_tick;

    reg [2:0] c_state, n_state;
    reg [$clog2(BIT_WIDTH)-1:0] tick_cnt_reg, tick_cnt_next;  // 60msec delay
    reg [$clog2(400)-1:0] dist_reg, dist_next;  // distance max 400cm
    reg trigger_reg, trigger_next;
    reg done_reg, done_next;

    assign done = done_reg;
    assign trigger = trigger_reg;
    assign dist_data = dist_reg;

    tick_gen_1us U_TICK_1US (
        .clk(clk),
        .rst(rst),
        .o_tick(w_1us_tick)  // 1us > 1tick
    );

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= 3'b0;
            tick_cnt_reg <= 0;
            trigger_reg <= 0;
            dist_reg <= 0;
            done_reg <= 0;
        end else begin
            c_state <= n_state;
            tick_cnt_reg <= tick_cnt_next;
            trigger_reg <= trigger_next;
            dist_reg <= dist_next;
            done_reg <= done_next;
        end
    end

    always @(*) begin
        tick_cnt_next = tick_cnt_reg;
        n_state = c_state;
        trigger_next = trigger_reg;
        dist_next = dist_reg;
        done_next = 1'b0;
        case (c_state)
            IDLE: begin
                tick_cnt_next = 0;
                trigger_next  = 1'b0;
                if (start) begin
                    n_state = START;
                    trigger_next = 1'b0;
                end
            end
            START: begin
                if (w_1us_tick == 1'b1) begin
                    if (tick_cnt_reg == 11) begin // slack time > 11usec
                        n_state = WAIT;
                        tick_cnt_next = 0;
                        trigger_next = 1'b0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                        trigger_next  = 1'b1;
                    end
                end
            end
            WAIT: begin
                if (echo == 1'b1) begin
                    n_state = DIST;
                    tick_cnt_next = 0;
                end
            end
            DIST: begin
                if (w_1us_tick == 1'b1) begin
                    if (echo == 1'b1) begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        n_state = AG_IDLE;
                        dist_next = tick_cnt_reg / 58;
                        tick_cnt_next = 0;
                    end
                end
            end
            AG_IDLE: begin
                if (w_1us_tick == 1'b1) begin
                    if (tick_cnt_reg == (BIT_WIDTH) - 1) begin // slack time > 58msec
                        n_state = IDLE;
                        tick_cnt_next = 0;
                        done_next = 1'b1;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            default: n_state = IDLE;
        endcase
    end
endmodule

module tick_gen_1us (
    input clk,
    input rst,
    output reg o_tick  
);

    // 100MHz / 100 = 1MHz (1us)
    parameter F_COUNT = 100;

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick      <= 0;
        end else begin
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_tick      <= 1'b1; 
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick      <= 1'b0;
            end
        end
    end

endmodule
