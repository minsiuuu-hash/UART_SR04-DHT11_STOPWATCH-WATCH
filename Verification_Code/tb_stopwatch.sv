`timescale 1ns / 1ps

interface stopwatch_interface (
    input logic clk
);
    logic       rst;
    logic       mode;  // 0: Up count, 1: Down count
    logic       clear;  // btn L
    logic       run_stop;  // btn R

    logic [6:0] msec;
    logic [5:0] sec;
    logic [5:0] min;
    logic [4:0] hour;

    // Assert: clear(버튼 L)가 눌리면 모든 카운트가 0이 되어야 함
    property clear_check;
        @(posedge clk) clear |=> (msec == 0 && sec == 0 && min == 0 && hour == 0);
    endproperty
    assert property (clear_check)
    else $error("%t : Clear Failed!", $time);

endinterface  // stopwatch_interface

class transaction;

    rand bit run_stop;
    rand bit clear;
    rand bit mode;
    rand int duration;

    logic [6:0] msec;
    logic [5:0] sec;
    logic [5:0] min;
    logic [4:0] hour;

    constraint c_duration {duration inside {[10 : 50000]};}

    function void display(string name);
        $display(
            "%t : [%s] run_stop(R)=%b, clear(L)=%b, mode=%b, duration=%0d clks | Time = %0d:%0d:%0d.%0d",
            $time, name, run_stop, clear, mode, duration, hour, min, sec, msec);
    endfunction

endclass  // transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int run_count);

        // mode=0, run_stop=1, clear=0 = up count
        tr = new();
        if (!tr.randomize() with {
                mode == 0;
                run_stop == 1;
                clear == 0;
            })
            $fatal(1, "Gen error 1");
        gen2drv_mbox.put(tr);
        tr.display("GEN_SEQ_1_UP_RUN");
        @(gen_next_ev);

        //  mode=1, run_stop=0, clear=0 = down count, stop
        tr = new();
        if (!tr.randomize() with {
                mode == 1;
                run_stop == 0;
                clear == 0;
            })
            $fatal(1, "Gen error 2");
        gen2drv_mbox.put(tr);
        tr.display("GEN_SEQ_2_DOWN_STOP");
        @(gen_next_ev);

        //  clear only 1 time
        tr = new();
        if (!tr.randomize() with {clear == 1;}) $fatal(1, "Gen error 3");
        gen2drv_mbox.put(tr);
        tr.display("GEN_SEQ_3_CLEAR");
        @(gen_next_ev);

        //  last run_count > run_stop = random, no clear
        repeat (run_count) begin
            tr = new();
            if (!tr.randomize() with {clear == 0;}) $fatal(1, "Gen error 4");
            gen2drv_mbox.put(tr);
            tr.display("GEN_SEQ_4_RANDOM");
            @(gen_next_ev);
        end

    endtask

endclass

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual stopwatch_interface stopwatch_if;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual stopwatch_interface stopwatch_if, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.stopwatch_if = stopwatch_if;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task preset();
        stopwatch_if.rst = 1;
        stopwatch_if.clear = 0;
        stopwatch_if.run_stop = 0;
        stopwatch_if.mode = 0;
        repeat (5) @(negedge stopwatch_if.clk);
        stopwatch_if.rst = 0;
        $display("%t : [DRV] Reset Completed", $time);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);

            stopwatch_if.run_stop = tr.run_stop;
            stopwatch_if.clear    = tr.clear;
            stopwatch_if.mode     = tr.mode;

            tr.display("DRV");

            repeat (tr.duration) @(posedge stopwatch_if.clk);

            ->gen_next_ev;
        end
    endtask

endclass  // driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual stopwatch_interface stopwatch_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual stopwatch_interface stopwatch_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task run();
        forever begin
            tr = new();
            @(negedge stopwatch_if.clk);
            tr.run_stop = stopwatch_if.run_stop;
            tr.clear    = stopwatch_if.clear;
            tr.mode     = stopwatch_if.mode;
            tr.msec     = stopwatch_if.msec;
            tr.sec      = stopwatch_if.sec;
            tr.min      = stopwatch_if.min;
            tr.hour     = stopwatch_if.hour;
            mon2scb_mbox.put(tr);
        end
    endtask

endclass  // monitor

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    logic [6:0] prev_msec;
    logic prev_run_stop;

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
        prev_run_stop = 0;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("SCB");

            prev_msec = tr.msec;
            prev_run_stop = tr.run_stop;
        end
    endtask

endclass  // scoreboard

class environment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    virtual stopwatch_interface stopwatch_if;

    function new(virtual stopwatch_interface stopwatch_if);
        this.stopwatch_if = stopwatch_if;
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, stopwatch_if, gen_next_ev);
        mon = new(mon2scb_mbox, stopwatch_if);
        scb = new(mon2scb_mbox);
    endfunction

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
    endtask

endclass  // environment

module tb_stopwatch ();

    logic clk;

    stopwatch_interface stopwatch_if (clk);
    environment env;

    stopwatch_datapath dut (
        .clk(clk),
        .rst(stopwatch_if.rst),
        .mode(stopwatch_if.mode),
        .clear(stopwatch_if.clear),
        .run_stop(stopwatch_if.run_stop),
        .msec(stopwatch_if.msec),
        .sec(stopwatch_if.sec),
        .min(stopwatch_if.min),
        .hour(stopwatch_if.hour)
    );
    defparam dut.u_TICK.F_COUNT = 1;
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(stopwatch_if);
        env.run();
        #100 $finish;
    end

endmodule
