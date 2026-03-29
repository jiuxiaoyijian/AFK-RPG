#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
FORMAL_BACKGROUND_DIR = ROOT / "assets" / "generated" / "afk_rpg_formal" / "backgrounds"
DEFAULT_SOURCE = ROOT / "assets" / "generated" / "formal_replacement_samples" / "backgrounds" / "chapter1_master_concept_v1.png"


@dataclass(frozen=True)
class LayerProfile:
	horizon_ratio: float
	sky_end_ratio: float
	far_end_ratio: float
	near_back_start_ratio: float
	near_front_top_ratio: float
	near_edge_width_ratio: float
	lane_clear_ratio: float
	loop_safe_ratio: float
	near_front_detail_soft: float
	near_front_detail_hard: float
	near_back_detail_soft: float
	near_back_detail_hard: float
	sky_luma_soft: float
	sky_luma_hard: float


PROFILES: Dict[str, LayerProfile] = {
	"chapter1_town_road": LayerProfile(
		horizon_ratio=0.33,
		sky_end_ratio=0.34,
		far_end_ratio=0.66,
		near_back_start_ratio=0.54,
		near_front_top_ratio=0.22,
		near_edge_width_ratio=0.22,
		lane_clear_ratio=0.26,
		loop_safe_ratio=0.12,
		near_front_detail_soft=0.08,
		near_front_detail_hard=0.22,
		near_back_detail_soft=0.06,
		near_back_detail_hard=0.20,
		sky_luma_soft=0.50,
		sky_luma_hard=0.74,
	),
}


def _iter_chunks(payload: bytes) -> Iterable[Tuple[bytes, bytes]]:
	offset = 8
	while offset < len(payload):
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


def _save_grayscale_mask(path: Path, width: int, height: int, values: Sequence[float]) -> None:
	pixels = bytearray(width * height * 4)
	for idx, value in enumerate(values):
		v = _clamp(max(0.0, min(1.0, value)) * 255.0)
		i = idx * 4
		pixels[i] = v
		pixels[i + 1] = v
		pixels[i + 2] = v
		pixels[i + 3] = 255
	save_rgba_png(path, width, height, pixels)


def _clamp(value: float) -> int:
	return max(0, min(255, int(round(value))))


def _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if edge0 == edge1:
		return 0.0
	t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
	return t * t * (3.0 - 2.0 * t)


def _lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


def _sample_bilinear(width: int, height: int, pixels: bytearray, fx: float, fy: float) -> Tuple[float, float, float, float]:
	fx = max(0.0, min(width - 1.001, fx))
	fy = max(0.0, min(height - 1.001, fy))
	x0 = int(math.floor(fx))
	y0 = int(math.floor(fy))
	x1 = min(width - 1, x0 + 1)
	y1 = min(height - 1, y0 + 1)
	tx = fx - x0
	ty = fy - y0

	def rgba_at(px: int, py: int) -> Tuple[int, int, int, int]:
		i = (py * width + px) * 4
		return pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]

	c00 = rgba_at(x0, y0)
	c10 = rgba_at(x1, y0)
	c01 = rgba_at(x0, y1)
	c11 = rgba_at(x1, y1)
	result = []
	for idx in range(4):
		top = _lerp(c00[idx], c10[idx], tx)
		bottom = _lerp(c01[idx], c11[idx], tx)
		result.append(_lerp(top, bottom, ty))
	return result[0], result[1], result[2], result[3]


def _resize_bilinear(src_w: int, src_h: int, src: bytearray, dst_w: int, dst_h: int) -> bytearray:
	dst = bytearray(dst_w * dst_h * 4)
	x_ratio = src_w / float(dst_w)
	y_ratio = src_h / float(dst_h)
	for y in range(dst_h):
		fy = (y + 0.5) * y_ratio - 0.5
		for x in range(dst_w):
			fx = (x + 0.5) * x_ratio - 0.5
			r, g, b, a = _sample_bilinear(src_w, src_h, src, fx, fy)
			i = (y * dst_w + x) * 4
			dst[i] = _clamp(r)
			dst[i + 1] = _clamp(g)
			dst[i + 2] = _clamp(b)
			dst[i + 3] = _clamp(a)
	return dst


def build_master_strip(width: int, height: int, src: bytearray, target_width: int, target_height: int) -> bytearray:
	return _resize_bilinear(width, height, src, target_width, target_height)


def apply_loop_safe(width: int, height: int, src: bytearray, seam_ratio: float) -> bytearray:
	dst = bytearray(src)
	seam_width = max(24, int(round(width * seam_ratio)))
	for y in range(height):
		for x in range(seam_width):
			left_i = (y * width + x) * 4
			right_x = width - seam_width + x
			right_i = (y * width + right_x) * 4
			t = _smoothstep(0.0, 1.0, x / max(1.0, seam_width - 1.0))
			for c in range(4):
				left = src[left_i + c]
				right = src[right_i + c]
				paired = _lerp(left, right, 0.5)
				dst[left_i + c] = _clamp(_lerp(paired, left, t))
				dst[right_i + c] = _clamp(_lerp(right, paired, 1.0 - t))
	return dst


def _brightness(r: int, g: int, b: int) -> float:
	return (r * 0.299 + g * 0.587 + b * 0.114) / 255.0


def _saturation(r: int, g: int, b: int) -> float:
	max_c = max(r, g, b) / 255.0
	min_c = min(r, g, b) / 255.0
	if max_c <= 0.0:
		return 0.0
	return (max_c - min_c) / max_c


def _build_content_maps(width: int, height: int, src: bytearray) -> Dict[str, List[float]]:
	luma_map: List[float] = [0.0] * (width * height)
	saturation_map: List[float] = [0.0] * (width * height)
	detail_map: List[float] = [0.0] * (width * height)
	object_map: List[float] = [0.0] * (width * height)
	sky_bias_map: List[float] = [0.0] * (width * height)

	for y in range(height):
		for x in range(width):
			i = (y * width + x) * 4
			idx = y * width + x
			r = src[i]
			g = src[i + 1]
			b = src[i + 2]
			luma = _brightness(r, g, b)
			saturation = _saturation(r, g, b)
			luma_map[idx] = luma
			saturation_map[idx] = saturation

	for y in range(height):
		for x in range(width):
			idx = y * width + x
			luma = luma_map[idx]
			saturation = saturation_map[idx]
			left = luma_map[idx - 1] if x > 0 else luma
			right = luma_map[idx + 1] if x + 1 < width else luma
			up = luma_map[idx - width] if y > 0 else luma
			down = luma_map[idx + width] if y + 1 < height else luma
			edge_strength = abs(left - right) * 0.55 + abs(up - down) * 0.75
			detail = min(1.0, edge_strength * 2.1 + saturation * 0.18)
			objectness = min(1.0, detail * 0.85 + (1.0 - _smoothstep(0.62, 0.9, luma)) * 0.32)
			sky_bias = min(1.0, _smoothstep(0.45, 0.84, luma) * (1.0 - detail * 0.65))
			detail_map[idx] = detail
			object_map[idx] = objectness
			sky_bias_map[idx] = sky_bias

	return {
		"luma": luma_map,
		"saturation": saturation_map,
		"detail": detail_map,
		"object": object_map,
		"sky_bias": sky_bias_map,
	}


def _downsample_blur(width: int, height: int, src: bytearray, divisor: int) -> bytearray:
	target_w = max(16, width // divisor)
	target_h = max(16, height // divisor)
	mini = _resize_bilinear(width, height, src, target_w, target_h)
	return _resize_bilinear(target_w, target_h, mini, width, height)


def _lane_clear_factor(x_ratio: float, profile: LayerProfile) -> float:
	center_distance = abs(x_ratio - 0.5) / 0.5
	center_clear = 1.0 - _smoothstep(0.0, profile.lane_clear_ratio, center_distance)
	return 1.0 - center_clear * 0.95


def _build_candidate_masks(width: int, height: int, content: Dict[str, List[float]], profile: LayerProfile) -> Dict[str, List[float]]:
	sky_mask: List[float] = [0.0] * (width * height)
	far_mask: List[float] = [0.0] * (width * height)
	mid_mask: List[float] = [0.0] * (width * height)
	near_back_mask: List[float] = [0.0] * (width * height)
	near_front_mask: List[float] = [0.0] * (width * height)

	for y in range(height):
		y_ratio = y / max(1, height - 1)
		top_region = 1.0 - _smoothstep(profile.near_front_top_ratio, profile.near_front_top_ratio + 0.08, y_ratio)
		sky_region = 1.0 - _smoothstep(profile.horizon_ratio * 0.74, profile.sky_end_ratio, y_ratio)
		upper_region = 1.0 - _smoothstep(profile.horizon_ratio, profile.far_end_ratio, y_ratio)
		bottom_region = _smoothstep(profile.near_back_start_ratio, 1.0, y_ratio)
		mid_vertical = _smoothstep(profile.horizon_ratio * 0.55, profile.horizon_ratio + 0.06, y_ratio) * (1.0 - _smoothstep(profile.near_back_start_ratio, 1.0, y_ratio) * 0.38)
		for x in range(width):
			x_ratio = x / max(1, width - 1)
			idx = y * width + x
			edge_pull = 0.0
			if x_ratio < profile.near_edge_width_ratio:
				edge_pull = 1.0 - _smoothstep(0.0, profile.near_edge_width_ratio, x_ratio)
			elif x_ratio > 1.0 - profile.near_edge_width_ratio:
				edge_pull = _smoothstep(1.0 - profile.near_edge_width_ratio, 1.0, x_ratio)
			lane_keep = _lane_clear_factor(x_ratio, profile)
			luma = content["luma"][idx]
			detail = content["detail"][idx]
			objectness = content["object"][idx]
			sky_bias = content["sky_bias"][idx]

			near_front_object = _smoothstep(profile.near_front_detail_soft, profile.near_front_detail_hard, objectness)
			near_back_object = _smoothstep(profile.near_back_detail_soft, profile.near_back_detail_hard, objectness)
			sky_luma = _smoothstep(profile.sky_luma_soft, profile.sky_luma_hard, luma)

			sky_mask[idx] = sky_region * sky_bias * sky_luma * (1.0 - edge_pull * 0.18)
			far_mask[idx] = upper_region * max(0.08, 1.0 - detail * 0.68) * (1.0 - objectness * 0.36)
			mid_mask[idx] = max(0.04, mid_vertical) * lane_keep
			near_back_mask[idx] = bottom_region * edge_pull * lane_keep * near_back_object
			near_front_mask[idx] = top_region * edge_pull * near_front_object

	return {
		"sky": sky_mask,
		"far": far_mask,
		"mid": mid_mask,
		"near_back": near_back_mask,
		"near_front": near_front_mask,
	}


def _build_ownership_maps(masks: Dict[str, List[float]]) -> Dict[str, List[float]]:
	total = len(masks["mid"])
	ownership = {
		"sky": [0.0] * total,
		"far": [0.0] * total,
		"mid": [0.0] * total,
		"near_back": [0.0] * total,
		"near_front": [0.0] * total,
	}
	for idx in range(total):
		sky = masks["sky"][idx]
		far = masks["far"][idx]
		mid = masks["mid"][idx]
		near_back = masks["near_back"][idx]
		near_front = masks["near_front"][idx]

		near_front_owner = _smoothstep(0.12, 0.34, near_front)
		near_back_owner = _smoothstep(0.10, 0.30, near_back) * (1.0 - near_front_owner * 0.6)
		sky_owner = _smoothstep(0.10, 0.34, sky) * (1.0 - near_front_owner * 0.4)
		far_owner = _smoothstep(0.12, 0.34, far) * (1.0 - near_front_owner * 0.4)
		mid_owner = max(0.0, 1.0 - max(near_front_owner * 0.96, near_back_owner * 0.84))

		ownership["near_front"][idx] = near_front_owner
		ownership["near_back"][idx] = near_back_owner
		ownership["sky"][idx] = sky_owner
		ownership["far"][idx] = far_owner
		ownership["mid"][idx] = mid_owner
	return ownership


def _build_layer_pixels(
	width: int,
	height: int,
	src: bytearray,
	blur_soft: bytearray,
	blur_medium: bytearray,
	masks: Dict[str, List[float]],
) -> Dict[str, bytearray]:
	ownership = _build_ownership_maps(masks)
	outputs = {
		"sky": bytearray(width * height * 4),
		"far": bytearray(width * height * 4),
		"mid": bytearray(width * height * 4),
		"near_back": bytearray(width * height * 4),
		"near_front": bytearray(width * height * 4),
	}

	for idx in range(width * height):
		i = idx * 4
		r = src[i]
		g = src[i + 1]
		b = src[i + 2]
		a = src[i + 3]
		sky_r = blur_soft[i]
		sky_g = blur_soft[i + 1]
		sky_b = blur_soft[i + 2]
		far_r = blur_medium[i]
		far_g = blur_medium[i + 1]
		far_b = blur_medium[i + 2]
		sky_alpha = masks["sky"][idx]
		far_alpha = masks["far"][idx]
		mid_alpha = masks["mid"][idx]
		near_back_alpha = masks["near_back"][idx]
		near_front_alpha = masks["near_front"][idx]
		sky_owner = ownership["sky"][idx]
		far_owner = ownership["far"][idx]
		mid_owner = ownership["mid"][idx]
		near_back_owner = ownership["near_back"][idx]
		near_front_owner = ownership["near_front"][idx]

		near_suppression = max(near_back_owner, near_front_owner)

		outputs["sky"][i] = _clamp(sky_r * 0.86 + 18.0)
		outputs["sky"][i + 1] = _clamp(sky_g * 0.92 + 24.0)
		outputs["sky"][i + 2] = _clamp(sky_b * 1.02 + 28.0)
		outputs["sky"][i + 3] = _clamp(a * sky_alpha * sky_owner)

		outputs["far"][i] = _clamp(far_r * 0.82 + 16.0)
		outputs["far"][i + 1] = _clamp(far_g * 0.88 + 18.0)
		outputs["far"][i + 2] = _clamp(far_b * 0.96 + 26.0)
		outputs["far"][i + 3] = _clamp(a * far_alpha * far_owner * (1.0 - near_front_owner * 0.72))

		mid_fill_blend = _smoothstep(0.08, 0.60, near_suppression)
		outputs["mid"][i] = _clamp(_lerp(r, far_r, mid_fill_blend * 0.86))
		outputs["mid"][i + 1] = _clamp(_lerp(g, far_g, mid_fill_blend * 0.86))
		outputs["mid"][i + 2] = _clamp(_lerp(b, far_b, mid_fill_blend * 0.86))
		outputs["mid"][i + 3] = _clamp(a * mid_alpha * mid_owner)

		outputs["near_back"][i] = _clamp(r * 0.98 + 12.0)
		outputs["near_back"][i + 1] = _clamp(g * 0.92 + 8.0)
		outputs["near_back"][i + 2] = _clamp(b * 0.82)
		outputs["near_back"][i + 3] = _clamp(a * near_back_alpha * near_back_owner)

		outputs["near_front"][i] = _clamp(r * 0.96 + 8.0)
		outputs["near_front"][i + 1] = _clamp(g * 0.9 + 6.0)
		outputs["near_front"][i + 2] = _clamp(b * 0.8)
		outputs["near_front"][i + 3] = _clamp(a * near_front_alpha * near_front_owner)

	return outputs


def _versioned_name(scene_name: str, version: str, suffix: str) -> str:
	if suffix == "master":
		return f"{scene_name}_master_{version}.png"
	if suffix == "master_loopsafe":
		return f"{scene_name}_master_loopsafe_{version}.png"
	return f"{scene_name}__{suffix}_{version}.png"


def write_layer_set(
	scene_name: str,
	version: str,
	width: int,
	height: int,
	master: bytearray,
	profile: LayerProfile,
	emit_debug_masks: bool = False,
) -> List[Path]:
	master_loopsafe = apply_loop_safe(width, height, master, profile.loop_safe_ratio)
	content = _build_content_maps(width, height, master_loopsafe)
	masks = _build_candidate_masks(width, height, content, profile)
	blur_soft = _downsample_blur(width, height, master_loopsafe, 12)
	blur_medium = _downsample_blur(width, height, master_loopsafe, 6)
	layers = _build_layer_pixels(width, height, master_loopsafe, blur_soft, blur_medium, masks)

	generated: List[Path] = []
	master_path = FORMAL_BACKGROUND_DIR / _versioned_name(scene_name, version, "master")
	loopsafe_path = FORMAL_BACKGROUND_DIR / _versioned_name(scene_name, version, "master_loopsafe")
	save_rgba_png(master_path, width, height, master)
	save_rgba_png(loopsafe_path, width, height, master_loopsafe)
	generated.append(master_path)
	generated.append(loopsafe_path)

	for layer_id in ["sky", "far", "mid", "near_back", "near_front"]:
		layer_path = FORMAL_BACKGROUND_DIR / _versioned_name(scene_name, version, layer_id)
		save_rgba_png(layer_path, width, height, layers[layer_id])
		generated.append(layer_path)

	if emit_debug_masks:
		mask_dir = FORMAL_BACKGROUND_DIR / "_debug_masks"
		mask_dir.mkdir(parents=True, exist_ok=True)
		for map_id in ["luma", "detail", "object", "sky_bias"]:
			mask_path = mask_dir / f"{scene_name}_{version}__{map_id}_mask.png"
			_save_grayscale_mask(mask_path, width, height, content[map_id])
			generated.append(mask_path)
		for layer_id in ["sky", "far", "mid", "near_back", "near_front"]:
			mask_path = mask_dir / f"{scene_name}_{version}__{layer_id}_mask.png"
			_save_grayscale_mask(mask_path, width, height, masks[layer_id])
			generated.append(mask_path)
	return generated


def generate_formal_layer_set(
	source_path: Path,
	scene_name: str,
	version: str,
	profile_id: str,
	target_width: int,
	target_height: int,
	emit_debug_masks: bool = False,
) -> List[Path]:
	if profile_id not in PROFILES:
		raise ValueError(f"Unknown layer profile: {profile_id}")
	width, height, pixels = load_rgba_png(source_path)
	master = build_master_strip(width, height, pixels, target_width, target_height)
	return write_layer_set(scene_name, version, target_width, target_height, master, PROFILES[profile_id], emit_debug_masks)


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Build loop-safe 5-layer parallax backgrounds from one master image.")
	parser.add_argument("--source", default=str(DEFAULT_SOURCE))
	parser.add_argument("--scene-name", default="chapter1_town_road")
	parser.add_argument("--version", default="v1")
	parser.add_argument("--profile", default="chapter1_town_road")
	parser.add_argument("--target-width", type=int, default=3072)
	parser.add_argument("--target-height", type=int, default=720)
	parser.add_argument("--emit-debug-masks", action="store_true")
	return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
	args = _parse_args(argv)
	generated = generate_formal_layer_set(
		Path(args.source),
		args.scene_name,
		args.version,
		args.profile,
		args.target_width,
		args.target_height,
		args.emit_debug_masks,
	)
	for path in generated:
		print(path.name)
	print(f"Generated {len(generated)} parallax background files.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main(__import__("sys").argv[1:]))
