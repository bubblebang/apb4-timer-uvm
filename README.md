# APB4 Timer Verification with SystemVerilog/UVM

## Overview

Designed a 32-bit APB4 timer and built a UVM verification environment
with directed and constrained-random stimulus, a cycle-based reference
model, protocol assertions, functional coverage, and a register model.

The timer supports:
- One-shot and periodic operation.
- Programmable reload value.
- Maskable interrupts and write-one-to-clear pending status.
- Byte-enabled writes using PSTRB.
- Privileged-write protection.
- Configurable APB wait states.

## Register Map

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00 | CTRL | RW | Bit 0: enable; bit 1: periodic; bit 2: IRQ enable |
| 0x04 | RELOAD | RW | 32-bit reload value; supports byte writes |
| 0x08 | COUNT | RO | Current countdown value |
| 0x0C | STATUS | W1C | Bit 0: interrupt pending |

All registers reset to zero. Reserved bits read as zero.

## Key Behavior

- A 0-to-1 ENABLE transition loads COUNT from RELOAD.
- One-shot expiry clears ENABLE and leaves COUNT at zero.
- Periodic expiry reloads COUNT.
- Expiry sets STATUS pending; IRQ asserts when pending and IRQ enable
  are both set.
- Writing one to STATUS bit 0 clears pending.
- Expiry takes priority over a simultaneous STATUS clear.
- Effective CTRL writes suppress counting and expiry for that edge.
- Unmapped or unaligned accesses, COUNT writes, and unprivileged writes
  return an APB error.

## Verification Architecture

The UVM environment contains an active APB agent, a timer monitor,
a reference-model scoreboard, functional coverage, and a UVM
register model.

| Component | Responsibility |
|-----------|----------------|
| APB sequencer | Supplies transactions to the driver |
| APB driver | Drives APB transfers and handles reset interruption |
| APB monitor | Publishes completed transfers |
| APB coverage | Samples addresses, strobes, direction, errors, privilege, and wait states |
| Timer monitor | Samples APB signals, reset, and IRQ every clock |
| Timer scoreboard | Predicts timer state and checks read data, error responses, and IRQ |
| Register model | Provides named register accesses and desired/mirrored values |
| Register adapter | Converts between register operations and APB transactions |
| Register predictor | Updates register mirrors from monitored bus transfers |

### Data Flow

- Sequences send transactions through the sequencer and driver to the DUT.
- The APB monitor sends completed transfers to coverage and the
  register predictor.
- The timer monitor sends clock-by-clock observations to the scoreboard.

### Independent Functional Checking

The scoreboard predicts CTRL, RELOAD, COUNT, and pending status from
observed requests and the specified timer behavior.

It checks pre-edge outputs before predicting state changes for the
next clock. Write acceptance is predicted from the access policy,
rather than trusting the DUT's PSLVERR response.

The register predictor tracks bus-visible register accesses.
Autonomous countdown, expiry, and interrupt behavior are checked
by the timer scoreboard.

### Protocol Assertions

Concurrent assertions in apb_if check:
- SETUP is followed by ACCESS with stable request fields.
- Requests remain stable throughout waiting ACCESS cycles.
- A completed transfer is followed by PENABLE deassertion.
- Read transfers use zero write strobes.

Assertions are disabled during reset.

## Running the Tests

The project was tested on EDA Playground using SystemVerilog,
Cadence Xcelium 25.03, and UVM 1.2.

### EDA Playground Setup

- Select SystemVerilog and Cadence Xcelium.
- Enable UVM 1.2.
- Add the DUT and testbench source files, preserving their include order.

Compile options:

```text
+define+APB_WAIT_CYCLES=2 -coverage functional
```

Run options:

```text
+UVM_TESTNAME=apb_random_test -svseed 1
```

APB_WAIT_CYCLES configures the DUT's fixed number of wait states.
UVM_TESTNAME selects the test, and svseed selects the random seed.

### Source Layout and File List

The repository separates RTL, agent, environment, sequences,
tests, and register-model files into directories.

For a local Xcelium installation, run from the project root and
use files.f to supply include directories and source files:

```sh
xrun -sv -uvm \
  -timescale 1ns/1ps \
  -access +rwc \
  -coverage functional \
  +define+APB_WAIT_CYCLES=2 \
  +UVM_TESTNAME=apb_smoke_test \
  -svseed 1 \
  -f files.f
```

The local command requires an installed and licensed Xcelium
environment. Regression results in this project were obtained
on EDA Playground.

On EDA Playground, use flat source tabs with the original included
filenames. Place the DUT in design.sv and the contents of tb_top.sv
in testbench.sv. The repository's files.f is not required there.

The earlier standalone testbench in examples/smog_test.sv is
excluded from the UVM build because it defines a separate tb_top.

### Regression Configuration

- Run all 16 directed and RAL tests with wait cycles 0 and 2.
- Run apb_random_test with wait cycles 0, 1, 2, and 3,
  using seeds 1, 2, and 3 for each configuration.

### Checking Results

A successful run must:
- Complete its intended sequence and finish normally.
- Report zero UVM errors and fatals.
- Produce no assertion failures or unexpected warnings.

apb_reset_test intentionally interrupts a transfer and produces
one RESET_ABORT warning.

Assertion failures appear separately from the UVM report summary,
so inspect the full simulation log.

## Verification Results

Simulator: Cadence Xcelium 25.03 with UVM 1.2.

### Directed regression
- 16 directed and RAL tests passed with APB wait cycles set to 0 and 2.
- Covered register accesses, access errors, byte strobes, timer modes,
  interrupts, reset recovery, and RAL prediction.
- Reset-interruption tests produced the expected RESET_ABORT warning.
- No unexpected UVM errors, fatals, or assertion failures.

### Random regression
- 12 runs: wait cycles {0, 1, 2, 3} × seeds {1, 2, 3}.
- 300 random transfers per run; 3,600 total.
- Zero UVM warnings, errors, fatals, or assertion failures.

### Functional coverage
- Each random run reported 90.62% APB functional coverage.
- All four wait-cycle bins were exercised across configurations.
- All seven timer event bins were exercised across directed tests.
- All defined functional coverage bins were exercised across the
  regression; a merged coverage database was not generated.

## Debugging Example: Partial-Write RAL Prediction

The RAL strobe test exposed a RELOAD mirror mismatch after a
partial write:

- Initial value: 0x11223344
- Write data: 0xAABBCCDD
- PSTRB: 4'b0101
- Expected mirror: 0x11BB33DD
- Actual mirror: 0xAABBCCDD

RELOAD was initially modeled as one 32-bit uvm_reg_field.
UVM 1.2 field prediction did not merge individual enabled bytes
within that field as required by this register.

The fix was to model RELOAD as four 8-bit fields, allowing each
field's prediction to follow its corresponding byte enable.

The partial-write and zero-strobe tests then passed with
APB wait cycles set to both 0 and 2.

## Limitations
- RTL code coverage was not measured.
- The driver does not generate back-to-back transfers with PSEL held high.
- RAL backdoor access was not implemented.
- The reset-abort test asserts reset before the first ACCESS sampling edge;
  it does not test cancellation of an outstanding wait-state assertion.