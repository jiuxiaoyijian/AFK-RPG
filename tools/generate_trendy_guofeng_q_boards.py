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
STYLE_BOARD_ROOT = ROOT / "assets" / "generated" / "style_boards_trendy_q"
CHARACTER_DIR = STYLE_BOARD_ROOT / "characters"
BACKGROUND_DIR = STYLE_BOARD_ROOT / "backgrounds"
UI_DIR = STYLE_BOARD_ROOT / "ui"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "style_boards_trendy_q"
LOG_PATH = ROOT / "文档" / "style_board_trendy_q_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "style_board_trendy_q_review_v1.md"

BASE_NEGATIVE = (
    "grimdark, horror, realistic anatomy, baby toddler proportions, giant anime eyes, "
    "xianxia, flying swords, overly ornate costume, mobile game splash art, hypersexualized, "
    "photorealistic, gore, dark dungeon, purple fantasy UI, depressing mood, logo, watermark, text"
)

BASE_CHARACTER = (
    "stylized new guofeng wuxia character, 2.3 heads tall, youthful jianghu disciple, "
    "cute but not childish, clean silhouette, simplified layered robe, visible weapon identity, "
    "travel-ready martial hero, steam-friendly indie game style"
)

BASE_BACKGROUND = (
    "stylized new guofeng wuxia environment, scenic jianghu street or ferry town, travel simulator feeling, "
    "warm daylight, clear central combat lane, Chinese architecture simplified for game readability, cozy adventurous mood"
)

BASE_UI = (
    "stylized new guofeng game UI mockup, light wood and brass martial arts interface, readable dark teal panels, "
    "clean ornamental frame, elegant but not heavy, relaxed adventure feeling, steam-friendly indie game HUD"
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
        generator="openai-trendy-q-style-board",
        meta={},
    )


def build_specs() -> List[asset_specs.AssetSpec]:
    return [
        _spec(
            "trendy_q_character_wanderer_v1",
            "characters",
            "assets/generated/style_boards_trendy_q/characters/trendy_q_character_wanderer_v1.png",
            "1024x1024",
            "transparent",
            f"{BASE_CHARACTER}, green-gray traveler robes, short cape, dao sword, warm daylight, calm confident expression",
        ),
        _spec(
            "trendy_q_character_bloodedge_v1",
            "characters",
            "assets/generated/style_boards_trendy_q/characters/trendy_q_character_bloodedge_v1.png",
            "1024x1024",
            "transparent",
            f"{BASE_CHARACTER}, red-brown martial outfit, cracked heavy blade, sharper posture, dynamic but friendly silhouette",
        ),
        _spec(
            "trendy_q_character_thunderseal_v1",
            "characters",
            "assets/generated/style_boards_trendy_q/characters/trendy_q_character_thunderseal_v1.png",
            "1024x1024",
            "transparent",
            f"{BASE_CHARACTER}, indigo and gold costume, talisman weapon, short lightning motifs, energetic readable silhouette",
        ),
        _spec(
            "trendy_q_background_ferry_v1",
            "backgrounds",
            "assets/generated/style_boards_trendy_q/backgrounds/trendy_q_background_ferry_v1.png",
            "1280x720",
            "opaque",
            f"{BASE_BACKGROUND}, riverside ferry town, banners, boats, market stalls, mild haze, scenic travel atmosphere",
        ),
        _spec(
            "trendy_q_background_market_v1",
            "backgrounds",
            "assets/generated/style_boards_trendy_q/backgrounds/trendy_q_background_market_v1.png",
            "1280x720",
            "opaque",
            f"{BASE_BACKGROUND}, lively jianghu market street, lanterns, tea house, wood bridges, soft afternoon light",
        ),
        _spec(
            "trendy_q_background_mountainroad_v1",
            "backgrounds",
            "assets/generated/style_boards_trendy_q/backgrounds/trendy_q_background_mountainroad_v1.png",
            "1280x720",
            "opaque",
            f"{BASE_BACKGROUND}, mountain path and gate tower, pine green palette, travel road composition, bright scenic depth",
        ),
        _spec(
            "trendy_q_ui_hud_v1",
            "ui",
            "assets/generated/style_boards_trendy_q/ui/trendy_q_ui_hud_v1.png",
            "1280x720",
            "opaque",
            f"{BASE_UI}, idle action RPG main HUD, dual resource orbs, objective card, loot card, compact bottom-right menu",
        ),
        _spec(
            "trendy_q_ui_inventory_v1",
            "ui",
            "assets/generated/style_boards_trendy_q/ui/trendy_q_ui_inventory_v1.png",
            "1280x720",
            "opaque",
            f"{BASE_UI}, paper doll plus grid inventory, q-style wuxia equipment page, clean cozy adventure mood",
        ),
        _spec(
            "trendy_q_ui_cube_v1",
            "ui",
            "assets/generated/style_boards_trendy_q/ui/trendy_q_ui_cube_v1.png",
            "1280x720",
            "opaque",
            f"{BASE_UI}, martial forge crafting interface, three-column layout, recipe tabs, target item preview, readable cozy workshop mood",
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
        "# AFK-RPG 潮流新国风 Q 版试片评审 v1",
        "",
        "## 样张清单",
        "",
    ]
    for spec in specs:
        lines.append(f"- `{spec.logical_id}`: `{spec.output_path}`")
    lines.extend(
        [
            "",
            "## 当前方向",
            "",
            "- 正式候选方向：`潮流新国风武侠 + 2.2 - 2.5 头身 Q 版角色`",
            "- 核心目标：保留武侠识别度，但整体更明快、更旅行感、更适合挂机长期观看。",
            "",
            "## 评审重点",
            "",
            "- 角色是否可爱但不低幼",
            "- 场景是否像江湖旅行模拟器，而不是黑暗地牢",
            "- UI 是否清爽、轻国风、适合 Steam 独立游戏用户审美",
            "- 角色、场景、UI 是否能统一成同一套视觉语言",
            "- 是否适合 `挂机刷装 + 武学 Build + 重入江湖` 的长期玩法",
            "",
            "## 初步建议",
            "",
            "- 角色优先确认脸型、头身比例与武器剪影语言",
            "- 场景优先确认旅行感、明快度与中央战斗走廊可读性",
            "- UI 优先确认“轻国风器物感”是否足够统一，避免回到厚重黑暗武侠",
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
    parser = argparse.ArgumentParser(description="Generate AFK-RPG trendy guofeng chibi style boards.")
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
        f"Generating {len(specs)} trendy guofeng Q-style board assets with {args.model} ({args.quality}).",
        flush=True,
    )
    generate_boards(specs, api_key, args.model, args.quality, args.sleep_seconds)
    asset_specs.verify_sizes(specs)
    print(f"Done. Verified {len(specs)} trendy guofeng Q-style board assets.", flush=True)
    print(f"Review notes: {REVIEW_PATH.relative_to(ROOT)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
