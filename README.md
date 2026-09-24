# Matrix Multiplier Architecture Tradeoff Report

## 1. Objective

This experiment compares two signed integer matrix-multiplication architectures:

- **N-multiplier architecture:** uses `N` parallel multipliers and completes one
  output dot product during each active clock cycle.
- **M-multiplier architecture:** uses `M` parallel multipliers, where `N < M < 2N`,
  and processes a flattened sequence of multiplication jobs. A group of jobs may
  cross a dot-product boundary, so the design retains an unfinished partial sum.

Two configurations were tested:

1. Small case: `N = 4`, `M = 5`
2. Large case: `N = 50`, `M = 99`

The large case is `N = 50`, not `N = 40`. This is the configuration used by the
simulation and Quartus projects, and it satisfies `50 < 99 < 100`.

## 2. Method

Both architectures were tested with the same self-checking SystemVerilog testbench.
The testbench calculated a software-style reference matrix product and compared every
hardware output against it. It ran 26 cases, including zero, identity, all-one,
directed signed, near-limit, and deterministic random matrices. Both architectures
passed all 26 cases at both matrix sizes.

Functional behavior and cycle counts were measured in ModelSim. Hardware resource
estimates were obtained from Quartus Prime Analysis & Synthesis for the Cyclone V
`5CSEMA5F31C6` on the DE1-SoC board.

For an `N x N` multiplication, there are `N^3` scalar multiplication jobs. Therefore,
the expected active-cycle counts are:

```text
N-multiplier cycles = N^2
M-multiplier cycles = ceil(N^3 / M)
```

## 3. Small Configuration: N = 4, M = 5

The N-multiplier design required 16 active cycles. The M-multiplier design required
13 cycles because `ceil(4^3 / 5) = ceil(64 / 5) = 13`.

| Measurement | N = 4 design | M = 5 design | Difference |
|---|---:|---:|---:|
| Active cycles | 16 | 13 | -3 (-18.75%) |
| Ideal same-frequency speedup | 1.000x | 1.231x | +23.08% throughput |
| Estimated ALMs | 187 | 760 | +573 (+306.42%) |
| Combinational ALUTs | 86 | 712 | +626 (+727.91%) |
| Dedicated registers | 294 | 315 | +21 (+7.14%) |
| Physical DSP blocks | 3 | 5 | +2 (+66.67%) |
| Inferred signed multipliers | 4 | 5 | +1 (+25.00%) |
| Top-level pins | 548 | 548 | No change |

The M design reduced the cycle count by 18.75%, but its estimated ALM usage was
4.06 times that of the N design and its combinational ALUT usage was 8.28 times as
large. Register usage increased by only 7.14%. This indicates that most of the added
cost came from combinational control and operand-selection logic, rather than from
storing the additional partial result.

Without post-fit clock frequencies, the 1.231x value is an ideal cycle-based speedup.
The M design produces lower real latency only if its clock frequency is greater than
81.25% of the N design's frequency:

```text
13 / Fmax_M < 16 / Fmax_N
Fmax_M / Fmax_N > 13 / 16 = 0.8125
```

## 4. Large Configuration: N = 50, M = 99

The N-multiplier design required 2,500 active cycles. The M-multiplier design
required 1,263 cycles because `ceil(50^3 / 99) = ceil(125000 / 99) = 1263`.

| Measurement | N = 50 design | M = 99 design | Difference |
|---|---:|---:|---:|
| Active cycles | 2,500 | 1,263 | -1,237 (-49.48%) |
| Ideal same-frequency speedup | 1.000x | 1.979x | +97.94% throughput |
| Estimated ALMs | 34,509 | 1,377,806 | +1,343,297 (+3,892.60%) |
| Combinational ALUTs | 16,222 | 1,455,050 | +1,438,828 (+8,869.61%) |
| Dedicated registers | 55,014 | 55,041 | +27 (+0.05%) |
| Physical DSP blocks | 49 | 99 | +50 (+102.04%) |
| Inferred signed multipliers | 50 | 99 | +49 (+98.00%) |
| Top-level pins | 95,004 | 95,004 | No change |
| Peak Quartus memory | 5,824 MB | 14,090 MB | +8,266 MB (+141.93%) |
| Synthesis elapsed time | 4 min 53 s | 2 h 18 min 16 s | 28.31x longer |

The cycle count was nearly halved, but combinational logic grew far faster than the
number of multipliers. The M design used 39.93 times as many estimated ALMs and
89.70 times as many combinational ALUTs as the N design. In contrast, it used only
27 additional registers, an increase of 0.05%.

The extreme logic growth is caused by the present implementation of the flattened
job scheduler. Each M lane converts a runtime job index into matrix coordinates using
division and modulo operations, then dynamically selects `a[i][k]` and `b[k][j]`.
For `N = 50`, division by 50 and 2,500 is not a simple bit slice. Quartus therefore
generated large divider, decoder, multiplexer, and routing networks for 99 lanes.

The cycle-based break-even frequency for the large case is:

```text
Fmax_M / Fmax_N > 1263 / 2500 = 0.5052
```

Thus, the M design could theoretically run at 50.52% of the N design's frequency and
still match its matrix latency. However, no post-fit Fmax is available because these
top-level designs cannot be placed and routed on the selected FPGA.

## 5. Device Feasibility

The selected Cyclone V device provides approximately 32,070 ALMs, 128,300 registers,
87 variable-precision DSP blocks, and 288 FPGA GPIO pins.

| Large design resource | N = 50 | M = 99 | Device capacity |
|---|---:|---:|---:|
| Estimated ALMs | 34,509 (107.61%) | 1,377,806 (4,296.25%) | 32,070 |
| Registers | 55,014 (42.88%) | 55,041 (42.90%) | 128,300 |
| DSP blocks | 49 (56.32%) | 99 (113.79%) | 87 |
| Top-level pins | 95,004 | 95,004 | 288 FPGA GPIO |

The N = 50 design already exceeds the ALM capacity by 2,439 ALMs. The M = 99 design
exceeds it by 1,345,736 ALMs and also requires 12 more DSP blocks than are available.
Both designs expose about 330 times the available FPGA GPIO count. Even the small
designs expose 548 top-level pins, so their current interfaces also prevent a complete
board-level fit despite their much smaller internal logic usage.

Analysis & Synthesis success means that Quartus generated a logical netlist. It does
not mean that the design fits on the FPGA, meets timing, or can be programmed onto the
board. A successful Fitter and TimeQuest run would be required to obtain physical
routing results and a reliable Fmax.

## 6. Conclusion

The M-multiplier architecture successfully trades hardware parallelism for fewer
execution cycles. It reduced the small-case latency from 16 to 13 cycles and the
large-case latency from 2,500 to 1,263 cycles. At an identical clock frequency, these
changes correspond to ideal speedups of 1.231x and 1.979x, respectively.

The measurements do **not** show that extra product storage is the main scalability
problem. Register growth was only 7.14% in the small experiment and 0.05% in the
large experiment. The dominant penalty was combinational logic generated by runtime
division, modulo, and dynamic matrix indexing. Consequently, the current M design
improves simulated cycle count but is not a scalable FPGA implementation.

A physically meaningful follow-up experiment should preserve the N-versus-M compute
comparison while replacing the flattened division-based decoder with counters or
compile-time lane mappings. It should also store matrices in on-chip memory and use a
small streaming or addressed interface. Fit-capable configurations could then be
compared using post-fit Fmax and the real latency equation `cycles / Fmax`.

## 7. Result Sources

The resource measurements were transcribed from the four locally generated Quartus
`.map.rpt` files. Generated reports are excluded from Git because they contain
machine-specific absolute paths. They can be reproduced from these checked-in
projects:

- `quartus_n/matrix_multiplier_n_project.qpf`
- `quartus_m/matrix_multiplier_m_project.qpf`
- `quartus_n50/matrix_multiplier_n50_project.qpf`
- `quartus_m99/matrix_multiplier_m99_project.qpf`
- `multiplier_comparison_tb.sv`
- `scripts/simulate_comparison.do`
- `scripts/simulate_comparison_large.do`
