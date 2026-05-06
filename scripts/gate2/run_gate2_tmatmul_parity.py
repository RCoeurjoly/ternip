#!/usr/bin/env python3
"""Gate2 parity check for TMATMUL block.

This generates deterministic fixed-point vector/matrix inputs, computes software
reference output, runs a Verilator RTL simulation of a dedicated parity TB, and
writes a result artifact for the execution log.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import subprocess
from pathlib import Path
from typing import List, Tuple



def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run one TMATMUL parity case and compare RTL to software."
    )
    parser.add_argument("--seed", type=int, default=1337, help="RNG seed.")
    parser.add_argument(
        "--basejump-stl",
        default=None,
        help="BaseJump STL checkout. If omitted, uses BASEJUMP_STL env var.",
    )
    parser.add_argument(
        "--output-dir",
        default="artifacts/gate2/seed_{seed}",
        help="Output artifact directory pattern.",
    )
    parser.add_argument(
        "--verilator",
        default="verilator",
        help="Verilator executable to invoke.",
    )
    parser.add_argument(
        "--sim-timeout-cycles",
        type=int,
        default=200000,
        help="Timeout for the Verilator simulation loops.",
    )
    return parser.parse_args()


def clamp_fixed(value: int, width: int = 8) -> int:
    hi = (1 << (width - 1)) - 1
    lo = -1 << (width - 1)
    return max(min(value, hi), lo)


def signed_hex_byte(value: int) -> str:
    return f"{value & 0xFF:02x}"


def signed_ternary_code(value: int) -> str:
    code = value & 0x3
    return f"{code:x}"


def write_hex_file(path: Path, entries: List[str]) -> None:
    with path.open("w", encoding="utf-8") as fp:
        fp.write("\n".join(entries))
        fp.write("\n")


def generate_case(seed: int) -> Tuple[List[int], List[List[int]], List[int]]:
    random.seed(seed)

    d = 64
    values = [random.randint(-24, 24) for _ in range(d)]
    matrix = [[random.choice((0, 1, -1)) for _ in range(d)] for _ in range(d)]

    expected = []
    for row in range(d):
        total = 0
        for col in range(d):
            total += matrix[row][col] * values[col]
        expected.append(clamp_fixed(total, width=8))

    return values, matrix, expected


def run_command(argv: List[str], cwd: Path) -> None:
    subprocess.run(argv, cwd=str(cwd), check=True)


def build_and_run(
    repo_root: Path,
    basejump_stl: str,
    verilator_bin: str,
    sim_dir: Path,
    vector_hex: Path,
    matrix_hex: Path,
    hw_output: Path,
    sim_log: Path,
    timeout_cycles: int,
) -> Tuple[int, str]:
    tb_path = repo_root / "scripts/gate2/tmatmul_parity_tb.sv"
    work_dir = sim_dir
    work_dir.mkdir(parents=True, exist_ok=True)

    includes = [
        f"{basejump_stl}/bsg_misc/bsg_adder_cin.sv",
        f"{basejump_stl}/bsg_misc/bsg_arb_round_robin.sv",
        f"{basejump_stl}/bsg_misc/bsg_circular_ptr.sv",
        f"{basejump_stl}/bsg_misc/bsg_counter_clear_up.sv",
        f"{basejump_stl}/bsg_misc/bsg_crossbar_o_by_i.sv",
        f"{basejump_stl}/bsg_misc/bsg_dff_en.sv",
        f"{basejump_stl}/bsg_misc/bsg_dff_reset.sv",
        f"{basejump_stl}/bsg_misc/bsg_encode_one_hot.sv",
        f"{basejump_stl}/bsg_misc/bsg_idiv_iterative_controller.sv",
        f"{basejump_stl}/bsg_misc/bsg_idiv_iterative.sv",
        f"{basejump_stl}/bsg_misc/bsg_imul_iterative.sv",
        f"{basejump_stl}/bsg_misc/bsg_mux_one_hot.sv",
        f"{basejump_stl}/bsg_misc/bsg_nor2.sv",
        f"{basejump_stl}/bsg_misc/bsg_round_robin_arb.sv",
        f"{basejump_stl}/bsg_mem/bsg_mem_1r1w_synth.sv",
        f"{basejump_stl}/bsg_mem/bsg_mem_1r1w.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_fifo_1r1w_small_hardened.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_fifo_1r1w_small_unhardened.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_fifo_1r1w_small.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_fifo_tracker.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_one_fifo.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_parallel_in_serial_out.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_round_robin_1_to_n.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_round_robin_n_to_1.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_serial_in_parallel_out_full.sv",
        f"{basejump_stl}/bsg_dataflow/bsg_two_fifo.sv",
        "rtl/ternip_pkg.sv",
        "rtl/ternip_vector_registers.sv",
        "rtl/common/ternip_gearbox_fifo.sv",
        "rtl/common/ternip_multioperand_accumulator.sv",
        "rtl/common/ternip_pipelined_mem.sv",
        "rtl/fus/ternip_tmatmul.sv",
        tb_path,
    ]

    cmd = [
        verilator_bin,
        "--binary",
        "--timing",
        "--sv",
        "-Wno-fatal",
        "-Wno-WIDTHEXPAND",
        "-Wno-WIDTHTRUNC",
        "-Wno-UNOPTFLAT",
        "-Wno-INITIALDLY",
        "--top-module",
        "tb_gate2_tmatmul_parity",
        "-Mdir",
        str(work_dir),
        "-I.",
        "-Irtl",
        "-Iconfig",
        f"-I{basejump_stl}/bsg_misc",
        f"-I{basejump_stl}/bsg_dataflow",
        f"-I{basejump_stl}/bsg_mem",
        "+define+TERNIP_REDUCED_YPCB_CONFIG",
    ] + includes

    run_command(cmd, repo_root)

    sim_path = work_dir / "Vtb_gate2_tmatmul_parity"
    sim_cmd = [
        str(sim_path),
        f"+vector_file={vector_hex}",
        f"+matrix_file={matrix_hex}",
        f"+out_file={hw_output}",
        f"+timeout_cycles={timeout_cycles}",
    ]

    with sim_log.open("w", encoding="utf-8") as log_fp:
        completed = subprocess.run(
            sim_cmd,
            cwd=str(repo_root),
            stdout=log_fp,
            stderr=subprocess.STDOUT,
        )

    return completed.returncode, sim_log.read_text(encoding="utf-8")


def load_hw_output(path: Path) -> List[int]:
    return [int(line.strip(), 10) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def compare_vectors(sw: List[int], hw: List[int]) -> Tuple[bool, int, List[Tuple[int, int, int]]]:
    if len(hw) != len(sw):
        max_abs_diff = max((abs(a - b) for a, b in zip(sw, hw)), default=10**9)
        return False, max_abs_diff, [(idx, s, h) for idx, (s, h) in enumerate(zip(sw, hw))]

    diffs = []
    max_abs_diff = 0
    for idx, (s, h) in enumerate(zip(sw, hw)):
        d = abs(s - h)
        max_abs_diff = max(max_abs_diff, d)
        if s != h:
            diffs.append((idx, s, h))

    return len(diffs) == 0, max_abs_diff, diffs


def main() -> int:
    args = parse_args()
    basejump_stl = args.basejump_stl or os.environ.get("BASEJUMP_STL")
    if not basejump_stl:
        raise RuntimeError("BaseJump STL path missing. Set --basejump-stl or BASEJUMP_STL.")

    repo_root = Path(__file__).resolve().parents[2]
    output_dir = Path(args.output_dir.format(seed=args.seed))
    output_dir.mkdir(parents=True, exist_ok=True)

    if shutil.which(args.verilator) is None:
        raise RuntimeError(f"Could not find verilator executable: {args.verilator}")

    vector_values, matrix_values, expected = generate_case(args.seed)
    vector_hex = output_dir / "vector.hex"
    matrix_hex = output_dir / "matrix.hex"
    hw_output = output_dir / "hw_output.txt"
    sim_log = output_dir / "sim.log"
    result_json = output_dir / "gate2_tmatmul_result.json"

    write_hex_file(vector_hex, [signed_hex_byte(v) for v in vector_values])
    flat_matrix = [signed_ternary_code(entry) for row in matrix_values for entry in row]
    write_hex_file(matrix_hex, flat_matrix)

    sim_rc, sim_output = build_and_run(
        repo_root=repo_root,
        basejump_stl=basejump_stl,
        verilator_bin=args.verilator,
        sim_dir=output_dir / "sim",
        vector_hex=vector_hex,
        matrix_hex=matrix_hex,
        hw_output=hw_output,
        sim_log=sim_log,
        timeout_cycles=args.sim_timeout_cycles,
    )

    if sim_rc != 0:
        raise RuntimeError(f"Verilator simulation failed. See {sim_log}")

    hw_values = load_hw_output(hw_output)
    match, max_abs_diff, mismatches = compare_vectors(expected, hw_values)

    result = {
        "seed": args.seed,
        "dimensions": {"D": len(vector_values), "matrix_rows": len(matrix_values)},
        "sim_timeout_cycles": args.sim_timeout_cycles,
        "status": "pass" if match else "fail",
        "max_abs_diff": max_abs_diff,
        "first_mismatch": mismatches[:5],
        "mismatch_count": len(mismatches),
        "sim_return_code": sim_rc,
        "sim_log": str(sim_log),
        "sim_output_snippet": sim_output.splitlines()[-20:],
        "expected_path": str(output_dir / "expected.txt"),
        "vector_path": str(vector_hex),
        "matrix_path": str(matrix_hex),
        "hw_output_path": str(hw_output),
    }

    (output_dir / "expected.txt").write_text(
        "\n".join(str(v) for v in expected) + "\n",
        encoding="utf-8",
    )
    result_json.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(
        json.dumps(
            {
                "artifact_dir": str(output_dir),
                "status": result["status"],
                "sim_rc": sim_rc,
            },
            indent=2,
        )
    )
    return 0 if match else 1


if __name__ == "__main__":
    raise SystemExit(main())
