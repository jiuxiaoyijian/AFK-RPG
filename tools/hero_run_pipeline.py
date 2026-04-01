#!/usr/bin/env python3
from __future__ import annotations

import math
import struct
import zlib
from collections import deque
from pathlib import Path
from typing import Iterable, Sequence, Tuple


def _iter_chunks(payload: bytes) -> Iterable[tuple[bytes, bytes]]:
	offset = 8
	while offset + 8 <= len(payload):
		length = struct.unpack(">I", payload[offset:offset + 4])[0]
		offset += 4
		chunk_type = payload[offset:offset + 4]
		offset += 4
		chunk_data = payload[offset:offset + length]
		offset += length
		offset += 4
		yield chunk_type, chunk_data
		if chunk_type == b"IEND":
			break


def load_rgba_png(path: Path) -> Tuple[int, int, bytearray]:
	payload = path.read_bytes()
	if payload[:8] != b"\x89PNG\r\n\x1a\n":
		raise ValueError(f"Unsupported PNG signature: {path}")

	width = 0
	height = 0
	bit_depth = 0
	color_type = 0
	compressed = bytearray()
	for chunk_type, chunk_data in _iter_chunks(payload):
		if chunk_type == b"IHDR":
			width, height, bit_depth, color_type, _compression, _filter, _interlace = struct.unpack(
				">IIBBBBB", chunk_data
			)
			if bit_depth != 8 or color_type not in {2, 6}:
				raise ValueError(f"Only 8-bit RGB/RGBA PNG is supported: {path}")
		elif chunk_type == b"IDAT":
			compressed.extend(chunk_data)

	raw = zlib.decompress(bytes(compressed))
	bytes_per_pixel = 4 if color_type == 6 else 3
	stride = width * bytes_per_pixel
	pixels = bytearray(width * height * 4)
	src = 0
	prev = bytearray(stride)
	for y in range(height):
		filter_type = raw[src]
		src += 1
		row = bytearray(raw[src:src + stride])
		src += stride

		if filter_type == 1:
			for i in range(bytes_per_pixel, stride):
				row[i] = (row[i] + row[i - bytes_per_pixel]) & 0xFF
		elif filter_type == 2:
			for i in range(stride):
				row[i] = (row[i] + prev[i]) & 0xFF
		elif filter_type == 3:
			for i in range(stride):
				left = row[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
				up = prev[i]
				row[i] = (row[i] + ((left + up) // 2)) & 0xFF
		elif filter_type == 4:
			for i in range(stride):
				a = row[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
				b = prev[i]
				c = prev[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
				p = a + b - c
				pa = abs(p - a)
				pb = abs(p - b)
				pc = abs(p - c)
				predictor = a
				if pb <= pa and pb <= pc:
					predictor = b
				elif pc < pa and pc < pb:
					predictor = c
				row[i] = (row[i] + predictor) & 0xFF
		elif filter_type != 0:
			raise ValueError(f"Unsupported PNG filter type {filter_type}: {path}")

		if color_type == 6:
			dst = y * width * 4
			pixels[dst:dst + width * 4] = row
		else:
			for x in range(width):
				src_i = x * 3
				dst_i = (y * width + x) * 4
				pixels[dst_i] = row[src_i]
				pixels[dst_i + 1] = row[src_i + 1]
				pixels[dst_i + 2] = row[src_i + 2]
				pixels[dst_i + 3] = 255
		prev = row
	return width, height, pixels


def save_rgba_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	stride = width * 4
	raw = bytearray()
	for y in range(height):
		raw.append(0)
		start = y * stride
		raw.extend(pixels[start:start + stride])

	def chunk(tag: bytes, data: bytes) -> bytes:
		crc = zlib.crc32(tag + data) & 0xFFFFFFFF
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

	png = bytearray()
	png.extend(b"\x89PNG\r\n\x1a\n")
	png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
	png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
	png.extend(chunk(b"IEND", b""))
	path.write_bytes(png)


def make_canvas(width: int, height: int, color: tuple[int, int, int, int] = (0, 0, 0, 0)) -> bytearray:
	r, g, b, a = color
	return bytearray([r, g, b, a] * (width * height))


def blit_rgba(
	dst_pixels: bytearray,
	dst_width: int,
	dst_height: int,
	src_pixels: bytearray,
	src_width: int,
	src_height: int,
	offset_x: int,
	offset_y: int,
) -> None:
	for y in range(src_height):
		dst_y = y + offset_y
		if dst_y < 0 or dst_y >= dst_height:
			continue
		for x in range(src_width):
			dst_x = x + offset_x
			if dst_x < 0 or dst_x >= dst_width:
				continue
			src_i = (y * src_width + x) * 4
			alpha = src_pixels[src_i + 3]
			if alpha <= 0:
				continue
			dst_i = (dst_y * dst_width + dst_x) * 4
			src_a = alpha / 255.0
			dst_a = dst_pixels[dst_i + 3] / 255.0
			out_a = src_a + dst_a * (1.0 - src_a)
			if out_a <= 0.0:
				continue
			for channel in range(3):
				src_v = src_pixels[src_i + channel]
				dst_v = dst_pixels[dst_i + channel]
				out_v = int((src_v * src_a + dst_v * dst_a * (1.0 - src_a)) / out_a)
				dst_pixels[dst_i + channel] = max(0, min(255, out_v))
			dst_pixels[dst_i + 3] = max(0, min(255, int(round(out_a * 255.0))))


def resize_rgba_nearest(
	src_pixels: bytearray,
	src_width: int,
	src_height: int,
	target_width: int,
	target_height: int,
) -> bytearray:
	if src_width == target_width and src_height == target_height:
		return bytearray(src_pixels)
	dst = bytearray(target_width * target_height * 4)
	for y in range(target_height):
		src_y = min(src_height - 1, int(y * src_height / target_height))
		for x in range(target_width):
			src_x = min(src_width - 1, int(x * src_width / target_width))
			src_i = (src_y * src_width + src_x) * 4
			dst_i = (y * target_width + x) * 4
			dst[dst_i:dst_i + 4] = src_pixels[src_i:src_i + 4]
	return dst


def estimate_background_rgb(width: int, height: int, pixels: bytearray) -> tuple[float, float, float]:
	samples: list[tuple[int, int, int]] = []
	positions = [
		(0, 0),
		(max(0, width - 1), 0),
		(0, max(0, height - 1)),
		(max(0, width - 1), max(0, height - 1)),
		(width // 2, 0),
		(width // 2, max(0, height - 1)),
	]
	for x, y in positions:
		index = (y * width + x) * 4
		samples.append((pixels[index], pixels[index + 1], pixels[index + 2]))
	r = sum(sample[0] for sample in samples) / len(samples)
	g = sum(sample[1] for sample in samples) / len(samples)
	b = sum(sample[2] for sample in samples) / len(samples)
	return r, g, b


def _dominant_border_colors(
	width: int,
	height: int,
	pixels: bytearray,
	max_colors: int = 2,
	quantize: int = 24,
) -> list[tuple[float, float, float]]:
	counts: dict[tuple[int, int, int], int] = {}
	sums: dict[tuple[int, int, int], list[int]] = {}
	step = max(1, min(width, height) // 120)
	border_points: list[tuple[int, int]] = []
	for x in range(0, width, step):
		border_points.append((x, 0))
		border_points.append((x, height - 1))
	for y in range(0, height, step):
		border_points.append((0, y))
		border_points.append((width - 1, y))
	for x, y in border_points:
		index = (y * width + x) * 4
		r = pixels[index]
		g = pixels[index + 1]
		b = pixels[index + 2]
		bucket = (r // quantize, g // quantize, b // quantize)
		counts[bucket] = counts.get(bucket, 0) + 1
		if bucket not in sums:
			sums[bucket] = [0, 0, 0]
		sums[bucket][0] += r
		sums[bucket][1] += g
		sums[bucket][2] += b
	dominant: list[tuple[float, float, float]] = []
	for bucket, _count in sorted(counts.items(), key=lambda item: item[1], reverse=True)[:max_colors]:
		total = counts[bucket]
		r_sum, g_sum, b_sum = sums[bucket]
		dominant.append((r_sum / total, g_sum / total, b_sum / total))
	return dominant


def _largest_component(mask: Sequence[bool], width: int, height: int) -> list[bool]:
	visited = [False] * len(mask)
	best_indices: list[int] = []
	for start, is_foreground in enumerate(mask):
		if not is_foreground or visited[start]:
			continue
		queue: deque[int] = deque([start])
		visited[start] = True
		component: list[int] = []
		while queue:
			index = queue.popleft()
			component.append(index)
			x = index % width
			y = index // width
			for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				neighbor = ny * width + nx
				if visited[neighbor] or not mask[neighbor]:
					continue
				visited[neighbor] = True
				queue.append(neighbor)
		if len(component) > len(best_indices):
			best_indices = component
	filtered = [False] * len(mask)
	for index in best_indices:
		filtered[index] = True
	return filtered


def _border_background_mask(
	width: int,
	height: int,
	pixels: bytearray,
	seed_threshold: float = 18.0,
	grow_threshold: float = 28.0,
) -> list[bool]:
	background_colors = _dominant_border_colors(width, height, pixels, max_colors=4)
	if not background_colors:
		background_colors = [estimate_background_rgb(width, height, pixels)]

	def min_distance(x: int, y: int) -> float:
		index = (y * width + x) * 4
		r = pixels[index]
		g = pixels[index + 1]
		b = pixels[index + 2]
		distances = []
		for bg_r, bg_g, bg_b in background_colors:
			dr = r - bg_r
			dg = g - bg_g
			db = b - bg_b
			distances.append(math.sqrt(dr * dr + dg * dg + db * db))
		return min(distances)

	background = [False] * (width * height)
	queue: deque[int] = deque()
	for x in range(width):
		for y in (0, height - 1):
			if min_distance(x, y) <= seed_threshold:
				index = y * width + x
				background[index] = True
				queue.append(index)
	for y in range(height):
		for x in (0, width - 1):
			if min_distance(x, y) <= seed_threshold:
				index = y * width + x
				if not background[index]:
					background[index] = True
					queue.append(index)
	while queue:
		index = queue.popleft()
		x = index % width
		y = index // width
		for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			neighbor = ny * width + nx
			if background[neighbor]:
				continue
			if min_distance(nx, ny) <= grow_threshold:
				background[neighbor] = True
				queue.append(neighbor)
	return background


def remove_border_background(
	width: int,
	height: int,
	pixels: bytearray,
	seed_threshold: float = 18.0,
	grow_threshold: float = 28.0,
) -> bytearray:
	background = _border_background_mask(width, height, pixels, seed_threshold, grow_threshold)
	output = bytearray(pixels)
	for index, is_background in enumerate(background):
		if not is_background:
			continue
		pixel_i = index * 4
		output[pixel_i + 3] = 0
	mask = [output[index * 4 + 3] > 0 for index in range(width * height)]
	if any(mask):
		mask = _largest_component(mask, width, height)
		for index, is_subject in enumerate(mask):
			if is_subject:
				continue
			pixel_i = index * 4
			output[pixel_i + 3] = 0
	return output


def erode_foreground_mask(
	mask: Sequence[bool],
	width: int,
	height: int,
	radius: int,
) -> list[bool]:
	if radius <= 0:
		return list(mask)
	current = list(mask)
	for _ in range(radius):
		next_mask = [False] * len(current)
		for index, is_foreground in enumerate(current):
			if not is_foreground:
				continue
			x = index % width
			y = index // width
			keep = True
			for nx, ny in (
				(x - 1, y),
				(x + 1, y),
				(x, y - 1),
				(x, y + 1),
				(x - 1, y - 1),
				(x + 1, y - 1),
				(x - 1, y + 1),
				(x + 1, y + 1),
			):
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					keep = False
					break
				if not current[ny * width + nx]:
					keep = False
					break
			next_mask[index] = keep
		current = next_mask
	return current


def trim_foreground_edges(
	width: int,
	height: int,
	pixels: bytearray,
	trim_radius: int = 0,
	alpha_threshold: int = 8,
) -> bytearray:
	if trim_radius <= 0:
		return bytearray(pixels)
	mask = [pixels[index * 4 + 3] > alpha_threshold for index in range(width * height)]
	if not any(mask):
		return bytearray(pixels)
	trimmed_mask = erode_foreground_mask(mask, width, height, trim_radius)
	output = bytearray(pixels)
	for index, keep in enumerate(trimmed_mask):
		if keep:
			continue
		pixel_i = index * 4
		output[pixel_i + 3] = 0
	return output


def build_foreground_mask(
	width: int,
	height: int,
	pixels: bytearray,
	alpha_threshold: int = 16,
	background_threshold: float = 42.0,
) -> list[bool]:
	has_transparency = any(pixels[index + 3] < 250 for index in range(0, len(pixels), 4))
	mask = [False] * (width * height)
	if has_transparency:
		for index in range(width * height):
			mask[index] = pixels[index * 4 + 3] > alpha_threshold
	else:
		background_colors = _dominant_border_colors(width, height, pixels, max_colors=2)
		if not background_colors:
			background_colors = [estimate_background_rgb(width, height, pixels)]
		for index in range(width * height):
			pixel_i = index * 4
			distances = []
			for bg_r, bg_g, bg_b in background_colors:
				dr = pixels[pixel_i] - bg_r
				dg = pixels[pixel_i + 1] - bg_g
				db = pixels[pixel_i + 2] - bg_b
				distances.append(math.sqrt(dr * dr + dg * dg + db * db))
			mask[index] = min(distances) >= background_threshold
	if any(mask):
		mask = _largest_component(mask, width, height)
	return mask


def compute_mask_metrics(width: int, height: int, mask: Sequence[bool]) -> dict | None:
	indices = [index for index, enabled in enumerate(mask) if enabled]
	if not indices:
		return None
	min_x = width
	min_y = height
	max_x = 0
	max_y = 0
	for index in indices:
		x = index % width
		y = index // width
		if x < min_x:
			min_x = x
		if y < min_y:
			min_y = y
		if x > max_x:
			max_x = x
		if y > max_y:
			max_y = y
	return {
		"bbox": [min_x, min_y, max_x, max_y],
		"center_x": (min_x + max_x) / 2.0,
		"head_y": min_y,
		"foot_y": max_y,
		"body_height": max_y - min_y + 1,
		"area": len(indices),
	}


def compute_frame_metrics(
	path: Path,
	alpha_threshold: int = 16,
	background_threshold: float = 42.0,
) -> dict | None:
	width, height, pixels = load_rgba_png(path)
	mask = build_foreground_mask(width, height, pixels, alpha_threshold, background_threshold)
	metrics = compute_mask_metrics(width, height, mask)
	if metrics is None:
		return None
	return {
		"path": str(path),
		"width": width,
		"height": height,
		**metrics,
	}


def stabilize_rgba_frame(
	path: Path,
	output_path: Path,
	anchor_x: int,
	foot_y: int | None,
	canvas_width: int,
	canvas_height: int,
	head_y: int | None = None,
	alpha_threshold: int = 16,
	background_threshold: float = 42.0,
) -> dict:
	width, height, pixels = load_rgba_png(path)
	mask = build_foreground_mask(width, height, pixels, alpha_threshold, background_threshold)
	metrics = compute_mask_metrics(width, height, mask)
	if metrics is None:
		raise ValueError(f"No foreground subject detected in {path}")
	dx = int(round(anchor_x - float(metrics["center_x"])))
	var_target_y = head_y if head_y is not None else foot_y
	var_source_y = metrics["head_y"] if head_y is not None else metrics["foot_y"]
	dy = int(round(float(var_target_y) - float(var_source_y)))
	canvas = make_canvas(canvas_width, canvas_height, (0, 0, 0, 0))
	blit_rgba(canvas, canvas_width, canvas_height, pixels, width, height, dx, dy)
	save_rgba_png(output_path, canvas_width, canvas_height, canvas)
	stabilized_metrics = compute_frame_metrics(output_path, alpha_threshold, background_threshold)
	if stabilized_metrics is None:
		raise ValueError(f"Stabilized frame lost its subject: {output_path}")
	return {
		"input_path": str(path),
		"output_path": str(output_path),
		"offset_x": dx,
		"offset_y": dy,
		"input_metrics": metrics,
		"output_metrics": {
			"bbox": stabilized_metrics["bbox"],
			"center_x": stabilized_metrics["center_x"],
			"head_y": stabilized_metrics["head_y"],
			"foot_y": stabilized_metrics["foot_y"],
			"body_height": stabilized_metrics["body_height"],
			"area": stabilized_metrics["area"],
		},
	}


def stabilize_rgba_sequence(
	frame_paths: Sequence[Path],
	output_paths: Sequence[Path],
	anchor_x: int,
	foot_y: int | None,
	canvas_width: int,
	canvas_height: int,
	head_y: int | None = None,
	alpha_threshold: int = 16,
	background_threshold: float = 42.0,
) -> list[dict]:
	if len(frame_paths) != len(output_paths):
		raise ValueError("frame_paths and output_paths must have the same length")
	report: list[dict] = []
	for frame_path, output_path in zip(frame_paths, output_paths):
		report.append(
			stabilize_rgba_frame(
				frame_path,
				output_path,
				anchor_x,
				foot_y,
				canvas_width,
				canvas_height,
				head_y,
				alpha_threshold,
				background_threshold,
			)
		)
	return report
