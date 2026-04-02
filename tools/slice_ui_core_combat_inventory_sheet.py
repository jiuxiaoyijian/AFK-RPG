#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Sequence


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
SHEET_PATH = ROOT / "assets" / "generated" / "afk_rpg_formal" / "ui" / "ui_core_combat_inventory_sheet_v1.png"
MANIFEST_PATH = ROOT / "assets" / "generated" / "afk_rpg_formal" / "ui" / "ui_core_combat_inventory_sheet_v1.json"
FFMPEG_CANDIDATES = [
    ROOT / ".vendor" / "imageio_ffmpeg" / "binaries" / "ffmpeg-macos-x86_64-v7.1",
    Path("/opt/homebrew/bin/ffmpeg"),
    Path("/usr/local/bin/ffmpeg"),
]

OUTPUT_MAP = {
    "player_header_frame": ["assets/generated/afk_rpg_formal/ui/hud/player_header_frame.png"],
    "portrait_ring_frame": ["assets/generated/afk_rpg_formal/ui/hud/portrait_ring_frame.png"],
    "stage_header_frame": ["assets/generated/afk_rpg_formal/ui/hud/stage_header_frame.png"],
    "objective_card_frame": ["assets/generated/afk_rpg_formal/ui/hud/objective_card_frame.png"],
    "loot_card_frame": ["assets/generated/afk_rpg_formal/ui/hud/loot_card_frame.png"],
    "combat_plate_frame": ["assets/generated/afk_rpg_formal/ui/hud/combat_plate_frame.png"],
    "left_orb_shell": ["assets/generated/afk_rpg_formal/ui/hud/left_orb_shell.png"],
    "right_orb_shell": ["assets/generated/afk_rpg_formal/ui/hud/right_orb_shell.png"],
    "skill_slot_frame": [
        "assets/generated/afk_rpg_formal/ui/hud/skill_slot_frame.png",
        "assets/generated/afk_rpg_formal/ui/skill_slot_base.png",
    ],
    "drop_toast_frame": ["assets/generated/afk_rpg_formal/ui/hud/drop_toast_frame.png"],
    "thin_divider": ["assets/generated/afk_rpg_formal/ui/hud/thin_divider.png"],
    "inventory_main_frame_9patch": ["assets/generated/afk_rpg_formal/ui/inventory/inventory_main_frame_9patch.png"],
    "inventory_header_bar_9patch": ["assets/generated/afk_rpg_formal/ui/inventory/inventory_header_bar_9patch.png"],
    "paper_doll_panel_9patch": ["assets/generated/afk_rpg_formal/ui/inventory/paper_doll_panel_9patch.png"],
    "inventory_grid_panel_9patch": ["assets/generated/afk_rpg_formal/ui/inventory/inventory_grid_panel_9patch.png"],
    "detail_panel_9patch": ["assets/generated/afk_rpg_formal/ui/inventory/detail_panel_9patch.png"],
    "toolbar_panel_9patch": ["assets/generated/afk_rpg_formal/ui/inventory/toolbar_panel_9patch.png"],
    "inventory_cell_frame": ["assets/generated/afk_rpg_formal/ui/inventory/inventory_cell_frame.png"],
    "equipment_slot_frame": [
        "assets/generated/afk_rpg_formal/ui/inventory/equipment_slot_frame.png",
        "assets/generated/afk_rpg_formal/ui/equipment_slot_base.png",
    ],
    "section_divider": ["assets/generated/afk_rpg_formal/ui/inventory/section_divider.png"],
    "option_dropdown_base": ["assets/generated/afk_rpg_formal/ui/controls/option_dropdown_base.png"],
    "page_arrow_left": ["assets/generated/afk_rpg_formal/ui/controls/page_arrow_left.png"],
    "page_arrow_right": ["assets/generated/afk_rpg_formal/ui/controls/page_arrow_right.png"],
    "button_primary_base": ["assets/generated/afk_rpg_formal/ui/controls/button_primary_base.png"],
    "button_secondary_base": ["assets/generated/afk_rpg_formal/ui/controls/button_secondary_base.png"],
    "button_danger_base": ["assets/generated/afk_rpg_formal/ui/controls/button_danger_base.png"],
    "rarity_frame_strip_common_to_ancient": ["assets/generated/afk_rpg_formal/ui/controls/rarity_frame_strip_common_to_ancient.png"],
}


def _ffmpeg_binary() -> str:
    for candidate in FFMPEG_CANDIDATES:
        if candidate.exists():
            return str(candidate)
    result = subprocess.run(["which", "ffmpeg"], check=False, capture_output=True, text=True)
    if result.stdout.strip():
        return result.stdout.strip()
    raise RuntimeError("ffmpeg not found.")


def _load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def _crop(ffmpeg_bin: str, source: Path, rect: list[int], destination: Path) -> None:
    x, y, width, height = rect
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            ffmpeg_bin,
            "-y",
            "-i",
            str(source),
            "-vf",
            f"crop={width}:{height}:{x}:{y}",
            "-frames:v",
            "1",
            "-update",
            "1",
            str(destination),
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main(argv: Sequence[str]) -> int:
    _ = argv
    ffmpeg_bin = _ffmpeg_binary()
    manifest = _load_manifest()
    items = manifest.get("items", [])
    for item in items:
        name = str(item.get("name", ""))
        destinations = OUTPUT_MAP.get(name, [])
        if not destinations:
            continue
        rect = item.get("rect", [])
        for destination in destinations:
            _crop(ffmpeg_bin, SHEET_PATH, rect, ROOT / destination)
            print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
