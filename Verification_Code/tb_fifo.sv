`timescale 1ns / 1ps `timescale 1ns / 1ps

interface fifo_interface (
    input logic clk
);

    logic       rst;
    logic [7:0] wdata;
    logic       we;  //push
    logic       re;  //pop
    logic [7:0] rdata;
    logic       full;
    logic       empty;

    //assert
    property preset_check;
        @(posedge clk) $fell(
            rst
        ) |=> (empty == 1'b1 && full == 1'b0);
    endproperty

    property no_write_when_full;
        @(posedge clk) disable iff (rst) full |-> !we;
    endproperty

    property no_read_when_empty;
        @(posedge clk) disable iff (rst) 
    empty |-> !re; // empty == 1 >>>>  re == 0
    endproperty

    reg_empty_full_check :
    assert property (preset_check)
    else
        $error(
            "%t : Check Your Reset Initial Value! empty = %b, full = %b",
            $time,
            empty,
            full
        );

    reg_full_nowrite_check :
    assert property (no_write_when_full)
    else
        $error(
            "%t : you are full, you can't write full = %b we = %b ",
            $time,
            full,
            we
        );

    reg_empty_noread_check :
    assert property (no_read_when_empty)
    else
        $error(
            "%t : you are empty, you can't read empty=%b  re=%b",
            $time,
            empty,
            re
        );

endinterface  //fifo_interface

class transaction;

    rand bit [7:0] wdata;
    rand bit       we;  //push
    rand bit       re;  //pop
    logic    [7:0] rdata;
    logic          rst;
    logic          full;
    logic          empty;
    
    function void display(string name);
        $display(
            "%t : [%s] push=%h, wdata =%2h, full=%h, pop=%h, rdata = %2h, empty = %h",
            $time, name, we, wdata, full, re, rdata, empty);

    endfunction  //new()

    // constraint
    // constraint read_only {we == 0; re == 1;}
    // constraint write_only {
    //     we == 1;
    //     re == 0;
    // }

endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            gen2drv_mbox.put(tr);
            @(gen_next_ev);
        end
    endtask  //run

endclass  //generator

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_if = fifo_if;
    endfunction

    task preset();
        fifo_if.rst = 1;
        fifo_if.wdata = 0;
        fifo_if.we = 0;
        fifo_if.re = 0;
        @(negedge fifo_if.clk);
        @(negedge fifo_if.clk);
        fifo_if.rst = 0;
        @(negedge fifo_if.clk);
    endtask  //preset

    task push();
        fifo_if.we = tr.we;
        fifo_if.wdata = tr.wdata;
        fifo_if.re = tr.re;
    endtask

    task pop();
        fifo_if.we = tr.we;
        fifo_if.wdata = tr.wdata;
        fifo_if.re = tr.re;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(posedge fifo_if.clk);
            #1;
            tr.display("DRV");
            if (tr.we) push();
            else fifo_if.we = 0;
            if (tr.re) pop();
            else fifo_if.re = 0;
        end
    endtask  //run

endclass  //driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_if;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task run();
        forever begin
            tr = new();
            @(negedge fifo_if.clk);
            tr.we    = fifo_if.we;
            tr.re    = fifo_if.re;
            tr.wdata = fifo_if.wdata;
            tr.rdata = fifo_if.rdata;
            tr.full  = fifo_if.full;
            tr.empty = fifo_if.empty;
            tr.display("MON");
            mon2scb_mbox.put(tr);
        end
    endtask  //run

endclass  //monitor

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    //QUEUE
    logic [7:0] fifo_queue[$:16];
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();  // 
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("SCB");
            //push
            if (tr.we & (!tr.full)) begin
                fifo_queue.push_front(tr.wdata);
            end
            //pop
            if (tr.re & (!tr.empty)) begin
                //pass/fail
                compare_data = fifo_queue.pop_back();
                if (compare_data == tr.rdata) begin
                    $display("pass");
                end else begin
                    $display("fail");
                end
            end
            ->gen_next_ev;
        end
    endtask  //run

endclass  //scoreboard

class environment;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_ev;
    virtual fifo_interface fifo_if;

    function new(virtual fifo_interface fifo_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, fifo_if);
        mon = new(mon2scb_mbox, fifo_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        drv.preset();
        fork
            gen.run(1000);
            drv.run();
            mon.run();
            scb.run();
        join_any
    endtask

endclass  //environment

module tb_fifo ();

    logic clk;
    fifo_interface fifo_if (clk);
    environment env;

    FIFO dut (
        .clk(clk),
        .rst(fifo_if.rst),
        .wdata(fifo_if.wdata),
        .we(fifo_if.we),  //pus()h
        .re(fifo_if.re),  //po()p
        .rdata(fifo_if.rdata),
        .full(fifo_if.full),
        .empty(fifo_if.empty)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(fifo_if);
        env.run();
    end



endmodule
