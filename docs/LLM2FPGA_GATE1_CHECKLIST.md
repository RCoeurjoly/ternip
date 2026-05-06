# Gate 1 Checklist: Software / checkpoint reproducibility

This checklist is the first step in the execution plan and is intended to be completed before block-level RTL work.

## 1) Run gate-1 smoke test

From repo root:

```bash
scripts/gate1/run_gate1_smoke.sh <hf-or-local-model-id> --prompt "The future of hardware-aware language models is" --repeats 2
```

Example:

```bash
scripts/gate1/run_gate1_smoke.sh ridgerchu/matmulfree-1.3B --repeats 2 --device cuda --dtype bfloat16
```

## 2) Record outputs

- Artifact path: `artifacts/gate1/gate1_smoke_result.json` (auto-generated)
- Required fields:
  - `reproducible`
  - `generated_texts`
  - `model_config`
  - `runs`

## 3) Gate 1 pass criteria

- Pass when:
  - `reproducible` is `true`.
  - Two or more runs produce bit-for-bit identical generation for the same prompt.
  - Model and tokenizer load without dependency exceptions.
  - Artifact is committed to team logs for replay.

## 4) Failure handling

- If dependency errors appear, pin and freeze the versions in `scripts/gate1/requirements-gate1.txt` before continuing.
- If generation is non-deterministic, retry with:
  - `do_sample=False` (already default),
  - fixed prompt,
  - fixed seed.
- If `hgrn_bit` is not recognized, rerun with:
  - `--trust-remote-code` and current recommended dependency versions.

## 5) Exit decision

- If Gate 1 fails after two complete retries, stop and treat repository-to-stack reproducibility as the blocking item.
- If Gate 1 passes, proceed to the block-level exporter/instruction bridge and block parity testing.
