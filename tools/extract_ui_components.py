#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import struct
import zlib
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
SOURCE_DIR = ROOT / "assets" / "generated" / "ui_runtime_extracts"
OUTPUT_DIR = ROOT / "assets" / "generated" / "ui_runtime_extracts_clean"
DEBUG_DIR = OUTPUT_DIR / "_debug_masks"
SPEC_PATH = ROOT / "tools" / "hud_component_specs.json"


@dataclass
class ComponentSpec:
	name: str
	source: str
	keep_mode: str = "largest"
	top_components: int = 1
	padding: int = 8
	seed_stride: int = 2
	step_threshold: int = 34
	bin_step: int = 16
	edge_threshold: int = 52
	min_component_area: int = 48
	center_bias: bool = True
	focus_rect: list[int] | None = None
	clear_rects: list[list[int]] | None = None
	preserve_canvas: bool = False


def _parse_specs() -> list[ComponentSpec]:
	data = json.loads(SPEC_PATH.read_text(encoding="utf-8"))
	return [ComponentSpec(**entry) for entry in data]


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
	for x in range(0, width, stride):
		points.append((x, 0))
		points.append((x, height - 1))
	for y in range(1, height - 1, stride):
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
	if spec.keep_mode == "top_n":
		selected = components[:spec.top_components]
	else:
		selected = components[:1]
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
	x0, y0, x1, y1 = focus_rect
	out = [[False for _ in range(width)] for _ in range(height)]
	for y in range(max(0, y0), min(height, y1)):
		for x in range(max(0, x0), min(width, x1)):
			out[y][x] = mask[y][x]
	return out


def _apply_clear_rects(mask: list[list[bool]], clear_rects: list[list[int]] | None) -> None:
	if not clear_rects:
		return
	height = len(mask)
	width = len(mask[0]) if height else 0
	for rect in clear_rects:
		x0, y0, x1, y1 = rect
		for y in range(max(0, y0), min(height, y1)):
			for x in range(max(0, x0), min(width, x1)):
				mask[y][x] = False


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


def _mask_to_debug(mask: list[list[bool]]) -> tuple[int, int, list[list[list[int]]]]:
	height = len(mask)
	width = len(mask[0]) if height else 0
	out = [[[255, 255, 255, 255] if mask[y][x] else [0, 0, 0, 255] for x in range(width)] for y in range(height)]
	return width, height, out


def _process_component(spec: ComponentSpec) -> dict[str, str]:
	source_path = SOURCE_DIR / spec.source
	width, height, pixels = _read_png(source_path)
	background_mask = _mark_background(width, height, pixels, spec)
	foreground_mask = [[not background_mask[y][x] for x in range(width)] for y in range(height)]
	foreground_mask = _apply_focus_rect(foreground_mask, spec.focus_rect)
	foreground_mask = _pick_components(foreground_mask, spec)
	_apply_clear_rects(foreground_mask, spec.clear_rects)
	out_width, out_height, cleaned = _trim_and_pad(pixels, foreground_mask, spec.padding, spec.preserve_canvas)

	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	DEBUG_DIR.mkdir(parents=True, exist_ok=True)

	output_path = OUTPUT_DIR / f"{spec.name}.png"
	_write_png(output_path, out_width, out_height, cleaned)

	bg_mask_path = DEBUG_DIR / f"{spec.name}__background_mask.png"
	fg_mask_path = DEBUG_DIR / f"{spec.name}__foreground_mask.png"
	bg_w, bg_h, bg_pixels = _mask_to_debug(background_mask)
	fg_w, fg_h, fg_pixels = _mask_to_debug(foreground_mask)
	_write_png(bg_mask_path, bg_w, bg_h, bg_pixels)
	_write_png(fg_mask_path, fg_w, fg_h, fg_pixels)

	return {
		"name": spec.name,
		"source": str(source_path.relative_to(ROOT)),
		"output": str(output_path.relative_to(ROOT)),
		"background_mask": str(bg_mask_path.relative_to(ROOT)),
		"foreground_mask": str(fg_mask_path.relative_to(ROOT)),
	}


def main() -> int:
	parser = argparse.ArgumentParser(description="Extract clean transparent HUD components from rough crops.")
	parser.add_argument("--only", nargs="*", default=[], help="Optional component names to process")
	args = parser.parse_args()

	results: list[dict[str, str]] = []
	for spec in _parse_specs():
		if args.only and spec.name not in args.only:
			continue
		results.append(_process_component(spec))

	print(json.dumps(results, ensure_ascii=False, indent=2))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
