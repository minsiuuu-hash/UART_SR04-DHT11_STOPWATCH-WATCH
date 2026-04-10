`timescale 1ns / 1ps

module ascii_sender (
    input clk,
    input rst,

    input i_send_start,
    input i_tx_busy,

    input [ 1:0] i_mode, // watch/stopwatch, distance, temperature, humidity
    input [15:0] i_distance,
    input [15:0] i_temperature,
    input [15:0] i_humidity,
    input [ 4:0] i_hour,
    input [ 5:0] i_min,
    input [ 5:0] i_sec,
    input [ 6:0] i_msec,

    output reg o_tx_start,
    output reg [7:0] o_tx_data
);

    // FSM STATE
    localparam IDLE = 3'd0;
    localparam CALC_100 = 3'd1;
    localparam CALC_10 = 3'd2;
    localparam WAIT_TX = 3'd3;
    localparam SEND = 3'd4;
    localparam NEXT_CHAR = 3'd5;

    reg [ 2:0] state;
    reg [ 3:0] char_index;
    reg [ 1:0] mode_reg;

    // do minus register
    reg [15:0] w_dist;
    reg [7:0] w_t_int, w_t_dec, w_h_int, w_h_dec;
    reg [6:0] w_hour, w_min, w_sec, w_msec;

    // bcd register
    reg [3:0] d100, d10, d1;  // DISTANCE
    reg [3:0] t_i10, t_i1, t_d10, t_d1;  // TEMPERATURE
    reg [3:0] h_i10, h_i1, h_d10, h_d1;  //HUMIDITY
    reg [3:0] hr10, hr1, mn10, mn1, sc10, sc1, ms10, ms1;  // WATCH,STOPWATCH

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            o_tx_start <= 1'b0;
            o_tx_data <= 8'h00;
            char_index <= 4'd0;
            mode_reg <= 2'd0;

            // initialize
            w_dist <= 0;
            w_t_int <= 0;
            w_t_dec <= 0;
            w_h_int <= 0;
            w_h_dec <= 0;
            w_hour <= 0;
            w_min <= 0;
            w_sec <= 0;
            w_msec <= 0;
            d100 <= 0;
            d10 <= 0;
            d1 <= 0;
            t_i10 <= 0;
            t_i1 <= 0;
            t_d10 <= 0;
            t_d1 <= 0;
            h_i10 <= 0;
            h_i1 <= 0;
            h_d10 <= 0;
            h_d1 <= 0;
            hr10 <= 0;
            hr1 <= 0;
            mn10 <= 0;
            mn1 <= 0;
            sc10 <= 0;
            sc1 <= 0;
            ms10 <= 0;
            ms1 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    o_tx_start <= 1'b0;
                    char_index <= 4'd0;
                    if (i_send_start) begin
                        mode_reg <= i_mode;
                        w_dist <= i_distance;
                        w_t_int <= i_temperature[15:8];
                        w_t_dec <= i_temperature[7:0];
                        w_h_int <= i_humidity[15:8];
                        w_h_dec <= i_humidity[7:0];
                        w_hour <= i_hour;
                        w_min <= i_min;
                        w_sec <= i_sec;
                        w_msec <= i_msec;

                        // BCD CNT initialize
                        d100 <= 0;
                        d10 <= 0;
                        t_i10 <= 0;
                        t_d10 <= 0;
                        h_i10 <= 0;
                        h_d10 <= 0;
                        hr10 <= 0;
                        mn10 <= 0;
                        sc10 <= 0;
                        ms10 <= 0;

                        state <= CALC_100;
                    end
                end
                CALC_100: begin
                    if (mode_reg == 2'd1 && w_dist >= 100) begin // distance mode
                        w_dist <= w_dist - 100;  
                        d100   <= d100 + 1;  
                    end else begin
                        state <= CALC_10; 
                    end
                end
                CALC_10: begin
                    if (mode_reg == 2'd0) begin  // watch/stopwatch
                        if (w_hour >= 10 || w_min >= 10 || w_sec >= 10 || w_msec >= 10) begin
                            if (w_hour >= 10) begin
                                w_hour <= w_hour - 10;
                                hr10   <= hr10 + 1;
                            end
                            if (w_min >= 10) begin
                                w_min <= w_min - 10;
                                mn10  <= mn10 + 1;
                            end
                            if (w_sec >= 10) begin
                                w_sec <= w_sec - 10;
                                sc10  <= sc10 + 1;
                            end
                            if (w_msec >= 10) begin
                                w_msec <= w_msec - 10;
                                ms10   <= ms10 + 1;
                            end
                        end else begin
                            hr1 <= w_hour[3:0];
                            mn1 <= w_min[3:0];
                            sc1 <= w_sec[3:0];
                            ms1 <= w_msec[3:0];
                            state <= WAIT_TX; 
                        end
                    end else if (mode_reg == 2'd1) begin  // distance mode
                        if (w_dist >= 10) begin
                            w_dist <= w_dist - 10;
                            d10 <= d10 + 1;
                        end else begin
                            d1 <= w_dist[3:0];
                            state <= WAIT_TX;
                        end
                    end else if (mode_reg == 2'd2) begin  // temperature mode
                        if (w_t_int >= 10 || w_t_dec >= 10) begin
                            if (w_t_int >= 10) begin
                                w_t_int <= w_t_int - 10;
                                t_i10   <= t_i10 + 1;
                            end
                            if (w_t_dec >= 10) begin
                                w_t_dec <= w_t_dec - 10;
                                t_d10   <= t_d10 + 1;
                            end
                        end else begin
                            t_i1  <= w_t_int[3:0];
                            t_d1  <= w_t_dec[3:0];
                            state <= WAIT_TX;
                        end
                    end else begin  // humidity
                        if (w_h_int >= 10 || w_h_dec >= 10) begin
                            if (w_h_int >= 10) begin
                                w_h_int <= w_h_int - 10;
                                h_i10   <= h_i10 + 1;
                            end
                            if (w_h_dec >= 10) begin
                                w_h_dec <= w_h_dec - 10;
                                h_d10   <= h_d10 + 1;
                            end
                        end else begin
                            h_i1  <= w_h_int[3:0];
                            h_d1  <= w_h_dec[3:0];
                            state <= WAIT_TX;
                        end
                    end
                end

                //BCD
                WAIT_TX: begin
                    if (!i_tx_busy) state <= SEND;
                end

                SEND: begin
                    o_tx_start <= 1'b1;  // FIFO ON
                    state <= NEXT_CHAR;

                    if (mode_reg == 2'd0) begin  // STOPWATCH/WATCH
                        case (char_index)
                            0: o_tx_data <= hr10 + 8'h30;
                            1: o_tx_data <= hr1 + 8'h30;
                            2: o_tx_data <= ":";
                            3: o_tx_data <= mn10 + 8'h30;
                            4: o_tx_data <= mn1 + 8'h30;
                            5: o_tx_data <= ":";
                            6: o_tx_data <= sc10 + 8'h30;
                            7: o_tx_data <= sc1 + 8'h30;
                            8: o_tx_data <= ".";
                            9: o_tx_data <= ms10 + 8'h30;
                            10: o_tx_data <= ms1 + 8'h30;
                            11: o_tx_data <= 8'h0D;
                            12: o_tx_data <= 8'h0A;
                            default: o_tx_data <= " ";
                        endcase
                    end else if (mode_reg == 2'd1) begin  // DISTANCE
                        case (char_index)
                            0: o_tx_data <= "d";
                            1: o_tx_data <= "=";
                            2: o_tx_data <= d100 + 8'h30;
                            3: o_tx_data <= d10 + 8'h30;
                            4: o_tx_data <= d1 + 8'h30;
                            5: o_tx_data <= "c";
                            6: o_tx_data <= "m";
                            7: o_tx_data <= 8'h0D;
                            8: o_tx_data <= 8'h0A;
                            default: o_tx_data <= " ";
                        endcase
                    end else if (mode_reg == 2'd2) begin  // TEMPERATURE
                        case (char_index)
                            0: o_tx_data <= "T";
                            1: o_tx_data <= "=";
                            2: o_tx_data <= t_i10 + 8'h30;
                            3: o_tx_data <= t_i1 + 8'h30;
                            4: o_tx_data <= ".";
                            5: o_tx_data <= t_d10 + 8'h30;
                            6: o_tx_data <= t_d1 + 8'h30;
                            7: o_tx_data <= "C";
                            8: o_tx_data <= 8'h0D;
                            9: o_tx_data <= 8'h0A;
                            default: o_tx_data <= " ";
                        endcase
                    end else begin  // HUMIDITY
                        case (char_index)
                            0: o_tx_data <= "H";
                            1: o_tx_data <= "=";
                            2: o_tx_data <= h_i10 + 8'h30;
                            3: o_tx_data <= h_i1 + 8'h30;
                            4: o_tx_data <= ".";
                            5: o_tx_data <= h_d10 + 8'h30;
                            6: o_tx_data <= h_d1 + 8'h30;
                            7: o_tx_data <= "%";
                            8: o_tx_data <= 8'h0D;
                            9: o_tx_data <= 8'h0A;
                            default: o_tx_data <= " ";
                        endcase
                    end
                end

                NEXT_CHAR: begin
                    o_tx_start <= 1'b0; 
                    if ((mode_reg == 2'd0 && char_index == 4'd12) || 
                        (mode_reg == 2'd1 && char_index == 4'd8)  ||
                        (mode_reg >= 2'd2 && char_index == 4'd9)) begin
                        state <= IDLE;
                    end else begin
                        char_index <= char_index + 1;
                        state <= WAIT_TX;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
