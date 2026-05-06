# Gate 2 Checklist: TMATMUL parity block replay

This gate focuses on proving a single TMATMUL block produces the same values as a
software reference for the same vector and matrix.

## 1) Run the Gate2 parity case

From repo root:

```bash
BASEJUMP_STL=<path-to-basejump-stl> \
  scripts/gate2/run_gate2_tmatmul_parity.py --seed 1337
```

If you want a shell wrapper:

```bash
BASEJUMP_STL=<path-to-basejump-stl> \
  scripts/gate2/run_gate2_tmatmul_parity.sh --seed 1337
```

## 2) Record outputs

- Artifact directory: `artifacts/gate2/seed_<seed>/`
- Required fields in `gate2_tmatmul_result.json`:
  - `seed`
  - `status`
  - `max_abs_diff`
  - `mismatch_count`
  - `expected_path`
  - `vector_path`
  - `matrix_path`
  - `hw_output_path`

## 3) Gate 2 pass criteria

- Status is `pass`.
- `mismatch_count == 0`.
- `sim_output` includes `TB_SIM_OK`.
- Rebuild is deterministic for the same seed.

## 4) Failure handling

- If RTL simulation fails to build, check `sim.log` and align BaseJump STL path and verilator flags.
- If mismatches remain, inspect:
  - vector packing order in `vector.hex`,
  - matrix packing order in `matrix.hex` (row-major vs column-major),
  - signed ternary coding for -1/0/+1,
  - saturation behavior in the reference Python computation.
- If timeout occurs, review stream timing assumptions and the stream-servicing model.

## 5) Gate transition

- If Gate 2 passes, proceed to board-level synthesis feasibility (Gate 3).
- If Gate 2 fails, fix the instruction-emitter/padding model before spending time on board integration.
