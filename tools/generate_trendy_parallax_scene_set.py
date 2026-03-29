#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List, Sequence

import generate_art_assets as asset_specs
import generate_openai_art_assets as openai_assets


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
OUTPUT_ROOT = ROOT / "assets" / "generated" / "style_boards_trendy_q_parallax"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "style_boards_trendy_q_parallax"
LOG_PATH = ROOT / "文档" / "style_board_trendy_q_parallax_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "style_board_trendy_q_parallax_review_v1.md"

BASE_NEGATIVE = (
    "grimdark, horror, realistic anatomy, giant anime eyes, xianxia, flying swords, "
    "photorealistic, gore, dark dungeon, purple fantasy UI, logo, watermark, text"
)

SCENE_BASE = (
    "stylized new guofeng wuxia side-scrolling battle scene, scenic jianghu travel atmosphere, "
    "warm daylight, bright mountain town mood, suitable for parallax scrolling game, "
    "clear horizontal combat lane, steam-friendly indie style"
)


def _spec(
    logical_id: str,
    output_path: str,
    prompt: str,
) -> asset_specs.AssetSpec:
    return asset_specs.AssetSpec(
        logical_id=logical_id,
        category="backgrounds",
        wired_now=False,
        output_path=output_path,
        target_size="1280x720",
        background_mode="opaque",
        prompt=prompt,
        negative_prompt=BASE_NEGATIVE,
        source_doc="16_潮流新国风Q版美术规范",
        replace_mode="new",
        generator="openai-trendy-parallax-scene-set",
        meta={},
    )


def build_specs(scene_key: str) -> List[asset_specs.AssetSpec]:
    base_name = f"{scene_key}_v1"
    return [
        _spec(
            f"{base_name}_far",
            f"assets/generated/style_boards_trendy_q_parallax/{base_name}__far.png",
            (
                f"{SCENE_BASE}, far background layer only, distant mountains, distant pagodas, skyline, "
                "atmospheric perspective, minimal detail, soft edges, no foreground objects, no close buildings"
            ),
        ),
        _spec(
            f"{base_name}_mid",
            f"assets/generated/style_boards_trendy_q_parallax/{base_name}__mid.png",
            (
                f"{SCENE_BASE}, midground playable layer, readable architecture, bridge or road, "
                "main battle lane centered, medium detail, clear location identity, no close foreground occluders"
            ),
        ),
        _spec(
            f"{base_name}_near",
            f"assets/generated/style_boards_trendy_q_parallax/{base_name}__near.png",
            (
                f"{SCENE_BASE}, foreground layer only, minimal scene content, occluding props near camera, "
                "lanterns, railings, branches, banner edges, stall corners, strong foreground framing, "
                "transparent feeling composition even on opaque image, avoid full background scene"
            ),
        ),
    ]


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


def _write_review_md(specs: Sequence[asset_specs.AssetSpec], scene_key: str) -> None:
    lines = [
        "# AFK-RPG 横版三层背景试片评审 v1",
        "",
        f"## 场景 key",
        "",
        f"- `{scene_key}`",
        "",
        "## 样张清单",
        "",
    ]
    for spec in specs:
        lines.append(f"- `{spec.logical_id}`: `{spec.output_path}`")
    lines.extend(
        [
            "",
            "## 评审重点",
            "",
            "- `far` 是否足够远、足够淡、只承担纵深氛围",
            "- `mid` 是否有清晰战斗走廊和地点识别",
            "- `near` 是否是前景遮挡物，而不是重复主场景",
            "- 三层拼起来是否像同一地点，而不是三张互不相关的图",
        ]
    )
    REVIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_scene_set(
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
    parser = argparse.ArgumentParser(description="Generate a coordinated far/mid/near trendy guofeng parallax scene set.")
    parser.add_argument("--scene-key", default="chapter1_travel_road")
    parser.add_argument("--model", default="gpt-image-1.5")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
    parser.add_argument("--sleep-seconds", type=float, default=12.0)
    parser.add_argument("--skip-generate", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = _parse_args(argv)
    specs = build_specs(args.scene_key)
    _write_review_md(specs, args.scene_key)
    if args.skip_generate:
        print(f"Wrote review scaffold to {REVIEW_PATH.relative_to(ROOT)}", flush=True)
        return 0

    api_key = openai_assets._load_api_key()
    print(
        f"Generating {len(specs)} coordinated parallax layers with {args.model} ({args.quality}).",
        flush=True,
    )
    generate_scene_set(specs, api_key, args.model, args.quality, args.sleep_seconds)
    asset_specs.verify_sizes(specs)
    print(f"Done. Verified {len(specs)} coordinated parallax layers.", flush=True)
    print(f"Review notes: {REVIEW_PATH.relative_to(ROOT)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
