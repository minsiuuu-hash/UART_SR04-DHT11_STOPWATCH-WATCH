`timescale 1ns / 1ps


module btn_debounce (
    input  clk,
    input  rst,
    input  i_btn,
    output o_btn
);


    parameter CLK_DIV = 100000;
    parameter F_COUNT = 100_000_000 / CLK_DIV;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg CLK_100khz_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            CLK_100khz_reg <= 0;

        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                CLK_100khz_reg <= 1'b1;
            end else begin
                CLK_100khz_reg <= 1'b0;
            end
        end
    end

    wire o_btn_down_u, o_btn_down_d;

    reg [7:0] q_reg, q_next;
    reg  edge_reg;
    wire debounce;

    always @(posedge CLK_100khz_reg, posedge rst) begin
        if (rst) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end

    always @(*) begin
        q_next = {i_btn, q_reg[7:1]};

    end

    assign debounce = &q_reg;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            edge_reg <= 0;
        end else begin
            edge_reg <= debounce;
        end
    end

    assign o_btn = debounce & ~edge_reg;

endmodule
