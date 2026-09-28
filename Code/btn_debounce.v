`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  rst,
    input  i_btn,
    output o_btn
);

    parameter CLK_DIV = 100_000;
    parameter F_COUNT = 100_000_000 / CLK_DIV;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg CLK_100khz_reg;

    // 버튼 접점은 먼저 clk에 동기화하고, 이후 기존 8회 샘플 판정을 적용한다.
    wire btn_sync;
    sync_2ff U_SYNC_BTN (
        .clk(clk), .rst(rst), .async_in(i_btn), .sync_out(btn_sync)
    );

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

    // 샘플링 펄스를 enable로 사용해 2FF, debounce, edge 검출을 같은 clk에 둔다.
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            q_reg <= 0;
        end else begin
            if (CLK_100khz_reg) q_reg <= q_next;
        end
    end

    always @(*) begin
        q_next = {btn_sync, q_reg[7:1]};
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
