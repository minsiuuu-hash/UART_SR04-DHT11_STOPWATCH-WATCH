`timescale 1ns / 1ps

module btn_avg_controller (
    input clk,
    input rst,
    input btn_r, // right btn, 1clk pulse

    input mode_sr04,
    input mode_dht11,

    input [15:0] i_distance,
    input [15:0] i_temperature,
    input [15:0] i_humidity,

    output reg o_sr04_start,
    output reg o_dht11_start,

    output reg [15:0] o_avg_distance,
    output reg [15:0] o_avg_temperature,
    output reg [15:0] o_avg_humidity
);
    reg [11:0] ms_timer;
    reg [6:0] sr04_timer;

    reg [19:0] sum_dist;
    reg [16:0] sum_temp;
    reg [16:0] sum_hum;

    // 16times measuring
    reg is_measuring;

    wire tick_1ms;

    tick_gen_1khz U_TICK_GEN_1KHZ (
        .clk(clk),
        .rst(rst),
        .o_1khz(tick_1ms)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ms_timer <= 0;
            sr04_timer <= 0;
            o_sr04_start <= 0;
            o_dht11_start <= 0;
            sum_dist <= 0;
            sum_temp <= 0;
            sum_hum <= 0;
            o_avg_distance <= 0;
            o_avg_temperature <= 0;
            o_avg_humidity <= 0;
            is_measuring <= 0;  
        end else begin
            o_sr04_start  <= 0;
            o_dht11_start <= 0;
            if (btn_r && !is_measuring) begin
                is_measuring <= 1;  // start measuring
                ms_timer <= 0;
                sr04_timer <= 0;
                sum_dist <= 0;
                sum_temp <= 0;
                sum_hum <= 0;
            end
            if (is_measuring) begin
                if (tick_1ms) begin
                    ms_timer <= ms_timer + 1;
                    if (sr04_timer == 124) sr04_timer <= 0;
                    else sr04_timer <= sr04_timer + 1;
                end
                if (mode_sr04) begin
                    if (tick_1ms && sr04_timer == 0) o_sr04_start <= 1;
                    if (tick_1ms && sr04_timer == 60) begin
                        sum_dist <= sum_dist + ((i_distance > 400) ? 16'd400 : i_distance);
                    end
                end
                if (mode_dht11) begin
                    if (tick_1ms && (ms_timer == 0 || ms_timer == 1000))
                        o_dht11_start <= 1;
                    if (tick_1ms && (ms_timer == 500 || ms_timer == 1500)) begin
                        sum_temp <= sum_temp + i_temperature;
                        sum_hum  <= sum_hum + i_humidity;
                    end
                end
                if (tick_1ms && ms_timer == 1999) begin // 2sec, 16times average
                    if (mode_sr04) o_avg_distance <= sum_dist >> 4; // shift calc
                    if (mode_dht11) begin
                        o_avg_temperature <= sum_temp >> 1;
                        o_avg_humidity <= sum_hum >> 1;
                    end
                    is_measuring <= 0; 
                end
            end
        end
    end
endmodule

module tick_gen_1khz (
    input clk,
    input rst,
    output reg o_1khz
);
    parameter F_COUNT = 100_000;

    reg [$clog2(F_COUNT) - 1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_1khz <= 1'b0; 
        end else begin
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_1khz <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_1khz <= 1'b0;
            end
        end
    end
endmodule
