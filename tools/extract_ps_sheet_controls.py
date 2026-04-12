#!/usr/bin/env python3
from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import hero_run_pipeline as png_tools


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
SOURCE = ROOT / "assets/generated/afk_rpg_formal/ui/source_ps_sheet_v1.png"
OUTPUT_ROOT = ROOT / "assets/generated/afk_rpg_formal/ui/extracted_ps_sheet_v1"

MaskKind = Literal["edge_bg", "dark_bg", "ellipse", "round_rect", "rect"]


@dataclass(frozen=True)
class ControlSpec:
	category: str
	name: str
	rect: tuple[int, int, int, int]
	mask: MaskKind = "edge_bg"
	radius: int = 12
	trim: bool = True
	fringe_passes: int = 2


def _specs() -> list[ControlSpec]:
	specs: list[ControlSpec] = [
		ControlSpec("orbs", "orbs_01_fire_orb_small", (20, 547, 70, 70), "ellipse"),
		ControlSpec("orbs", "orbs_02_blue_orb_small", (96, 547, 72, 72), "ellipse"),
		ControlSpec("orbs", "orbs_03_red_resource_orb", (28, 608, 132, 132), "ellipse"),
		ControlSpec("orbs", "orbs_04_fan_round_button", (158, 607, 79, 79), "ellipse"),
		ControlSpec("orbs", "orbs_05_fist_skill_button", (158, 684, 73, 73), "ellipse"),
		ControlSpec("orbs", "orbs_06_fist_round_button", (646, 547, 75, 75), "ellipse"),
		ControlSpec("orbs", "orbs_07_menu_round_button", (646, 682, 74, 74), "ellipse"),
		ControlSpec("panels", "panels_01_red_long_tab", (31, 461, 158, 36), "edge_bg"),
		ControlSpec("panels", "panels_02_blue_long_tab", (200, 461, 157, 36), "edge_bg"),
		ControlSpec("panels", "panels_03_dark_long_tab", (369, 461, 157, 36), "edge_bg"),
		ControlSpec("panels", "panels_04_green_long_tab", (537, 461, 160, 36), "edge_bg"),
		ControlSpec("panels", "panels_05_green_scroll_frame", (257, 541, 113, 71), "edge_bg"),
		ControlSpec("panels", "panels_06_red_scroll_frame", (383, 541, 113, 71), "edge_bg"),
		ControlSpec("panels", "panels_07_gold_scroll_frame", (507, 541, 113, 71), "edge_bg"),
		ControlSpec("panels", "panels_08_dark_bottom_bar", (248, 644, 379, 108), "edge_bg"),
		ControlSpec("panels", "panels_09_large_paper_panel", (1194, 302, 193, 435), "edge_bg"),
		ControlSpec("buttons", "buttons_01_chat_bubble_button", (256, 718, 34, 24), "dark_bg", fringe_passes=1),
		ControlSpec("buttons", "buttons_02_gold_arrow_right", (587, 716, 32, 27), "dark_bg", fringe_passes=1),
		ControlSpec("frames", "frames_01_ornate_empty_strip", (1122, 262, 270, 59), "edge_bg"),
		ControlSpec("frames", "frames_02_tall_scroll_side_frame", (1131, 330, 47, 153), "edge_bg"),
		ControlSpec("frames", "frames_03_corner_border_left", (1123, 230, 57, 58), "edge_bg"),
		ControlSpec("frames", "frames_04_corner_border_bottom", (1124, 514, 56, 46), "edge_bg"),
	]

	# Lower icon cluster only. These are intentionally treated as individual icons,
	# not as an auto-segmented group, to avoid adjacent items getting glued together.
	icon_rects = [
		(817, 331, 43, 43, "purple_gem_round"),
		(866, 331, 43, 43, "green_blade_round"),
		(918, 331, 43, 43, "gold_cup_round"),
		(967, 331, 45, 45, "blue_beast_round"),
		(1018, 331, 43, 43, "spirit_round"),
		(1067, 331, 44, 44, "red_slash_round"),
		(817, 374, 43, 43, "fire_scroll_round"),
		(866, 374, 43, 43, "martial_fist_round"),
		(918, 374, 43, 43, "gold_medal_round"),
		(967, 374, 43, 43, "red_charm_round"),
		(1018, 374, 43, 43, "jade_mountain_round"),
		(1067, 374, 44, 44, "blue_gear_round"),
		(817, 417, 43, 43, "fire_blade_round"),
		(867, 417, 43, 43, "ember_sweep_round"),
		(918, 417, 43, 43, "red_splinter_round"),
		(967, 417, 43, 43, "bronze_hook_round"),
		(1018, 417, 43, 43, "green_bottle_round"),
		(1067, 417, 44, 44, "green_wind_round"),
		(817, 461, 43, 43, "teal_tower_round"),
		(867, 461, 43, 43, "dark_water_round"),
		(918, 461, 43, 43, "blue_moon_round"),
		(968, 461, 43, 43, "flame_core_round"),
		(1018, 461, 43, 43, "bronze_relic_round"),
		(1068, 461, 43, 43, "blue_dash_round"),
		(817, 505, 43, 43, "purple_rift_round"),
		(868, 505, 43, 43, "wooden_slash_square"),
		(918, 505, 43, 43, "green_talisman_square"),
		(968, 505, 43, 43, "blue_sword_square"),
		(1018, 505, 43, 43, "blue_streak_square"),
		(1068, 505, 43, 43, "gold_slash_square"),
		(819, 578, 38, 39, "wooden_box"),
		(869, 577, 38, 40, "red_crate"),
		(920, 577, 38, 40, "green_bottle"),
		(969, 577, 38, 40, "jade_flask"),
		(1018, 577, 39, 41, "blue_book"),
		(1069, 577, 38, 40, "gold_leaf"),
		(818, 621, 38, 40, "green_token"),
		(868, 621, 38, 40, "paper_scroll"),
		(918, 621, 39, 40, "blue_cloud"),
		(968, 621, 39, 40, "small_sword"),
		(1018, 621, 39, 40, "gold_ring"),
		(1068, 621, 39, 40, "red_cloth"),
		(818, 664, 38, 40, "red_book"),
		(868, 664, 40, 41, "flower_bundle"),
		(918, 664, 40, 42, "blue_crystal"),
		(968, 664, 39, 42, "blue_gem"),
	]
	for index, (x, y, w, h, label) in enumerate(icon_rects, start=1):
		specs.append(ControlSpec("icons", f"icons_{index:02d}_{label}", (x, y, w, h), "edge_bg", fringe_passes=1))
	return specs


def _pixel(pixels: bytearray, width: int, x: int, y: int) -> tuple[int, int, int, int]:
	i = (y * width + x) * 4
	return pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]


def _set_alpha(pixels: bytearray, width: int, x: int, y: int, alpha: int) -> None:
	pixels[(y * width + x) * 4 + 3] = max(0, min(255, alpha))


def _crop(source: bytearray, source_width: int, source_height: int, rect: tuple[int, int, int, int]) -> tuple[int, int, bytearray]:
	x, y, crop_width, crop_height = rect
	x = max(0, min(source_width - 1, x))
	y = max(0, min(source_height - 1, y))
	crop_width = max(1, min(source_width - x, crop_width))
	crop_height = max(1, min(source_height - y, crop_height))
	output = bytearray(crop_width * crop_height * 4)
	for row in range(crop_height):
		src_i = ((y + row) * source_width + x) * 4
		dst_i = row * crop_width * 4
		output[dst_i:dst_i + crop_width * 4] = source[src_i:src_i + crop_width * 4]
	return crop_width, crop_height, output


def _is_background_color(r: int, g: int, b: int, a: int) -> bool:
	if a < 16:
		return True
	# Source sheet background is off-white/parchment. Keep colored UI interiors.
	if r >= 205 and g >= 198 and b >= 170 and max(r, g, b) - min(r, g, b) <= 74:
		return True
	if r >= 225 and g >= 218 and b >= 195:
		return True
	return False


def _is_light_fringe(r: int, g: int, b: int, a: int) -> bool:
	if a < 16:
		return False
	return r >= 190 and g >= 178 and b >= 148 and max(r, g, b) - min(r, g, b) <= 92


def _is_dark_bar_background(r: int, g: int, b: int, a: int) -> bool:
	if a < 16:
		return True
	return r <= 115 and g <= 118 and b <= 118


def _remove_edge_background(width: int, height: int, pixels: bytearray) -> None:
	visited = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()

	def try_push(x: int, y: int) -> None:
		if x < 0 or y < 0 or x >= width or y >= height:
			return
		index = y * width + x
		if visited[index]:
			return
		r, g, b, a = _pixel(pixels, width, x, y)
		if _is_background_color(r, g, b, a):
			visited[index] = 1
			queue.append((x, y))

	for x in range(width):
		try_push(x, 0)
		try_push(x, height - 1)
	for y in range(height):
		try_push(0, y)
		try_push(width - 1, y)

	while queue:
		x, y = queue.popleft()
		_set_alpha(pixels, width, x, y, 0)
		try_push(x - 1, y)
		try_push(x + 1, y)
		try_push(x, y - 1)
		try_push(x, y + 1)


def _remove_edge_background_with_predicate(width: int, height: int, pixels: bytearray, predicate) -> None:
	visited = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()

	def try_push(x: int, y: int) -> None:
		if x < 0 or y < 0 or x >= width or y >= height:
			return
		index = y * width + x
		if visited[index]:
			return
		r, g, b, a = _pixel(pixels, width, x, y)
		if predicate(r, g, b, a):
			visited[index] = 1
			queue.append((x, y))

	for x in range(width):
		try_push(x, 0)
		try_push(x, height - 1)
	for y in range(height):
		try_push(0, y)
		try_push(width - 1, y)

	while queue:
		x, y = queue.popleft()
		_set_alpha(pixels, width, x, y, 0)
		try_push(x - 1, y)
		try_push(x + 1, y)
		try_push(x, y - 1)
		try_push(x, y + 1)


def _has_transparent_neighbor(width: int, height: int, pixels: bytearray, x: int, y: int) -> bool:
	for dy in (-1, 0, 1):
		for dx in (-1, 0, 1):
			if dx == 0 and dy == 0:
				continue
			nx = x + dx
			ny = y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				return True
			if _pixel(pixels, width, nx, ny)[3] == 0:
				return True
	return False


def _defringe(width: int, height: int, pixels: bytearray, passes: int) -> None:
	for _ in range(max(0, passes)):
		to_clear: list[tuple[int, int]] = []
		for y in range(height):
			for x in range(width):
				r, g, b, a = _pixel(pixels, width, x, y)
				if _is_light_fringe(r, g, b, a) and _has_transparent_neighbor(width, height, pixels, x, y):
					to_clear.append((x, y))
		for x, y in to_clear:
			_set_alpha(pixels, width, x, y, 0)


def _apply_ellipse_mask(width: int, height: int, pixels: bytearray) -> None:
	cx = (width - 1) / 2.0
	cy = (height - 1) / 2.0
	rx = max(1.0, width / 2.0 - 1.0)
	ry = max(1.0, height / 2.0 - 1.0)
	for y in range(height):
		for x in range(width):
			d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
			if d > 1.0:
				_set_alpha(pixels, width, x, y, 0)
			elif d > 0.92:
				i = (y * width + x) * 4 + 3
				pixels[i] = min(pixels[i], int(round(255 * (1.0 - (d - 0.92) / 0.08))))


def _apply_round_rect_mask(width: int, height: int, pixels: bytearray, radius: int) -> None:
	radius = max(1, min(radius, width // 2, height // 2))
	for y in range(height):
		for x in range(width):
			cx = min(max(x, radius), width - 1 - radius)
			cy = min(max(y, radius), height - 1 - radius)
			dx = x - cx
			dy = y - cy
			dist2 = dx * dx + dy * dy
			if dist2 > radius * radius:
				_set_alpha(pixels, width, x, y, 0)


def _trim_alpha(width: int, height: int, pixels: bytearray, padding: int = 2) -> tuple[int, int, bytearray]:
	min_x = width
	min_y = height
	max_x = -1
	max_y = -1
	for y in range(height):
		for x in range(width):
			if _pixel(pixels, width, x, y)[3] > 0:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return width, height, pixels
	min_x = max(0, min_x - padding)
	min_y = max(0, min_y - padding)
	max_x = min(width - 1, max_x + padding)
	max_y = min(height - 1, max_y + padding)
	return _crop(pixels, width, height, (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


def _process(spec: ControlSpec, source_width: int, source_height: int, source_pixels: bytearray) -> tuple[int, int, bytearray]:
	width, height, pixels = _crop(source_pixels, source_width, source_height, spec.rect)
	if spec.mask in {"edge_bg", "ellipse", "round_rect"}:
		_remove_edge_background(width, height, pixels)
	elif spec.mask == "dark_bg":
		_remove_edge_background_with_predicate(width, height, pixels, _is_dark_bar_background)
	if spec.mask == "ellipse":
		_apply_ellipse_mask(width, height, pixels)
	elif spec.mask == "round_rect":
		_apply_round_rect_mask(width, height, pixels, spec.radius)
	_defringe(width, height, pixels, spec.fringe_passes)
	if spec.trim:
		width, height, pixels = _trim_alpha(width, height, pixels)
	return width, height, pixels


def main() -> int:
	if not SOURCE.exists():
		raise FileNotFoundError(SOURCE)
	source_width, source_height, source_pixels = png_tools.load_rgba_png(SOURCE)
	counts: dict[str, int] = {}
	for spec in _specs():
		width, height, pixels = _process(spec, source_width, source_height, source_pixels)
		output_path = OUTPUT_ROOT / spec.category / f"{spec.name}.png"
		png_tools.save_rgba_png(output_path, width, height, pixels)
		counts[spec.category] = counts.get(spec.category, 0) + 1
		print(f"{spec.category}/{spec.name}.png {width}x{height}")
	print("summary", counts)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
