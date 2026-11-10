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

## Verification Plan

This plan maps the current RTL requirements to implemented tests, checkers,
and coverage. It documents the present verification scope; it is not a claim
that every entry was written before implementation or that all possible
behaviors have been verified. Test names below are selectable with
`+UVM_TESTNAME=<test_name>` and are defined in
[`tb/test/apb_test_lib.sv`](tb/test/apb_test_lib.sv).

### Strategy and Checking Responsibilities

- **Directed tests** establish deterministic behavior and target interactions
  that random traffic may not reliably reach.
- **Constrained-random tests** mix valid and invalid accesses, privilege levels,
  byte strobes, control settings, and small reload values to exercise expiry
  during bus traffic.
- **The cycle-based scoreboard** samples through `timer_monitor` every PCLK.
  It checks pre-edge read responses and IRQ against expected state, then
  advances the model. It predicts access errors independently of `PSLVERR`;
  transfer completion is identified from observed `PSEL && PENABLE && PREADY`.
- **Protocol assertions** check request sequencing and stability separately
  from timer functional behavior.
- **RAL tests** check frontdoor accesses, desired/mirrored values, byte-enable
  prediction, access policies, and reset synchronization. Monitor-based
  prediction is enabled and auto-prediction is disabled. Autonomous COUNT,
  pending-status, and control changes remain the functional scoreboard's
  responsibility; RAL is not a cycle-by-cycle timer reference model.

### Requirements-to-Test Matrix

All tests in this table are implemented. Execution evidence is summarized
under [Verification Results](#verification-results) and archived in `logs/`;
this table does not imply a new regression was run when documenting the plan.

| ID | Requirement and targeted scenarios | Test(s) | Checking / coverage evidence |
|---|---|---|---|
| VP-01 | Correct RELOAD write/read and baseline bus operation | `apb_smoke_test` | Explicit readback checks; scoreboard; address and direction coverage |
| VP-02 | One-shot start loads RELOAD; countdown expires; COUNT stops at zero; ENABLE clears while IRQ enable is retained | `apb_one_shot_test` | Cycle model, register readback, IRQ check; one-shot expiry event |
| VP-03 | Periodic expiry reloads COUNT and preserves control settings; repeated expiry and clear behavior | `apb_periodic_test` | Cycle model, readback and IRQ checks; periodic expiry event |
| VP-04 | Reject unprivileged writes, COUNT writes, unmapped accesses and unaligned accesses; preserve state after rejected writes; permit unprivileged reads | `apb_error_test`, `apb_random_test` | Independent error prediction, readback and state checks; address, privilege, direction and error bins/crosses |
| VP-05 | All 16 RELOAD strobe masks; unselected bytes retain data; CTRL updates only when byte 0 is selected; zero-strobe writes are no-ops | `apb_strobe_test` | Explicit byte-merge/readback checks and scoreboard; all write-strobe bins |
| VP-06 | Expiry sets sticky pending while masked; unmasking asserts IRQ; masking preserves pending; STATUS ignores upper-byte/zero strobes and clears on a byte-0 write of one | `apb_irq_mask_test` | Per-clock IRQ model and STATUS readback; masked/unmasked pending and pending-clear events |
| VP-07 | RELOAD=0 remains enabled at zero without expiry; RELOAD=1 gives the smallest nonzero one-shot countdown | `apb_boundary_test` | Explicit COUNT/CTRL/STATUS checks and cycle model; one-shot expiry event; no dedicated reload-value coverpoint |
| VP-08 | Disable holds COUNT; writing RELOAD while disabled does not change COUNT; re-enable starts from the new RELOAD rather than resuming | `apb_restart_test` | Directed readback checks and exact cycle-model prediction; no dedicated restart event bin |
| VP-09 | Updating RELOAD during periodic operation preserves the current countdown; a subsequent expiry uses the updated value | `apb_reload_update_test` | Directed COUNT/RELOAD/CTRL checks and cycle model; periodic expiry event |
| VP-10 | Simultaneous expiry and STATUS W1C: expiry wins; after stopping the timer an uncontested clear succeeds | `apb_expiry_clear_test` | Periodic RELOAD=1 forces expiry on clear-completion edges; STATUS checks and expiry/clear-collision event |
| VP-11 | Reset interrupts an active transfer, resets all registers and IRQ, and allows subsequent traffic to recover | `apb_reset_test` | Transaction abort check, reset readback, per-clock model and reset-interruption event; expected `RESET_ABORT` warning |
| VP-12 | Mixed traffic with mapped/invalid addresses, privilege variation, strobes, CTRL values 0-7, STATUS writes 0/1 and RELOAD writes 0-20 | `apb_random_test` | Cycle scoreboard, protocol assertions, bus coverage and timer-event coverage; unexpected aborts/unknown error responses fail |
| VP-13 | RAL frontdoor RELOAD write/read and monitor-driven mirror update | `apb_ral_smoke_test` | Explicit returned-data and mirror checks |
| VP-14 | `set()` changes desired value without changing mirror; `update()` synchronizes hardware; `needs_update()` clears; `mirror(UVM_CHECK)` succeeds | `apb_ral_update_test` | Explicit desired/mirror checks plus UVM mirror comparison |
| VP-15 | Actual DUT reset synchronizes all register-model desired/mirrored values and hardware reset values | `apb_ral_reset_test` | Check model values before readback, then independently read every hardware register |
| VP-16 | Direct APB partial/zero-strobe writes update the RAL RELOAD mirror correctly | `apb_ral_strobe_test` | Mirror checked before target readback; alternating byte masks and zero-strobe preservation |
| VP-17 | Rejected unprivileged write preserves RELOAD hardware/mirror; STATUS write-zero preserves pending and write-one clears it | `apb_ral_policy_test` | Explicit mirror and data checks; poll STATUS to synchronize hardware-generated pending before W1C checks |

VP-01 through VP-11 and VP-13 through VP-17 comprise the **16 directed/RAL
tests**. VP-12 is the separate constrained-random test.

### Protocol Assertion Plan

Assertions are implemented in [`tb/apb_if.sv`](tb/apb_if.sv) and disabled
when reset is active or not known to be released.

| Assertion label | Rule checked | Exercised by |
|---|---|---|
| `APB_SETUP_TO_ACCESS` | SETUP advances to ACCESS on the next edge with stable address, direction, data, strobes and protection | Completed traffic in directed, RAL and random tests |
| `APB_WAIT_STABLE` | A stalled ACCESS remains selected/enabled with stable request fields until the next sampled edge | Tests with nonzero `APB_WAIT_CYCLES` |
| `APB_COMPLETION_ENDS_ACCESS` | PENABLE deasserts on the edge after transfer completion; PSEL is allowed to remain high | All completed transfers; held-PSEL back-to-back stimulus is not currently generated |
| `APB_READ_STROBES_ZERO` | Read requests have PSTRB=0 | Read traffic in directed, RAL and random tests |

Passing legal traffic checks that assertions do not fail in those runs. It
does not by itself demonstrate that every assertion detects injected faults.
The driver contains a commented wait-state corruption hook; it is disabled
in the normal regression and is not counted as an archived negative-test result.

### Functional Coverage Plan

Bus coverage is sampled from completed, non-aborted transactions with known
`PSLVERR` in [`tb/env/apb_coverage.sv`](tb/env/apb_coverage.sv).
Timer-event coverage is sampled from predicted state/events in
[`tb/env/timer_scoreboard.sv`](tb/env/timer_scoreboard.sv); observed behavior
is checked separately against that model.

| Coverage item | Defined bins / combinations | Closure approach |
|---|---|---|
| `cp_address` | CTRL, RELOAD, COUNT, STATUS, unaligned, unmapped aligned | Directed error tests and mixed random addresses |
| `cp_strobe` | Zero, full, and each of 14 partial masks; writes only | Exhaust all masks in `apb_strobe_test`; random traffic supplements |
| `cp_direction` | Read, write | Directed/RAL and random traffic |
| `cp_error` | Success, error response | Positive accesses and directed/random negative accesses |
| `cp_wait` | 0, 1, 2, 3-99 wait cycles | Separate fixed-wait configurations 0, 1, 2, 3; a hit at 3 covers the range bin, not every value through 99 |
| `cp_privilege` | Privileged, unprivileged | Error tests and weighted random privilege |
| `cx_address_direction` | Address category x read/write | Random traffic supplements directed accesses |
| `cx_privilege_direction_error` | Privilege x direction x response | Excludes successful unprivileged writes, which violate this DUT's policy; scoreboard still checks failures of that policy |
| Timer events | One-shot expiry, periodic expiry, masked pending, unmasked pending, pending clear, expiry/clear collision, reset interruption | Dedicated directed tests target each event; random traffic supplements |

Coverage closure means hitting the defined reachable goals, reviewing unhit
bins, and resolving checker failures. It does not prove the design bug-free.
Wait-state and timer-event goals are exercised across multiple runs; the
archive does not establish a single merged coverage database. For example,
one fixed-wait run naturally hits only one of the four wait bins.

### Completion Criteria and Evidence

- Execute all directed/RAL tests at wait settings 0 and 2, and random traffic
  at settings 0, 1, 2 and 3. Preserve seeds and run options for reproduction.
- Require intended sequences to finish with zero unexpected UVM errors,
  fatals or assertion failures. Treat the reset test's intentional
  `RESET_ABORT` warning separately from unexpected warnings.
- Review the individual coverage reports against the matrix above rather
  than equating an overall percentage with complete verification.
- Archived evidence: [directed/RAL logs](logs/logs_directed_test.docx),
  [larger random runs](logs/logs_random_test.docx), and
  [wait/seed sweep](logs/logs_random_test_wait_cycle_0123_svseed_123.docx).
  These are historical run records, not an automatically regenerated report.
  The supplied archive does not tie each run to a source commit; it should
  not be treated as proof that the exact current source snapshot was rerun.

### Remaining Verification Work

| Gap | Current scope | Proposed extension |
|---|---|---|
| Back-to-back transfers | Driver inserts idle cycles | Add consecutive transfers with PSEL held high and PENABLE returning to SETUP |
| Maximum reload value | Directed boundary test targets 0 and 1 | Add 0xFFFFFFFF load/decrement checks over a short window; do not wait billions of clocks for expiry |
| Exact-edge interactions | Expiry/W1C collision is directed; other priorities are modeled | Add deterministic CTRL-write/expiry and RELOAD-write/periodic-expiry collision tests and event bins |
| Reset during an established wait | Abort test resets before the first ACCESS sampling edge | Assert reset after a sampled stall to exercise cancellation of a pending wait assertion |
| Assertion fault injection | Legal-traffic checks are present | Add reproducible negative tests for each protocol assertion |
| Timer-specific coverage detail | Seven event bins are present | Add restart, reload boundary, mode-transition and event/configuration crosses |
| RTL coverage and backdoor | Not currently measured / implemented | Add RTL coverage analysis and, if useful, HDL paths plus backdoor tests |


## Running the Tests

The project was tested on EDA Playground using SystemVerilog,
Cadence Xcelium 25.03, and UVM 1.2.

### EDA Playground Setup

- Select SystemVerilog and Cadence Xcelium.
- Enable UVM 1.2.
- Add the DUT and testbench sources, preserving their include order.

Compile options:

```text
+define+APB_WAIT_CYCLES=2 -coverage functional
```

Run options:

```text
+UVM_TESTNAME=apb_random_test +NUM_ITERS=16 +NUM_XFERS=2000 -svseed random
```

- `APB_WAIT_CYCLES`: fixed DUT wait-state count.
- `UVM_TESTNAME`: test to execute.
- `NUM_ITERS`: sequence iterations; default 1.
- `NUM_XFERS`: random transfers per iteration; default 300.
- `-svseed random`: automatically selects the simulation seed.

This configuration requests 32,000 random transfers with two wait states.
Save the seed printed in the simulation log and use `-svseed <seed>`
to reproduce the run.

Repeat with `APB_WAIT_CYCLES` set to 0, 1, 2, and 3 to exercise
all four configurations.

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

The earlier standalone testbench in examples/smoke_test.sv is
excluded from the UVM build because it defines a separate tb_top.

### Recommended Regression Configuration

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

The following results summarize historical runs recorded with the project.
Adding this verification plan did not rerun the simulations.

Simulator: Cadence Xcelium 25.03 with UVM 1.2.

### Directed regression
- The archived directed log records all 16 directed/RAL tests passing
  with `APB_WAIT_CYCLES=2`. Repeating them at wait setting 0 is part of
  the recommended regression; that run is not evidenced by the supplied logs.
- Covered register accesses, access errors, byte strobes, timer modes,
  interrupts, reset recovery, and RAL prediction.
- Reset-interruption tests produced the expected RESET_ABORT warning.
- No unexpected UVM errors, fatals, or assertion failures.

### Random Regression
- The larger-run archive records 136,000 constrained-random transfers across
  wait settings 0, 1, 2 and 3, using 2,000 transfers per iteration.
- The separate wait/seed sweep records another 3,600 random transfers:
  300 transfers for each of the 12 wait-setting/seed combinations.
- These counts exclude directed setup and cleanup accesses.
- Observed zero scoreboard mismatches.

### Functional Coverage
- The archived random reports show 100% for write-strobe coverage.
- Achieved 100% coverage for address, direction, privilege, and error response,
  including address × direction and privilege × direction × error crosses.
- Exercised all four wait-state bins across configurations.
- Exercised all seven timer-event bins across directed tests.

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

The archived `apb_ral_strobe_test` run passes with two wait states,
including the partial-write and zero-strobe checks. The supplied logs do
not separately demonstrate this directed test at zero wait states.
The earlier failing mirror values above are a documented debugging example;
the original failing run is not included in the supplied log archive.

## Limitations
- RTL code coverage was not measured.
- The driver does not generate back-to-back transfers with PSEL held high.
- RAL backdoor access was not implemented.
- The reset-abort test asserts reset before the first ACCESS sampling edge;
  it does not test cancellation of an outstanding wait-state assertion.
