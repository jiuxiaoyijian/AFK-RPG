#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import math
import os
import struct
import zlib
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
SPEC_PATH = ROOT / "tools" / "ui_component_specs.json"
REVIEW_ROOT = ROOT / "assets" / "generated" / "ui_component_review"


@dataclass
class ComponentSpec:
	id: str
	name: str
	source_rect: list[int] | None = None
	extract_mode: str = "crop"
	output_name: str | None = None
	mapping: str = ""
	status: str = "candidate"
	notes: str = ""
	nine_slice: list[int] | None = None
	keep_rects: list[list[int]] = field(default_factory=list)
	keep_round_rects: list[list[int]] = field(default_factory=list)
	keep_ellipse_rects: list[list[int]] = field(default_factory=list)
	clear_rects: list[list[int]] = field(default_factory=list)
	clear_round_rects: list[list[int]] = field(default_factory=list)
	clear_ellipse_rects: list[list[int]] = field(default_factory=list)
	alpha_seed_rects: list[list[int]] = field(default_factory=list)
	trim_alpha: bool = False
	padding: int = 0
	preserve_canvas: bool = False
	top_components: int = 1
	keep_mode: str = "largest"
	seed_stride: int = 2
	step_threshold: int = 34
	bin_step: int = 16
	edge_threshold: int = 52
	min_component_area: int = 48
	center_bias: bool = True
	focus_rect: list[int] | None = None


@dataclass
class ProfileSpec:
	id: str
	title: str
	source: str
	output_dir: str
	review_html: str
	manifest_md: str
	description: str = ""
	components: list[ComponentSpec] = field(default_factory=list)


def _parse_specs() -> list[ProfileSpec]:
	data = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
	profiles: list[ProfileSpec] = []
	for raw_profile in data.get("profiles", []):
		components = [ComponentSpec(**entry) for entry in raw_profile.get("components", [])]
		profiles.append(
			ProfileSpec(
				id=raw_profile["id"],
				title=raw_profile["title"],
				source=raw_profile["source"],
				output_dir=raw_profile["output_dir"],
				review_html=raw_profile["review_html"],
				manifest_md=raw_profile["manifest_md"],
				description=raw_profile.get("description", ""),
				components=components,
			)
		)
	return profiles


def _read_chunks(raw: bytes) -> Iterable[tuple[bytes, bytes]]:
	offset = 8
	while offset < len(raw):
		length = struct.unpack(">I", raw[offset:offset + 4])[0]
		chunk_type = raw[offset + 4:offset + 8]
		chunk_data = raw[offset + 8:offset + 8 + length]
		yield chunk_type, chunk_data
		offset += 12 + length


def _paeth_predictor(a: int, b: int, c: int) -> int:
	p = a + b - c
	pa = abs(p - a)
	pb = abs(p - b)
	pc = abs(p - c)
	if pa <= pb and pa <= pc:
		return a
	if pb <= pc:
		return b
	return c


def _read_png(path: Path) -> tuple[int, int, list[list[list[int]]]]:
	raw = path.read_bytes()
	if raw[:8] != b"\x89PNG\r\n\x1a\n":
		raise ValueError(f"Not a PNG: {path}")

	width = 0
	height = 0
	bit_depth = 0
	color_type = 0
	idat_parts: list[bytes] = []

	for chunk_type, chunk_data in _read_chunks(raw):
		if chunk_type == b"IHDR":
			width, height, bit_depth, color_type, compression, flt, interlace = struct.unpack(">IIBBBBB", chunk_data)
			if bit_depth != 8:
				raise ValueError("Only 8-bit PNG supported")
			if compression != 0 or flt != 0 or interlace != 0:
				raise ValueError("Unsupported PNG compression/filter/interlace")
			if color_type not in (2, 6):
				raise ValueError(f"Unsupported color type: {color_type}")
		elif chunk_type == b"IDAT":
			idat_parts.append(chunk_data)

	channels = 4 if color_type == 6 else 3
	stride = width * channels
	decompressed = zlib.decompress(b"".join(idat_parts))

	rows: list[list[list[int]]] = []
	prev = [0] * stride
	pos = 0
	for _y in range(height):
		filter_type = decompressed[pos]
		pos += 1
		row = list(decompressed[pos:pos + stride])
		pos += stride
		if filter_type == 1:
			for i in range(stride):
				left = row[i - channels] if i >= channels else 0
				row[i] = (row[i] + left) & 255
		elif filter_type == 2:
			for i in range(stride):
				row[i] = (row[i] + prev[i]) & 255
		elif filter_type == 3:
			for i in range(stride):
				left = row[i - channels] if i >= channels else 0
				up = prev[i]
				row[i] = (row[i] + ((left + up) // 2)) & 255
		elif filter_type == 4:
			for i in range(stride):
				left = row[i - channels] if i >= channels else 0
				up = prev[i]
				up_left = prev[i - channels] if i >= channels else 0
				row[i] = (row[i] + _paeth_predictor(left, up, up_left)) & 255
		elif filter_type != 0:
			raise ValueError(f"Unsupported PNG filter: {filter_type}")

		px_row: list[list[int]] = []
		for x in range(width):
			base = x * channels
			if channels == 4:
				px_row.append(row[base:base + 4])
			else:
				px_row.append(row[base:base + 3] + [255])
		rows.append(px_row)
		prev = row
	return width, height, rows


def _pack_chunk(chunk_type: bytes, chunk_data: bytes) -> bytes:
	crc = zlib.crc32(chunk_type)
	crc = zlib.crc32(chunk_data, crc) & 0xFFFFFFFF
	return struct.pack(">I", len(chunk_data)) + chunk_type + chunk_data + struct.pack(">I", crc)


def _write_png(path: Path, width: int, height: int, pixels: list[list[list[int]]]) -> None:
	raw_rows = bytearray()
	for y in range(height):
		raw_rows.append(0)
		for x in range(width):
			raw_rows.extend(bytes(pixels[y][x][:4]))
	compressed = zlib.compress(bytes(raw_rows), 9)
	ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
	png = bytearray(b"\x89PNG\r\n\x1a\n")
	png.extend(_pack_chunk(b"IHDR", ihdr))
	png.extend(_pack_chunk(b"IDAT", compressed))
	png.extend(_pack_chunk(b"IEND", b""))
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_bytes(bytes(png))


def _crop_pixels(pixels: list[list[list[int]]], rect: list[int]) -> tuple[int, int, list[list[list[int]]]]:
	x, y, width, height = rect
	out = [[px[:] for px in row[x:x + width]] for row in pixels[y:y + height]]
	return width, height, out


def _clear_rects(pixels: list[list[list[int]]], clear_rects: list[list[int]]) -> None:
	if not clear_rects:
		return
	height = len(pixels)
	width = len(pixels[0]) if height else 0
	for rect in clear_rects:
		x, y, rect_width, rect_height = rect
		for py in range(max(0, y), min(height, y + rect_height)):
			for px in range(max(0, x), min(width, x + rect_width)):
				pixels[py][px] = [0, 0, 0, 0]


def _clear_round_rects(pixels: list[list[list[int]]], clear_round_rects: list[list[int]]) -> None:
	if not clear_round_rects:
		return
	height = len(pixels)
	width = len(pixels[0]) if height else 0
	for rect in clear_round_rects:
		x, y, rect_width, rect_height, radius = rect
		right = x + rect_width
		bottom = y + rect_height
		radius = max(0, min(radius, rect_width // 2, rect_height // 2))
		for py in range(max(0, y), min(height, bottom)):
			for px in range(max(0, x), min(width, right)):
				inside = False
				if radius == 0:
					inside = True
				elif (x + radius) <= px < (right - radius) or (y + radius) <= py < (bottom - radius):
					inside = True
				else:
					cx = x + radius if px < (x + radius) else right - radius - 1
					cy = y + radius if py < (y + radius) else bottom - radius - 1
					dx = px - cx
					dy = py - cy
					inside = (dx * dx + dy * dy) <= (radius * radius)
				if inside:
					pixels[py][px] = [0, 0, 0, 0]


def _clear_ellipse_rects(pixels: list[list[list[int]]], clear_ellipse_rects: list[list[int]]) -> None:
	if not clear_ellipse_rects:
		return
	height = len(pixels)
	width = len(pixels[0]) if height else 0
	for rect in clear_ellipse_rects:
		x, y, rect_width, rect_height = rect
		if rect_width <= 0 or rect_height <= 0:
			continue
		cx = x + rect_width * 0.5
		cy = y + rect_height * 0.5
		rx = max(1.0, rect_width * 0.5)
		ry = max(1.0, rect_height * 0.5)
		for py in range(max(0, y), min(height, y + rect_height)):
			for px in range(max(0, x), min(width, x + rect_width)):
				dx = (px + 0.5 - cx) / rx
				dy = (py + 0.5 - cy) / ry
				if (dx * dx + dy * dy) <= 1.0:
					pixels[py][px] = [0, 0, 0, 0]


def _point_in_round_rect(px: int, py: int, rect: list[int]) -> bool:
	x, y, rect_width, rect_height, radius = rect
	right = x + rect_width
	bottom = y + rect_height
	if px < x or py < y or px >= right or py >= bottom:
		return False
	radius = max(0, min(radius, rect_width // 2, rect_height // 2))
	if radius == 0:
		return True
	if (x + radius) <= px < (right - radius) or (y + radius) <= py < (bottom - radius):
		return True
	cx = x + radius if px < (x + radius) else right - radius - 1
	cy = y + radius if py < (y + radius) else bottom - radius - 1
	dx = px - cx
	dy = py - cy
	return (dx * dx + dy * dy) <= (radius * radius)


def _point_in_ellipse_rect(px: int, py: int, rect: list[int]) -> bool:
	x, y, rect_width, rect_height = rect
	if rect_width <= 0 or rect_height <= 0:
		return False
	if px < x or py < y or px >= (x + rect_width) or py >= (y + rect_height):
		return False
	cx = x + rect_width * 0.5
	cy = y + rect_height * 0.5
	rx = max(1.0, rect_width * 0.5)
	ry = max(1.0, rect_height * 0.5)
	dx = (px + 0.5 - cx) / rx
	dy = (py + 0.5 - cy) / ry
	return (dx * dx + dy * dy) <= 1.0


def _clip_to_keep_shapes(pixels: list[list[list[int]]], spec: ComponentSpec) -> None:
	if not spec.keep_rects and not spec.keep_round_rects and not spec.keep_ellipse_rects:
		return
	height = len(pixels)
	width = len(pixels[0]) if height else 0
	for py in range(height):
		for px in range(width):
			keep = False
			for rect in spec.keep_rects:
				x, y, rect_width, rect_height = rect
				if x <= px < (x + rect_width) and y <= py < (y + rect_height):
					keep = True
					break
			if not keep:
				for rect in spec.keep_round_rects:
					if _point_in_round_rect(px, py, rect):
						keep = True
						break
			if not keep:
				for rect in spec.keep_ellipse_rects:
					if _point_in_ellipse_rect(px, py, rect):
						keep = True
						break
			if not keep:
				pixels[py][px] = [0, 0, 0, 0]


def _trim_alpha_bounds(pixels: list[list[list[int]]]) -> tuple[int, int, list[list[list[int]]]]:
	height = len(pixels)
	width = len(pixels[0]) if height else 0
	points = [(x, y) for y in range(height) for x in range(width) if pixels[y][x][3] > 0]
	if not points:
		return width, height, pixels
	xs = [p[0] for p in points]
	ys = [p[1] for p in points]
	min_x = min(xs)
	min_y = min(ys)
	max_x = max(xs)
	max_y = max(ys)
	new_w = max_x - min_x + 1
	new_h = max_y - min_y + 1
	out = [[[0, 0, 0, 0] for _ in range(new_w)] for _ in range(new_h)]
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			out[y - min_y][x - min_x] = pixels[y][x][:]
	return new_w, new_h, out


def _rgb(px: list[int]) -> tuple[int, int, int]:
	return px[0], px[1], px[2]


def _color_distance(a: list[int], b: list[int]) -> float:
	dr = a[0] - b[0]
	dg = a[1] - b[1]
	db = a[2] - b[2]
	return math.sqrt(dr * dr + dg * dg + db * db)


def _quantize(px: list[int], step: int) -> tuple[int, int, int]:
	return px[0] // step, px[1] // step, px[2] // step


def _sample_border(width: int, height: int, stride: int) -> list[tuple[int, int]]:
	points: list[tuple[int, int]] = []
	for x in range(0, width, max(1, stride)):
		points.append((x, 0))
		points.append((x, height - 1))
	for y in range(1, height - 1, max(1, stride)):
		points.append((0, y))
		points.append((width - 1, y))
	return points


def _average_color(pixels: list[list[list[int]]], points: list[tuple[int, int]]) -> list[int]:
	total = [0, 0, 0]
	count = 0
	for x, y in points:
		px = pixels[y][x]
		if px[3] <= 0:
			continue
		total[0] += px[0]
		total[1] += px[1]
		total[2] += px[2]
		count += 1
	if count == 0:
		return [0, 0, 0, 255]
	return [total[0] // count, total[1] // count, total[2] // count, 255]


def _seed_points_from_rects(
	width: int,
	height: int,
	seed_rects: list[list[int]],
	stride: int,
) -> list[tuple[int, int]]:
	points: list[tuple[int, int]] = []
	for rect in seed_rects:
		x, y, rect_width, rect_height = rect
		for py in range(max(0, y), min(height, y + rect_height), max(1, stride)):
			for px in range(max(0, x), min(width, x + rect_width), max(1, stride)):
				points.append((px, py))
	if not points:
		return []
	return points


def _build_edge_map(width: int, height: int, pixels: list[list[list[int]]]) -> list[list[float]]:
	edge_map = [[0.0 for _ in range(width)] for _ in range(height)]
	for y in range(height):
		for x in range(width):
			current = pixels[y][x]
			best = 0.0
			if x > 0:
				best = max(best, _color_distance(current, pixels[y][x - 1]))
			if y > 0:
				best = max(best, _color_distance(current, pixels[y - 1][x]))
			if x + 1 < width:
				best = max(best, _color_distance(current, pixels[y][x + 1]))
			if y + 1 < height:
				best = max(best, _color_distance(current, pixels[y + 1][x]))
			edge_map[y][x] = best
	return edge_map


def _mark_background(width: int, height: int, pixels: list[list[list[int]]], spec: ComponentSpec) -> list[list[bool]]:
	border_points = _sample_border(width, height, spec.seed_stride)
	border_mean = _average_color(pixels, border_points)
	border_bins = {_quantize(pixels[y][x], spec.bin_step) for x, y in border_points}
	edge_map = _build_edge_map(width, height, pixels)

	visited = [[False for _ in range(width)] for _ in range(height)]
	queue: deque[tuple[int, int]] = deque()

	for x, y in border_points:
		queue.append((x, y))
		visited[y][x] = True

	while queue:
		x, y = queue.popleft()
		current = pixels[y][x]
		for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
			if nx < 0 or ny < 0 or nx >= width or ny >= height or visited[ny][nx]:
				continue
			candidate = pixels[ny][nx]
			if candidate[3] == 0:
				visited[ny][nx] = True
				queue.append((nx, ny))
				continue
			bin_match = _quantize(candidate, spec.bin_step) in border_bins
			d_current = _color_distance(candidate, current)
			d_mean = _color_distance(candidate, border_mean)
			low_edge = edge_map[ny][nx] <= spec.edge_threshold
			if low_edge and (bin_match or (d_current <= spec.step_threshold and d_mean <= spec.step_threshold * 2.2)):
				visited[ny][nx] = True
				queue.append((nx, ny))
	return visited


def _mark_seed_region(
	width: int,
	height: int,
	pixels: list[list[list[int]]],
	spec: ComponentSpec,
	seed_points: list[tuple[int, int]],
) -> list[list[bool]]:
	if not seed_points:
		return [[False for _ in range(width)] for _ in range(height)]
	reference_mean = _average_color(pixels, seed_points)
	reference_bins = {_quantize(pixels[y][x], spec.bin_step) for x, y in seed_points}
	edge_map = _build_edge_map(width, height, pixels)

	visited = [[False for _ in range(width)] for _ in range(height)]
	queue: deque[tuple[int, int]] = deque()
	for x, y in seed_points:
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		queue.append((x, y))
		visited[y][x] = True

	while queue:
		x, y = queue.popleft()
		current = pixels[y][x]
		for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
			if nx < 0 or ny < 0 or nx >= width or ny >= height or visited[ny][nx]:
				continue
			candidate = pixels[ny][nx]
			if candidate[3] == 0:
				visited[ny][nx] = True
				queue.append((nx, ny))
				continue
			bin_match = _quantize(candidate, spec.bin_step) in reference_bins
			d_current = _color_distance(candidate, current)
			d_mean = _color_distance(candidate, reference_mean)
			low_edge = edge_map[ny][nx] <= spec.edge_threshold
			if low_edge and (bin_match or (d_current <= spec.step_threshold and d_mean <= spec.step_threshold * 2.2)):
				visited[ny][nx] = True
				queue.append((nx, ny))
	return visited


def _connected_components(mask: list[list[bool]]) -> list[list[tuple[int, int]]]:
	height = len(mask)
	width = len(mask[0]) if height else 0
	visited = [[False for _ in range(width)] for _ in range(height)]
	components: list[list[tuple[int, int]]] = []
	for y in range(height):
		for x in range(width):
			if not mask[y][x] or visited[y][x]:
				continue
			component: list[tuple[int, int]] = []
			queue: deque[tuple[int, int]] = deque([(x, y)])
			visited[y][x] = True
			while queue:
				cx, cy = queue.popleft()
				component.append((cx, cy))
				for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
					if nx < 0 or ny < 0 or ny >= height or nx >= width:
						continue
					if visited[ny][nx] or not mask[ny][nx]:
						continue
					visited[ny][nx] = True
					queue.append((nx, ny))
			components.append(component)
	return components


def _component_bbox(component: list[tuple[int, int]]) -> tuple[int, int, int, int]:
	xs = [p[0] for p in component]
	ys = [p[1] for p in component]
	return min(xs), min(ys), max(xs), max(ys)


def _score_component(component: list[tuple[int, int]], width: int, height: int, center_bias: bool) -> float:
	area = float(len(component))
	if not center_bias:
		return area
	min_x, min_y, max_x, max_y = _component_bbox(component)
	center_x = (min_x + max_x) * 0.5
	center_y = (min_y + max_y) * 0.5
	dx = abs(center_x - width * 0.5) / max(1.0, width * 0.5)
	dy = abs(center_y - height * 0.5) / max(1.0, height * 0.5)
	center_bonus = max(0.0, 1.2 - (dx + dy))
	return area * (1.0 + center_bonus)


def _pick_components(mask: list[list[bool]], spec: ComponentSpec) -> list[list[bool]]:
	height = len(mask)
	width = len(mask[0]) if height else 0
	components = _connected_components(mask)
	components = [c for c in components if len(c) >= spec.min_component_area]
	components.sort(key=lambda c: _score_component(c, width, height, spec.center_bias), reverse=True)
	selected = components[:spec.top_components] if spec.keep_mode == "top_n" else components[:1]
	out = [[False for _ in range(width)] for _ in range(height)]
	for component in selected:
		for x, y in component:
			out[y][x] = True
	return out


def _apply_focus_rect(mask: list[list[bool]], focus_rect: list[int] | None) -> list[list[bool]]:
	if not focus_rect:
		return mask
	height = len(mask)
	width = len(mask[0]) if height else 0
	x, y, rect_width, rect_height = focus_rect
	out = [[False for _ in range(width)] for _ in range(height)]
	for py in range(max(0, y), min(height, y + rect_height)):
		for px in range(max(0, x), min(width, x + rect_width)):
			out[py][px] = mask[py][px]
	return out


def _trim_and_pad(
	pixels: list[list[list[int]]],
	mask: list[list[bool]],
	padding: int,
	preserve_canvas: bool,
) -> tuple[int, int, list[list[list[int]]]]:
	height = len(mask)
	width = len(mask[0]) if height else 0
	points = [(x, y) for y in range(height) for x in range(width) if mask[y][x]]
	if not points:
		return width, height, [[[0, 0, 0, 0] for _ in range(width)] for _ in range(height)]
	if preserve_canvas:
		out = [[[0, 0, 0, 0] for _ in range(width)] for _ in range(height)]
		for y in range(height):
			for x in range(width):
				if mask[y][x]:
					out[y][x] = pixels[y][x][:]
		return width, height, out
	xs = [p[0] for p in points]
	ys = [p[1] for p in points]
	min_x = max(0, min(xs) - padding)
	min_y = max(0, min(ys) - padding)
	max_x = min(width - 1, max(xs) + padding)
	max_y = min(height - 1, max(ys) + padding)
	new_w = max_x - min_x + 1
	new_h = max_y - min_y + 1
	out = [[[0, 0, 0, 0] for _ in range(new_w)] for _ in range(new_h)]
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if mask[y][x]:
				out[y - min_y][x - min_x] = pixels[y][x][:]
	return new_w, new_h, out


def _apply_transparent_mask(
	pixels: list[list[list[int]]],
	mask: list[list[bool]],
) -> tuple[int, int, list[list[list[int]]]]:
	height = len(pixels)
	width = len(pixels[0]) if height else 0
	out = [[px[:] for px in row] for row in pixels]
	for y in range(height):
		for x in range(width):
			if mask[y][x]:
				out[y][x] = [0, 0, 0, 0]
	return width, height, out


def _extract_crop_component(source_pixels: list[list[list[int]]], spec: ComponentSpec) -> tuple[int, int, list[list[list[int]]]]:
	if not spec.source_rect:
		raise ValueError(f"{spec.id} missing source_rect for crop extraction")
	width, height, cropped = _crop_pixels(source_pixels, spec.source_rect)
	_clip_to_keep_shapes(cropped, spec)
	_clear_rects(cropped, spec.clear_rects)
	_clear_round_rects(cropped, spec.clear_round_rects)
	_clear_ellipse_rects(cropped, spec.clear_ellipse_rects)
	if spec.trim_alpha:
		return _trim_alpha_bounds(cropped)
	return width, height, cropped


def _extract_mask_component(source_pixels: list[list[list[int]]], spec: ComponentSpec) -> tuple[int, int, list[list[list[int]]]]:
	if not spec.source_rect:
		raise ValueError(f"{spec.id} missing source_rect for clean_mask extraction")
	_, _, cropped = _crop_pixels(source_pixels, spec.source_rect)
	_clear_rects(cropped, spec.clear_rects)
	width = len(cropped[0]) if cropped else 0
	height = len(cropped)
	background_mask = _mark_background(width, height, cropped, spec)
	foreground_mask = [[not background_mask[y][x] for x in range(width)] for y in range(height)]
	foreground_mask = _apply_focus_rect(foreground_mask, spec.focus_rect)
	foreground_mask = _pick_components(foreground_mask, spec)
	return _trim_and_pad(cropped, foreground_mask, spec.padding, spec.preserve_canvas)


def _extract_cutout_component(source_pixels: list[list[list[int]]], spec: ComponentSpec) -> tuple[int, int, list[list[list[int]]]]:
	if not spec.source_rect:
		raise ValueError(f"{spec.id} missing source_rect for cutout extraction")
	_, _, cropped = _crop_pixels(source_pixels, spec.source_rect)
	height = len(cropped)
	width = len(cropped[0]) if height else 0
	mask = [[False for _ in range(width)] for _ in range(height)]
	if spec.alpha_seed_rects:
		seed_points = _seed_points_from_rects(width, height, spec.alpha_seed_rects, spec.seed_stride)
		seed_mask = _mark_seed_region(width, height, cropped, spec, seed_points)
		for y in range(height):
			for x in range(width):
				mask[y][x] = mask[y][x] or seed_mask[y][x]
	if spec.clear_rects:
		for rect in spec.clear_rects:
			x, y, rect_width, rect_height = rect
			for py in range(max(0, y), min(height, y + rect_height)):
				for px in range(max(0, x), min(width, x + rect_width)):
					mask[py][px] = True
	_, _, out = _apply_transparent_mask(cropped, mask)
	_clear_round_rects(out, spec.clear_round_rects)
	_clear_ellipse_rects(out, spec.clear_ellipse_rects)
	return width, height, out


def _component_output_path(profile: ProfileSpec, component: ComponentSpec) -> Path | None:
	if component.extract_mode == "skip":
		return None
	file_name = component.output_name or f"{component.name}.png"
	return ROOT / profile.output_dir / file_name


def _rect_to_string(rect: list[int] | None) -> str:
	if not rect:
		return "--"
	x, y, width, height = rect
	return f"{x}, {y}, {width}, {height}"


def _json_escape(raw: str) -> str:
	return html.escape(raw, quote=True)


def _relative_href(from_dir: Path, to_path: Path) -> str:
	return os.path.relpath(to_path, start=from_dir)


def _build_profile_page(profile: ProfileSpec, manifest: list[dict[str, str]]) -> None:
	page_path = ROOT / profile.review_html
	page_path.parent.mkdir(parents=True, exist_ok=True)
	source_path = ROOT / profile.source
	source_rel = _relative_href(page_path.parent, source_path)

	overlay_markup: list[str] = []
	component_markup: list[str] = []
	for entry in manifest:
		rect = entry.get("source_rect")
		if rect and rect != "--":
			x, y, width, height = [int(part.strip()) for part in rect.split(",")]
			overlay_markup.append(
				f'<div class="overlay" style="left:{x}px;top:{y}px;width:{width}px;height:{height}px;">'
				f'<span>{_json_escape(entry["id"])}</span></div>'
			)

		image_markup = '<div class="thumb empty">保留现状</div>'
		if entry.get("output"):
			output_rel = _relative_href(page_path.parent, ROOT / entry["output"])
			image_markup = f'<img class="thumb" src="{_json_escape(output_rel)}" alt="{_json_escape(entry["name"])}">'

		component_markup.append(
			"""
			<section class="component-card">
			  <div class="component-head">
			    <div class="component-id">{id}</div>
			    <div class="component-name">{name}</div>
			  </div>
			  <div class="component-body">
			    {image_markup}
			    <dl>
			      <div><dt>映射</dt><dd>{mapping}</dd></div>
			      <div><dt>状态</dt><dd>{status}</dd></div>
			      <div><dt>模式</dt><dd>{mode}</dd></div>
			      <div><dt>源框</dt><dd>{rect}</dd></div>
			      <div><dt>9-slice</dt><dd>{nine_slice}</dd></div>
			      <div><dt>输出</dt><dd>{output}</dd></div>
			      <div><dt>备注</dt><dd>{notes}</dd></div>
			    </dl>
			  </div>
			</section>
			""".format(
				id=_json_escape(entry["id"]),
				name=_json_escape(entry["name"]),
				image_markup=image_markup,
				mapping=_json_escape(entry["mapping"]),
				status=_json_escape(entry["status"]),
				mode=_json_escape(entry["mode"]),
				rect=_json_escape(entry.get("source_rect", "--")),
				nine_slice=_json_escape(entry.get("nine_slice", "--")),
				output=_json_escape(entry.get("output", "--")),
				notes=_json_escape(entry.get("notes", "")),
			)
		)

	page_html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{_json_escape(profile.title)}</title>
  <style>
    :root {{
      --bg: #111319;
      --panel: #1b1f28;
      --panel-soft: #232938;
      --border: rgba(255,255,255,.12);
      --text: #eef2f8;
      --muted: #a5afc1;
      --accent: #8fb3ff;
      --warn: #e3ba6c;
      --good: #8fd6a7;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      padding: 28px;
      background: linear-gradient(180deg, #0f1117, #151925);
      color: var(--text);
      font: 14px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    a {{ color: var(--accent); }}
    .page {{ max-width: 1600px; margin: 0 auto; display: grid; gap: 20px; }}
    .hero, .panel {{ background: var(--panel); border: 1px solid var(--border); border-radius: 18px; }}
    .hero {{ padding: 20px 22px; }}
    .hero h1 {{ margin: 0 0 10px; font-size: 28px; }}
    .hero p {{ margin: 0; color: var(--muted); }}
    .panel {{ padding: 18px; }}
    .source-wrap {{ overflow: auto; }}
    .source-canvas {{
      position: relative;
      width: 1280px;
      height: 720px;
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid rgba(255,255,255,.08);
      background: #000;
    }}
    .source-canvas img {{ display: block; width: 1280px; height: 720px; }}
    .overlay {{
      position: absolute;
      border: 2px solid rgba(143, 179, 255, 0.9);
      background: rgba(143, 179, 255, 0.12);
      box-shadow: inset 0 0 0 1px rgba(255,255,255,.16);
    }}
    .overlay span {{
      position: absolute;
      top: 4px;
      left: 4px;
      padding: 2px 6px;
      border-radius: 999px;
      background: rgba(17, 19, 25, 0.86);
      color: var(--text);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: .04em;
    }}
    .component-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 16px;
    }}
    .component-card {{
      background: var(--panel-soft);
      border: 1px solid var(--border);
      border-radius: 16px;
      overflow: hidden;
    }}
    .component-head {{
      padding: 12px 14px;
      border-bottom: 1px solid rgba(255,255,255,.08);
      display: grid;
      gap: 4px;
    }}
    .component-id {{ color: var(--warn); font-weight: 700; letter-spacing: .06em; }}
    .component-name {{ font-size: 17px; font-weight: 700; }}
    .component-body {{
      padding: 14px;
      display: grid;
      gap: 14px;
    }}
    .thumb {{
      width: 100%;
      min-height: 140px;
      object-fit: contain;
      border-radius: 12px;
      background:
        linear-gradient(45deg, rgba(255,255,255,.03) 25%, transparent 25%, transparent 75%, rgba(255,255,255,.03) 75%),
        linear-gradient(45deg, rgba(255,255,255,.03) 25%, transparent 25%, transparent 75%, rgba(255,255,255,.03) 75%);
      background-position: 0 0, 12px 12px;
      background-size: 24px 24px;
      border: 1px solid rgba(255,255,255,.08);
      display: block;
    }}
    .thumb.empty {{
      display: grid;
      place-items: center;
      color: var(--muted);
      font-weight: 600;
    }}
    dl {{
      margin: 0;
      display: grid;
      gap: 10px;
    }}
    dl div {{
      display: grid;
      gap: 4px;
    }}
    dt {{
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: .08em;
    }}
    dd {{
      margin: 0;
      color: var(--text);
      word-break: break-word;
    }}
  </style>
</head>
<body>
  <main class="page">
    <section class="hero">
      <a href="index.html">返回总览</a>
      <h1>{_json_escape(profile.title)}</h1>
      <p>{_json_escape(profile.description)}</p>
    </section>
    <section class="panel">
      <h2>源图标注</h2>
      <div class="source-wrap">
        <div class="source-canvas">
          <img src="{_json_escape(str(source_rel))}" alt="{_json_escape(profile.title)}">
          {''.join(overlay_markup)}
        </div>
      </div>
    </section>
    <section class="panel">
      <h2>控件候选与映射</h2>
      <div class="component-grid">
        {''.join(component_markup)}
      </div>
    </section>
  </main>
</body>
</html>
"""
	page_path.write_text(page_html, encoding="utf-8")


def _build_root_index(profiles: list[ProfileSpec]) -> None:
	index_path = REVIEW_ROOT / "index.html"
	index_path.parent.mkdir(parents=True, exist_ok=True)
	items = []
	for profile in profiles:
		page_name = Path(profile.review_html).name
		manifest_name = Path(profile.manifest_md).name
		items.append(
			f"""
			<section class="card">
			  <h2>{_json_escape(profile.title)}</h2>
			  <p>{_json_escape(profile.description)}</p>
			  <div class="links">
			    <a href="{_json_escape(page_name)}">打开评审页</a>
			    <a href="{_json_escape(manifest_name)}">查看清单</a>
			  </div>
			</section>
			"""
		)
	index_html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AFK-RPG UI Component Review</title>
  <style>
    body {{
      margin: 0;
      padding: 28px;
      background: linear-gradient(180deg, #0f1117, #171c28);
      color: #eef2f8;
      font: 14px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    main {{ max-width: 1200px; margin: 0 auto; display: grid; gap: 18px; }}
    .hero, .card {{
      background: rgba(27, 31, 40, 0.96);
      border: 1px solid rgba(255,255,255,.12);
      border-radius: 18px;
    }}
    .hero {{ padding: 22px; }}
    .hero h1 {{ margin: 0 0 8px; font-size: 30px; }}
    .hero p {{ margin: 0; color: #a5afc1; }}
    .grid {{ display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); }}
    .card {{ padding: 18px; }}
    .card h2 {{ margin: 0 0 8px; font-size: 22px; }}
    .card p {{ margin: 0 0 14px; color: #a5afc1; }}
    .links {{ display: flex; gap: 12px; flex-wrap: wrap; }}
    a {{ color: #8fb3ff; }}
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <h1>AFK-RPG UI 控件评审总览</h1>
      <p>本页汇总 HUD 与背包两组示意图切控件结果。当前仅产出评审与清单，不接入场景资源。</p>
    </section>
    <section class="grid">
      {''.join(items)}
    </section>
  </main>
</body>
</html>
"""
	index_path.write_text(index_html, encoding="utf-8")


def _write_manifest(profile: ProfileSpec, manifest: list[dict[str, str]]) -> None:
	manifest_path = ROOT / profile.manifest_md
	manifest_path.parent.mkdir(parents=True, exist_ok=True)
	lines = [
		f"# {profile.title}",
		"",
		profile.description,
		"",
		"| ID | 名称 | 映射 | 状态 | 模式 | 源框 | 9-slice | 输出 | 备注 |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	for entry in manifest:
		lines.append(
			"| {id} | {name} | {mapping} | {status} | {mode} | {rect} | {nine_slice} | {output} | {notes} |".format(
				id=entry["id"],
				name=entry["name"],
				mapping=entry["mapping"],
				status=entry["status"],
				mode=entry["mode"],
				rect=entry.get("source_rect", "--"),
				nine_slice=entry.get("nine_slice", "--"),
				output=entry.get("output", "--"),
				notes=entry.get("notes", ""),
			)
		)
	manifest_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _process_profile(profile: ProfileSpec) -> dict[str, object]:
	source_path = ROOT / profile.source
	_, _, source_pixels = _read_png(source_path)
	manifest: list[dict[str, str]] = []

	for component in profile.components:
		output_path = _component_output_path(profile, component)
		output_rel = str(output_path.relative_to(ROOT)) if output_path else ""
		if component.extract_mode == "skip":
			manifest.append(
				{
					"id": component.id,
					"name": component.name,
					"mapping": component.mapping,
					"status": component.status,
					"mode": component.extract_mode,
					"source_rect": _rect_to_string(component.source_rect),
					"nine_slice": _rect_to_string(component.nine_slice),
					"output": output_rel,
					"notes": component.notes or "首轮保留现状，不生成替换资源",
				}
			)
			continue

		if component.extract_mode == "clean_mask":
			width, height, extracted = _extract_mask_component(source_pixels, component)
		elif component.extract_mode == "cutout":
			width, height, extracted = _extract_cutout_component(source_pixels, component)
		else:
			width, height, extracted = _extract_crop_component(source_pixels, component)
		if output_path is None:
			raise ValueError(f"{component.id} missing output path")
		_write_png(output_path, width, height, extracted)
		manifest.append(
			{
				"id": component.id,
				"name": component.name,
				"mapping": component.mapping,
				"status": component.status,
				"mode": component.extract_mode,
				"source_rect": _rect_to_string(component.source_rect),
				"nine_slice": _rect_to_string(component.nine_slice),
				"output": output_rel,
				"notes": component.notes,
			}
		)

	_build_profile_page(profile, manifest)
	_write_manifest(profile, manifest)
	return {
		"profile": profile.id,
		"source": profile.source,
		"review_html": profile.review_html,
		"manifest_md": profile.manifest_md,
		"components": manifest,
	}


def main() -> int:
	parser = argparse.ArgumentParser(
		description="Extract candidate UI components from review boards and generate HTML review pages."
	)
	parser.add_argument(
		"--profile",
		nargs="*",
		default=[],
		help="Optional profile ids to process. Defaults to all profiles in ui_component_specs.json.",
	)
	args = parser.parse_args()

	results: list[dict[str, object]] = []
	profiles = _parse_specs()
	selected_profiles: list[ProfileSpec] = []
	for profile in profiles:
		if args.profile and profile.id not in args.profile:
			continue
		selected_profiles.append(profile)
		results.append(_process_profile(profile))

	_build_root_index(selected_profiles)
	print(json.dumps(results, ensure_ascii=False, indent=2))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
