#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import generate_art_assets as asset_specs
import generate_openai_art_assets as openai_assets


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "ui_core_sheet"
LOG_PATH = ROOT / "文档" / "ui_core_combat_inventory_sheet_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "ui_core_combat_inventory_sheet_review_v1.md"
FFMPEG_CANDIDATES = [
    ROOT / ".vendor" / "imageio_ffmpeg" / "binaries" / "ffmpeg-macos-x86_64-v7.1",
    Path("/opt/homebrew/bin/ffmpeg"),
    Path("/usr/local/bin/ffmpeg"),
]

OUTPUT_PATH = "assets/generated/afk_rpg_formal/ui/ui_core_combat_inventory_sheet_v1.png"
MANIFEST_PATH = "assets/generated/afk_rpg_formal/ui/ui_core_combat_inventory_sheet_v1.json"

NEGATIVE_PROMPT = (
    "text, letters, numbers, labels, logo, watermark, character art, scene art, mockup screenshot, whole interface screen, "
    "perspective view, tilted panels, overlapping components, touching components, fused components, cropped components, "
    "full dark fantasy ARPG, grimdark, purple fantasy UI, heavy black-gold page-game UI, oversized wood slabs, xianxia talisman clutter, "
    "photorealistic metal, thick ornate borders, glossy mobile splash-art UI, giant shadows behind components"
)


@dataclass(frozen=True)
class SheetItem:
    name: str
    rect: tuple[int, int, int, int]
    slice: tuple[int, int, int, int] | None
    use_in_scene: str


def _sheet_items() -> list[SheetItem]:
    return [
        SheetItem("player_header_frame", (16, 16, 352, 118), (22, 22, 22, 22), "HUD"),
        SheetItem("portrait_ring_frame", (392, 16, 104, 104), None, "HUD"),
        SheetItem("stage_header_frame", (520, 16, 320, 64), (20, 18, 20, 18), "HUD"),
        SheetItem("drop_toast_frame", (864, 16, 248, 84), (18, 18, 18, 18), "HUD"),
        SheetItem("thin_divider", (1136, 20, 220, 24), None, "HUD"),
        SheetItem("objective_card_frame", (16, 156, 252, 296), (18, 18, 18, 18), "HUD"),
        SheetItem("loot_card_frame", (292, 156, 216, 296), (18, 18, 18, 18), "HUD"),
        SheetItem("combat_plate_frame", (532, 156, 600, 148), (28, 24, 28, 20), "HUD"),
        SheetItem("left_orb_shell", (1156, 156, 156, 156), None, "HUD"),
        SheetItem("right_orb_shell", (1336, 156, 156, 156), None, "HUD"),
        SheetItem("skill_slot_frame", (1186, 336, 96, 96), None, "HUD"),
        SheetItem("inventory_main_frame_9patch", (16, 476, 560, 258), (20, 20, 20, 20), "InventoryPanel"),
        SheetItem("inventory_header_bar_9patch", (600, 476, 420, 60), (18, 16, 18, 16), "InventoryPanel"),
        SheetItem("paper_doll_panel_9patch", (1044, 476, 180, 260), (18, 18, 18, 18), "InventoryPanel"),
        SheetItem("inventory_grid_panel_9patch", (1248, 476, 272, 260), (18, 18, 18, 18), "InventoryPanel"),
        SheetItem("detail_panel_9patch", (16, 758, 280, 160), (18, 18, 18, 18), "InventoryPanel"),
        SheetItem("toolbar_panel_9patch", (320, 758, 520, 72), (18, 16, 18, 16), "InventoryPanel"),
        SheetItem("inventory_cell_frame", (864, 758, 76, 76), None, "ItemCardButton"),
        SheetItem("equipment_slot_frame", (964, 758, 84, 84), None, "InventoryPanel"),
        SheetItem("section_divider", (1072, 758, 220, 52), None, "InventoryPanel"),
        SheetItem("option_dropdown_base", (16, 860, 180, 52), (16, 16, 16, 16), "InventoryPanel"),
        SheetItem("page_arrow_left", (220, 860, 64, 64), None, "InventoryPanel"),
        SheetItem("page_arrow_right", (308, 860, 64, 64), None, "InventoryPanel"),
        SheetItem("button_primary_base", (396, 860, 180, 56), (16, 16, 16, 16), "InventoryPanel"),
        SheetItem("button_secondary_base", (600, 860, 180, 56), (16, 16, 16, 16), "InventoryPanel"),
        SheetItem("button_danger_base", (804, 860, 180, 56), (16, 16, 16, 16), "InventoryPanel"),
        SheetItem("rarity_frame_strip_common_to_ancient", (1008, 848, 512, 96), None, "ItemCardButton"),
    ]


def _build_spec(output_path: str) -> asset_specs.AssetSpec:
    slot_lines = [
        "Top HUD band, left to right: player_header_frame, portrait_ring_frame, stage_header_frame, drop_toast_frame, thin_divider.",
        "HUD second row, left to right: objective_card_frame, loot_card_frame, combat_plate_frame, left_orb_shell, right_orb_shell, small skill_slot_frame beneath the orb pair.",
        "Middle inventory band, left to right: inventory_main_frame_9patch, inventory_header_bar_9patch, paper_doll_panel_9patch, inventory_grid_panel_9patch.",
        "Middle inventory lower row: detail_panel_9patch, toolbar_panel_9patch, inventory_cell_frame, equipment_slot_frame, section_divider.",
        "Bottom common band, left to right: option_dropdown_base, page_arrow_left, page_arrow_right, button_primary_base, button_secondary_base, button_danger_base, rarity_frame_strip_common_to_ancient.",
    ]
    prompt = (
        "stylized new guofeng game UI atlas sheet, one single transparent sprite atlas for a Chinese wuxia idle RPG, "
        "1536 by 1024 composition, exactly twenty-seven isolated UI components, no text on any component, no complete interface mockup, "
        "light wood and brass fantasy-free martial arts interface, clean ornamental frame, readable dark teal panel, elegant but not heavy, relaxed adventure feeling, "
        "high value polished indie game asset sheet, high brightness and medium-low saturation, warm brass accents, matte dark teal interiors, "
        "thin clean borders, travel-themed jianghu material language, no thick black-gold decoration, no page-game heaviness. "
        "Every component must sit orthographically inside its own transparent slot with at least 24px empty transparent spacing around it, no overlap, no touching, no perspective tilt. "
        "These are cuttable production parts, not concept poster elements. "
        "Components required: "
        "player header frame, portrait ring frame, stage header frame, objective card frame, loot card frame, combat plate frame, "
        "left orb shell, right orb shell, skill slot frame, drop toast frame, thin divider, "
        "inventory main frame, inventory header bar, paper doll panel, inventory grid panel, detail panel, toolbar panel, "
        "inventory cell frame, equipment slot frame, section divider, option dropdown base, left page arrow button, right page arrow button, "
        "primary button base, secondary button base, danger button base, rarity frame strip with seven mini frames for common uncommon rare epic set legendary ancient. "
        "Layout rules: %s"
    ) % " ".join(slot_lines)
    return asset_specs.AssetSpec(
        logical_id="ui_core_combat_inventory_sheet_v1",
        category="ui",
        wired_now=False,
        output_path=output_path,
        target_size="1536x1024",
        background_mode="transparent",
        prompt=prompt,
        negative_prompt=NEGATIVE_PROMPT,
        source_doc="16_潮流新国风Q版美术规范",
        replace_mode="new",
        generator="openai-ui-core-sheet",
        meta={},
    )


def _save_raw_image(spec: asset_specs.AssetSpec, payload: dict, model: str, quality: str) -> Path:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    size = openai_assets._generation_size(spec)
    raw_path = RAW_DIR / f"{spec.logical_id}__{model}__{quality}__{size}.png"
    raw_path.write_bytes(payload["__image_bytes"])
    return raw_path


def _append_log(spec: asset_specs.AssetSpec, payload: dict, model: str, quality: str, raw_path: Path, manifest_path: Path) -> None:
    entry = {
        "logical_id": spec.logical_id,
        "output_path": spec.output_path,
        "manifest_path": str(manifest_path.relative_to(ROOT)),
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


def _write_manifest(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "sheet": {
            "path": OUTPUT_PATH,
            "size": [1536, 1024],
            "padding": 16,
            "gap": 24,
            "version": 1,
        },
        "items": [
            {
                "name": item.name,
                "rect": list(item.rect),
                "slice": list(item.slice) if item.slice else None,
                "use_in_scene": item.use_in_scene,
            }
            for item in _sheet_items()
        ],
    }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _write_review(path: Path, spec: asset_specs.AssetSpec) -> None:
    lines = [
        "# AFK-RPG 核心战斗与背包 UI 单图集评审 v1",
        "",
        "## 产物",
        "",
        f"- 图集：`{spec.output_path}`",
        f"- 清单：`{MANIFEST_PATH}`",
        "",
        "## 本轮范围",
        "",
        "- 只覆盖 HUD 与背包相关基础静态件",
        "- 不包含成长中心、异闻录、推演、设置、GM 与完整交互态",
        "- 统一为一张 1536x1024 透明图集，便于后续切图与接线",
        "",
        "## 组件列表",
        "",
    ]
    for item in _sheet_items():
        lines.append(f"- `{item.name}` -> `{item.use_in_scene}` | rect=`{list(item.rect)}` | slice=`{list(item.slice) if item.slice else None}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _ffmpeg_binary() -> str:
    for candidate in FFMPEG_CANDIDATES:
        if candidate.exists():
            return str(candidate)
    ffmpeg_path = subprocess.run(
        ["which", "ffmpeg"],
        check=False,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if ffmpeg_path:
        return ffmpeg_path
    raise RuntimeError("ffmpeg not found for UI atlas transparency postprocess.")


def _make_background_transparent(path: Path) -> None:
    temp_path = path.with_name(path.stem + "__transparent.png")
    command = [
        _ffmpeg_binary(),
        "-y",
        "-i",
        str(path),
        "-vf",
        "format=rgba,colorkey=0xE3C68B:0.18:0.05",
        str(temp_path),
    ]
    subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    os.replace(temp_path, path)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a single transparent UI atlas for AFK-RPG core combat and inventory.")
    parser.add_argument("--output", default=OUTPUT_PATH)
    parser.add_argument("--manifest", default=MANIFEST_PATH)
    parser.add_argument("--model", default="gpt-image-1.5")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = _parse_args(argv)
    spec = _build_spec(args.output)
    api_key = openai_assets._load_api_key()
    payload = openai_assets._request_image(api_key, spec, args.model, args.quality)
    raw_path = _save_raw_image(spec, payload, args.model, args.quality)
    final_path = ROOT / spec.output_path
    openai_assets._center_crop_and_resize(raw_path, final_path, spec.target_size)
    _make_background_transparent(final_path)
    manifest_path = ROOT / args.manifest
    _write_manifest(manifest_path)
    _write_review(REVIEW_PATH, spec)
    _append_log(spec, payload, args.model, args.quality, raw_path, manifest_path)
    print(final_path.relative_to(ROOT))
    print(manifest_path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
