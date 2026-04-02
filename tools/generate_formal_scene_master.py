#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Sequence

import generate_art_assets as asset_specs
import generate_openai_art_assets as openai_assets


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "formal_scene_masters"
LOG_PATH = ROOT / "文档" / "formal_scene_master_openai生成日志_v1.jsonl"

BASE_NEGATIVE = (
    "mirrored composition, duplicated landmark, repeated buildings, repeated bridge, repeated lantern rows, "
    "foreground collage, multiple conflicting vanishing points, top-down view, dark grim scene, logo, watermark, text, "
    "xianxia, fantasy floating islands, giant close-up props blocking center lane, ghosting, double exposure, "
    "semi-transparent overlap, duplicated foreground prop, cut-off bridge, cut-off tree canopy touching edge"
)


def build_spec(output_path: str, preset: str) -> asset_specs.AssetSpec:
    if preset == "single_native_v1":
        logical_id = "chapter1_town_road_single_native_v1"
        prompt = (
            "stylized polished new guofeng wuxia side-scrolling final combat backdrop for chapter one, "
            "one complete native horizontal battle scene, not a source plate, not a layer split concept, "
            "bright jianghu mountain lake town in warm daylight, "
            "clear open combat road and shore path across the lower middle area for character battles, "
            "integrated depth inside one image with distant mountains, lake water, bridges, lakeside inns, village houses, trees, rocks and grasses, "
            "balanced side-view composition for action gameplay, readable central battle corridor, "
            "left and right edges calm and natural without oversized cut-off landmark, "
            "foreground only low rocks, grass and gentle framing, no giant prop blocking the lane, "
            "midground bridge and waterside buildings clearly readable, "
            "clean perspective, crisp painted details, coherent scale, no stretched architecture, no distorted roofs, no warped ground plane, no blurry upscale look"
        )
    elif preset == "single_strip_v2":
        logical_id = "chapter1_single_strip_master_v2"
        prompt = (
            "stylized polished new guofeng wuxia side-scrolling final combat backdrop for chapter one, "
            "single finished panoramic scene by a bright mountain lake town, "
            "one coherent playable location, wide open combat road across the lower third, "
            "clear side-view action game lane for characters, "
            "integrated depth inside one image with distant mountains, lake water, bridges, waterside houses, trees, rocks and grass, "
            "balanced composition, readable center battle corridor, "
            "foreground details only as low rocks, grass edges and light framing, no giant close props, "
            "midground bridge, inns and lakeside buildings clearly readable, "
            "peaceful warm daylight jianghu travel atmosphere, clean perspective, crisp painted details, "
            "intended as one final scrolling battle background, not for layer splitting, not for transparent cut layers, "
            "avoid stretched architecture, avoid oversized roofs, avoid distorted ground scale, avoid blurry upscale look"
        )
    else:
        logical_id = "chapter1_master_concept_v1"
        prompt = (
            "stylized trendy new guofeng wuxia side-scrolling master background for chapter one, "
            "single continuous scenic river-town road outside an inn station, warm daylight travel atmosphere, "
            "one coherent location, side-view action game lane, center combat corridor kept open, "
            "left and right edges simple and loop-friendly, no unique giant landmark touching either edge, "
            "foreground props only near outer edge margins, with only small lanterns, branches, railings, banners or crates suitable for near layers, "
            "distant mountains, skyline and pagodas reserved for far layer, "
            "midground inns, bridge, stalls, waterline and main road clearly readable for mid layer, "
            "designed to be split into sky far mid near_back near_front layers later, "
            "no foreground object crossing the center combat corridor, no doubled props, no mirrored repetition, "
            "horizontal scrolling background with clean repeatable edge silhouettes and seam-safe left and right margins, "
            "clean perspective, tourism-like jianghu feeling, Steam-friendly indie game art"
        )
    return asset_specs.AssetSpec(
        logical_id=logical_id,
        category="backgrounds",
        wired_now=False,
        output_path=output_path,
        target_size="1536x1024",
        background_mode="opaque",
        prompt=prompt,
        negative_prompt=BASE_NEGATIVE,
        source_doc="16_潮流新国风Q版美术规范",
        replace_mode="new",
        generator="openai-formal-scene-master",
        meta={},
    )


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


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a formal chapter-one scene master.")
    parser.add_argument(
        "--output",
        default="assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_single_native_v1.png",
    )
    parser.add_argument(
        "--preset",
        choices=["parallax_master_v1", "single_strip_v2", "single_native_v1"],
        default="single_native_v1",
    )
    parser.add_argument("--model", default="gpt-image-1.5")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = _parse_args(argv)
    spec = build_spec(args.output, args.preset)
    api_key = openai_assets._load_api_key()
    payload = openai_assets._request_image(api_key, spec, args.model, args.quality)
    raw_path = _save_raw_image(spec, payload, args.model, args.quality)
    final_path = ROOT / spec.output_path
    openai_assets._center_crop_and_resize(raw_path, final_path, spec.target_size)
    _append_log(spec, payload, args.model, args.quality, raw_path)
    print(final_path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
