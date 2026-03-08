`timescale 1ns / 1ps

module control_unit (
    input clk,
    input rst,
    input i_sel_mode,  // sw[1] : 0:stopwatch, 1: watch
    input i_mode,      // sw[0]
    input i_run_stop,  // btn_r (Right Button)
    input i_clear,     // btn_l (Left Button)
    input i_down_u,    // btn_u (Up Button -> Watch Down Left)
    input i_down_d,    // btn_d (Down Button -> Watch Down Right)

    output reg o_mode,     //stopwach
    output reg o_run_stop,
    output reg o_clear,

    output reg o_watch_up_l,    // Watch hour/sec Up Left 
    output reg o_watch_up_r,    // Watch min/msec Up Right 
    output reg o_watch_down_u,  // Watch hour/sec Down Left 
    output reg o_watch_down_d,  // Watch min/msec Down Right 
    output reg o_watch_change   // Watch change mode
);

    reg [1:0] current_st, next_st;
    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10;

    // SL 
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            current_st <= STOP;
        end else begin
            current_st <= next_st;
        end
    end

    // CL
    always @(*) begin
        next_st = current_st;
        o_run_stop = 1'b0;
        o_clear = 1'b0;
        o_mode = 1'b0;
        o_watch_change = 1'b0;
        o_watch_up_l = 1'b0;
        o_watch_up_r = 1'b0;
        o_watch_down_u = 1'b0;
        o_watch_down_d = 1'b0;

        if (i_sel_mode == 0) begin
            o_mode = i_mode;  // Stopwatch Datapath Up/Down 
            case (current_st)
                STOP: begin
                    o_run_stop = 0;
                    o_clear = 0;
                    if (i_run_stop == 1) begin
                        next_st = RUN;
                    end else if (i_clear == 1) begin
                        next_st = CLEAR;
                    end else begin
                        next_st = STOP;
                    end
                end

                RUN: begin
                    o_run_stop = 1;  // keep 1
                    o_clear = 0;
                    if (i_run_stop == 1) begin
                        next_st = STOP;
                    end else begin
                        next_st = RUN;
                    end
                end

                CLEAR: begin
                    o_run_stop = 0;
                    o_clear = 1;
                    next_st = STOP; 
                end

                default: begin
                    next_st = STOP;
                    o_clear = 0;
                    o_run_stop = 0;
                end
            endcase

        end else begin
            // watch mode always keep, not 1tick
            o_watch_change = i_mode;  // change

            o_watch_up_l = i_clear;  // Left btn -> hour/sec up
            o_watch_up_r = i_run_stop;  // Right btn -> min/msec up

            o_watch_down_u = i_down_u;    // Up btn -> hour/sec down
            o_watch_down_d = i_down_d;    // Down btn -> min/msec down
        end
    end

endmodule
