#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import http.client
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterable, Sequence

import generate_art_assets as asset_specs
import hero_run_pipeline as png_tools


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
RAW_DIR = ROOT / "assets" / "generated" / "_openai_raw" / "object_parallax_scenes"
PARTS_DIR = ROOT / "assets" / "generated" / "afk_rpg_formal" / "backgrounds" / "object_parts"
BACKGROUND_DIR = ROOT / "assets" / "generated" / "afk_rpg_formal" / "backgrounds"
LAYOUT_DIR = ROOT / "data" / "backgrounds" / "object_scene_layouts"
LOG_PATH = ROOT / "文档" / "object_parallax_scene_openai生成日志_v1.jsonl"
REVIEW_PATH = ROOT / "文档" / "object_parallax_scene_review_v1.md"
API_URL = "https://api.openai.com/v1/images/generations"

LAYER_ORDER = ["sky", "far", "mid", "near_back", "near_front"]

SCENE_SPECS = {
	"chapter1_town_road_objects_v1": {
		"scene_summary": "第一章山镇道路，暖日江湖集镇，避免整张概念图切层，改为独立环境物件拼景深。",
		"repeat_size": [3072, 720],
		"ground_y": 540,
		"player_spawn_y": 500,
		"scroll_speed_multipliers": {
			"sky": 0.08,
			"far": 0.18,
			"mid": 0.42,
			"near_back": 0.72,
			"near_front": 1.0,
		},
		"parallax_distances": {
			"sky": 8.0,
			"far": 14.0,
			"mid": 22.0,
			"near_back": 30.0,
			"near_front": 36.0,
		},
		"anchor_bias": {
			"sky": 0.0,
			"far": -16.0,
			"mid": -10.0,
			"near_back": -4.0,
			"near_front": 0.0,
		},
		"objects": [
			{
				"id": "sky_wash",
				"size": "1536x1024",
				"background": "opaque",
				"prompt": (
					"Use case: stylized-concept\n"
					"Asset type: parallax sky plate for chapter 1 side-scrolling battle scene\n"
					"Primary request: warm daylight wuxia market-town sky only, pale blue to parchment gradient, soft clouds, gentle haze, no buildings, no ground, no characters, no framing props\n"
					"Style/medium: polished 2D painted game background\n"
					"Composition/framing: wide horizontal atmosphere plate with calm empty center and empty edges for loop-safe parallax use\n"
					"Constraints: no architecture, no mountains, no text, no logo, no vignette"
				),
			},
			{
				"id": "far_mountain_ridge",
				"size": "1536x1024",
				"background": "transparent",
				"prompt": (
					"Use case: stylized-concept\n"
					"Asset type: transparent far-background parallax prop\n"
					"Primary request: long distant mountain ridge with a few tiny pagoda rooftops, atmospheric perspective, horizontal silhouette only\n"
					"Style/medium: polished 2D painted wuxia game prop\n"
					"Composition/framing: single long horizontal ridge cluster, transparent background, centered subject, leave padding around edges\n"
					"Constraints: no foreground trees, no ground plane, no characters, no text, no logo"
				),
			},
			{
				"id": "gate_bridge_cluster",
				"size": "1536x1024",
				"background": "transparent",
				"prompt": (
					"Use case: stylized-concept\n"
					"Asset type: transparent far-to-mid parallax environment prop\n"
					"Primary request: town gate tower, roofline cluster, light bridge hint, distant wall segment, readable mountain-town identity\n"
					"Style/medium: polished 2D painted wuxia game prop\n"
					"Composition/framing: horizontal cluster only, transparent background, subject centered with generous empty padding, suitable for placing above a battle lane\n"
					"Constraints: no ground foreground, no close props, no characters, no text, no logo"
				),
			},
			{
				"id": "teahouse_market_row",
				"size": "1536x1024",
				"background": "transparent",
				"prompt": (
					"Use case: stylized-concept\n"
					"Asset type: transparent midground parallax environment prop\n"
					"Primary request: tea house facades, shop row, cloth banners, light fence, jianghu market architecture strip\n"
					"Style/medium: polished 2D painted wuxia game prop\n"
					"Composition/framing: horizontal street-side building cluster only, transparent background, no full scene, leave clear space below for combat lane\n"
					"Constraints: no characters, no carts, no full ground floor perspective, no text, no logo"
				),
			},
			{
				"id": "stall_awning_fence",
				"size": "1024x1024",
				"background": "transparent",
				"prompt": (
					"Use case: stylized-concept\n"
					"Asset type: transparent near-background parallax prop\n"
					"Primary request: market stall awning corners, fence posts, hanging cloth, wooden rail fragments\n"
					"Style/medium: polished 2D painted wuxia game prop\n"
					"Composition/framing: single clustered prop group, transparent background, readable silhouette, no complete scene\n"
					"Constraints: no people, no text, no logo"
				),
			},
			{
				"id": "lantern_branch_foreground",
				"size": "1024x1024",
				"background": "transparent",
				"prompt": (
					"Use case: stylized-concept\n"
					"Asset type: transparent foreground framing prop\n"
					"Primary request: plum branch, blossoms, hanging lanterns, close-camera decorative framing cluster\n"
					"Style/medium: polished 2D painted wuxia game prop\n"
					"Composition/framing: asymmetrical prop cluster only, transparent background, keep negative space so it can sit in a screen corner\n"
					"Constraints: no full tree, no characters, no text, no logo"
				),
			},
		],
		"layers": {
			"sky": [
				{"asset": "sky_wash", "x": 0, "y": 0, "scale": 2.0, "alpha": 255},
				{"asset": "far_mountain_ridge", "x": 220, "y": 70, "scale": 1.58, "alpha": 168},
				{"asset": "far_mountain_ridge", "x": 1580, "y": 82, "scale": 1.42, "alpha": 144},
			],
			"far": [
				{"asset": "gate_bridge_cluster", "x": 280, "y": 118, "scale": 1.2, "alpha": 214},
				{"asset": "gate_bridge_cluster", "x": 1680, "y": 132, "scale": 1.08, "alpha": 194},
			],
			"mid": [
				{"asset": "teahouse_market_row", "x": 220, "y": 168, "scale": 1.28, "alpha": 255},
				{"asset": "teahouse_market_row", "x": 1660, "y": 176, "scale": 1.2, "alpha": 248},
			],
			"near_back": [
				{"asset": "stall_awning_fence", "x": 96, "y": 284, "scale": 1.05, "alpha": 232},
				{"asset": "stall_awning_fence", "x": 2350, "y": 296, "scale": 0.92, "alpha": 220},
			],
			"near_front": [
				{"asset": "lantern_branch_foreground", "x": -40, "y": 18, "scale": 1.12, "alpha": 240},
				{"asset": "lantern_branch_foreground", "x": 2500, "y": 30, "scale": 0.98, "alpha": 224, "flip_x": True},
			],
		},
	},
}


def _load_api_key() -> str:
	value = os.environ.get("OPENAI_API_KEY", "").strip()
	if not value:
		raise SystemExit("OPENAI_API_KEY is required.")
	return value


def _request_image(api_key: str, prompt: str, size: str, background: str, model: str, quality: str) -> dict:
	body = {
		"model": model,
		"prompt": prompt,
		"size": size,
		"quality": quality,
		"background": background,
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
			raise RuntimeError("Image generation failed: %s %s" % (exc.code, detail))
		except (urllib.error.URLError, http.client.IncompleteRead, TimeoutError) as exc:
			last_error = exc
			time.sleep(2.0)
	else:
		raise RuntimeError("Image generation network error: %s" % last_error)
	data = payload.get("data") or []
	if not data or not data[0].get("b64_json"):
		raise RuntimeError("Image generation returned no image payload.")
	payload["__image_bytes"] = base64.b64decode(data[0]["b64_json"])
	return payload


def _iter_scene_objects(scene_key: str) -> Iterable[dict]:
	for item in SCENE_SPECS[scene_key]["objects"]:
		yield item


def _raw_output_path(scene_key: str, object_id: str, model: str, quality: str, size: str) -> Path:
	return RAW_DIR / scene_key / f"{object_id}__{model}__{quality}__{size}.png"


def _final_object_path(scene_key: str, object_id: str) -> Path:
	return PARTS_DIR / scene_key / f"{object_id}.png"


def _write_png(path: Path, payload: bytes) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_bytes(payload)


def _resize_bilinear(src_width: int, src_height: int, src: bytearray, dst_width: int, dst_height: int) -> bytearray:
	if src_width == dst_width and src_height == dst_height:
		return bytearray(src)
	dst = bytearray(dst_width * dst_height * 4)
	x_ratio = src_width / float(dst_width)
	y_ratio = src_height / float(dst_height)
	for y in range(dst_height):
		fy = max(0.0, min(src_height - 1.001, (y + 0.5) * y_ratio - 0.5))
		y0 = int(math.floor(fy))
		y1 = min(src_height - 1, y0 + 1)
		ty = fy - y0
		for x in range(dst_width):
			fx = max(0.0, min(src_width - 1.001, (x + 0.5) * x_ratio - 0.5))
			x0 = int(math.floor(fx))
			x1 = min(src_width - 1, x0 + 1)
			tx = fx - x0
			for channel in range(4):
				c00 = src[(y0 * src_width + x0) * 4 + channel]
				c10 = src[(y0 * src_width + x1) * 4 + channel]
				c01 = src[(y1 * src_width + x0) * 4 + channel]
				c11 = src[(y1 * src_width + x1) * 4 + channel]
				top = c00 + (c10 - c00) * tx
				bottom = c01 + (c11 - c01) * tx
				value = int(round(top + (bottom - top) * ty))
				dst[(y * dst_width + x) * 4 + channel] = max(0, min(255, value))
	return dst


def _modulate_alpha(pixels: bytearray, alpha: int) -> bytearray:
	if alpha >= 255:
		return bytearray(pixels)
	output = bytearray(pixels)
	for index in range(0, len(output), 4):
		output[index + 3] = int(round(output[index + 3] * (alpha / 255.0)))
	return output


def _flip_x(width: int, height: int, pixels: bytearray) -> bytearray:
	output = bytearray(len(pixels))
	for y in range(height):
		for x in range(width):
			src_i = (y * width + x) * 4
			dst_i = (y * width + (width - 1 - x)) * 4
			output[dst_i:dst_i + 4] = pixels[src_i:src_i + 4]
	return output


def _apply_vertical_fade_and_brightness(
	width: int,
	height: int,
	pixels: bytearray,
	brightness: float,
	top_fade: int,
) -> bytearray:
	output = bytearray(pixels)
	fade_height = max(1, top_fade)
	for y in range(height):
		fade_alpha = 1.0
		if y < fade_height:
			fade_alpha = y / float(fade_height)
		for x in range(width):
			index = (y * width + x) * 4
			for channel in range(3):
				output[index + channel] = max(0, min(255, int(round(output[index + channel] * brightness))))
			output[index + 3] = max(0, min(255, int(round(output[index + 3] * fade_alpha))))
	return output


def _load_layout(scene_key: str) -> dict:
	layout_path = LAYOUT_DIR / f"{scene_key}.json"
	if not layout_path.exists():
		raise SystemExit(f"Missing layout config: {layout_path}")
	return json.loads(layout_path.read_text(encoding="utf-8"))


def _resolve_repo_path(path_text: str) -> Path:
	if path_text.startswith("res://"):
		return ROOT / path_text.removeprefix("res://")
	return ROOT / path_text


def _crop_rgba(width: int, height: int, pixels: bytearray, rect: Sequence[int] | None) -> tuple[int, int, bytearray]:
	if rect is None:
		return width, height, bytearray(pixels)
	x, y, crop_w, crop_h = [int(value) for value in rect]
	x = max(0, min(width, x))
	y = max(0, min(height, y))
	crop_w = max(1, min(width - x, crop_w))
	crop_h = max(1, min(height - y, crop_h))
	output = bytearray(crop_w * crop_h * 4)
	for row in range(crop_h):
		src_i = ((y + row) * width + x) * 4
		dst_i = row * crop_w * 4
		output[dst_i:dst_i + crop_w * 4] = pixels[src_i:src_i + crop_w * 4]
	return crop_w, crop_h, output


def _load_asset_cache(layout: dict) -> dict[str, tuple[int, int, bytearray]]:
	cache: dict[str, tuple[int, int, bytearray]] = {}
	for asset in layout.get("assets", []):
		cache[str(asset["id"])] = png_tools.load_rgba_png(_resolve_repo_path(str(asset["path"])))
	return cache


def _prepare_placement_pixels(
	cache: dict[str, tuple[int, int, bytearray]],
	placement: dict,
) -> tuple[int, int, bytearray]:
	src_width, src_height, src_pixels = cache[str(placement["asset_id"])]
	work_width, work_height, work_pixels = _crop_rgba(src_width, src_height, src_pixels, placement.get("source_rect"))
	if placement.get("flip_x", False):
		work_pixels = _flip_x(work_width, work_height, work_pixels)
	scale = float(placement.get("scale", 1.0))
	target_width = max(1, int(round(work_width * scale)))
	target_height = max(1, int(round(work_height * scale)))
	resized = _resize_bilinear(work_width, work_height, work_pixels, target_width, target_height)
	modulated = _modulate_alpha(resized, int(placement.get("alpha", 255)))
	return target_width, target_height, modulated


def _compose_layers_from_layout(layout: dict) -> dict[str, str]:
	scene_key = str(layout["scene_id"])
	repeat_width, repeat_height = [int(value) for value in layout["repeat_size"]]
	cache = _load_asset_cache(layout)
	composed_paths: dict[str, str] = {}
	for layer_id in LAYER_ORDER:
		canvas = png_tools.make_canvas(repeat_width, repeat_height, (0, 0, 0, 0))
		for placement in layout.get("world_layers", {}).get(layer_id, []):
			target_width, target_height, prepared = _prepare_placement_pixels(cache, placement)
			png_tools.blit_rgba(
				canvas,
				repeat_width,
				repeat_height,
				prepared,
				target_width,
				target_height,
				int(placement.get("x", 0)),
				int(placement.get("y", 0)),
			)
		output_path = BACKGROUND_DIR / f"{scene_key}__{layer_id}.png"
		png_tools.save_rgba_png(output_path, repeat_width, repeat_height, canvas)
		composed_paths[layer_id] = str(output_path.relative_to(ROOT))
	return composed_paths


def _compute_corner_position(
	corner: str,
	offset: Sequence[int],
	element_width: int,
	element_height: int,
	screen_width: int,
	screen_height: int,
) -> tuple[int, int]:
	offset_x = int(offset[0]) if len(offset) >= 1 else 0
	offset_y = int(offset[1]) if len(offset) >= 2 else 0
	if corner == "top_right":
		return screen_width - element_width - offset_x, offset_y
	if corner == "bottom_left":
		return offset_x, screen_height - element_height - offset_y
	if corner == "bottom_right":
		return screen_width - element_width - offset_x, screen_height - element_height - offset_y
	return offset_x, offset_y


def _export_corner_overlays(layout: dict) -> list[dict]:
	screen_width, screen_height = [int(value) for value in layout.get("screen_size", [1280, 720])]
	cache = _load_asset_cache(layout)
	runtime_overlays: list[dict] = []
	for entry in layout.get("corner_overlays", []):
		src_width, src_height, src_pixels = cache[str(entry["asset_id"])]
		crop_width, crop_height, crop_pixels = _crop_rgba(src_width, src_height, src_pixels, entry.get("source_rect"))
		output_path = _resolve_repo_path(str(entry["output_path"]))
		png_tools.save_rgba_png(output_path, crop_width, crop_height, crop_pixels)
		scale = float(entry.get("scale", 1.0))
		placed_width = max(1, int(round(crop_width * scale)))
		placed_height = max(1, int(round(crop_height * scale)))
		position = _compute_corner_position(
			str(entry.get("corner", "top_left")),
			entry.get("offset", [0, 0]),
			placed_width,
			placed_height,
			screen_width,
			screen_height,
		)
		runtime_overlays.append({
			"id": str(entry["id"]),
			"path": "res://%s" % output_path.relative_to(ROOT).as_posix(),
			"corner": str(entry.get("corner", "top_left")),
			"offset": [int(value) for value in entry.get("offset", [0, 0])],
			"position": [position[0], position[1]],
			"scale": scale,
			"alpha": int(entry.get("alpha", 255)),
			"flip_x": bool(entry.get("flip_x", False)),
		})
	return runtime_overlays


def _copy_region(
	src_width: int,
	src_height: int,
	src_pixels: bytearray,
	x: int,
	y: int,
	copy_width: int,
	copy_height: int,
) -> bytearray:
	output = png_tools.make_canvas(copy_width, copy_height, (0, 0, 0, 0))
	for row in range(copy_height):
		src_y = y + row
		if src_y < 0 or src_y >= src_height:
			continue
		src_x = max(0, min(src_width, x))
		row_width = min(copy_width, src_width - src_x)
		if row_width <= 0:
			continue
		src_i = (src_y * src_width + src_x) * 4
		dst_i = row * copy_width * 4
		output[dst_i:dst_i + row_width * 4] = src_pixels[src_i:src_i + row_width * 4]
	return output


def _write_previews(layout: dict, layer_paths: dict[str, str], runtime_overlays: list[dict]) -> dict[str, str]:
	screen_width, screen_height = [int(value) for value in layout.get("screen_size", [1280, 720])]
	preview_offset_x = int(layout.get("preview_offset_x", 0))
	stack_canvas = png_tools.make_canvas(screen_width, screen_height, (0, 0, 0, 0))
	for layer_id in LAYER_ORDER:
		layer_width, layer_height, layer_pixels = png_tools.load_rgba_png(_resolve_repo_path(layer_paths[layer_id]))
		region = _copy_region(layer_width, layer_height, layer_pixels, preview_offset_x, 0, screen_width, screen_height)
		png_tools.blit_rgba(stack_canvas, screen_width, screen_height, region, screen_width, screen_height, 0, 0)
	stack_output = _resolve_repo_path(str(layout["preview_outputs"]["stack_preview"]))
	png_tools.save_rgba_png(stack_output, screen_width, screen_height, stack_canvas)

	overlay_canvas = bytearray(stack_canvas)
	for entry in runtime_overlays:
		overlay_width, overlay_height, overlay_pixels = png_tools.load_rgba_png(_resolve_repo_path(str(entry["path"])))
		if bool(entry.get("flip_x", False)):
			overlay_pixels = _flip_x(overlay_width, overlay_height, overlay_pixels)
		scale = float(entry.get("scale", 1.0))
		target_width = max(1, int(round(overlay_width * scale)))
		target_height = max(1, int(round(overlay_height * scale)))
		resized = _resize_bilinear(overlay_width, overlay_height, overlay_pixels, target_width, target_height)
		modulated = _modulate_alpha(resized, int(entry.get("alpha", 255)))
		position = entry.get("position", [0, 0])
		png_tools.blit_rgba(
			overlay_canvas,
			screen_width,
			screen_height,
			modulated,
			target_width,
			target_height,
			int(position[0]),
			int(position[1]),
		)
	overlay_output = _resolve_repo_path(str(layout["preview_outputs"]["overlay_preview"]))
	png_tools.save_rgba_png(overlay_output, screen_width, screen_height, overlay_canvas)
	return {
		"stack_preview": str(stack_output.relative_to(ROOT)),
		"overlay_preview": str(overlay_output.relative_to(ROOT)),
	}


def _build_ground_band(layout: dict) -> dict | None:
	ground_band: dict | None = layout.get("ground_band")
	if ground_band is None:
		return None
	source_width, source_height, source_pixels = png_tools.load_rgba_png(_resolve_repo_path(str(ground_band["source_path"])))
	crop_width, crop_height, crop_pixels = _crop_rgba(source_width, source_height, source_pixels, ground_band.get("source_rect"))
	output_width, output_height = [int(value) for value in ground_band.get("output_size", [crop_width, crop_height])]
	resized = _resize_bilinear(crop_width, crop_height, crop_pixels, output_width, output_height)
	processed = _apply_vertical_fade_and_brightness(
		output_width,
		output_height,
		resized,
		float(ground_band.get("brightness", 1.0)),
		int(ground_band.get("top_fade", 0)),
	)
	output_path = _resolve_repo_path(str(ground_band["output_path"]))
	png_tools.save_rgba_png(output_path, output_width, output_height, processed)
	return {
		"path": "res://%s" % output_path.relative_to(ROOT).as_posix(),
		"position": [int(value) for value in ground_band.get("position", [0, 0])],
	}


def _append_log(scene_key: str, object_id: str, payload: dict, model: str, quality: str, size: str, background: str) -> None:
	entry = {
		"scene_key": scene_key,
		"object_id": object_id,
		"model": model,
		"quality": quality,
		"size": size,
		"background": background,
		"raw_path": str(_raw_output_path(scene_key, object_id, model, quality, size).relative_to(ROOT)),
		"final_path": str(_final_object_path(scene_key, object_id).relative_to(ROOT)),
		"revised_prompt": payload.get("data", [{}])[0].get("revised_prompt"),
		"created": payload.get("created"),
	}
	LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
	with LOG_PATH.open("a", encoding="utf-8") as handle:
		handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _write_review(layout: dict, composed_paths: dict[str, str], runtime_overlays: list[dict], preview_paths: dict[str, str], ground_band: dict | None) -> None:
	scene_key = str(layout["scene_id"])
	lines = [
		"# 物件式多景深背景方案评审 v1",
		"",
		f"## 场景",
		"",
		f"- `{scene_key}`",
		f"- {layout['scene_summary']}",
		"",
		"## 资源分类",
		"",
	]
	for item in layout.get("assets", []):
		lines.append(
			"- `%s` -> `%s` | type=`%s` | layer=`%s` | anchor=`%s` | scale=`%s-%s` | repeat=`%s` | flip=`%s` | lock_corner=`%s`" % (
				item["id"],
				item["path"],
				item["resource_type"],
				item["recommended_layer"],
				item["recommended_anchor"],
				item["scale_range"][0],
				item["scale_range"][1],
				item["allow_repeat"],
				item["allow_flip"],
				item["lock_corner"],
			)
		)
	lines.extend(["", "## 合成层", ""])
	for layer_id in LAYER_ORDER:
		lines.append(f"- `{layer_id}` -> `{composed_paths[layer_id]}`")
	if ground_band is not None:
		lines.extend(["", "## 地面条带", ""])
		lines.append("- `ground_band` -> `%s` | position=`%s`" % (ground_band["path"], ground_band["position"]))
	lines.extend(["", "## 固定挂角 Overlay", ""])
	for entry in runtime_overlays:
		lines.append(
			"- `%s` -> `%s` | corner=`%s` | offset=`%s` | scale=`%s` | alpha=`%s` | flip_x=`%s`" % (
				entry["id"],
				entry["path"],
				entry["corner"],
				entry["offset"],
				entry["scale"],
				entry["alpha"],
				entry["flip_x"],
			)
		)
	lines.extend(
		[
			"",
			"## 预览输出",
			"",
			"- `stack_preview` -> `%s`" % preview_paths["stack_preview"],
			"- `overlay_preview` -> `%s`" % preview_paths["overlay_preview"],
			"",
			"## 调试目标",
			"",
			"- `far_mountain_ridge` 从天空层抽离，只承担远景山脊。",
			"- `teahouse_market_row` 作为主中景条带，只保留一次主条带和一次弱重复。",
			"- `gate_bridge_cluster` 改为单地标，不再和房屋条带等权重复。",
			"- `stall_awning_fence` 按局部裁切后只放左右两端。",
			"- `lantern_branch_foreground` 不再进入世界层，而是固定镜头角。",
		]
	)
	REVIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_scene(scene_key: str, model: str, quality: str, sleep_seconds: float) -> dict[str, str]:
	api_key = _load_api_key()
	for object_def in _iter_scene_objects(scene_key):
		object_id = object_def["id"]
		size = object_def["size"]
		background = object_def["background"]
		print(f"Generating {scene_key}:{object_id}", flush=True)
		payload = _request_image(api_key, object_def["prompt"], size, background, model, quality)
		raw_path = _raw_output_path(scene_key, object_id, model, quality, size)
		final_path = _final_object_path(scene_key, object_id)
		_write_png(raw_path, payload["__image_bytes"])
		_write_png(final_path, payload["__image_bytes"])
		_append_log(scene_key, object_id, payload, model, quality, size, background)
		print(f"  saved {final_path.relative_to(ROOT)}", flush=True)
		if sleep_seconds > 0:
			time.sleep(sleep_seconds)
	layout = _load_layout(scene_key)
	return _compose_layers_from_layout(layout)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate and compose object-based parallax backgrounds.")
	parser.add_argument("--scene-key", default="chapter1_town_road_objects_v1", choices=sorted(SCENE_SPECS.keys()))
	parser.add_argument("--model", default="gpt-image-1.5")
	parser.add_argument("--quality", choices=["low", "medium", "high"], default="high")
	parser.add_argument("--sleep-seconds", type=float, default=10.0)
	parser.add_argument("--compose-only", action="store_true")
	return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
	args = _parse_args(argv)
	layout = _load_layout(args.scene_key)
	if args.compose_only:
		composed_paths = _compose_layers_from_layout(layout)
	else:
		composed_paths = generate_scene(args.scene_key, args.model, args.quality, args.sleep_seconds)
	ground_band = _build_ground_band(layout)
	runtime_overlays = _export_corner_overlays(layout)
	preview_paths = _write_previews(layout, composed_paths, runtime_overlays)
	_write_review(layout, composed_paths, runtime_overlays, preview_paths, ground_band)
	print(f"Review written to {REVIEW_PATH.relative_to(ROOT)}", flush=True)
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
