#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

import hero_run_pipeline as run_pipeline


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
DEFAULT_CANDIDATE_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "hero_run_video" / "keyframe_candidates" / "hero_run_candidates_v1"
RAW_CUTOUT_DIR = ROOT / "assets" / "generated" / "hero_run_review" / "direct_cutouts"
FINAL_DIR = ROOT / "assets" / "generated" / "afk_rpg_formal" / "characters"
REPORT_PATH = ROOT / "assets" / "generated" / "hero_run_review" / "hero_run_direct_extract_report.json"
DEFAULT_FRAMES = ["frame_001.png", "frame_006.png", "frame_011.png", "frame_016.png", "frame_021.png", "frame_026.png"]


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Build final hero run PNGs by directly cutting frames from a run reference video.")
	parser.add_argument("--candidate-dir", default=str(DEFAULT_CANDIDATE_DIR))
	parser.add_argument("--frame", action="append", dest="frames", default=[])
	parser.add_argument("--seed-threshold", type=float, default=18.0)
	parser.add_argument("--grow-threshold", type=float, default=28.0)
	parser.add_argument("--trim-radius", type=int, default=2)
	parser.add_argument("--anchor-x", type=int, default=384)
	parser.add_argument("--foot-y", type=int, default=729)
	parser.add_argument("--head-y", type=int, default=230)
	parser.add_argument("--canvas-width", type=int, default=768)
	parser.add_argument("--canvas-height", type=int, default=768)
	return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
	args = _parse_args(argv)
	candidate_dir = Path(args.candidate_dir)
	frame_names = args.frames or list(DEFAULT_FRAMES)
	frame_paths = [candidate_dir / name for name in frame_names]
	for frame_path in frame_paths:
		if not frame_path.exists():
			raise SystemExit(f"Missing candidate frame: {frame_path}")

	RAW_CUTOUT_DIR.mkdir(parents=True, exist_ok=True)
	temp_paths: list[Path] = []
	for index, frame_path in enumerate(frame_paths, start=1):
		width, height, pixels = run_pipeline.load_rgba_png(frame_path)
		cutout = run_pipeline.remove_border_background(
			width,
			height,
			pixels,
			seed_threshold=args.seed_threshold,
			grow_threshold=args.grow_threshold,
		)
		cutout = run_pipeline.trim_foreground_edges(
			width,
			height,
			cutout,
			trim_radius=args.trim_radius,
		)
		temp_path = RAW_CUTOUT_DIR / f"hero_move_direct_cutout_{index:02d}.png"
		run_pipeline.save_rgba_png(temp_path, width, height, cutout)
		temp_paths.append(temp_path)

	final_paths = [FINAL_DIR / f"hero_move_anim_{index:02d}.png" for index in range(1, len(temp_paths) + 1)]
	report = run_pipeline.stabilize_rgba_sequence(
		temp_paths,
		final_paths,
		anchor_x=args.anchor_x,
		foot_y=args.foot_y,
		canvas_width=args.canvas_width,
		canvas_height=args.canvas_height,
		head_y=args.head_y,
	)
	REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
	REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
	print(f"Built {len(final_paths)} direct-extract run frames.")
	print(f"Report: {REPORT_PATH.relative_to(ROOT)}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main(__import__("sys").argv[1:]))
