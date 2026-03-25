`timescale 1ns / 1ps

interface uart_interface (
    input logic clk
);
    logic rst;
    logic uart_rx;
    logic uart_tx;

    property preset_check;
        @(posedge clk) $fell(
            rst
        ) |=> (uart_rx == 1'b1);
    endproperty

    reg_reset_check :
    assert property (preset_check)
        $display("%t : [ASSERT] Reset Initial Value Passed!", $time);
    else $error("%t : [ASSERT] Check Your Reset Initial Value!", $time);

endinterface  // uart_interface

class transaction;

    rand bit [7:0] tx_data; // Data to send (PC -> Board)
    logic    [7:0] rx_data; // Data received (Board -> PC)

    function void display(string name);
        $display("%t : [%s] tx_data = %2h, rx_data = %2h", $time, name,
                 tx_data, rx_data);
    endfunction

endclass  // transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;  // Send expected data to SCB
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  // new()

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr);  // Put expected data for scoreboard
            tr.display("GEN");
            @(gen_next_ev);
        end
    endtask  // run

endclass  // generator

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_if;

    localparam BIT_PERIOD = 10416;  // 9600 Baudrate

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_if = uart_if;
    endfunction

    task preset();
        uart_if.rst = 1;
        uart_if.uart_rx = 1;  // Idle state for UART is HIGH
        @(negedge uart_if.clk);
        @(negedge uart_if.clk);
        uart_if.rst = 0;
        @(negedge uart_if.clk);
    endtask  // preset

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(posedge uart_if.clk);
            tr.display("DRV_START");

            // START Bit
            uart_if.uart_rx = 0;
            repeat (BIT_PERIOD) @(posedge uart_if.clk);

            // DATA Bits (LSB First)
            for (int i = 0; i < 8; i++) begin
                uart_if.uart_rx = tr.tx_data[i];
                repeat (BIT_PERIOD) @(posedge uart_if.clk);
            end

            // STOP Bit
            uart_if.uart_rx = 1;
            repeat (BIT_PERIOD) @(posedge uart_if.clk);

            tr.display("DRV_DONE");
        end
    endtask  // run

endclass  // driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_interface uart_if;

    localparam BIT_PERIOD = 10416;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if = uart_if;
    endfunction  // new()

    task run();
        forever begin
            tr = new();
            // Wait for START bit (Falling edge of uart_tx)
            @(negedge uart_if.uart_tx);

            // Move to the middle of the START bit, then to the middle of the first DATA bit
            repeat (BIT_PERIOD / 2) @(posedge uart_if.clk);
            repeat (BIT_PERIOD) @(posedge uart_if.clk);

            // DATA Bits
            for (int i = 0; i < 8; i++) begin
                tr.rx_data[i] = uart_if.uart_tx;
                repeat (BIT_PERIOD) @(posedge uart_if.clk);
            end

            tr.display("MON_CAPTURE");
            mon2scb_mbox.put(tr);
        end
    endtask  // run

endclass  // monitor

class scoreboard;

    transaction gen_tr;
    transaction mon_tr;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    logic [7:0] expected_queue[$:16];
    logic [7:0] compare_data;

    int total_count;
    int pass_count;
    int fail_count;

    function new(mailbox#(transaction) gen2scb_mbox,
                 mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.gen2scb_mbox = gen2scb_mbox;
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev = gen_next_ev;

        total_count = 0;
        pass_count = 0;
        fail_count = 0;
    endfunction  // new()

    task run(int run_count);
        repeat (run_count) begin
            // GET expected
            gen2scb_mbox.get(gen_tr);
            expected_queue.push_front(gen_tr.tx_data);

            // GET  actual
            mon2scb_mbox.get(mon_tr);

            // compare
            compare_data = expected_queue.pop_back();
            total_count++;

            if (compare_data == mon_tr.rx_data) begin
                pass_count++;
                $display("%t : [SCB] PASS! | Expected: %2h == Received: %2h",
                         $time, compare_data, mon_tr.rx_data);
            end else begin
                fail_count++;
                $display("%t : [SCB] FAIL! | Expected: %2h != Received: %2h",
                         $time, compare_data, mon_tr.rx_data);
            end

            ->gen_next_ev;
        end

        //  summary
        $display(
            "\n==================================================================");
        $display("%t : [SCB_SUMMARY] TOTAL=%0d PASS=%0d FAIL=%0d", $time,
                 total_count, pass_count, fail_count);
        $display(
            "==================================================================\n");
    endtask  // run

endclass  // scoreboard

class environment;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event                  gen_next_ev;
    virtual uart_interface uart_if;

    function new(virtual uart_interface uart_if);
        gen2drv_mbox = new();
        gen2scb_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, uart_if);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(gen2scb_mbox, mon2scb_mbox, gen_next_ev);
    endfunction  // new()

    task run();
        drv.preset();
        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run(100);
        join_any
    endtask

endclass  // environment

module tb_uart_top ();

    logic clk;
    uart_interface uart_if (clk);
    environment env;

    UART_TOP dut (
        .clk(clk),
        .rst(uart_if.rst),
        .uart_rx(uart_if.uart_rx),
        .uart_tx(uart_if.uart_tx)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(uart_if);
        env.run();

        #10000;
        $display("%t : [SIM] Simulation Finished.", $time);
        $finish;
    end

endmodule
