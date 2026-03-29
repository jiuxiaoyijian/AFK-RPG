#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

import generate_art_assets as asset_specs
import generate_openai_art_assets as openai_assets


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
STYLE_BOARD_ROOT = ROOT / "assets" / "generated" / "style_boards"
CHARACTER_DIR = STYLE_BOARD_ROOT / "characters"
BACKGROUND_DIR = STYLE_BOARD_ROOT / "backgrounds"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "style_boards"
LOG_PATH = ROOT / "文档" / "style_board_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "style_board_review_v1.md"

BASE_CHARACTER_PROMPT = (
    "young jianghu martial disciple, normal body proportion, black-gray layered wuxia robes, "
    "brown sash, dark hair in topknot, single-edged dao sword, stern calm expression, "
    "full-body character, no xianxia"
)

BASE_BACKGROUND_PROMPT = (
    "jianghu market town or ferry crossing or black-market depot, gate tower, old wood, cloth banners, "
    "lanterns, iron fixtures, readable middle ground, clear central combat lane, no UI, no text"
)

BASE_NEGATIVE = (
    asset_specs.NEGATIVE_PROMPT
    + ", chibi, anime big head, super deformed, exaggerated cute proportions"
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
        source_doc="武侠美术风格试片方案",
        replace_mode="new",
        generator="openai-style-board",
        meta={},
    )


def build_specs() -> List[asset_specs.AssetSpec]:
    return [
        _spec(
            "styleA_character_v1",
            "characters",
            "assets/generated/style_boards/characters/styleA_character_v1.png",
            "1024x1024",
            "transparent",
            (
                f"{asset_specs.GLOBAL_PROMPT}, {BASE_CHARACTER_PROMPT}, "
                "new guofeng wuxia, semi-realistic, dark jianghu, layered black-gray robe, "
                "old wood and iron mood, copper accents, restrained palette, readable silhouette, "
                "grounded martial arts, dangerous but elegant"
            ),
        ),
        _spec(
            "styleA_background_v1",
            "backgrounds",
            "assets/generated/style_boards/backgrounds/styleA_background_v1.png",
            "1280x720",
            "opaque",
            (
                f"{asset_specs.GLOBAL_PROMPT}, {BASE_BACKGROUND_PROMPT}, "
                "new guofeng wuxia, semi-realistic, dark jianghu, old wood and iron, copper accents, "
                "lantern glow, restrained gray-brown palette, strong midground readability, combat-safe center"
            ),
        ),
        _spec(
            "styleB_character_v1",
            "characters",
            "assets/generated/style_boards/characters/styleB_character_v1.png",
            "1024x1024",
            "transparent",
            "expressive ink wash wuxia, painterly brushwork, atmospheric Chinese martial arts, "
            "textured strokes, poetic but dangerous jianghu, dramatic silhouette, "
            f"{BASE_CHARACTER_PROMPT}",
        ),
        _spec(
            "styleB_background_v1",
            "backgrounds",
            "assets/generated/style_boards/backgrounds/styleB_background_v1.png",
            "1280x720",
            "opaque",
            "expressive ink wash wuxia environment, painterly brushwork, atmospheric Chinese martial town, "
            "textured strokes, poetic but dangerous jianghu, soft depth, controlled negative space, "
            f"{BASE_BACKGROUND_PROMPT}",
        ),
        _spec(
            "styleC_character_v1",
            "characters",
            "assets/generated/style_boards/characters/styleC_character_v1.png",
            "1024x1024",
            "transparent",
            "stylized new guofeng wuxia, youthful sharp design, modern Chinese fashion influence, "
            "clean silhouette, premium key art look, readable costume layering, cool restrained colors, "
            f"{BASE_CHARACTER_PROMPT}",
        ),
        _spec(
            "styleC_background_v1",
            "backgrounds",
            "assets/generated/style_boards/backgrounds/styleC_background_v1.png",
            "1280x720",
            "opaque",
            "stylized new guofeng wuxia environment, youthful premium key art mood, sharper edges, "
            "cleaner palette, modern composition sense, readable combat lane, "
            f"{BASE_BACKGROUND_PROMPT}",
        ),
    ]


def _save_raw_image(spec: asset_specs.AssetSpec, payload: Dict, model: str, quality: str) -> Path:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    size = openai_assets._generation_size(spec)
    raw_path = RAW_DIR / f"{spec.logical_id}__{model}__{quality}__{size}.png"
    raw_path.write_bytes(payload["__image_bytes"])
    return raw_path


def _append_log(spec: asset_specs.AssetSpec, payload: Dict, model: str, quality: str, raw_path: Path) -> None:
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
        "# AFK-RPG 武侠美术风格试片评审 v1",
        "",
        "## 样张清单",
        "",
    ]
    for spec in specs:
        lines.append(f"- `{spec.logical_id}`: `{spec.output_path}`")
    lines.extend(
        [
            "",
            "## 简短结论",
            "",
            "- 主推荐方向：`A 新国风暗黑武侠`。它最适合挂机刷宝 ARPG 的长期观看、强度成长和江湖危险感。",
            "- 次级吸收方向：`B 写意厚涂武侠` 适合章节插画、结果卡、宣传图，不建议作为全局运行态主风格。",
            "- 有价值但不建议全局采用：`C 潮流新国风武侠` 适合吸收其角色年轻化与服装利落感，但如果全局铺开，容易偏海报风而削弱江湖旧感。",
            "",
            "## 最终建议的风格定义 v1",
            "",
            "- 主风格：`半写实新国风暗黑武侠`",
            "- 角色：正常比例，年轻、冷峻、利落，不二头身，不仙侠。",
            "- 场景：旧木、铁件、布幔、灯火、门楼、渡口，中央战斗区域保持可读。",
            "- 色彩：低饱和灰褐与墨黑为底，铜金、朱红、冷青做点缀。",
            "- 用途分层：运行态用 A，章节插图和结果卡可吸收 B，角色造型年轻化吸收 C。",
            "",
            "## 评审标准",
            "",
            "- 是否适合挂机刷宝 ARPG",
            "- 是否有武侠感",
            "- 是否年轻化",
            "- 是否适合批量生产",
            "- 是否适合传承、秘录、秘境、重入江湖这些核心系统",
        ]
    )
    REVIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_style_boards(
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
    parser = argparse.ArgumentParser(description="Generate AFK-RPG style board comparison images.")
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
        f"Generating {len(specs)} style-board assets with {args.model} ({args.quality}).",
        flush=True,
    )
    generate_style_boards(specs, api_key, args.model, args.quality, args.sleep_seconds)
    asset_specs.verify_sizes(specs)
    print(f"Done. Verified {len(specs)} generated style-board assets.", flush=True)
    print(f"Review notes: {REVIEW_PATH.relative_to(ROOT)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
