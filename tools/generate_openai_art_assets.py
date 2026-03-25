#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import getpass
import http.client
import json
import math
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

import generate_art_assets as asset_specs


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
API_URL = "https://api.openai.com/v1/images/generations"
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw"
LOG_PATH = ROOT / "文档" / "美术资源_openai生成日志_v1.jsonl"


def _prompt_wrapper(spec: asset_specs.AssetSpec) -> str:
    category = spec.category
    if category == "backgrounds":
        prefix = (
            "Create a polished 2D action-RPG combat background for a Chinese wuxia idle game. "
            "Wide landscape composition, readable middle ground, central combat lane kept visually open, "
            "foreground-midground-background separation, no UI, no text, no logo."
        )
    elif category in {"bosses", "characters", "portraits", "enemies"}:
        prefix = (
            "Create a polished transparent-background character game asset for a Chinese wuxia action RPG. "
            "Single subject only, centered composition, readable silhouette, no text, no logo, no cropped head."
        )
    elif category == "icons":
        prefix = (
            "Create a polished transparent-background game icon for a Chinese wuxia action RPG. "
            "Single emblem or object, centered, bold silhouette, minimal clutter, no text, no border text."
        )
    else:
        prefix = (
            "Create a polished game UI art asset for a Chinese wuxia action RPG. "
            "Decorative but readable, no text, no logo, preserve a clean readable central area."
        )
    return "%s %s Negative guidance: %s" % (prefix, spec.prompt, spec.negative_prompt)


def _generation_size(spec: asset_specs.AssetSpec) -> str:
    width, height = asset_specs.parse_size(spec.meta.get("sheet_size", spec.target_size))
    aspect = width / float(height)
    if aspect > 1.15:
        return "1536x1024"
    if aspect < 0.85:
        return "1024x1536"
    return "1024x1024"


def _background_mode(spec: asset_specs.AssetSpec) -> str:
    if spec.background_mode == "transparent":
        return "transparent"
    return "opaque"


def _load_api_key() -> str:
    env_value = os.environ.get("OPENAI_API_KEY", "").strip()
    if env_value:
        return env_value
    prompt_value = getpass.getpass("Enter OPENAI_API_KEY: ").strip()
    if not prompt_value:
        raise SystemExit("OPENAI_API_KEY is required.")
    return prompt_value


def _request_image(
    api_key: str,
    spec: asset_specs.AssetSpec,
    model: str,
    quality: str,
) -> Dict:
    body = {
        "model": model,
        "prompt": _prompt_wrapper(spec),
        "size": _generation_size(spec),
        "quality": quality,
        "background": _background_mode(spec),
        "output_format": "png",
    }
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": "Bearer %s" % api_key,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    last_error: Exception | None = None
    for _attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=600) as response:
                payload = json.loads(response.read().decode("utf-8"))
            break
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError("Image generation failed for %s: %s %s" % (spec.logical_id, exc.code, detail))
        except (urllib.error.URLError, http.client.IncompleteRead, TimeoutError) as exc:
            last_error = exc
            time.sleep(2.0)
    else:
        raise RuntimeError("Image generation network error for %s: %s" % (spec.logical_id, last_error))

    data = payload.get("data") or []
    if not data:
        raise RuntimeError("Image generation returned no data for %s" % spec.logical_id)
    first = data[0]
    b64_json = first.get("b64_json")
    if not b64_json:
        raise RuntimeError("Image generation returned no b64_json for %s" % spec.logical_id)
    payload["__image_bytes"] = base64.b64decode(b64_json)
    return payload


def _center_crop_and_resize(src_path: Path, dst_path: Path, target_size: str) -> None:
    target_w, target_h = asset_specs.parse_size(target_size)
    probe = subprocess.check_output(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(src_path)],
        text=True,
    )
    values: Dict[str, int] = {}
    for line in probe.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in {"pixelWidth", "pixelHeight"}:
            values[key] = int(value)
    src_w = values["pixelWidth"]
    src_h = values["pixelHeight"]
    src_ratio = src_w / float(src_h)
    target_ratio = target_w / float(target_h)

    crop_w = src_w
    crop_h = src_h
    if abs(src_ratio - target_ratio) > 0.001:
        if src_ratio > target_ratio:
            crop_w = int(round(src_h * target_ratio))
            crop_h = src_h
        else:
            crop_w = src_w
            crop_h = int(round(src_w / target_ratio))

    temp_crop = dst_path.parent / ("%s.crop.png" % dst_path.stem)
    temp_resize = dst_path.parent / ("%s.resize.png" % dst_path.stem)
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        if crop_w != src_w or crop_h != src_h:
            subprocess.check_call(
                ["sips", "--cropToHeightWidth", str(crop_h), str(crop_w), str(src_path), "--out", str(temp_crop)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            crop_source = temp_crop
        else:
            crop_source = src_path
        subprocess.check_call(
            ["sips", "-z", str(target_h), str(target_w), str(crop_source), "--out", str(temp_resize)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        temp_resize.replace(dst_path)
    finally:
        if temp_crop.exists():
            temp_crop.unlink()
        if temp_resize.exists():
            temp_resize.unlink()


def _save_raw_image(spec: asset_specs.AssetSpec, payload: Dict, model: str, quality: str) -> Path:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    size = _generation_size(spec)
    raw_path = RAW_DIR / ("%s__%s__%s__%s.png" % (spec.logical_id, model, quality, size))
    raw_path.write_bytes(payload["__image_bytes"])
    return raw_path


def _append_log(spec: asset_specs.AssetSpec, payload: Dict, model: str, quality: str, raw_path: Path) -> None:
    entry = {
        "logical_id": spec.logical_id,
        "output_path": spec.output_path,
        "model": model,
        "quality": quality,
        "requested_size": _generation_size(spec),
        "target_size": spec.target_size,
        "background": _background_mode(spec),
        "raw_path": str(raw_path.relative_to(ROOT)),
        "prompt": _prompt_wrapper(spec),
        "revised_prompt": payload.get("data", [{}])[0].get("revised_prompt"),
        "created": payload.get("created"),
    }
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _select_specs(
    scope: str,
    logical_ids: Sequence[str],
    limit: int,
) -> List[asset_specs.AssetSpec]:
    specs = asset_specs.build_specs()
    if scope == "wired":
        specs = [spec for spec in specs if spec.wired_now]
    elif scope == "unwired":
        specs = [spec for spec in specs if not spec.wired_now]

    logical_id_filter = {item.strip() for item in logical_ids if item.strip()}
    if logical_id_filter:
        specs = [spec for spec in specs if spec.logical_id in logical_id_filter]

    if limit > 0:
        specs = specs[:limit]
    return specs


def _quality_for_spec(default_quality: str, spec: asset_specs.AssetSpec) -> str:
    if spec.category == "backgrounds":
        return default_quality
    if default_quality == "high":
        return "high"
    return default_quality


def generate_specs(
    specs: Sequence[asset_specs.AssetSpec],
    api_key: str,
    model: str,
    quality: str,
    sleep_seconds: float,
) -> None:
    total = len(specs)
    for index, spec in enumerate(specs, start=1):
        spec_quality = _quality_for_spec(quality, spec)
        print("[%d/%d] %s -> %s" % (index, total, spec.logical_id, spec.output_path), flush=True)
        payload = _request_image(api_key, spec, model, spec_quality)
        raw_path = _save_raw_image(spec, payload, model, spec_quality)
        final_path = ROOT / spec.output_path
        _center_crop_and_resize(raw_path, final_path, spec.target_size)
        _append_log(spec, payload, model, spec_quality, raw_path)
        print("  saved %s" % final_path.relative_to(ROOT), flush=True)
        if sleep_seconds > 0 and index < total:
            time.sleep(sleep_seconds)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate AFK-RPG art assets via the OpenAI Images API.")
    parser.add_argument("--scope", choices=["wired", "unwired", "all"], default="wired")
    parser.add_argument("--model", default="gpt-image-1.5")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="medium")
    parser.add_argument("--sleep-seconds", type=float, default=12.0)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--logical-id", action="append", default=[])
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = _parse_args(argv)
    specs = _select_specs(args.scope, args.logical_id, args.limit)
    if not specs:
        print("No assets matched the requested selection.", file=sys.stderr)
        return 1
    api_key = _load_api_key()
    print(
        "Generating %d assets with %s (%s, scope=%s)." % (
            len(specs),
            args.model,
            args.quality,
            args.scope,
        ),
        flush=True,
    )
    generate_specs(specs, api_key, args.model, args.quality, args.sleep_seconds)
    asset_specs.verify_sizes(specs)
    print("Done. Verified %d generated assets." % len(specs), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
