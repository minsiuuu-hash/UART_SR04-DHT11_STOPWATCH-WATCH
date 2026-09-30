`timescale 1ns / 1ps

// INIT: 1 for UART RX and DHT11, 0 for other inputs.
module sync_2ff #(
    parameter INIT = 1'b0
) (
    input  wire clk,
    input  wire rst,
    input  wire async_in,
    output wire sync_out
);
    reg meta_ff, sync_ff;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            meta_ff <= INIT;
            sync_ff <= INIT;
        end else begin
            meta_ff <= async_in;
            sync_ff <= meta_ff;
        end
    end

    // 첫 번째 FF는 외부 로직에서 사용하지 않는다.
    assign sync_out = sync_ff;
endmodule
