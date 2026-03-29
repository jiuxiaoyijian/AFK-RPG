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
ROUND2_ROOT = ROOT / "assets" / "generated" / "style_boards_trendy_q_round2"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "style_boards_trendy_q_round2"
LOG_PATH = ROOT / "文档" / "style_board_trendy_q_round2_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "style_board_trendy_q_round2_review_v1.md"

BASE_NEGATIVE = (
    "grimdark, horror, realistic anatomy, baby toddler proportions, giant anime eyes, "
    "xianxia, flying swords, overly ornate costume, mobile game splash art, hypersexualized, "
    "photorealistic, gore, dark dungeon, purple fantasy UI, depressing mood, logo, watermark, text"
)


def _spec(
    logical_id: str,
    category: str,
    output_path: str,
    target_size: str,
    background_mode: str,
    prompt: str,
) -> asset_specs.AssetSpec:
    return asset_specs.AssetSpec(
        logical_id=logical_id,
        category=category,
        wired_now=False,
        output_path=output_path,
        target_size=target_size,
        background_mode=background_mode,
        prompt=prompt,
        negative_prompt=BASE_NEGATIVE,
        source_doc="16_潮流新国风Q版美术规范",
        replace_mode="new",
        generator="openai-trendy-q-style-board-round2",
        meta={},
    )


def build_specs() -> List[asset_specs.AssetSpec]:
    return [
        _spec(
            "round2_hero_proportion_v1",
            "characters",
            "assets/generated/style_boards_trendy_q_round2/round2_hero_proportion_v1.png",
            "1024x1024",
            "transparent",
            (
                "stylized new guofeng wuxia hero, exactly 2.3 heads tall, cute but not childish, "
                "less anime, smaller eyes, shorter face, Chinese martial hero identity, green-gray traveler robe, "
                "short cape, dao sword, visible topknot, waist sash, boots, clean silhouette, steam-friendly indie game"
            ),
        ),
        _spec(
            "round2_enemy_chibi_v1",
            "characters",
            "assets/generated/style_boards_trendy_q_round2/round2_enemy_chibi_v1.png",
            "1024x1024",
            "transparent",
            (
                "stylized new guofeng wuxia enemy, exactly 2.3 heads tall, readable hostile silhouette, "
                "cute but dangerous, less anime, smaller eyes, rugged martial bandit, brown-red outfit, short blade, "
                "steam-friendly indie game, clean shape language"
            ),
        ),
        _spec(
            "round2_battle_lane_v1",
            "backgrounds",
            "assets/generated/style_boards_trendy_q_round2/round2_battle_lane_v1.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia side-scrolling battle scene, scenic jianghu travel road, "
                "clear horizontal combat lane, foreground midground background separation, "
                "bright mountain town atmosphere, cozy adventurous mood, simplified readable details, "
                "suitable for parallax scrolling game"
            ),
        ),
        _spec(
            "round2_main_hud_v1",
            "ui",
            "assets/generated/style_boards_trendy_q_round2/round2_main_hud_v1.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia game HUD, actual playable interface mockup, "
                "top-left circular portrait and resources, top-right stage progress, left loot card, "
                "right objective card, bottom center dual resource orbs and skill bar, bottom-right compact menu, "
                "light wood and brass materials, cozy adventure feeling, not concept board"
            ),
        ),
        _spec(
            "round2_inventory_cube_v1",
            "ui",
            "assets/generated/style_boards_trendy_q_round2/round2_inventory_cube_v1.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia game inventory and forge interface, actual playable UI mockup, "
                "paper doll plus grid inventory on one side, forge crafting three-column layout on the other, "
                "q-style martial arts gear icons, light wood and brass, readable dark teal panels, "
                "steam-friendly indie game interface"
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


def _write_review_md(specs: Sequence[asset_specs.AssetSpec]) -> None:
    lines = [
        "# AFK-RPG 潮流新国风 Q 版试片评审 v2",
        "",
        "## 样张清单",
        "",
    ]
    for spec in specs:
        lines.append(f"- `{spec.logical_id}`: `{spec.output_path}`")
    lines.extend(
        [
            "",
            "## 本轮目标",
            "",
            "- 压低主角与敌人的头身比例到 `2.2 - 2.5`",
            "- 减少日系感，强化中国武侠识别物",
            "- 验证横版推进式战斗场景是否仍保留旅行感",
            "- 验证主 HUD 与背包/百炼坊是否能真正转成实际游戏界面，而不是展示概念板",
        ]
    )
    REVIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_boards(
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
    parser = argparse.ArgumentParser(description="Generate AFK-RPG trendy guofeng chibi round-2 boards.")
    parser.add_argument("--model", default="gpt-image-1.5")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
    parser.add_argument("--sleep-seconds", type=float, default=12.0)
    parser.add_argument("--skip-generate", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = _parse_args(argv)
    specs = build_specs()
    _write_review_md(specs)
    if args.skip_generate:
        print(f"Wrote review scaffold to {REVIEW_PATH.relative_to(ROOT)}", flush=True)
        return 0

    api_key = openai_assets._load_api_key()
    print(
        f"Generating {len(specs)} trendy guofeng Q-style round-2 assets with {args.model} ({args.quality}).",
        flush=True,
    )
    generate_boards(specs, api_key, args.model, args.quality, args.sleep_seconds)
    asset_specs.verify_sizes(specs)
    print(f"Done. Verified {len(specs)} trendy guofeng Q-style round-2 assets.", flush=True)
    print(f"Review notes: {REVIEW_PATH.relative_to(ROOT)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
