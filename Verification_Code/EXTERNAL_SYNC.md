# External input synchronization regression

Add `Code/sync_2ff.v` to the Vivado design sources along with the existing RTL.
The top-level ports and pin assignments are unchanged.

The design contains 13 independent synchronizers (26 flip-flops):

- UART RX and DHT input: reset value HIGH.
- SR04 echo, four buttons and six switches: reset value LOW.
- DHT output enable/data are unchanged; only the receive path is synchronized.
- Button sampling uses the existing 100 kHz pulse as a clock enable on `clk`.
  The eight-sample debounce rule is unchanged.

The reset architecture is unchanged. Switch bits are synchronized independently;
this does not provide an atomic multi-bit mode update. Digital simulation checks
functional behavior and sampling latency, not analog metastability or board timing.

## Simulation (Vivado 2023.2 / PowerShell)

Run from the repository root using a separate build directory:

```powershell
$repo = (Get-Location).Path
$build = Join-Path $env:TEMP ('uart_sync_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $build | Out-Null
Push-Location $build
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $env:TEMP = $build
    $env:TMP = $build
    $rtl = Get-ChildItem (Join-Path $repo 'Code') -Filter '*.v' |
        Select-Object -ExpandProperty FullName
    xvlog $rtl
    if ($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
    xvlog -sv (Join-Path $repo 'Verification_Code/tb_external_sync.sv')
    if ($LASTEXITCODE -ne 0) { throw 'Testbench compile failed' }
    xelab tb_external_sync -s external_sync_test -mt off
    if ($LASTEXITCODE -ne 0) { throw 'Elaboration failed' }
    xsim external_sync_test -runall
    if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
    if (!(Select-String -Path xsim.log -SimpleMatch 'PASS ALL external input synchronization regressions')) {
        throw 'Regression did not complete successfully; inspect xsim.log'
    }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Pop-Location
}
```

Checks include:

- Both synchronizer reset values and two-edge rising/falling propagation.
- All four button paths: short glitch rejection, one-clock output, long hold and repress.
- All six switch bits reaching synchronized control signals.
- UART at nominal 9600 baud, four response formats, queued echo and a second `s`
  during a response, with TX FIFO full exercised. The scoreboard compares all 61
  transmitted bytes including CR/LF. Only the watch payload is frozen for this check.
- SR04 at 10/100/200 cm with asynchronous echo edges and the original 1 us tick.
  The post-measurement quiet period is shortened in the fixture, retaining enough
  counter bits for the longest pulse. The existing integer distance quantization
  permits the expected value or one cm less at a boundary.
- Two complete DHT frames with original timing, distinct data and valid checksums.
  The sensor fixture starts its response after the existing host driver releases
  the line; it does not validate electrical contention or the unmodified driver.

## Synthesis

From a separate build directory, run:

```text
vivado -mode batch -source /path/to/Verification_Code/synth_external_sync.tcl
```

The script synthesizes `TOP_module` for `xc7a35tcpg236-1` and fails if the 26
`ASYNC_REG` flip-flops are not preserved. It produces `sync_utilization.rpt`.
This is a synthesis check, not a placed-and-routed timing or physical board test.

## Recorded result (2026-09-28)

Vivado 2023.2 completed the regression with `PASS ALL external input synchronization regressions`:
61 UART bytes matched, all four buttons and six switches passed, SR04 returned
10/100/200 cm, and both DHT frames matched their data and checksums. Synthesis
passed with all 26 `ASYNC_REG` flip-flops preserved and zero synthesis errors.
The pre-existing watch port-width warnings remain. No physical board test was run.
