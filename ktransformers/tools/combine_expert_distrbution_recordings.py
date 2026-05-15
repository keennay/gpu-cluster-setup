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

    raw_totals = []
    skipped_combined = []
    for path in sorted(rec_dir.glob("expert_distribution_recorder_*.pt")):
        data = torch.load(path, map_location="cpu", weights_only=True)
        logical_count = data["logical_count"]
        if logical_count.shape[0] == 1:
            skipped_combined.append(str(path))
            continue
        raw_totals.append((path, logical_count.sum(dim=0, keepdim=True)))

    if not raw_totals:
        raise SystemExit(f"No raw expert_distribution_recorder_*.pt files found in {rec_dir}")

    total = None
    used = []
    for path, chunk_total in raw_totals:
        total = chunk_total if total is None else total + chunk_total
        used.append(str(path))

    out = rec_dir / f"expert_distribution_recorder_{time.time()}.pt"
    torch.save({"logical_count": total}, out)

    print(f"wrote {out}")
    print(f"combined {len(used)} chunks")
    print(f"skipped {len(skipped_combined)} already-combined files")
    print(f"logical_count shape: {tuple(total.shape)}")


if __name__ == "__main__":
    main()
