<div align="center">
  <img src="docs/ternip.svg" alt="Ternip Logo" width="200"/>
  <h1>Ternip</h1>
  <p>RTL accelerator by for Ridger Chu's <a href="https://github.com/ridgerchu/matmulfreellm">MatmulFree LLM</a></p>
</div>

---

## Overview

Private video: UCSC CSE210 Winter 2026 Ethan Sifferman (1.58-bit LLM on FPGA)

Ternip is a parameterizable, open-source RTL implementation of a hardware accelerator targeting the MatmulFree LLM algoirhtnm. MatmulFree LLMs replace traditional matrix multiplication with ternary weight operations, enabling significant reductions in compute and memory bandwidth — making them well-suited for hardware acceleration.

This project is licensed under the [BSD 3-Clause License](LICENSE) and is free to use, modify, and distribute.

### Notable Files

| File | Description |
|------|-------------|
| [docs/LLM2FPGA_EXECUTION_PLAN.md](docs/LLM2FPGA_EXECUTION_PLAN.md) | Feasibility plan for end-to-end FPGA inference adoption with gated go/no-go criteria. |
| [docs/LLM2FPGA_GATE1_CHECKLIST.md](docs/LLM2FPGA_GATE1_CHECKLIST.md) | Gate 1 execution checklist and artifact format. |
| [docs/LLM2FPGA_GATE2_CHECKLIST.md](docs/LLM2FPGA_GATE2_CHECKLIST.md) | Gate 2 parity checklist for TMATMUL block replay. |
| [rtl/ternip/ternip_core.sv](rtl/ternip/ternip_core.sv) | Top-level compute core |
| [rtl/fus/ternip_tmatmul.sv](rtl/fus/ternip_tmatmul.sv) | Ternary matrix multiplication unit |
| [rtl/fus/ternip_rms.sv](rtl/fus/ternip_rms.sv) | RMS normalization unit |
| [rtl/math/](rtl/math/) | Math modules (sqrt, sigmoid, SiLU, and more) |
| [scripts/gate1/run_gate1_smoke.sh](scripts/gate1/run_gate1_smoke.sh) | Gate 1 deterministic checkpoint smoke test runner. |
| [scripts/gate2/run_gate2_tmatmul_parity.sh](scripts/gate2/run_gate2_tmatmul_parity.sh) | Gate 2 TMATMUL parity runner. |

*Tests and build flow are not currently provided but will be made available shortly.*

## Dependencies

Ternip depends on the [BaseJump STL](https://github.com/bespoke-silicon-group/basejump_stl) hardware library.

## FuseSoC

Ternip is available on the [FuseSoC Package Directory](https://fusesoc.net). To add it as a library using the GitHub repo directly:

```bash
fusesoc library add ternip https://github.com/sifferman/ternip --sync-type=git
```

Then declare it as a dependency in your `.core` file:

```yaml
filesets:
  rtl:
    depend:
      - sifferman::ternip
```

## Citation

If you use this work, please cite the original MatmulFree LLM paper:

```bibtex
@article{zhu2024scalable,
  title   = {Scalable MatMul-free Language Modeling},
  author  = {Zhu, Rui-Jie and Zhang, Yu and Sifferman, Ethan and Sheaves, Tyler and Wang, Yiqiao and Richmond, Dustin and Zhou, Peng and Eshraghian, Jason K},
  journal = {arXiv preprint arXiv:2406.02528},
  year    = {2024}
}
```

## Contributors

See [docs/CONTRIBUTORS](docs/CONTRIBUTORS).
