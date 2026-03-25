`timescale 1ns / 1ps

interface uart_interface (
    input logic clk
);

    logic       rst;
    logic       rx;
    logic [7:0] rx_data;
    logic       rx_done;

endinterface

class transaction;

    rand bit [7:0] TX;  // 8-bit expected data sent from testbench
    logic    [7:0] rx_data;  // 8-bit data received from DUT
    logic          rx_done;

    function void display(string name);
        $display("%t : [%s] TX = %2h, rx_data = %2h, rx_done = %0b", $time,
                 name, TX, rx_data, rx_done);
    endfunction

endclass

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox; // mailbox to send expected data to scoreboard
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);  // send transaction to driver
            gen2scb_mbox.put(tr);  // send expected value to scoreboard
            tr.display("GEN");
            @(gen_next_ev);
        end
    endtask

endclass

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_if;

    localparam BIT_PERIOD = 10416;  // 9600bps

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_if = uart_if;
    endfunction

    task preset();
        uart_if.rst = 1;
        uart_if.rx  = 1;
        @(posedge uart_if.clk);
        @(posedge uart_if.clk);
        uart_if.rst = 0;
        @(posedge uart_if.clk);
    endtask

    task uart_tx(logic [7:0] data);
        // Start bit (0)
        uart_if.rx = 0;
        repeat (BIT_PERIOD) @(posedge uart_if.clk);

        // Data bits (LSB first)
        for (int i = 0; i < 8; i++) begin
            uart_if.rx = data[i];
            repeat (BIT_PERIOD) @(posedge uart_if.clk);
        end

        // Stop bit (1)
        uart_if.rx = 1;
        repeat (BIT_PERIOD) @(posedge uart_if.clk);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            uart_tx(tr.TX);
            tr.display("DRV");
            // Idle time before next frame
            // repeat (BIT_PERIOD * 2)
            @(posedge uart_if.clk);
            @(posedge uart_if.clk);
        end
    endtask

endclass

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_interface uart_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if = uart_if;
    endfunction

    task run();
        fork
            // Track shifting process in real time
            forever begin
                @(posedge uart_if.rx_done);  //@(uart_if.rx_data);
                @(negedge uart_if.clk);
                if (!uart_if.rst) begin
                    $display("%t : rx_data = %2h", $time, uart_if.rx_data);
                end
            end

            // Capture final result when rx_done is asserted
            forever begin
                @(posedge uart_if.rx_done);
                @(negedge uart_if.clk);
                tr = new();
                tr.rx_data = uart_if.rx_data;
                tr.rx_done = uart_if.rx_done;
                tr.display("MON");
                mon2scb_mbox.put(tr);
            end
        join
    endtask

endclass

class scoreboard;

    transaction tr_mon;
    transaction tr_gen;

    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_ev;

    int unsigned total_cnt, pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen2scb_mbox = gen2scb_mbox;
        this.gen_next_ev = gen_next_ev;

        total_cnt = 0;
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction

    task run();
        forever begin
            gen2scb_mbox.get(tr_gen);
            mon2scb_mbox.get(tr_mon);

            total_cnt++;

            if (tr_mon.rx_data === tr_gen.TX) begin
                pass_cnt++;
                $display("%t : [SCB] PASS: %0d times, TX = %2h, rx_data = %2h",
                         $time, total_cnt, tr_gen.TX, tr_mon.rx_data);
            end else begin
                fail_cnt++;
                $display("%t : [SCB] FAIL: %0d times, TX = %2h, rx_data = %2h",
                         $time, total_cnt, tr_gen.TX, tr_mon.rx_data);
            end
            $display("      [SCB]  total = %0d times, pass = %0d, fail = %0d\n",
                     total_cnt, pass_cnt, fail_cnt);
            ->gen_next_ev;
        end
    endtask

endclass

class environment;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;

    event                  gen_next_ev;
    virtual uart_interface uart_if;

    function new(virtual uart_interface uart_if);
        this.uart_if = uart_if;

        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen2scb_mbox = new();

        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, uart_if);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(mon2scb_mbox, gen2scb_mbox, gen_next_ev);
    endfunction

    task run();
        drv.preset();
        fork
            gen.run(100);  // run 10 random test cases
            drv.run();
            mon.run();
            scb.run();
        join_any

        #50000 $stop;  // end simulation
    endtask

endclass

module tb_uart_rx;

    logic clk;
    always #5 clk = ~clk;  // 100MHz clock generation

    uart_interface uart_if (clk);
    environment env;

    // DUT connection (uart_rx_top must exist in the project)
    uart_rxtop dut (
        .clk(clk),
        .rst(uart_if.rst),
        .rx(uart_if.rx),
        .rx_data(uart_if.rx_data),
        .rx_done(uart_if.rx_done)
    );

    initial begin
        clk = 0;
        env = new(uart_if);
        env.run();
    end

endmodule
