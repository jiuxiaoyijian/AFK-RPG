#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, Sequence

import generate_art_assets as asset_specs
import generate_openai_art_assets as openai_assets


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
LOG_PATH = ROOT / "文档" / "美术资源_openai生成日志_v1.jsonl"


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Restore generated AFK-RPG assets from previously saved OpenAI raw outputs.")
    parser.add_argument("--scope", choices=["wired", "unwired", "all"], default="wired")
    parser.add_argument("--logical-id", action="append", default=[])
    return parser.parse_args(argv)


def _load_latest_entries() -> Dict[str, Dict]:
    latest: Dict[str, Dict] = {}
    with LOG_PATH.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            logical_id = str(entry.get("logical_id", "")).strip()
            if logical_id:
                latest[logical_id] = entry
    return latest


def main(argv: Sequence[str]) -> int:
    args = _parse_args(argv)
    specs = asset_specs.build_specs()
    if args.scope == "wired":
        specs = [spec for spec in specs if spec.wired_now]
    elif args.scope == "unwired":
        specs = [spec for spec in specs if not spec.wired_now]

    logical_ids = {item.strip() for item in args.logical_id if item.strip()}
    if logical_ids:
        specs = [spec for spec in specs if spec.logical_id in logical_ids]

    latest_entries = _load_latest_entries()
    restored_count = 0
    for spec in specs:
        entry = latest_entries.get(spec.logical_id)
        if entry is None:
            continue
        raw_path = ROOT / str(entry.get("raw_path", ""))
        if not raw_path.exists():
            continue
        output_path = ROOT / spec.output_path
        openai_assets._center_crop_and_resize(raw_path, output_path, spec.target_size)
        restored_count += 1
        print("restored %s -> %s" % (spec.logical_id, spec.output_path))

    asset_specs.verify_sizes(specs)
    print("Restored %d assets from OpenAI raw outputs." % restored_count)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(__import__("sys").argv[1:]))
