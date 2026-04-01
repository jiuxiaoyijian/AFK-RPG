#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Sequence

import hero_run_pipeline as run_pipeline


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "hero_run_video" / "keyframe_candidates"
REVIEW_DIR = ROOT / "assets" / "generated" / "hero_run_review"
DEFAULT_BASELINE_GLOB = "assets/generated/afk_rpg_formal/characters/hero_move_anim_0*.png"


def _resolve_ffmpeg_tool() -> str:
	ffmpeg = shutil.which("ffmpeg")
	if ffmpeg:
		return ffmpeg
	vendor_dir = ROOT / ".vendor"
	if str(vendor_dir) not in sys.path:
		sys.path.insert(0, str(vendor_dir))
	try:
		import imageio_ffmpeg
	except Exception:
		imageio_ffmpeg = None
	if imageio_ffmpeg is None:
		raise SystemExit("ffmpeg is required. Install system ffmpeg or `pip install --target .vendor imageio-ffmpeg`.")
	return imageio_ffmpeg.get_ffmpeg_exe()


def _probe_duration_with_ffmpeg(ffmpeg_path: str, video_path: Path) -> float:
	process = subprocess.run(
		[
			ffmpeg_path,
			"-i",
			str(video_path),
		],
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		text=True,
	)
	output = f"{process.stdout}\n{process.stderr}"
	match = re.search(r"Duration:\s+(\d+):(\d+):(\d+(?:\.\d+)?)", output)
	if match is None:
		raise SystemExit("Unable to determine video duration from ffmpeg output.")
	hours = int(match.group(1))
	minutes = int(match.group(2))
	seconds = float(match.group(3))
	return hours * 3600.0 + minutes * 60.0 + seconds


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Extract and review hero run keyframe candidates.")
	parser.add_argument("--video", default="")
	parser.add_argument("--source-glob", default="")
	parser.add_argument("--candidate-count", type=int, default=30)
	parser.add_argument("--target-keyframes", type=int, default=6)
	parser.add_argument("--review-name", default="hero_run_keyframes_v1")
	parser.add_argument("--background-threshold", type=float, default=42.0)
	parser.add_argument("--alpha-threshold", type=int, default=16)
	return parser.parse_args(argv)


def _assert_mode(args: argparse.Namespace) -> None:
	if bool(args.video) == bool(args.source_glob):
		raise SystemExit("Pass exactly one of --video or --source-glob.")


def _extract_from_video(video_path: Path, candidate_count: int, review_name: str) -> list[Path]:
	ffmpeg_path = _resolve_ffmpeg_tool()
	output_dir = RAW_DIR / review_name
	output_dir.mkdir(parents=True, exist_ok=True)
	for old_frame in output_dir.glob("*.png"):
		old_frame.unlink()
	duration = max(0.1, _probe_duration_with_ffmpeg(ffmpeg_path, video_path))
	fps = candidate_count / duration
	output_pattern = output_dir / "frame_%03d.png"
	subprocess.check_call(
		[
			ffmpeg_path,
			"-hide_banner",
			"-loglevel",
			"error",
			"-y",
			"-i",
			str(video_path),
			"-vf",
			f"fps={fps:.6f}",
			str(output_pattern),
		]
	)
	return sorted(output_dir.glob("frame_*.png"))


def _collect_source_glob(pattern: str) -> list[Path]:
	return sorted(ROOT.glob(pattern))


def _suggest_keyframe_indices(total: int, target: int) -> set[int]:
	if total <= 0 or target <= 0:
		return set()
	if total <= target:
		return set(range(total))
	indices: set[int] = set()
	for slot in range(target):
		ratio = slot / float(target)
		index = min(total - 1, int(round(ratio * total)))
		indices.add(index)
	return indices


def _frame_card(frame_path: Path, metrics: dict, is_suggested: bool, review_dir: Path) -> str:
	rel_path = frame_path.relative_to(review_dir.parent.parent)
	bbox = metrics["bbox"]
	return (
		"<article class='card'>"
		f"<img src='../../{rel_path.as_posix()}' alt='{frame_path.name}'>"
		f"<h3>{frame_path.name}</h3>"
		f"<p>bbox: {bbox[0]}, {bbox[1]}, {bbox[2]}, {bbox[3]}</p>"
		f"<p>foot_y: {metrics['foot_y']}</p>"
		f"<p>center_x: {metrics['center_x']:.2f}</p>"
		f"<p>body_height: {metrics['body_height']}</p>"
		f"<p class='status {'pick' if is_suggested else 'review'}'>{'suggested' if is_suggested else 'review'}</p>"
		"</article>"
	)


def _write_review_files(
	review_name: str,
	frame_paths: Sequence[Path],
	metrics_list: Sequence[dict],
	suggested_indices: set[int],
) -> None:
	REVIEW_DIR.mkdir(parents=True, exist_ok=True)
	html_path = REVIEW_DIR / f"{review_name}.html"
	json_path = REVIEW_DIR / f"{review_name}.json"
	md_path = REVIEW_DIR / f"{review_name}.md"

	cards = []
	for index, (frame_path, metrics) in enumerate(zip(frame_paths, metrics_list)):
		cards.append(_frame_card(frame_path, metrics, index in suggested_indices, REVIEW_DIR))
	html = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>{review_name}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #11141b; color: #ebe5d8; margin: 24px; }}
    h1 {{ margin-bottom: 12px; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px; }}
    .card {{ background: #1c2130; border: 1px solid #2d3548; border-radius: 14px; padding: 14px; }}
    .card img {{ width: 100%; height: auto; border-radius: 10px; background: #0b0e14; }}
    .card h3 {{ font-size: 15px; margin: 12px 0 8px; }}
    .card p {{ margin: 4px 0; font-size: 13px; color: #d0c7b4; }}
    .status {{ display: inline-block; margin-top: 8px; padding: 4px 8px; border-radius: 999px; font-weight: 600; }}
    .status.pick {{ background: #204d39; color: #9ae0b9; }}
    .status.review {{ background: #47361d; color: #e6c27a; }}
  </style>
</head>
<body>
  <h1>{review_name}</h1>
  <p>候选帧共 {len(frame_paths)} 张，建议关键帧 {len(suggested_indices)} 张。</p>
  <div class="grid">
    {''.join(cards)}
  </div>
</body>
</html>
"""
	html_path.write_text(html, encoding="utf-8")
	json_path.write_text(json.dumps(metrics_list, ensure_ascii=False, indent=2), encoding="utf-8")
	md_lines = [
		f"# {review_name}",
		"",
		f"- 候选帧数: `{len(frame_paths)}`",
		f"- 建议关键帧数: `{len(suggested_indices)}`",
		"",
		"## 指标",
		"",
	]
	for index, metrics in enumerate(metrics_list):
		status = "suggested" if index in suggested_indices else "review"
		md_lines.append(
			f"- `{Path(metrics['path']).name}`: bbox=`{metrics['bbox']}` foot_y=`{metrics['foot_y']}` center_x=`{metrics['center_x']:.2f}` body_height=`{metrics['body_height']}` status=`{status}`"
		)
	md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")


def main(argv: Sequence[str]) -> int:
	args = _parse_args(argv)
	_assert_mode(args)
	if args.video:
		frame_paths = _extract_from_video(Path(args.video), args.candidate_count, args.review_name)
	else:
		pattern = args.source_glob or DEFAULT_BASELINE_GLOB
		frame_paths = _collect_source_glob(pattern)

	if not frame_paths:
		raise SystemExit("No candidate frames found.")

	metrics_list: list[dict] = []
	for frame_path in frame_paths:
		metrics = run_pipeline.compute_frame_metrics(
			frame_path,
			alpha_threshold=args.alpha_threshold,
			background_threshold=args.background_threshold,
		)
		if metrics is None:
			continue
		metrics_list.append(metrics)

	if not metrics_list:
		raise SystemExit("Unable to detect a foreground subject in the candidate frames.")

	valid_frame_paths = [Path(metrics["path"]) for metrics in metrics_list]
	suggested_indices = _suggest_keyframe_indices(len(valid_frame_paths), args.target_keyframes)
	_write_review_files(args.review_name, valid_frame_paths, metrics_list, suggested_indices)
	print(f"Wrote review HTML to {(REVIEW_DIR / f'{args.review_name}.html').relative_to(ROOT)}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
