#!/usr/bin/env python3
import argparse
import time
from pathlib import Path

import torch


def parse_args():
    parser = argparse.ArgumentParser(
        description="Combine chunked expert_distribution_recorder_*.pt files."
    )
    parser.add_argument(
        "recording_dir",
        nargs="?",
        default="01",
        help="Directory containing expert_distribution_recorder_*.pt files.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    rec_dir = Path(args.recording_dir)

    files = sorted(rec_dir.glob("expert_distribution_recorder_*.pt"))
    files = [path for path in files if "combined" not in path.name]
    if not files:
        raise SystemExit(f"No expert_distribution_recorder_*.pt files found in {rec_dir}")

    total = None
    used = []
    for path in files:
        data = torch.load(path, map_location="cpu", weights_only=True)
        logical_count = data["logical_count"]
        chunk_total = logical_count.sum(dim=0, keepdim=True)
        total = chunk_total if total is None else total + chunk_total
        used.append(str(path))

    out = rec_dir / f"expert_distribution_recorder_combined_{time.time()}.pt"
    torch.save({"logical_count": total, "combined_from": used}, out)

    print(f"wrote {out}")
    print(f"combined {len(used)} chunks")
    print(f"logical_count shape: {tuple(total.shape)}")


if __name__ == "__main__":
    main()
