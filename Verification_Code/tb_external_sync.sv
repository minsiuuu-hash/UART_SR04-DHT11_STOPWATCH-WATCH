`timescale 1ns / 1ps

// Self-checking regression: nominal 100 MHz, 9600 baud and real sensor pulse widths.
// Digital simulation checks latency/protocol behavior; it cannot model metastability.
module tb_external_sync;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg [5:0] sw = 0;
    reg [3:0] buttons = 0;
    reg rx = 1;
    wire tx;
    tri1 top_dht;
    TOP_module dut (
        .clk(clk), .rst(rst), .sw(sw),
        .btn_l(buttons[0]), .btn_r(buttons[1]),
        .btn_u(buttons[2]), .btn_d(buttons[3]),
        .uart_rx(rx), .i_echo(1'b0), .uart_tx(tx),
        .o_trig(), .dhtio(top_dht), .fnd_digit(), .fnd_data()
    );

    localparam BIT_NS = (100_000_000 / (9600 * 16)) * 16 * 10;
    reg [7:0] expected [0:255];
    integer expected_count = 0;
    integer received_count = 0;
    integer full_cycles = 0;
    integer queued_cycles = 0;
    integer button_count [0:3];
    reg [3:0] previous_buttons = 0;
    wire [3:0] button_pulses = {dut.o_btn_d, dut.o_btn_u, dut.o_btn_r, dut.o_btn_l};
    reg uart_ok = 0, sr04_ok = 0, dht_ok = 0, sync_ok = 0;
    integer i;

    reg unit_input = 0;
    wire unit_zero, unit_one;
    sync_2ff sync_zero (.clk(clk), .rst(rst), .async_in(unit_input), .sync_out(unit_zero));
    sync_2ff #(.INIT(1'b1)) sync_one (
        .clk(clk), .rst(rst), .async_in(unit_input), .sync_out(unit_one));

    reg sr_start = 0, echo = 0;
    wire sr_trigger, sr_done;
    wire [15:0] distance;
    // Shorten the quiet period; retain a 14-bit counter for the longest 11600 us pulse.
    // The 1 us measurement tick is unchanged.
    sr04_controller #(.BIT_WIDTH(16384)) sr (
        .clk(clk), .rst(rst), .start(sr_start), .echo(echo),
        .trigger(sr_trigger), .done(sr_done), .dist_data(distance));

    reg dht_start = 0, sensor_low = 0;
    tri1 dht_bus;
    assign dht_bus = sensor_low ? 1'b0 : 1'bz;
    wire [15:0] humidity, temperature;
    wire dht_done, dht_valid;
    dht11_controller dht (
        .clk(clk), .rst(rst), .start(dht_start),
        .humidity(humidity), .temperature(temperature),
        .dht11_done(dht_done), .dht11_valid(dht_valid), .debug(), .dhtio(dht_bus));

    task expect_text(input string value);
        integer j;
        begin
            for (j = 0; j < value.len(); j = j + 1) begin
                expected[expected_count] = value[j];
                expected_count = expected_count + 1;
            end
        end
    endtask

    task send_byte(input [7:0] value);
        integer j;
        begin
            // Deliberately change the external pin away from a sampling clock edge.
            @(negedge clk); #3;
            rx = 0;
            #(BIT_NS);
            for (j = 0; j < 8; j = j + 1) begin
                rx = value[j];
                #(BIT_NS);
            end
            rx = 1;
            #(BIT_NS);
        end
    endtask

    task drain;
        begin
            wait (received_count == expected_count);
            #(BIT_NS * 2);
            if (dut.w_sender_busy || !dut.w_rx_empty)
                $fatal(1, "Sender/RX did not drain");
        end
    endtask

    task set_switches(input [5:0] value);
        begin
            @(negedge clk); #2;
            sw = value;
            repeat (3) @(posedge clk);
            #1;
            if (dut.sw_sync !== value) $fatal(1, "Switch synchronization failed");
        end
    endtask

    task measure_distance(input integer cm, input integer phase_ns);
        begin
            @(negedge clk); sr_start = 1;
            @(negedge clk); sr_start = 0;
            @(posedge sr_trigger);
            @(negedge sr_trigger);
            #(200003 + phase_ns);
            echo = 1;
            #(cm * 58000);
            echo = 0;
            @(posedge sr_done); #1;
            // Existing 1 us quantization/floor division can differ by one cm at a boundary.
            if (distance < cm - 1 || distance > cm)
                $fatal(1, "SR04 %0d cm stimulus produced %0d", cm, distance);
            $display("PASS SR04: stimulus=%0d cm result=%0d cm phase=%0d ns", cm, distance, phase_ns);
        end
    endtask

    task send_dht_frame(input [39:0] frame, input integer phase_ns);
        integer j;
        begin
            @(negedge clk); dht_start = 1;
            @(negedge clk); dht_start = 0;
            // Model the sensor after the host releases the existing bidirectional driver.
            wait (dht.io_sel_reg == 0);
            #(3 + phase_ns);
            sensor_low = 1;
            #80000;
            sensor_low = 0;
            #80000;
            for (j = 39; j >= 0; j = j - 1) begin
                sensor_low = 1;
                #50000;
                sensor_low = 0;
                if (frame[j]) #70000;
                else #28000;
            end
            sensor_low = 1;
            #50000;
            sensor_low = 0;
            // done is combinational: sample it as a synchronous consumer would,
            // rather than triggering on an intermediate delta-cycle transition.
            do @(posedge clk); while (!dht_done);
            #1;
            if (humidity !== frame[39:24] || temperature !== frame[23:8] || !dht_valid)
                $fatal(1, "DHT mismatch H=%h T=%h valid=%b", humidity, temperature, dht_valid);
            $display("PASS DHT: H=%h T=%h checksum valid, phase=%0d ns", humidity, temperature, phase_ns);
            repeat (5) @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.w_sender_busy && dut.w_rx_pop) $fatal(1, "RX pop during sender busy");
            if (dut.w_sender_tx_start && (dut.w_echo_valid || dut.w_tx_full))
                $fatal(1, "TX collision/rejected sender byte");
            if (dut.U_UART_TOP.w_rx_done && dut.U_UART_TOP.U_FIFO_RX.full)
                $fatal(1, "Unexpected RX overflow in test");
            if (dut.w_tx_full) full_cycles = full_cycles + 1;
            if (dut.w_sender_busy && !dut.w_rx_empty) queued_cycles = queued_cycles + 1;
            for (integer k = 0; k < 4; k = k + 1) begin
                if (button_pulses[k] && previous_buttons[k]) $fatal(1, "Button pulse wider than one clock");
                if (button_pulses[k]) button_count[k] = button_count[k] + 1;
            end
            previous_buttons <= button_pulses;
        end
    end

    initial begin : serial_monitor
        reg [7:0] value;
        integer j;
        wait (!rst);
        forever begin
            @(negedge tx);
            #(BIT_NS / 2);
            if (tx !== 0) $fatal(1, "Invalid UART start");
            for (j = 0; j < 8; j = j + 1) begin
                #(BIT_NS);
                value[j] = tx;
            end
            #(BIT_NS);
            if (tx !== 1) $fatal(1, "Invalid UART stop");
            if (received_count >= expected_count || value !== expected[received_count])
                $fatal(1, "UART byte %0d expected %h got %h", received_count, expected[received_count], value);
            received_count = received_count + 1;
        end
    end

    initial begin
        for (i = 0; i < 4; i = i + 1) button_count[i] = 0;
        repeat (5) @(negedge clk);
        if (unit_zero !== 0 || unit_one !== 1) $fatal(1, "INIT/reset failed");
        rst = 0;
    end

    initial begin
        wait (!rst);
        repeat (3) @(negedge clk);
        #2; unit_input = 1;
        @(posedge clk); #1;
        if (unit_zero !== 0 || unit_one !== 0) $fatal(1, "Output changed after only one FF");
        @(posedge clk); #1;
        if (unit_zero !== 1 || unit_one !== 1) $fatal(1, "Two-cycle capture failed");
        @(negedge clk); #3; unit_input = 0;
        @(posedge clk); #1;
        if (unit_zero !== 1) $fatal(1, "Falling edge bypassed second FF");
        @(posedge clk); #1;
        if (unit_zero !== 0) $fatal(1, "Falling edge not synchronized");
        sync_ok = 1;
        $display("PASS 2FF: INIT=0/1 and rising/falling latency");
    end

    initial begin
        wait (!rst);
        measure_distance(10, 0);
        measure_distance(100, 17);
        measure_distance(200, 451);
        sr04_ok = 1;
    end

    initial begin
        wait (!rst);
        send_dht_frame({8'd55, 8'd0, 8'd20, 8'd0, 8'd75}, 0);
        send_dht_frame({8'd61, 8'd0, 8'd26, 8'd0, 8'd87}, 7);
        dht_ok = 1;
    end

    initial begin : top_scenarios
        integer j;
        // Freeze only the display payload for deterministic UART formatting checks.
        // All external input synchronizers and both serial engines remain active.
        force dut.w_watch_time = {5'd11, 6'd4, 6'd12, 7'd67};
        wait (!rst);
        for (j = 0; j < 6; j = j + 1) set_switches(6'b000001 << j);
        set_switches(0);
        for (j = 0; j < 4; j = j + 1) begin
            #3; buttons[j] = 1;
            #20000; buttons[j] = 0; // Too short to pass eight 10 us samples.
            #100000;
            if (button_count[j] != 0) $fatal(1, "Short button glitch accepted");
            #7; buttons[j] = 1;
            #200000;
            if (button_count[j] != 1) $fatal(1, "Held button did not produce exactly one pulse");
            buttons[j] = 0;
            #100000;
            #1; buttons[j] = 1;
            #200000;
            buttons[j] = 0;
            #100000;
            if (button_count[j] != 2) $fatal(1, "Second press not recognized");
        end
        $display("PASS buttons/switches: 4 buttons, glitch rejection, hold/repress; 6 switch bits");

        expect_text("r"); send_byte("r"); drain();
        expect_text("11:04:12.67\015\012r11:04:12.67\015\012u");
        send_byte("s"); send_byte("r"); send_byte("s"); send_byte("u"); drain();
        set_switches(6'b001000);
        expect_text("d=000cm\015\012l"); send_byte("s"); send_byte("l"); drain();
        set_switches(6'b010000);
        expect_text("T=00.00C\015\012d"); send_byte("s"); send_byte("d"); drain();
        set_switches(6'b110000);
        expect_text("H=00.00%\015\012r"); send_byte("s"); send_byte("r"); drain();
        if (full_cycles == 0 || queued_cycles == 0) $fatal(1, "Backpressure not exercised");
        uart_ok = 1;
        $display("PASS UART: %0d exact bytes at 9600 baud; queued commands and TX full", received_count);
    end

    initial begin
        wait (sync_ok && sr04_ok && dht_ok && uart_ok);
        $display("PASS ALL external input synchronization regressions");
        $finish;
    end
    initial begin
        #150000000;
        $fatal(1, "Timeout sync=%b sr04=%b dht=%b uart=%b bytes=%0d/%0d",
            sync_ok, sr04_ok, dht_ok, uart_ok, received_count, expected_count);
    end
endmodule
