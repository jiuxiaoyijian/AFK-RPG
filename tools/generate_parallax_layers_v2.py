#!/usr/bin/env python3
"""
Per-layer parallax background generator for AFK-RPG.

Generates each of the 5 parallax layers (sky/far/mid/near_back/near_front)
independently via the OpenAI Images API, then post-processes for loop-safe
horizontal tiling. Cross-platform (uses Pillow, no macOS sips dependency).

Usage:
    python generate_parallax_layers_v2.py --scene chapter1_town_road --version v2
    python generate_parallax_layers_v2.py --scene chapter2_shrine_fields --version v2
    python generate_parallax_layers_v2.py --scene chapter1_town_road --version v2 --layers mid near_front
"""
from __future__ import annotations

import argparse
import base64
import getpass
import http.client
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

try:
    from PIL import Image
except ImportError:
    sys.exit(
        "Pillow is required. Install with:\n"
        "  pip install Pillow>=10.0\n"
    )

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "assets" / "generated" / "afk_rpg_formal" / "backgrounds"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "parallax_layers_v2"
LOG_PATH = ROOT / "文档" / "parallax_layers_v2_openai生成日志.jsonl"
API_URL = "https://api.openai.com/v1/images/generations"

TARGET_WIDTH = 3072
TARGET_HEIGHT = 720
SEAM_BLEND_PX = 128

LAYER_IDS = ["sky", "far", "mid", "near_back", "near_front"]

STYLE_BASE = (
    "stylized trendy new guofeng wuxia, "
    "2D side-scrolling game background layer, "
    "warm daylight, cozy jianghu travel atmosphere, "
    "high-quality indie game art, Steam-friendly, "
    "clean readable composition"
)

STYLE_NEGATIVE = (
    "grimdark, horror, realistic anatomy, xianxia, flying swords, "
    "dark dungeon, photorealistic, text, watermark, logo, UI elements, "
    "multiple conflicting vanishing points, top-down view, "
    "semi-transparent ghosting, double exposure"
)


SCENE_DEFS: Dict[str, Dict] = {
    "chapter1_town_road": {
        "display_name": "桃溪外渡 · 驿路",
        "scene_description": "a scenic river-town road outside an inn station, with distant mountains, a small bridge over a stream, peach blossoms, and warm afternoon light",
        "palette": "warm amber, peach blossom pink, misty blue-gray mountains, bamboo green, pale sky blue, soft gold sunlight",
        "sky": {
            "prompt": (
                "seamless horizontally tileable sky background layer for a 2D side-scrolling game, "
                "wide panoramic Chinese landscape sky, soft warm afternoon light, "
                "gentle clouds drifting, distant mountain silhouettes at bottom edge, "
                "gradient from pale blue top to warm golden horizon, "
                "left and right edges blend seamlessly for horizontal looping, "
                "no ground objects, no buildings, no trees, only sky and distant atmosphere"
            ),
            "background": "opaque",
        },
        "far": {
            "prompt": (
                "seamless horizontally tileable far background layer for a 2D side-scrolling game, "
                "distant Chinese mountain range silhouettes, faint pagoda outlines, "
                "misty river valley, very low detail, atmospheric perspective, "
                "pale blue-gray tones, mountains occupy lower 40 percent of image, "
                "upper area is transparent or very faded, "
                "left and right edges blend seamlessly for horizontal looping, "
                "no foreground objects, no trees, no buildings up close"
            ),
            "background": "transparent",
        },
        "mid": {
            "prompt": (
                "seamless horizontally tileable midground layer for a 2D side-scrolling game, "
                "Chinese wuxia river-town scene, small inn buildings, wooden bridge, "
                "stone road path, peach blossom trees at medium distance, "
                "market stalls with fabric awnings, lanterns hanging, "
                "center combat corridor kept clear and open for gameplay, "
                "buildings and structures on left and right thirds, "
                "warm afternoon sunlight, readable architectural silhouettes, "
                "left and right edges blend seamlessly for horizontal looping, "
                "transparent sky area above the rooflines"
            ),
            "background": "transparent",
        },
        "near_back": {
            "prompt": (
                "seamless horizontally tileable near-background layer for a 2D side-scrolling game, "
                "sparse foreground decorative elements on transparent background, "
                "wooden fence posts, stone lanterns, bamboo stalks, wine barrels, "
                "elements only at left and right edges of frame, "
                "center area completely empty and transparent for gameplay, "
                "warm-toned wood and stone materials, Chinese wuxia inn courtyard props, "
                "left and right edges blend seamlessly for horizontal looping"
            ),
            "background": "transparent",
        },
        "near_front": {
            "prompt": (
                "seamless horizontally tileable foreground layer for a 2D side-scrolling game, "
                "very sparse closest foreground elements on transparent background, "
                "grass tufts at bottom edge, fallen peach petals, small wildflowers, "
                "occasional bamboo leaf tips hanging from top corners, "
                "elements only at extreme edges, most of frame is transparent, "
                "warm afternoon light catching the grass blades, "
                "left and right edges blend seamlessly for horizontal looping"
            ),
            "background": "transparent",
        },
    },
    "chapter2_shrine_fields": {
        "display_name": "祠下灵田 · 古祠",
        "scene_description": "ancient shrine grounds with spirit herb fields, stone pathways, old wooden shrine buildings, mystical fog, and green-tinted twilight atmosphere",
        "palette": "moss green, shrine wood brown, mist gray, spirit herb cyan, old copper, twilight indigo",
        "sky": {
            "prompt": (
                "seamless horizontally tileable sky background layer for a 2D side-scrolling game, "
                "mystical Chinese twilight sky, green-tinted atmosphere, "
                "low hanging mist and clouds, faint moon or sun glow through haze, "
                "gradient from deep indigo top to misty green-gray horizon, "
                "left and right edges blend seamlessly for horizontal looping, "
                "no ground objects, no buildings, only sky and atmospheric mist"
            ),
            "background": "opaque",
        },
        "far": {
            "prompt": (
                "seamless horizontally tileable far background layer for a 2D side-scrolling game, "
                "distant ancient Chinese mountain temple silhouettes, "
                "terraced herb fields on hillside, faint shrine gate outlines, "
                "heavy atmospheric mist, green-gray tones, very low detail, "
                "mountains and temples occupy lower 40 percent of image, "
                "left and right edges blend seamlessly for horizontal looping, "
                "no foreground objects, no close-up details"
            ),
            "background": "transparent",
        },
        "mid": {
            "prompt": (
                "seamless horizontally tileable midground layer for a 2D side-scrolling game, "
                "ancient Chinese shrine courtyard scene, weathered wooden shrine buildings, "
                "stone pathway with moss, herb garden plots with glowing spirit herbs, "
                "old stone pillars and torii-like shrine gates, "
                "center combat corridor kept clear and open for gameplay, "
                "buildings and gardens on left and right thirds, "
                "mystical green-tinted twilight lighting, readable silhouettes, "
                "left and right edges blend seamlessly for horizontal looping, "
                "transparent sky area above structures"
            ),
            "background": "transparent",
        },
        "near_back": {
            "prompt": (
                "seamless horizontally tileable near-background layer for a 2D side-scrolling game, "
                "sparse foreground decorative elements on transparent background, "
                "old stone shrine lanterns, moss-covered rocks, herb baskets, "
                "wooden shrine fence posts, hanging prayer charms, "
                "elements only at left and right edges of frame, "
                "center area completely empty and transparent for gameplay, "
                "green-tinted mystical atmosphere, ancient weathered materials, "
                "left and right edges blend seamlessly for horizontal looping"
            ),
            "background": "transparent",
        },
        "near_front": {
            "prompt": (
                "seamless horizontally tileable foreground layer for a 2D side-scrolling game, "
                "very sparse closest foreground elements on transparent background, "
                "glowing spirit herb sprouts at bottom edge, moss patches, "
                "occasional hanging vine or branch tip from top corners, "
                "elements only at extreme edges, most of frame is transparent, "
                "mystical green glow on plant elements, "
                "left and right edges blend seamlessly for horizontal looping"
            ),
            "background": "transparent",
        },
    },
}


def load_api_key() -> str:
    env_value = os.environ.get("OPENAI_API_KEY", "").strip()
    if env_value:
        return env_value
    prompt_value = getpass.getpass("Enter OPENAI_API_KEY: ").strip()
    if not prompt_value:
        raise SystemExit("OPENAI_API_KEY is required.")
    return prompt_value


def build_full_prompt(scene_id: str, layer_id: str) -> str:
    scene = SCENE_DEFS[scene_id]
    layer = scene[layer_id]
    parts = [
        STYLE_BASE,
        f"Color palette: {scene['palette']}.",
        layer["prompt"],
        f"Negative guidance: {STYLE_NEGATIVE}",
    ]
    return " ".join(parts)


def request_image(api_key: str, prompt: str, background: str, model: str, quality: str) -> dict:
    body = {
        "model": model,
        "prompt": prompt,
        "size": "1536x1024",
        "quality": quality,
        "background": background,
        "output_format": "png",
    }
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=600) as response:
                payload = json.loads(response.read().decode("utf-8"))
            break
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"API error: {exc.code} {detail}")
        except (urllib.error.URLError, http.client.IncompleteRead, TimeoutError) as exc:
            last_error = exc
            print(f"  Retry {attempt + 1}/3 after network error: {exc}")
            time.sleep(3.0)
    else:
        raise RuntimeError(f"Network error after 3 retries: {last_error}")

    data = payload.get("data") or []
    if not data:
        raise RuntimeError("API returned no image data")
    b64_json = data[0].get("b64_json")
    if not b64_json:
        raise RuntimeError("API returned no b64_json")
    payload["__image_bytes"] = base64.b64decode(b64_json)
    return payload


def center_crop_and_resize(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    src_w, src_h = img.size
    target_ratio = target_w / target_h
    src_ratio = src_w / src_h

    if abs(src_ratio - target_ratio) > 0.01:
        if src_ratio > target_ratio:
            crop_w = int(src_h * target_ratio)
            crop_h = src_h
        else:
            crop_w = src_w
            crop_h = int(src_w / target_ratio)
        left = (src_w - crop_w) // 2
        top = (src_h - crop_h) // 2
        img = img.crop((left, top, left + crop_w, top + crop_h))

    if img.size != (target_w, target_h):
        img = img.resize((target_w, target_h), Image.LANCZOS)
    return img


def apply_loop_safe_blend(img: Image.Image, blend_px: int) -> Image.Image:
    """Cosine-weighted blend of left and right edges for seamless horizontal tiling."""
    if blend_px <= 0:
        return img
    width, height = img.size
    if blend_px * 2 >= width:
        blend_px = width // 4

    pixels = img.load()
    bands = len(img.getbands())

    for y in range(height):
        for x in range(blend_px):
            t = 0.5 * (1.0 - math.cos(math.pi * x / blend_px))
            right_x = width - blend_px + x
            left_px = pixels[x, y]
            right_px = pixels[right_x, y]
            blended = tuple(
                int(left_px[c] * (1.0 - t) + right_px[c] * t + 0.5)
                for c in range(bands)
            )
            mirror_blended = tuple(
                int(right_px[c] * t + left_px[c] * (1.0 - t) + 0.5)
                for c in range(bands)
            )
            pixels[x, y] = blended
            pixels[right_x, y] = mirror_blended

    return img


def output_filename(scene_id: str, layer_id: str, version: str) -> str:
    return f"{scene_id}__{layer_id}_{version}.png"


def generate_layer(
    api_key: str,
    scene_id: str,
    layer_id: str,
    version: str,
    model: str,
    quality: str,
) -> Path:
    scene = SCENE_DEFS[scene_id]
    layer_def = scene[layer_id]
    prompt = build_full_prompt(scene_id, layer_id)
    background = layer_def.get("background", "transparent")

    print(f"  Generating {layer_id} ({background})...", flush=True)
    payload = request_image(api_key, prompt, background, model, quality)

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    raw_path = RAW_DIR / f"{scene_id}__{layer_id}_{version}__raw.png"
    raw_path.write_bytes(payload["__image_bytes"])

    img = Image.open(raw_path)
    if background == "transparent" and img.mode != "RGBA":
        img = img.convert("RGBA")
    elif background == "opaque" and img.mode != "RGBA":
        img = img.convert("RGBA")

    img = center_crop_and_resize(img, TARGET_WIDTH, TARGET_HEIGHT)
    img = apply_loop_safe_blend(img, SEAM_BLEND_PX)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    final_path = OUTPUT_DIR / output_filename(scene_id, layer_id, version)
    img.save(final_path, "PNG")

    append_log(scene_id, layer_id, version, model, quality, prompt, payload, raw_path, final_path)

    print(f"  Saved: {final_path.relative_to(ROOT)}", flush=True)
    return final_path


def append_log(
    scene_id: str,
    layer_id: str,
    version: str,
    model: str,
    quality: str,
    prompt: str,
    payload: dict,
    raw_path: Path,
    final_path: Path,
) -> None:
    entry = {
        "scene_id": scene_id,
        "layer_id": layer_id,
        "version": version,
        "model": model,
        "quality": quality,
        "target_size": f"{TARGET_WIDTH}x{TARGET_HEIGHT}",
        "raw_path": str(raw_path.relative_to(ROOT)),
        "final_path": str(final_path.relative_to(ROOT)),
        "prompt": prompt,
        "revised_prompt": (payload.get("data") or [{}])[0].get("revised_prompt"),
        "created": payload.get("created"),
    }
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def generate_scene(
    api_key: str,
    scene_id: str,
    version: str,
    model: str,
    quality: str,
    layers: List[str],
    sleep_seconds: float,
) -> List[Path]:
    print(f"\n=== Generating scene: {scene_id} ({SCENE_DEFS[scene_id]['display_name']}) ===\n", flush=True)
    generated: List[Path] = []
    for i, layer_id in enumerate(layers):
        path = generate_layer(api_key, scene_id, layer_id, version, model, quality)
        generated.append(path)
        if sleep_seconds > 0 and i < len(layers) - 1:
            print(f"  Waiting {sleep_seconds}s before next layer...", flush=True)
            time.sleep(sleep_seconds)
    return generated


def update_scene_defs_json(scene_id: str, version: str, layers: List[str]) -> None:
    defs_path = ROOT / "data" / "backgrounds" / "parallax_scene_defs.json"
    if not defs_path.exists():
        print(f"  Warning: {defs_path} not found, skipping JSON update.", flush=True)
        return

    with defs_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    scene_key_map = {
        "chapter1_town_road": "chapter1_town_road",
        "chapter2_shrine_fields": "chapter2_shrine_fields",
    }
    base_scene_id = scene_key_map.get(scene_id, scene_id)

    target_entry = None
    for entry in data.get("scene_defs", []):
        if entry.get("base_scene_id") == base_scene_id:
            target_entry = entry
            break

    if target_entry is None:
        new_id = f"{scene_id}_{version}"
        target_entry = {
            "id": new_id,
            "base_scene_id": base_scene_id,
            "repeat_size": [TARGET_WIDTH, TARGET_HEIGHT],
            "ground_y": 540,
            "player_spawn_y": 500,
            "lane_clear_region": [0.22, 0.54, 0.46, 0.24],
            "scroll_speed_multipliers": {
                "sky": 0.06, "far": 0.16, "mid": 0.42,
                "near_back": 0.72, "near_front": 1.0,
            },
            "parallax_distances": {
                "sky": 8.0, "far": 14.0, "mid": 22.0,
                "near_back": 30.0, "near_front": 36.0,
            },
            "anchor_bias": {
                "sky": 0.0, "far": -16.0, "mid": -10.0,
                "near_back": -4.0, "near_front": 0.0,
            },
            "layer_paths": {},
        }
        data["scene_defs"].append(target_entry)

    layer_paths = target_entry.setdefault("layer_paths", {})
    for layer_id in layers:
        filename = output_filename(scene_id, layer_id, version)
        layer_paths[layer_id] = f"res://assets/generated/afk_rpg_formal/backgrounds/{filename}"

    target_entry["repeat_size"] = [TARGET_WIDTH, TARGET_HEIGHT]

    with defs_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"  Updated {defs_path.relative_to(ROOT)}", flush=True)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate per-layer parallax backgrounds via OpenAI Images API."
    )
    parser.add_argument(
        "--scene",
        required=True,
        choices=list(SCENE_DEFS.keys()),
        help="Scene profile to generate.",
    )
    parser.add_argument("--version", default="v2", help="Version tag for output files.")
    parser.add_argument(
        "--layers",
        nargs="+",
        default=LAYER_IDS,
        choices=LAYER_IDS,
        help="Which layers to generate (default: all 5).",
    )
    parser.add_argument("--model", default="gpt-image-1", help="OpenAI image model.")
    parser.add_argument(
        "--quality",
        choices=["low", "medium", "high"],
        default="high",
        help="Generation quality.",
    )
    parser.add_argument(
        "--sleep-seconds",
        type=float,
        default=8.0,
        help="Wait between layer requests to avoid rate limits.",
    )
    parser.add_argument(
        "--skip-json-update",
        action="store_true",
        help="Skip auto-updating parallax_scene_defs.json.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    api_key = load_api_key()

    generated = generate_scene(
        api_key=api_key,
        scene_id=args.scene,
        version=args.version,
        model=args.model,
        quality=args.quality,
        layers=args.layers,
        sleep_seconds=args.sleep_seconds,
    )

    if not args.skip_json_update:
        update_scene_defs_json(args.scene, args.version, args.layers)

    print(f"\nDone. Generated {len(generated)} layer images.")
    for p in generated:
        print(f"  {p.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
