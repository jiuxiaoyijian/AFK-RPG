#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List, Sequence

import generate_art_assets as asset_specs
import generate_openai_art_assets as openai_assets
import hero_run_pipeline as run_pipeline


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "hero_action_frames"
LOG_PATH = ROOT / "文档" / "hero_action_frames_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "hero_action_frames_review_v1.md"
RUN6_STABILIZE_REPORT_PATH = ROOT / "assets" / "generated" / "hero_run_review" / "hero_run6_stabilize_report.json"

BASE_NEGATIVE = (
	"grimdark, horror, realistic anatomy, baby toddler proportions, giant anime eyes, "
	"xianxia, flying swords, overly ornate costume, mobile game splash art, hypersexualized, "
	"photorealistic, gore, dark dungeon, purple fantasy UI, depressing mood, logo, watermark, text, "
	"blurry silhouette, inconsistent weapon, inconsistent costume, extra limbs, duplicate body"
)

BASE_CHARACTER = (
	"stylized new guofeng wuxia hero, exactly 2.3 heads tall, cute but not childish, "
	"steam-friendly indie game style, less anime, smaller eyes, shorter face, Chinese martial hero identity, "
	"same hero across frames, green-gray traveler robe, short cape, visible topknot, waist sash, boots, "
	"single dao sword, clean silhouette, transparent background, centered full body character sheet frame"
)


def _spec(
	logical_id: str,
	output_path: str,
	prompt: str,
) -> asset_specs.AssetSpec:
	return asset_specs.AssetSpec(
		logical_id=logical_id,
		category="characters",
		wired_now=True,
		output_path=output_path,
		target_size="768x768",
		background_mode="transparent",
		prompt=prompt,
		negative_prompt=BASE_NEGATIVE,
		source_doc="16_潮流新国风Q版美术规范",
		replace_mode="overwrite",
		generator="openai-hero-action-frames",
		meta={},
	)


def build_specs() -> List[asset_specs.AssetSpec]:
	return build_specs_for_mode("legacy", True, True)


def build_specs_for_mode(mode: str, include_move: bool, include_attack: bool) -> List[asset_specs.AssetSpec]:
	move_prompts = [
		"side-scrolling move frame 1, rightward jog anticipation, front foot planted, rear foot lifting, calm forward focus",
		"side-scrolling move frame 2, rightward run contact pose, body leaning forward, cape and sash trailing, readable stride",
		"side-scrolling move frame 3, rightward passing pose, opposite leg forward, sword hand stable, dynamic but clean silhouette",
		"side-scrolling move frame 4, rightward push-off pose, rear leg extended, slight bounce, ready to loop back to frame 1",
	]
	if mode == "run6":
		move_prompts = [
			"side-scrolling run frame 1, rightward front-foot contact pose, forward lean, same hero identity as hero_formal_stand_v1 and hero_formal_action_v1, stable sword hand, readable stride start",
			"side-scrolling run frame 2, rightward compression pose, body settles over leading foot, trailing leg folding inward, cloth overlap controlled, consistent costume silhouette",
			"side-scrolling run frame 3, rightward passing pose, rear leg swings through, torso stable, head angle consistent, clean readable overlap",
			"side-scrolling run frame 4, rightward flight pose, both feet briefly off the ground, short cape trailing, same facial structure and robe family, strong loop silhouette",
			"side-scrolling run frame 5, opposite-foot contact pose, mirrored stride energy but same camera, same costume, same dao sword placement, no character drift",
			"side-scrolling run frame 6, opposite-side passing pose, trailing foot crossing through, ready to loop back to frame 1, stable root and clean readable limbs",
		]
	attack_prompts = [
		"side-scrolling attack frame 1, wind-up pose, dao drawn back, body coiled, readable anticipation",
		"side-scrolling attack frame 2, early slash, dao moving forward, weight shift, cape flaring, strong readable line of action",
		"side-scrolling attack frame 3, impact slash pose, dao extended, strongest action frame, energetic but clean silhouette",
		"side-scrolling attack frame 4, recovery pose, body settling, dao lowering, pose readable for loop back to combat",
	]
	specs: List[asset_specs.AssetSpec] = []
	if include_move:
		for index, suffix in enumerate(move_prompts, start=1):
			specs.append(
				_spec(
					f"hero_formal_move_anim_{index:02d}",
					f"assets/generated/afk_rpg_formal/characters/hero_move_anim_{index:02d}.png",
					f"{BASE_CHARACTER}, {suffix}",
				)
			)
	if include_attack:
		for index, suffix in enumerate(attack_prompts, start=1):
			specs.append(
				_spec(
					f"hero_formal_attack_anim_{index:02d}",
					f"assets/generated/afk_rpg_formal/characters/hero_attack_anim_{index:02d}.png",
					f"{BASE_CHARACTER}, {suffix}",
				)
			)
	return specs


def _save_raw_image(spec: asset_specs.AssetSpec, payload: dict, model: str, quality: str) -> Path:
	RAW_DIR.mkdir(parents=True, exist_ok=True)
	size = openai_assets._generation_size(spec)
	raw_path = RAW_DIR / f"{spec.logical_id}__{model}__{quality}__{size}.png"
	raw_path.write_bytes(payload["__image_bytes"])
	return raw_path


def _append_log(spec: asset_specs.AssetSpec, payload: dict, model: str, quality: str, raw_path: Path) -> None:
	entry = {
		"logical_id": spec.logical_id,
		"output_path": spec.output_path,
		"model": model,
		"quality": quality,
		"requested_size": openai_assets._generation_size(spec),
		"target_size": spec.target_size,
		"background": openai_assets._background_mode(spec),
		"raw_path": str(raw_path.relative_to(ROOT)),
		"prompt": openai_assets._prompt_wrapper(spec),
		"revised_prompt": payload.get("data", [{}])[0].get("revised_prompt"),
		"created": payload.get("created"),
	}
	LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
	with LOG_PATH.open("a", encoding="utf-8") as handle:
		handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _write_review_md(specs: Sequence[asset_specs.AssetSpec]) -> None:
	lines = [
		"# AFK-RPG 主角正式动作帧评审 v1",
		"",
		"## 样张清单",
		"",
	]
	for spec in specs:
		lines.append(f"- `{spec.logical_id}`: `{spec.output_path}`")
	lines.extend(
		[
			"",
			"## 目标",
			"",
			"- 统一主角 `idle / move / combat / attack` 的 Q 版新国风风格",
			"- 为运行版提供真正的多帧 `move / attack` 资源，而不是静态图拼接",
			"- 确保横版向右推进时，动作方向、武器方向和衣摆方向一致",
		]
	)
	REVIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _stabilize_run6_frames(specs: Sequence[asset_specs.AssetSpec]) -> None:
	move_specs = [spec for spec in specs if spec.logical_id.startswith("hero_formal_move_anim_")]
	if len(move_specs) != 6:
		return
	frame_paths = [ROOT / spec.output_path for spec in move_specs]
	run_pipeline.stabilize_rgba_sequence(
		frame_paths,
		frame_paths,
		anchor_x=384,
		foot_y=729,
		canvas_width=768,
		canvas_height=768,
	)
	report: list[dict] = []
	for frame_path in frame_paths:
		metrics = run_pipeline.compute_frame_metrics(frame_path)
		if metrics is not None:
			report.append(metrics)
	RUN6_STABILIZE_REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
	RUN6_STABILIZE_REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


def generate_frames(
	specs: Sequence[asset_specs.AssetSpec],
	api_key: str,
	model: str,
	quality: str,
	sleep_seconds: float,
) -> None:
	total = len(specs)
	for index, spec in enumerate(specs, start=1):
		print(f"[{index}/{total}] {spec.logical_id} -> {spec.output_path}", flush=True)
		payload = openai_assets._request_image(api_key, spec, model, quality)
		raw_path = _save_raw_image(spec, payload, model, quality)
		final_path = ROOT / spec.output_path
		openai_assets._center_crop_and_resize(raw_path, final_path, spec.target_size)
		_append_log(spec, payload, model, quality, raw_path)
		print(f"  saved {final_path.relative_to(ROOT)}", flush=True)
		if sleep_seconds > 0 and index < total:
			import time
			time.sleep(sleep_seconds)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate AFK-RPG formal hero move/attack frames.")
	parser.add_argument("--model", default="gpt-image-1.5")
	parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
	parser.add_argument("--sleep-seconds", type=float, default=12.0)
	parser.add_argument("--mode", choices=["legacy", "run6"], default="legacy")
	parser.add_argument("--animation", choices=["all", "move", "attack"], default="all")
	parser.add_argument("--skip-generate", action="store_true")
	return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
	args = _parse_args(argv)
	include_move = args.animation in {"all", "move"}
	include_attack = args.animation in {"all", "attack"}
	specs = build_specs_for_mode(args.mode, include_move, include_attack)
	_write_review_md(specs)
	if args.skip_generate:
		print(f"Wrote review scaffold to {REVIEW_PATH.relative_to(ROOT)}", flush=True)
		return 0

	api_key = openai_assets._load_api_key()
	print(
		f"Generating {len(specs)} formal hero action frames with {args.model} ({args.quality}).",
		flush=True,
	)
	generate_frames(specs, api_key, args.model, args.quality, args.sleep_seconds)
	if args.mode == "run6":
		_stabilize_run6_frames(specs)
	asset_specs.verify_sizes(specs)
	print(f"Done. Verified {len(specs)} hero action frames.", flush=True)
	print(f"Review notes: {REVIEW_PATH.relative_to(ROOT)}", flush=True)
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
