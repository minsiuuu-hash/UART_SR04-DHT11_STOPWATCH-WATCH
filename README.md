# UART + SR04 + DHT11 + Stopwatch + Watch

FPGA : Basys3  
7-segment display : Common Anode  
Frequency : 100 MHz  

Tool : Vivado, VS Code

---

## Design Goal

### 1. STOPWATCH Function

Time mode is selected when `sw[4] = 0` and `sw[3] = 0`.

`sw[1] = 0` : Stopwatch Mode

| Condition | Description |
|---|---|
| Initial Value | `00:00:00.00` |
| `sw[0] = 0` | Up-count mode |
| `sw[0] = 1` | Down-count mode |
| Right Button | Start / Stop stopwatch |
| Left Button or Reset Button | Clear stopwatch time to initial value |
| `sw[2] = 1` | Hour : Min display mode |
| `sw[2] = 0` | Sec : Msec display mode |

In stopwatch mode, the right button toggles the stopwatch between run and stop.  
The counting direction is selected by `sw[0]`.

| `sw[0]` | Stopwatch Operation |
|---|---|
| `0` | Count up |
| `1` | Count down |

### 2. WATCH Function

Time mode is selected when `sw[4] = 0` and `sw[3] = 0`.

`sw[1] = 1` : Watch Mode

| Condition | Description |
|---|---|
| Initial Value | `12:00:00.00` |
| `sw[0] = 0` | Normal watch mode |
| `sw[0] = 1` | Time change mode |
| `sw[2] = 1` | Hour : Min display mode |
| `sw[2] = 0` | Sec : Msec display mode |

In normal watch mode, the watch counts time automatically.  
In time change mode, the watch count stops and the time can be changed using the buttons.

#### Button Control in Time Change Mode

| Button | `sw[2] = 1` Hour : Min Mode | `sw[2] = 0` Sec : Msec Mode |
|---|---|---|
| Left Button | Hour UP | Sec UP |
| Right Button | Min UP | Msec UP |
| Up Button | Hour DOWN | Sec DOWN |
| Down Button | Min DOWN | Msec DOWN |

### 3. SR04

`sw[5:0] = 6'b001000`

#### SPEC

| Item | Value |
|---|---|
| Distance | 2 ~ 400 cm |
| Angle | -15º ~ 15º |
| Output Signal | HIGH pulse |

In SR04 mode, the right button starts measurement.  
The SR04 controller measures distance 16 times during a 2-second interval and displays the average value.

| Button | Function |
|---|---|
| Right Button | Start Measuring Button |

---

### 4. DHT11

#### SPEC

| Item | Value |
|---|---|
| Humidity | 20% ~ 90% |
| Temperature | 0ºC ~ 50ºC |

#### Humidity Mode

`sw[5:0] = 6'b110000`

In DHT11 mode, the right button starts measurement.  
The DHT11 controller measures humidity twice during a 2-second interval and displays the average value.

#### Temperature Mode

`sw[5:0] = 6'b010000`

In DHT11 mode, the right button starts measurement.  
The DHT11 controller measures temperature twice during a 2-second interval and displays the average value.

| Button | Function |
|---|---|
| Right Button | Start Measuring Button |

---

## Block Diagram

### 1. STOPWATCH

![project image](img/stopwatch.png)

`tick_gen_100hz = 10 msec`

The stopwatch uses tick count to make time.

| Time Unit | Range | Bit Width |
|---|---:|---:|
| Hour | 0 ~ 23 | 5 bit |
| Min | 0 ~ 59 | 6 bit |
| Sec | 0 ~ 59 | 6 bit |
| Msec | 0 ~ 99 | 7 bit |

---

### 2. WATCH

![project image](img/watch.png)

The watch structure is similar to the stopwatch.

---

### 3. FULL

![project image](img/whole.png)

---

## Verification

To verify this project, we made SystemVerilog code like UVM.

---

### 1. STOPWATCH_WATCH B/D

![project image](img/stopwatch_watch_bd.png)

#### Scenario

| No. | Scenario | Expected Result |
|---:|---|---|
| 1 | Reset | `12:00:00:00` |
| 2 | Stopwatch | msec > sec, sec > min, min > hour |
| 3 | Watch | msec > sec, sec > min, min > hour |
| 4 | Change Time | Check time change operation |
| 5 | Button | Check button operation |

---

### 2. FIFO B/D

![project image](img/fifo_bd.png)

#### Scenario

| Mode | Scenario |
|---|---|
| PUSH MODE | `!FULL` = `wptr++`, `empty = 0`, if `wptr == rptr`, then `FULL` |
| POP MODE | `!empty` = `rptr++`, `full = 0`, if `rptr == wptr`, then `EMPTY` |
| BOTH | `FULL` = `rptr++`, `full = 0` |
| BOTH | `empty` = `wptr++`, `empty = 0` |
| BOTH | Extra = `wptr++`, `rptr++` |

---

### 3. UART RX B/D

![project image](img/uart_rx_bd.png)

#### Scenario

| Item | Description |
|---|---|
| Driver Task | UART_TX |
| Timing | UART timing to give 16 tick |
| Mailbox | Add a mailbox between the generator and the scoreboard |
| Compare | Random 8-bit TX value is compared with `rx_data` value in `mon2scb_mailbox` |

---

### 4. UART FULL B/D

  ![project image](img/uart_bd.png)<br>

#### Scenario

| Item | Description |
|---|---|
| Monitor Task | Receive the value imported from the interface reliably |
| Sampling Timing | A total of 1.5 `BIT_PERIOD` is received so that it can be received from the middle, 8 ticks |
| Loop Back UART | Compare the result data with the random data received through `gen2scb_mailbox` and `mon2scb_mailbox` |

---

## Presentation

In the bottom, it is our presentation.

- [STOPWATCH,WATCH.pdf](https://github.com/user-attachments/files/28661408/STOPWATCH.WATCH.pdf)
- [UART_FIFO_SR04_DHT11_STOPWATCH,WATCH.pdf](https://github.com/user-attachments/files/28661409/UART_FIFO_SR04_DHT11_STOPWATCH.WATCH.pdf)
- [Verification.pdf](https://github.com/user-attachments/files/28661413/Verification.pdf)

