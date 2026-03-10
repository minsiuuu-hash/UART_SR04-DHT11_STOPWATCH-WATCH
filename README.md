FPGA : Basys3 

Tool : Vivado , VS code

Design Goal
1. STOPWATCH Function(sw[1] = 0, stopwatch mode)
   1) initial value = 00:00:00.00, sw[6:2] = 5'bxxxxx;
   2) sw[0] = 0, press right btn(START) = increase stopwatch time
   3) sw[1] = 1, press right btn(START) = decrease stopwatch time
   4) press left btn or rst btn = clear stopwatch time to initial value

2. WATCH Function(sw[1] = 1, watch mode)
   1) initial value = 12:00:00.00
   2) sw[0] = 1, normal watch
   3) sw[1] = 0, we can change clock time using left, right, up, down btn
      1. Right btn = Min, Msec UP
      2. Left btn = Hour, Sec UP
      3. Up btn = Min, Msec DOWN
      4. Down btn = Hour, Sec DOWN
   4)  asdf

3. SR04
   1) ASDF
   2) dfea

5. DHT11
   1) ASDF
   
[UART_SR04_DHT11_STOPWATCH_WATCH.pdf](https://github.com/user-attachments/files/25823325/UART_SR04_DHT11_STOPWATCH_WATCH.pdf)
