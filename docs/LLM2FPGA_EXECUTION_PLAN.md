# Ternip LLM2FPGA End-to-End Feasibility Plan

## Executive decision (recommended)

**Adopt ternip for a constrained feasibility spike only; do not commit to full end-to-end production adoption until three gates are passed.**

This plan is designed to produce a clear decision after limited engineering effort:

- **Go**: deliver a one-prompt token loop path for 370M or evidence of equivalent capability.
- **Revise**: narrow scope to software verification or single-block replay and defer broader board integration.
- **Stop**: block-level correctness or target-board feasibility cannot be met with acceptable risk/effort.

---

## Phase 0: Scope and assumptions

- Target: `ternip` middle-stack + MatMul-free released checkpoints.
- Primary architecture target for the spike: **single-block, single-board, 370M-class** path.
- No new platform-dependent optimizations in scope until gates are passed.
- Repository remains the source of truth for RTL and metadata.

**Known missing pieces to build locally**

- Checkpoint export / ternary packing pipeline
- Instruction emitter/assembler (ISA from paper)
- Host runtime + token loop
- Board shell/host transport/MMIO integration
- Reproducible benchmark and soak validation harness

 Gate 1 execution assets are available at:

- [docs/LLM2FPGA_GATE1_CHECKLIST.md](LLM2FPGA_GATE1_CHECKLIST.md)
- [scripts/gate1/run_gate1_smoke.py](../scripts/gate1/run_gate1_smoke.py)
- [scripts/gate1/run_gate1_smoke.sh](../scripts/gate1/run_gate1_smoke.sh)
- [docs/LLM2FPGA_GATE2_CHECKLIST.md](LLM2FPGA_GATE2_CHECKLIST.md)
- [scripts/gate2/run_gate2_tmatmul_parity.py](../scripts/gate2/run_gate2_tmatmul_parity.py)
- [scripts/gate2/run_gate2_tmatmul_parity.sh](../scripts/gate2/run_gate2_tmatmul_parity.sh)
- [scripts/gate2/tmatmul_parity_tb.sv](../scripts/gate2/tmatmul_parity_tb.sv)

---

## Gating checkpoints

### Gate 1 — Software/model reproducibility (Go/No-Go)

**Objective:** prove released checkpoints + model stack are stable and deterministic enough for hardware parity.

**Deliverable**

- One pinned dependency set and environment lock (Torch/Transformers/Triton stack).
- Script: load 370M checkpoint and generate a short deterministic prompt run.
- Artifact: output transcript + reproducibility notes.

**Success criteria**

- Two consecutive runs produce identical outputs for the same prompt.
- No unresolved dependency blockers (e.g., `hgrn_bit` import/config resolution).
- Repro instructions complete enough for team replication.

**Fail conditions (No-Go)**

- Repeated dependency breakage or model load failures after one-time freeze.
- Unstable generation behavior attributable to software dependency drift.

---

### Gate 2 — Block-level parity (Go/Revise/No-Go)

**Objective:** close the model-to-RTL arithmetic gap on a bounded block scope.

**Deliverable**

- Checkpoint exporter for one block/layer: weight/state extraction + ternary packer for a first compatible layout.
- Minimal instruction emitter matching existing RTL ISA semantics.
- Golden-model testbench comparing:
  - TMATMUL
  - RMS path
  - row-wise ops used in the model block

**Success criteria**

- All synthetic and sampled real-prompt vectors match software within defined tolerance bounds.
- Memory layout and ISA emission are deterministic and versioned.
- CI-friendly test harness stub is in place (even if using local simulation only).

**Fail conditions**

- Cannot emit valid block instructions for published checkpoints.
- Block outputs diverge in ways that are not explainable by fixed-point/quantization policy.
- Golden parity requires unbounded rewrite of RTL or model format.

---

### Gate 3 — Board-level feasibility (Go/Revise/No-Go)

**Objective:** validate core feasibility on the chosen board family before investing in runtime polish.

**Deliverable**

- Synthesized target(s): at minimum `ternip_tmatmul` and/or trimmed top-level core.
- Memory-path stress test for your shell (sequential DRAM access baseline).
- Measured notes: Fmax, area, timing closure, burst/no-burst throughput envelope.

**Success criteria**

- Positive timing closure path with clearly identified operating frequency.
- Measured memory and compute profiles align with a non-pathological token-loop estimate.
- No blockers that lock you to a single vendor-specific stack by default.

**Fail conditions**

- Severe resource or timing failure in baseline configuration.
- DDR/MMIO assumptions incompatible with planned host-path architecture.

---

## Execution sequence (recommended)

1. **Week 1: Software lock and checkpoint smoke test**
   - Execute Gate 1.
2. **Week 2: Exporter + emitter + block parity**
   - Execute Gate 2.
3. **Week 3: RTL block OOC + board integration baseline**
   - Execute Gate 3.
4. **Week 4: One-board single-prompt loop (only if all gates pass)**
   - Demonstrate decode loop path on one prompt.
5. **Week 5+: Optional follow-up**
   - If all gates pass, continue with host runtime, token scheduling, and burst/parallelism tuning.
   - If any gate fails, execute the corresponding Revise path.

---

## Decision table

| Gate result | Immediate action |
|---|---|
| 1 pass / 2 pass / 3 fail | Revise to blocked components only; delay board runtime. |
| 1 pass / 2 fail / 3 pending | Pause end-to-end work; fix block format/ISA bridge first. |
| 1 fail | Stop spike; resolve software stack before any hardware effort. |
| 1 pass / 2 pass / 3 pass | Continue to full 370M single-board decode + benchmarking. |

---

## Risks and mitigations

- **Integration risk:** missing assembler/runtime pieces → build bridges in isolated scripts first; keep format/versioned interfaces.
- **Toolchain risk:** no public full synthesis flow → establish minimal reproducible synth/check command now.
- **Portability risk:** paper platform differs from target family → gate execution to target board early.
- **Model/runtime compatibility risk:** nonstandard `hgrn_bit` stack → keep pinning strict and document exact compatible versions.

---

## Exit criteria for this spike

- A documented decision after Gate 3 with measured evidence.
- Recommendation to proceed to broader end-to-end implementation, or to defer and keep ternip as R&D-only IP core.
