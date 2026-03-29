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
OUTPUT_ROOT = ROOT / "assets" / "generated" / "formal_replacement_samples"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "formal_replacement_samples"
LOG_PATH = ROOT / "文档" / "formal_replacement_samples_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "formal_replacement_samples_review_v1.md"

BASE_NEGATIVE = (
    "grimdark, horror, realistic anatomy, giant anime eyes, baby toddler proportions, xianxia, "
    "flying swords, photorealistic, gore, dark dungeon, purple fantasy UI, logo, watermark, text, "
    "mobile game splash art, overdecorated UI, hypersexualized"
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
        generator="openai-formal-replacement-samples",
        meta={},
    )


def build_specs() -> List[asset_specs.AssetSpec]:
    return [
        _spec(
            "hero_formal_stand_v1",
            "characters",
            "assets/generated/formal_replacement_samples/characters/hero_formal_stand_v1.png",
            "1024x1024",
            "transparent",
            (
                "stylized new guofeng wuxia hero for final game replacement sample, exactly 2.3 heads tall, "
                "cute but not childish, less anime, calm confident traveler swordsman, green-gray layered robe, "
                "short cape, visible topknot, waist sash, boots, one-handed dao, clear Steam-friendly indie silhouette, "
                "front three-quarter standing pose, production-ready character asset"
            ),
        ),
        _spec(
            "hero_formal_action_v1",
            "characters",
            "assets/generated/formal_replacement_samples/characters/hero_formal_action_v1.png",
            "1024x1024",
            "transparent",
            (
                "stylized new guofeng wuxia hero for final game replacement sample, exactly 2.3 heads tall, "
                "same costume family as formal hero, energetic rightward running attack pose for side-scrolling action, "
                "traveling martial artist, readable limbs, short cape trailing, dao slash motion, clean silhouette, "
                "production-ready action concept"
            ),
        ),
        _spec(
            "enemy_bandit_formal_v1",
            "enemies",
            "assets/generated/formal_replacement_samples/characters/enemy_bandit_formal_v1.png",
            "1024x1024",
            "transparent",
            (
                "stylized new guofeng wuxia enemy for final game replacement sample, exactly 2.3 heads tall, "
                "hostile bandit silhouette, red-brown traveler armor, short blade, rough cloth and leather, "
                "cute but dangerous, not childish, same world as the formal hero, production-ready enemy asset"
            ),
        ),
        _spec(
            "boss_silver_hook_formal_v1",
            "bosses",
            "assets/generated/formal_replacement_samples/characters/boss_silver_hook_formal_v1.png",
            "1024x1024",
            "transparent",
            (
                "stylized new guofeng wuxia boss for final game replacement sample, exactly 2.5 heads tall, "
                "silver hook elder inspired martial villain, compact chibi proportion but imposing presence, "
                "hook weapon, layered dark-blue and old-gold robe, stern expression, readable boss silhouette, "
                "same world as hero and enemy, production-ready boss asset"
            ),
        ),
        _spec(
            "chapter1_travel_road_formal_far_v1",
            "backgrounds",
            "assets/generated/formal_replacement_samples/backgrounds/chapter1_travel_road_formal__far.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia side-scrolling chapter one battle scene, far background layer only, "
                "bright travel road atmosphere, distant mountains, distant rooftops, thin mist, warm daylight, "
                "highly simplified far silhouettes, no midground buildings, no foreground props"
            ),
        ),
        _spec(
            "chapter1_travel_road_formal_mid_v1",
            "backgrounds",
            "assets/generated/formal_replacement_samples/backgrounds/chapter1_travel_road_formal__mid.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia side-scrolling chapter one battle scene, midground playable layer only, "
                "travel road through a scenic jianghu town, readable road and inn facades, clear central combat lane, "
                "light tourism-like atmosphere, cozy adventurous mood, no foreground occluders"
            ),
        ),
        _spec(
            "chapter1_travel_road_formal_near_v1",
            "backgrounds",
            "assets/generated/formal_replacement_samples/backgrounds/chapter1_travel_road_formal__near.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia side-scrolling chapter one battle scene, foreground layer only, "
                "close camera props for parallax, lanterns, banners, rails, branch edges, stall corners, "
                "minimal composition, readable gaps, no full scene, no distant mountains"
            ),
        ),
        _spec(
            "main_hud_formal_v1",
            "ui",
            "assets/generated/formal_replacement_samples/ui/main_hud_formal_v1.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia side-scrolling game HUD for final replacement sample, "
                "top-left circular portrait and compact role info, top-right stage progress, right-side mission card, "
                "left-side compact loot feed, bottom-center clean dual resource orbs and skill bar, bottom-right compact menu, "
                "light brass and wood accents, low clutter, actually playable layout, production-ready"
            ),
        ),
        _spec(
            "inventory_formal_v1",
            "ui",
            "assets/generated/formal_replacement_samples/ui/inventory_formal_v1.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia inventory screen for final replacement sample, "
                "paper doll with nine equipment slots on the left, 10 by 4 grid inventory in the center, "
                "detail and comparison panel on the right, compact toolbar at the bottom, "
                "q-style martial gear icons, readable actual game UI, light travel-themed Chinese design, production-ready"
            ),
        ),
        _spec(
            "cube_formal_v1",
            "ui",
            "assets/generated/formal_replacement_samples/ui/cube_formal_v1.png",
            "1280x720",
            "opaque",
            (
                "stylized new guofeng wuxia forge interface for final replacement sample, "
                "three-column forge layout, left recipe tabs and candidate list, center target details and options, "
                "right materials and result preview, same q-style martial gear language as inventory, "
                "clean practical game UI, production-ready"
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
        "# AFK-RPG 正式替换级样张评审 v1",
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
            "- 角色不再做纯风格探索，而是收口到可替换的主角 / 普通敌人 / Boss 体系",
            "- 第一章背景按正式量产逻辑直接给出 `far / mid / near` 三层协同样张",
            "- 主 HUD、背包、百炼坊各给一张更接近可直接实装的界面样张",
            "",
            "## 评审标准",
            "",
            "- 主角与敌我角色是否共享同一世界观和比例语言",
            "- Boss 是否比普通敌人更有压迫感，但仍保持 Q 版体系统一",
            "- 第一章三层背景是否像同一地点，而不是三张随机图",
            "- HUD 是否真正为战斗让出舞台",
            "- 背包与百炼坊是否更像真实运行界面，而不是展示海报",
        ]
    )
    REVIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_samples(
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
    parser = argparse.ArgumentParser(description="Generate AFK-RPG formal replacement sample set.")
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
        f"Generating {len(specs)} formal replacement samples with {args.model} ({args.quality}).",
        flush=True,
    )
    generate_samples(specs, api_key, args.model, args.quality, args.sleep_seconds)
    asset_specs.verify_sizes(specs)
    print(f"Done. Verified {len(specs)} formal replacement samples.", flush=True)
    print(f"Review notes: {REVIEW_PATH.relative_to(ROOT)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
