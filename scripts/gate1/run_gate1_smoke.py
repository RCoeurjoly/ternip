#!/usr/bin/env python3
"""Gate 1 reproducibility smoke test.

This script loads a MatMul-free/HGRN checkpoint and performs
reproducible generation twice for the same prompt to verify deterministic
software behavior before FPGA integration work starts.
"""

from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timezone
from pathlib import Path

import torch
from transformers import AutoConfig, AutoModelForCausalLM, AutoTokenizer


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a deterministic checkpoint generation smoke test."
    )
    parser.add_argument(
        "--model-id",
        required=True,
        help="Hugging Face model id or local path for checkpoint.",
    )
    parser.add_argument(
        "--prompt",
        default="The future of hardware-aware language models is",
        help="Prompt used for deterministic replay.",
    )
    parser.add_argument(
        "--output-dir",
        default="artifacts/gate1",
        help="Directory to write JSON artifacts.",
    )
    parser.add_argument(
        "--max-new-tokens",
        type=int,
        default=16,
        help="Number of tokens to generate.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=1234,
        help="PRNG seed for reproducibility.",
    )
    parser.add_argument(
        "--dtype",
        default="float16",
        choices=["float16", "bfloat16", "float32"],
        help="PyTorch dtype for model load.",
    )
    parser.add_argument(
        "--device",
        default="cpu",
        choices=["cpu", "cuda", "mps"],
        help="Device to run generation on.",
    )
    parser.add_argument(
        "--trust-remote-code",
        action="store_true",
        help="Pass through to tokenizer/model loading for custom architectures.",
    )
    parser.add_argument(
        "--repeats",
        type=int,
        default=2,
        help="How many deterministic runs to perform.",
    )
    parser.add_argument(
        "--max-length",
        type=int,
        default=256,
        help="Optional tokenizer max length input cap.",
    )
    return parser.parse_args()


def normalize_dtype(name: str) -> torch.dtype:
    if name == "float16":
        return torch.float16
    if name == "bfloat16":
        return torch.bfloat16
    if name == "float32":
        return torch.float32
    raise ValueError(f"Unsupported dtype: {name}")


def build_payload(
    run_idx: int,
    prompt: str,
    model_id: str,
    args: argparse.Namespace,
    generated: str,
    token_ids: list[int],
) -> dict[str, object]:
    return {
        "run_idx": run_idx,
        "model_id": model_id,
        "prompt": prompt,
        "seed": args.seed,
        "dtype": args.dtype,
        "device": args.device,
        "max_new_tokens": args.max_new_tokens,
        "generated_text": generated,
        "generated_token_ids": token_ids,
        "generated_len": len(token_ids),
    }


def main() -> int:
    args = parse_args()
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    torch.manual_seed(args.seed)
    random.seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)

    dtype = normalize_dtype(args.dtype)

    config = AutoConfig.from_pretrained(
        args.model_id,
        trust_remote_code=args.trust_remote_code,
    )
    tokenizer = AutoTokenizer.from_pretrained(
        args.model_id,
        trust_remote_code=args.trust_remote_code,
    )

    if not hasattr(tokenizer, "bos_token") or tokenizer.bos_token is None:
        tokenizer.add_special_tokens({"bos_token": "<s>"})

    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        torch_dtype=dtype,
        trust_remote_code=args.trust_remote_code,
    ).to(args.device)
    model.eval()

    runs = []
    for run_idx in range(args.repeats):
        torch.manual_seed(args.seed + run_idx)
        random.seed(args.seed + run_idx)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(args.seed + run_idx)

        inputs = tokenizer(
            args.prompt,
            return_tensors="pt",
            truncation=True,
            max_length=args.max_length,
        ).to(args.device)

        with torch.no_grad():
            output = model.generate(
                **inputs,
                max_new_tokens=args.max_new_tokens,
                do_sample=False,
            )

        token_ids = output[0].tolist()
        text = tokenizer.decode(
            token_ids[inputs["input_ids"].shape[1] :],
            skip_special_tokens=True,
        )
        runs.append(build_payload(run_idx, args.prompt, args.model_id, args, text, token_ids))

    first = runs[0]["generated_text"]
    all_match = all(run["generated_text"] == first for run in runs)

    result = {
        "model_id": args.model_id,
        "model_config": {
            "architectures": list(getattr(config, "architectures", [])),
            "model_type": getattr(config, "model_type", None),
            "hidden_size": getattr(config, "hidden_size", None),
            "intermediate_size": getattr(config, "intermediate_size", None),
        },
        "prompt": args.prompt,
        "parameters": {
            "seed": args.seed,
            "dtype": args.dtype,
            "device": args.device,
            "max_new_tokens": args.max_new_tokens,
            "max_length": args.max_length,
            "repeats": args.repeats,
            "trust_remote_code": args.trust_remote_code,
        },
        "runs": runs,
        "reproducible": all_match,
        "first_run_text": first,
        "generated_texts": [r["generated_text"] for r in runs],
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
    }

    out_file = out_dir / "gate1_smoke_result.json"
    out_file.write_text(json.dumps(result, indent=2))

    summary = {
        "artifact": str(out_file),
        "reproducible": all_match,
    }
    print(json.dumps(summary, indent=2))
    return 0 if all_match else 1


if __name__ == "__main__":
    raise SystemExit(main())
