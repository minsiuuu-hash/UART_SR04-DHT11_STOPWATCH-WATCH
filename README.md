FPGA : Basys3
Frequency = 100Mhz

Tool : Vivado , VS code

Design Goal
1. STOPWATCH Function(sw[1] = 0, stopwatch mode)
   1) initial value = 00:00:00.00, sw[5:3] = 3'bxxx;
   2) sw[0] = 0, press right btn(START) = increase stopwatch time(msec)
   3) sw[1] = 1, press right btn(START) = decrease stopwatch time(msec)
   4) press left btn or rst btn = clear stopwatch time to initial value
   5) sw[1] = 1, Hour:Min mode
   6) sw[1] = 0, Sec:Msec mode

2. WATCH Function(sw[1] = 1, watch mode)
   1) initial value = 12:00:00.00
   2) sw[0] = 1, normal watch
   3) sw[1] = 0, you can change clock time using left, right, up, down btn
      1. Right btn = Min, Msec UP
      2. Left btn = Hour, Sec UP
      3. Up btn = Min, Msec DOWN
      4. Down btn = Hour, Sec DOWN

3. SR04(sw[5:0] = 6'b001000)
   1) SPEC
      1. Distance = 2 ~ 400cm
      2. Angle = -15º ~ 15º
      4. Out Signal = HIGH pulse
   2) sensor can't measure distance exactly, so we measure the average distance value for 2sec.

4. DHT11
   1) SPEC
      1. Humidiy = 20% ~ 90%
      2. Temperature = 0ºC ~ 50ºC
   3) Humidity (sw[5:0] = 6'b110000)
      1. sensor can't measure humidity exactly, so we measure the average distance value for 2sec.  
   3) Temperature (sw[5:0] = 6'b010000)
      1. sensor can't measure temperature exactly, so we measure the average distance value for 2sec.
     

Block Diagram

1. STOPWATCH
![project image](img/stopwatch.png)
tick_gen_100hz = 10msec <br>
make tick_count to make time <br>
hour = 0 ~ 23 , min = 0 ~ 59 , sec = 0 ~ 59 , msec = 0 ~ 99 <br>
hour = 5bit , min = 6bit , sec = 6bit , msec = 7bit <br>

2. WATCH 
![project image](img/stopwatch.png)
same like stopwatch
3. FULL
![project image](img/whole.png)

in the bottom, it is our presentation.   
[UART_SR04_DHT11_STOPWATCH_WATCH.pdf](https://github.com/user-attachments/files/25823325/UART_SR04_DHT11_STOPWATCH_WATCH.pdf)

TO VERIFICATION THIS PROJECT
We make SYSTEM VERILOG CODE LIKE UVM

1. STOPWATCH_WATCH B/D
   사진추가
   각각의 시나리오
3. FIFO B/D
   사진추가
   각각의 시나리오
5. UART RX B/D
   사진추가
   각각의 시나리오
7. UART FULL B/D
  사진추가
 각각의 시나리오



