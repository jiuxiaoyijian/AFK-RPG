#!/usr/bin/env python3
from __future__ import annotations

import argparse
import colorsys
import math
import random
import struct
import subprocess
import textwrap
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
GLOBAL_PROMPT = (
    "wuxia jianghu, ink wash and xieyi, dark iron and old wood, copper ornament, "
    "parchment texture, restrained palette, cinematic composition, readable silhouette, "
    "game asset, clean edges, Chinese martial atmosphere"
)
NEGATIVE_PROMPT = (
    "xianxia, immortal, flying sword, crane, cloud sea, purple fantasy UI, western armor, "
    "sci-fi, cyberpunk, photorealistic, text, watermark, logo"
)


@dataclass
class AssetSpec:
    logical_id: str
    category: str
    wired_now: bool
    output_path: str
    target_size: str
    background_mode: str
    prompt: str
    negative_prompt: str
    source_doc: str
    replace_mode: str
    generator: str
    meta: Dict[str, str]


class Canvas:
    def __init__(self, width: int, height: int, background: Tuple[int, int, int, int] = (0, 0, 0, 0)) -> None:
        self.width = width
        self.height = height
        self.data = bytearray(width * height * 4)
        if background != (0, 0, 0, 0):
            self.fill(background)

    def fill(self, color: Tuple[int, int, int, int]) -> None:
        r, g, b, a = color
        px = bytes([r, g, b, a])
        self.data[:] = px * (self.width * self.height)

    def blend_pixel(self, x: int, y: int, color: Tuple[int, int, int, int]) -> None:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        idx = (y * self.width + x) * 4
        sr, sg, sb, sa = color
        if sa <= 0:
            return
        dr, dg, db, da = self.data[idx], self.data[idx + 1], self.data[idx + 2], self.data[idx + 3]
        src_a = sa / 255.0
        dst_a = da / 255.0
        out_a = src_a + dst_a * (1.0 - src_a)
        if out_a <= 0.0:
            return
        out_r = int((sr * src_a + dr * dst_a * (1.0 - src_a)) / out_a)
        out_g = int((sg * src_a + dg * dst_a * (1.0 - src_a)) / out_a)
        out_b = int((sb * src_a + db * dst_a * (1.0 - src_a)) / out_a)
        self.data[idx] = max(0, min(255, out_r))
        self.data[idx + 1] = max(0, min(255, out_g))
        self.data[idx + 2] = max(0, min(255, out_b))
        self.data[idx + 3] = max(0, min(255, int(out_a * 255.0)))

    def draw_rect(self, x0: int, y0: int, x1: int, y1: int, color: Tuple[int, int, int, int]) -> None:
        xa = max(0, min(x0, x1))
        xb = min(self.width, max(x0, x1))
        ya = max(0, min(y0, y1))
        yb = min(self.height, max(y0, y1))
        for y in range(ya, yb):
            for x in range(xa, xb):
                self.blend_pixel(x, y, color)

    def draw_circle(self, cx: float, cy: float, radius: float, color: Tuple[int, int, int, int]) -> None:
        r2 = radius * radius
        x0 = max(0, int(cx - radius - 1))
        x1 = min(self.width - 1, int(cx + radius + 1))
        y0 = max(0, int(cy - radius - 1))
        y1 = min(self.height - 1, int(cy + radius + 1))
        for y in range(y0, y1 + 1):
            dy = y - cy
            for x in range(x0, x1 + 1):
                dx = x - cx
                if dx * dx + dy * dy <= r2:
                    self.blend_pixel(x, y, color)

    def draw_ring(
        self,
        cx: float,
        cy: float,
        radius: float,
        thickness: float,
        color: Tuple[int, int, int, int],
    ) -> None:
        outer = radius * radius
        inner = max(0.0, radius - thickness) ** 2
        x0 = max(0, int(cx - radius - 1))
        x1 = min(self.width - 1, int(cx + radius + 1))
        y0 = max(0, int(cy - radius - 1))
        y1 = min(self.height - 1, int(cy + radius + 1))
        for y in range(y0, y1 + 1):
            dy = y - cy
            for x in range(x0, x1 + 1):
                dx = x - cx
                d2 = dx * dx + dy * dy
                if inner <= d2 <= outer:
                    self.blend_pixel(x, y, color)

    def draw_line(
        self,
        x0: float,
        y0: float,
        x1: float,
        y1: float,
        thickness: float,
        color: Tuple[int, int, int, int],
    ) -> None:
        min_x = max(0, int(min(x0, x1) - thickness - 1))
        max_x = min(self.width - 1, int(max(x0, x1) + thickness + 1))
        min_y = max(0, int(min(y0, y1) - thickness - 1))
        max_y = min(self.height - 1, int(max(y0, y1) + thickness + 1))
        dx = x1 - x0
        dy = y1 - y0
        length_sq = dx * dx + dy * dy
        if length_sq <= 0.0001:
            self.draw_circle(x0, y0, thickness * 0.5, color)
            return
        radius_sq = (thickness * 0.5) ** 2
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                t = ((x - x0) * dx + (y - y0) * dy) / length_sq
                t = max(0.0, min(1.0, t))
                px = x0 + t * dx
                py = y0 + t * dy
                dist_sq = (x - px) ** 2 + (y - py) ** 2
                if dist_sq <= radius_sq:
                    self.blend_pixel(x, y, color)

    def draw_gradient(self, top: Tuple[int, int, int], bottom: Tuple[int, int, int]) -> None:
        for y in range(self.height):
            t = y / max(1, self.height - 1)
            color = (
                int(top[0] + (bottom[0] - top[0]) * t),
                int(top[1] + (bottom[1] - top[1]) * t),
                int(top[2] + (bottom[2] - top[2]) * t),
                255,
            )
            self.draw_rect(0, y, self.width, y + 1, color)

    def save_png(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = bytearray()
        stride = self.width * 4
        for y in range(self.height):
            raw.append(0)
            start = y * stride
            raw.extend(self.data[start:start + stride])

        def chunk(tag: bytes, payload: bytes) -> bytes:
            crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
            return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)

        png = bytearray()
        png.extend(b"\x89PNG\r\n\x1a\n")
        png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)))
        png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
        png.extend(chunk(b"IEND", b""))
        path.write_bytes(png)


def clamp(value: float) -> int:
    return max(0, min(255, int(value)))


def hex_rgba(hex_value: str, alpha: int = 255) -> Tuple[int, int, int, int]:
    hex_value = hex_value.lstrip("#")
    return (
        int(hex_value[0:2], 16),
        int(hex_value[2:4], 16),
        int(hex_value[4:6], 16),
        alpha,
    )


PALETTE = {
    "ink": hex_rgba("#121317"),
    "panel": hex_rgba("#1A1D24"),
    "panel_alt": hex_rgba("#232834"),
    "gold": hex_rgba("#826A3A"),
    "gold_soft": hex_rgba("#B79B5A"),
    "jade": hex_rgba("#5FA36A"),
    "red": hex_rgba("#A84A3A"),
    "blue": hex_rgba("#5D7FA6"),
    "text": hex_rgba("#E6DCC8"),
    "text_dim": hex_rgba("#9E9688"),
    "paper": hex_rgba("#C9B999"),
    "mist": hex_rgba("#D9D6CF", 90),
    "white_soft": hex_rgba("#F2EEE6", 180),
}


def accent_for_name(name: str) -> Tuple[int, int, int, int]:
    if "wind" in name or "yufeng" in name:
        return PALETTE["jade"]
    if "blood" in name or "xuejie" in name:
        return PALETTE["red"]
    if "thunder" in name or "wulei" in name:
        return PALETTE["blue"]
    if "iron" in name:
        return hex_rgba("#8C8068")
    if "gold" in name or "legendary" in name or "rare" in name:
        return PALETTE["gold_soft"]
    return PALETTE["gold"]


def lighten(color: Tuple[int, int, int, int], amount: float) -> Tuple[int, int, int, int]:
    r, g, b, a = color
    return (clamp(r + (255 - r) * amount), clamp(g + (255 - g) * amount), clamp(b + (255 - b) * amount), a)


def darken(color: Tuple[int, int, int, int], amount: float) -> Tuple[int, int, int, int]:
    r, g, b, a = color
    return (clamp(r * (1.0 - amount)), clamp(g * (1.0 - amount)), clamp(b * (1.0 - amount)), a)


def seeded_rng(name: str) -> random.Random:
    return random.Random(zlib.crc32(name.encode("utf-8")) & 0xFFFFFFFF)


def add_paper_noise(canvas: Canvas, rng: random.Random, density: int = 2400, tint: Tuple[int, int, int, int] = PALETTE["mist"]) -> None:
    for _ in range(density):
        x = rng.randrange(canvas.width)
        y = rng.randrange(canvas.height)
        alpha = rng.randint(8, tint[3])
        canvas.blend_pixel(x, y, (tint[0], tint[1], tint[2], alpha))


def add_vignette(canvas: Canvas, strength: float = 0.7) -> None:
    cx = canvas.width * 0.5
    cy = canvas.height * 0.52
    max_dist = math.sqrt(cx * cx + cy * cy)
    for y in range(canvas.height):
        for x in range(canvas.width):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy) / max_dist
            alpha = clamp(max(0.0, dist - 0.38) * 210.0 * strength)
            if alpha > 0:
                canvas.blend_pixel(x, y, (18, 19, 23, alpha))


def draw_mountain_layer(canvas: Canvas, rng: random.Random, y_base: int, amplitude: int, color: Tuple[int, int, int, int]) -> None:
    points: List[int] = []
    x = 0
    while x <= canvas.width:
        offset = rng.randint(-amplitude, amplitude)
        points.append(max(0, min(canvas.height, y_base + offset)))
        x += max(40, canvas.width // 12)
    step = canvas.width / max(1, len(points) - 1)
    for i in range(len(points) - 1):
        x0 = int(i * step)
        x1 = int((i + 1) * step)
        y0 = points[i]
        y1 = points[i + 1]
        for x in range(x0, min(canvas.width, x1 + 1)):
            t = 0.0 if x1 == x0 else (x - x0) / float(x1 - x0)
            ridge = int(y0 + (y1 - y0) * t)
            canvas.draw_rect(x, ridge, x + 1, canvas.height, color)


def draw_town_silhouette(canvas: Canvas, rng: random.Random, ground_y: int, accent: Tuple[int, int, int, int]) -> None:
    x = 24
    while x < canvas.width:
        block_w = rng.randint(70, 150)
        block_h = rng.randint(90, 180)
        if canvas.width * 0.34 < x < canvas.width * 0.66:
            x += block_w // 2
            continue
        canvas.draw_rect(x, ground_y - block_h, x + block_w, ground_y, (28, 24, 20, 220))
        roof_h = rng.randint(18, 36)
        canvas.draw_line(x - 4, ground_y - block_h, x + block_w * 0.5, ground_y - block_h - roof_h, 8, (45, 35, 29, 220))
        canvas.draw_line(x + block_w + 4, ground_y - block_h, x + block_w * 0.5, ground_y - block_h - roof_h, 8, (45, 35, 29, 220))
        for _ in range(rng.randint(1, 3)):
            wx = rng.randint(x + 10, x + block_w - 12)
            wy = rng.randint(ground_y - block_h + 15, ground_y - 20)
            canvas.draw_rect(wx, wy, wx + 10, wy + 16, (accent[0], accent[1], accent[2], 70))
        x += block_w + rng.randint(18, 30)


def draw_bridge(canvas: Canvas, y: int, accent: Tuple[int, int, int, int]) -> None:
    canvas.draw_line(0, y, canvas.width, y, 10, (50, 42, 38, 220))
    for x in range(0, canvas.width, max(20, canvas.width // 24)):
        h = 22 if x % 2 == 0 else 28
        canvas.draw_line(x, y, x, y - h, 8, (60, 54, 46, 220))
        canvas.draw_circle(x, y - h - 4, 6, (accent[0], accent[1], accent[2], 120))


def draw_ruins(canvas: Canvas, rng: random.Random, ground_y: int) -> None:
    for x in range(40, canvas.width, max(80, canvas.width // 8)):
        w = rng.randint(36, 70)
        h = rng.randint(100, 220)
        if canvas.width * 0.36 < x < canvas.width * 0.62:
            continue
        canvas.draw_rect(x, ground_y - h, x + w, ground_y, (44, 52, 48, 200))
        canvas.draw_rect(x + 8, ground_y - h + 18, x + w - 8, ground_y - h + 26, (98, 108, 95, 120))
        for crack in range(3):
            cx = x + 12 + crack * 12
            canvas.draw_line(cx, ground_y - h + 10, cx + 10, ground_y - h + 46, 3, (18, 24, 22, 180))


def draw_lanterns(canvas: Canvas, rng: random.Random, y_band: Tuple[int, int], accent: Tuple[int, int, int, int], count: int = 8) -> None:
    for _ in range(count):
        x = rng.randint(40, canvas.width - 40)
        if canvas.width * 0.40 < x < canvas.width * 0.60:
            continue
        y = rng.randint(*y_band)
        canvas.draw_line(x, y - 18, x, y, 2, (90, 78, 50, 180))
        canvas.draw_circle(x, y, 6, (accent[0], accent[1], accent[2], 170))


def render_background(theme: str, width: int, height: int, logical_id: str) -> Canvas:
    canvas = Canvas(width, height)
    rng = seeded_rng(logical_id)
    if "taoxi" in theme or "qingyun" in theme:
        canvas.draw_gradient((28, 35, 40), (72, 73, 54))
        draw_mountain_layer(canvas, rng, int(height * 0.36), int(height * 0.10), (48, 58, 52, 180))
        draw_mountain_layer(canvas, rng, int(height * 0.50), int(height * 0.08), (30, 38, 33, 200))
        draw_bridge(canvas, int(height * 0.76), PALETTE["gold"])
        draw_lanterns(canvas, rng, (int(height * 0.28), int(height * 0.42)), PALETTE["gold"], 10)
    elif "cixia" in theme or "luoyan" in theme:
        canvas.draw_gradient((20, 28, 30), (58, 66, 55))
        draw_mountain_layer(canvas, rng, int(height * 0.32), int(height * 0.10), (38, 47, 44, 180))
        draw_ruins(canvas, rng, int(height * 0.80))
        draw_mountain_layer(canvas, rng, int(height * 0.57), int(height * 0.05), (26, 33, 30, 210))
        draw_lanterns(canvas, rng, (int(height * 0.42), int(height * 0.52)), PALETTE["jade"], 5)
    elif "tiesuo" in theme or "market" in theme or "dock" in theme:
        canvas.draw_gradient((26, 24, 28), (88, 63, 42))
        draw_town_silhouette(canvas, rng, int(height * 0.80), PALETTE["red"])
        draw_bridge(canvas, int(height * 0.82), PALETTE["red"])
        draw_lanterns(canvas, rng, (int(height * 0.22), int(height * 0.46)), PALETTE["red"], 12)
        canvas.draw_rect(0, int(height * 0.82), canvas.width, height, (40, 28, 22, 220))
    elif "rift" in theme or "trial" in theme:
        canvas.draw_gradient((16, 20, 28), (34, 46, 70))
        draw_mountain_layer(canvas, rng, int(height * 0.35), int(height * 0.08), (46, 56, 84, 160))
        for _ in range(18):
            x = rng.randint(40, width - 40)
            y = rng.randint(int(height * 0.18), int(height * 0.72))
            canvas.draw_line(x, y, x + rng.randint(-30, 30), y + rng.randint(26, 72), 4, (150, 180, 220, 90))
        canvas.draw_circle(width * 0.5, height * 0.30, height * 0.08, (100, 140, 190, 90))
    elif "xuedao" in theme:
        canvas.draw_gradient((30, 36, 44), (96, 112, 130))
        draw_mountain_layer(canvas, rng, int(height * 0.34), int(height * 0.11), (170, 182, 190, 120))
        draw_mountain_layer(canvas, rng, int(height * 0.52), int(height * 0.07), (78, 88, 104, 220))
        for _ in range(2600):
            x = rng.randrange(width)
            y = rng.randrange(height)
            canvas.blend_pixel(x, y, (238, 242, 246, rng.randint(10, 40)))
    elif "jianzhong" in theme:
        canvas.draw_gradient((20, 22, 28), (74, 62, 58))
        for i in range(12):
            x = int(width * (0.08 + i * 0.07))
            top = int(height * (0.25 + (i % 3) * 0.03))
            bottom = int(height * 0.88)
            canvas.draw_line(x, bottom, x + rng.randint(-12, 12), top, 10, (82, 76, 68, 180))
            canvas.draw_line(x - 16, top + 30, x + 16, top + 10, 6, (110, 100, 82, 140))
    else:
        canvas.draw_gradient((22, 24, 30), (58, 64, 74))
        draw_mountain_layer(canvas, rng, int(height * 0.40), int(height * 0.08), (38, 46, 48, 180))
    add_paper_noise(canvas, rng, density=max(1200, width * height // 420), tint=PALETTE["mist"])
    add_vignette(canvas, 0.72)
    return canvas


def add_ink_splash(canvas: Canvas, rng: random.Random, cx: float, cy: float, radius: float, color: Tuple[int, int, int, int]) -> None:
    for _ in range(28):
        off_x = rng.uniform(-radius, radius)
        off_y = rng.uniform(-radius, radius)
        rr = rng.uniform(radius * 0.10, radius * 0.42)
        alpha = rng.randint(18, color[3])
        canvas.draw_circle(cx + off_x, cy + off_y, rr, (color[0], color[1], color[2], alpha))


def render_portrait(kind: str, width: int, height: int, logical_id: str) -> Canvas:
    rng = seeded_rng(logical_id)
    canvas = Canvas(width, height)
    accent = accent_for_name(kind)
    shadow = (18, 18, 22, 130)
    add_ink_splash(canvas, rng, width * 0.50, height * 0.46, min(width, height) * 0.22, shadow)
    add_ink_splash(canvas, rng, width * 0.55, height * 0.58, min(width, height) * 0.18, (40, 32, 24, 60))

    robe = darken(accent, 0.42)
    robe_high = lighten(robe, 0.22)
    skin = (214, 186, 154, 220)
    hair = (22, 20, 19, 235)
    width_scale = width * 0.5
    torso_top = height * 0.46
    torso_bottom = height * 0.92
    center_x = width * 0.50
    canvas.draw_circle(center_x, height * 0.29, width * 0.10, skin)
    canvas.draw_circle(center_x, height * 0.25, width * 0.11, hair)
    canvas.draw_rect(int(center_x - width_scale * 0.18), int(torso_top), int(center_x + width_scale * 0.18), int(torso_bottom), robe)
    canvas.draw_line(center_x - width_scale * 0.34, torso_bottom, center_x, torso_top + 10, width * 0.12, robe)
    canvas.draw_line(center_x + width_scale * 0.34, torso_bottom, center_x, torso_top + 10, width * 0.12, robe)
    canvas.draw_line(center_x - width_scale * 0.22, torso_top + 42, center_x + width_scale * 0.22, torso_top + 42, width * 0.025, robe_high)
    canvas.draw_line(center_x, torso_top + 32, center_x, torso_bottom - 28, width * 0.018, lighten(accent, 0.26))

    if "female" in kind:
        canvas.draw_line(center_x - width * 0.12, height * 0.21, center_x - width * 0.19, height * 0.48, width * 0.08, hair)
        canvas.draw_line(center_x + width * 0.12, height * 0.21, center_x + width * 0.19, height * 0.48, width * 0.08, hair)
        canvas.draw_circle(center_x, height * 0.26, width * 0.05, (184, 48, 44, 110))
    elif "smith" in kind:
        canvas.draw_rect(int(center_x - width * 0.12), int(height * 0.18), int(center_x + width * 0.12), int(height * 0.24), (68, 52, 36, 230))
        canvas.draw_line(center_x + width * 0.22, height * 0.64, center_x + width * 0.36, height * 0.32, width * 0.06, accent)
        canvas.draw_rect(int(center_x + width * 0.30), int(height * 0.25), int(center_x + width * 0.39), int(height * 0.35), lighten(accent, 0.28))
    elif "headmaster" in kind or "elder" in kind:
        canvas.draw_rect(int(center_x - width * 0.11), int(height * 0.18), int(center_x + width * 0.11), int(height * 0.24), (40, 30, 26, 220))
        canvas.draw_line(center_x, height * 0.36, center_x + width * 0.28, height * 0.80, width * 0.03, accent)
    elif "hook_elder" in kind or "yingou" in kind:
        canvas.draw_line(center_x + width * 0.18, height * 0.34, center_x + width * 0.36, height * 0.68, width * 0.04, accent)
        canvas.draw_ring(center_x + width * 0.36, height * 0.68, width * 0.055, width * 0.025, lighten(accent, 0.25))
        canvas.draw_rect(int(center_x - width * 0.14), int(height * 0.18), int(center_x + width * 0.14), int(height * 0.24), (52, 34, 28, 230))
    elif "overseer" in kind or "jilu" in kind:
        canvas.draw_rect(int(center_x - width * 0.10), int(height * 0.14), int(center_x + width * 0.10), int(height * 0.20), (58, 44, 32, 220))
        canvas.draw_rect(int(center_x + width * 0.20), int(height * 0.45), int(center_x + width * 0.34), int(height * 0.76), accent)
        canvas.draw_circle(center_x + width * 0.27, height * 0.41, width * 0.04, lighten(accent, 0.24))
    elif "fuci" in kind or "shanjun" in kind or "iron_beast" in kind:
        canvas.draw_rect(int(center_x - width * 0.10), int(height * 0.14), int(center_x + width * 0.10), int(height * 0.24), (44, 42, 36, 230))
        canvas.draw_line(center_x - width * 0.20, height * 0.18, center_x - width * 0.05, height * 0.08, width * 0.03, accent)
        canvas.draw_line(center_x + width * 0.20, height * 0.18, center_x + width * 0.05, height * 0.08, width * 0.03, accent)
    elif "enemy_elite" in kind:
        canvas.draw_rect(int(center_x - width * 0.11), int(height * 0.18), int(center_x + width * 0.11), int(height * 0.22), (72, 46, 32, 230))
        canvas.draw_line(center_x + width * 0.18, height * 0.34, center_x + width * 0.30, height * 0.72, width * 0.05, accent)
    elif "enemy_normal" in kind:
        canvas.draw_line(center_x + width * 0.18, height * 0.34, center_x + width * 0.26, height * 0.68, width * 0.04, accent)
    else:
        canvas.draw_circle(center_x, height * 0.29, width * 0.06, (accent[0], accent[1], accent[2], 100))

    canvas.draw_ring(center_x, height * 0.52, width * 0.26, width * 0.015, (accent[0], accent[1], accent[2], 56))
    return canvas


def draw_symbol(canvas: Canvas, kind: str, accent: Tuple[int, int, int, int]) -> None:
    c = canvas.width * 0.5
    mid = canvas.height * 0.5
    ink = (232, 225, 205, 235)
    if "blade" in kind or "weapon" in kind:
        canvas.draw_line(c - 44, mid + 42, c + 34, mid - 38, 24, ink)
        canvas.draw_rect(int(c - 12), int(mid + 24), int(c + 14), int(mid + 56), accent)
    elif "axe" in kind:
        canvas.draw_line(c, mid - 56, c, mid + 56, 18, ink)
        canvas.draw_rect(int(c - 54), int(mid - 28), int(c + 8), int(mid + 6), accent)
    elif "spear" in kind:
        canvas.draw_line(c, mid - 68, c, mid + 60, 14, ink)
        canvas.draw_line(c - 18, mid - 56, c, mid - 80, 10, accent)
        canvas.draw_line(c + 18, mid - 56, c, mid - 80, 10, accent)
    elif "orb" in kind:
        canvas.draw_circle(c, mid, 50, (accent[0], accent[1], accent[2], 180))
        canvas.draw_ring(c, mid, 62, 10, ink)
    elif "staff" in kind:
        canvas.draw_line(c - 10, mid + 60, c + 10, mid - 54, 20, ink)
        canvas.draw_circle(c + 8, mid - 62, 20, accent)
    elif "helmet" in kind:
        canvas.draw_circle(c, mid - 8, 56, ink)
        canvas.draw_rect(int(c - 46), int(mid - 4), int(c + 46), int(mid + 42), (18, 19, 23, 255))
        canvas.draw_ring(c, mid - 8, 56, 10, accent)
    elif "armor" in kind:
        canvas.draw_rect(int(c - 54), int(mid - 58), int(c + 54), int(mid + 54), ink)
        canvas.draw_rect(int(c - 24), int(mid - 10), int(c + 24), int(mid + 54), (18, 19, 23, 255))
        canvas.draw_line(c - 58, mid - 44, c - 24, mid - 8, 18, accent)
        canvas.draw_line(c + 58, mid - 44, c + 24, mid - 8, 18, accent)
    elif "glove" in kind:
        canvas.draw_rect(int(c - 24), int(mid - 50), int(c + 40), int(mid + 46), ink)
        for i in range(4):
            canvas.draw_rect(int(c - 28 + i * 16), int(mid - 70), int(c - 16 + i * 16), int(mid - 38), accent)
    elif "legs" in kind:
        canvas.draw_rect(int(c - 42), int(mid - 56), int(c - 8), int(mid + 52), ink)
        canvas.draw_rect(int(c + 8), int(mid - 56), int(c + 42), int(mid + 52), ink)
        canvas.draw_ring(c, mid + 12, 66, 8, accent)
    elif "boots" in kind:
        canvas.draw_rect(int(c - 46), int(mid - 20), int(c - 6), int(mid + 48), ink)
        canvas.draw_rect(int(c + 6), int(mid - 20), int(c + 46), int(mid + 48), ink)
        canvas.draw_rect(int(c - 56), int(mid + 34), int(c - 2), int(mid + 58), accent)
        canvas.draw_rect(int(c + 2), int(mid + 34), int(c + 56), int(mid + 58), accent)
    elif "accessory" in kind or "gem_" in kind:
        canvas.draw_ring(c, mid, 60, 12, ink)
        canvas.draw_circle(c, mid, 30, accent)
    elif "belt" in kind:
        canvas.draw_rect(int(c - 72), int(mid - 22), int(c + 72), int(mid + 22), ink)
        canvas.draw_rect(int(c - 18), int(mid - 18), int(c + 18), int(mid + 18), accent)
    elif "resource_xianghuoqian" in kind or "suiyin" in kind:
        canvas.draw_circle(c - 18, mid, 28, ink)
        canvas.draw_circle(c + 18, mid, 28, accent)
    elif "resource_cihui" in kind or "duancai" in kind:
        canvas.draw_rect(int(c - 52), int(mid - 18), int(c + 52), int(mid + 18), ink)
        canvas.draw_line(c - 44, mid - 30, c + 44, mid + 30, 10, accent)
    elif "resource_linghe" in kind or "jingtie" in kind:
        canvas.draw_circle(c, mid, 54, ink)
        canvas.draw_circle(c, mid, 34, accent)
    elif "resource_zhenyi_canpian" in kind or "mijuan" in kind:
        canvas.draw_line(c - 44, mid + 40, c - 8, mid - 52, 18, ink)
        canvas.draw_line(c + 44, mid + 40, c + 8, mid - 52, 18, accent)
    elif "rift_key" in kind:
        canvas.draw_ring(c - 22, mid - 12, 28, 10, ink)
        canvas.draw_line(c + 4, mid - 12, c + 64, mid - 12, 16, accent)
        canvas.draw_rect(int(c + 30), int(mid - 12), int(c + 42), int(mid + 18), accent)
        canvas.draw_rect(int(c + 50), int(mid - 12), int(c + 62), int(mid + 8), accent)
    elif "school_yufeng" in kind:
        canvas.draw_ring(c, mid, 60, 12, accent)
        canvas.draw_line(c - 30, mid + 30, c + 24, mid - 36, 18, ink)
        canvas.draw_line(c - 10, mid + 50, c + 42, mid - 16, 12, accent)
    elif "school_xuejie" in kind:
        canvas.draw_circle(c, mid - 8, 36, accent)
        canvas.draw_line(c, mid + 16, c, mid + 70, 18, ink)
    elif "school_wulei" in kind:
        canvas.draw_line(c - 16, mid - 56, c + 10, mid - 8, 16, ink)
        canvas.draw_line(c + 10, mid - 8, c - 6, mid + 18, 16, accent)
        canvas.draw_line(c - 6, mid + 18, c + 28, mid + 60, 16, ink)
    elif "system_wudao" in kind:
        canvas.draw_rect(int(c - 56), int(mid - 48), int(c + 56), int(mid + 48), ink)
        canvas.draw_line(c - 10, mid - 48, c - 10, mid + 48, 6, accent)
        canvas.draw_line(c + 18, mid - 40, c + 18, mid + 40, 4, accent)
    elif "system_yiwenlu" in kind or "codex" in kind:
        canvas.draw_rect(int(c - 60), int(mid - 50), int(c + 32), int(mid + 50), ink)
        canvas.draw_line(c + 36, mid - 42, c + 36, mid + 42, 8, accent)
        canvas.draw_rect(int(c + 24), int(mid - 50), int(c + 40), int(mid + 50), accent)
    elif "system_jiyuantuiyan" in kind or "analysis" in kind:
        canvas.draw_line(c - 50, mid + 40, c - 14, mid - 10, 18, ink)
        canvas.draw_line(c - 14, mid - 10, c + 18, mid + 10, 18, accent)
        canvas.draw_line(c + 18, mid + 10, c + 56, mid - 40, 18, ink)
    elif "system_biguan_suode" in kind or "offline" in kind:
        canvas.draw_circle(c, mid, 60, ink)
        canvas.draw_line(c, mid - 36, c, mid + 10, 12, accent)
        canvas.draw_line(c, mid, c + 28, mid - 24, 12, accent)
    elif "system_jinrijiyuan" in kind or "daily" in kind:
        canvas.draw_ring(c, mid, 58, 10, ink)
        canvas.draw_circle(c, mid, 18, accent)
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            canvas.draw_line(c + math.cos(rad) * 26, mid + math.sin(rad) * 26, c + math.cos(rad) * 56, mid + math.sin(rad) * 56, 8, accent)
    elif "drop_daily_reward" in kind or "drop_event_reward" in kind:
        canvas.draw_circle(c, mid, 62, ink)
        for angle in [0, 72, 144, 216, 288]:
            rad = math.radians(angle)
            canvas.draw_line(c, mid, c + math.cos(rad) * 58, mid + math.sin(rad) * 58, 14, accent)
    elif "drop_equipment" in kind:
        canvas.draw_rect(int(c - 52), int(mid - 38), int(c + 52), int(mid + 38), ink)
        canvas.draw_ring(c, mid, 54, 10, accent)
    elif "drop_salvage" in kind:
        canvas.draw_line(c - 50, mid - 50, c + 50, mid + 50, 22, ink)
        canvas.draw_line(c + 50, mid - 50, c - 50, mid + 50, 22, accent)
    elif "nav_inventory" in kind:
        canvas.draw_rect(int(c - 54), int(mid - 26), int(c + 54), int(mid + 50), ink)
        canvas.draw_line(c - 32, mid - 26, c - 20, mid - 58, 12, accent)
        canvas.draw_line(c + 32, mid - 26, c + 20, mid - 58, 12, accent)
    else:
        canvas.draw_circle(c, mid, 52, ink)
        canvas.draw_ring(c, mid, 64, 8, accent)


def render_icon(kind: str, width: int, height: int, logical_id: str) -> Canvas:
    canvas = Canvas(width, height)
    accent = accent_for_name(kind)
    canvas.draw_circle(width * 0.5, height * 0.5, width * 0.42, (16, 17, 20, 170))
    canvas.draw_ring(width * 0.5, height * 0.5, width * 0.44, width * 0.03, (accent[0], accent[1], accent[2], 180))
    draw_symbol(canvas, kind, accent)
    return canvas


def render_frame(kind: str, width: int, height: int, logical_id: str) -> Canvas:
    canvas = Canvas(width, height)
    accent = accent_for_name(kind)
    outer = darken(accent, 0.18)
    inner = lighten(accent, 0.28)
    canvas.draw_rect(0, 0, width, height, (0, 0, 0, 0))
    canvas.draw_rect(10, 10, width - 10, height - 10, (18, 20, 24, 140))
    canvas.draw_rect(18, 18, width - 18, height - 18, (0, 0, 0, 0))
    canvas.draw_ring(width * 0.5, height * 0.5, width * 0.48, width * 0.02, (outer[0], outer[1], outer[2], 190))
    canvas.draw_ring(width * 0.5, height * 0.5, width * 0.43, width * 0.015, (inner[0], inner[1], inner[2], 180))
    corners = [(28, 28), (width - 28, 28), (28, height - 28), (width - 28, height - 28)]
    for cx, cy in corners:
        canvas.draw_circle(cx, cy, 18, (inner[0], inner[1], inner[2], 160))
        canvas.draw_ring(cx, cy, 24, 6, (255, 245, 220, 120))
    if "set_" in kind:
        canvas.draw_circle(width * 0.5, 34, 18, (accent[0], accent[1], accent[2], 180))
    return canvas


def render_result_card(kind: str, width: int, height: int, logical_id: str) -> Canvas:
    canvas = Canvas(width, height)
    accent = accent_for_name(kind)
    canvas.draw_gradient((28, 30, 36), (18, 20, 25))
    for offset in range(0, height, 18):
        canvas.draw_line(0, offset, width, offset + 24, 2, (255, 255, 255, 8))
    canvas.draw_rect(24, 24, width - 24, height - 24, (16, 18, 24, 180))
    canvas.draw_rect(48, 48, width - 48, height - 48, (0, 0, 0, 0))
    canvas.draw_ring(width * 0.5, height * 0.5, min(width, height) * 0.43, 12, (accent[0], accent[1], accent[2], 110))
    canvas.draw_line(86, 82, width - 86, 82, 8, (accent[0], accent[1], accent[2], 160))
    canvas.draw_line(86, height - 82, width - 86, height - 82, 8, (accent[0], accent[1], accent[2], 120))
    add_paper_noise(canvas, seeded_rng(logical_id), density=2000, tint=(214, 202, 176, 18))
    return canvas


def render_button(kind: str, width: int, height: int, logical_id: str) -> Canvas:
    canvas = Canvas(width, height)
    accent = accent_for_name(kind)
    canvas.draw_gradient((42, 38, 34), (24, 22, 20))
    canvas.draw_rect(4, 4, width - 4, height - 4, (24, 25, 30, 140))
    canvas.draw_rect(8, 8, width - 8, height - 8, (0, 0, 0, 0))
    canvas.draw_line(10, 12, width - 10, 12, 4, lighten(accent, 0.24))
    canvas.draw_line(10, height - 12, width - 10, height - 12, 4, darken(accent, 0.12))
    return canvas


def render_scroll_bar(width: int, height: int, logical_id: str) -> Canvas:
    canvas = Canvas(width, height)
    canvas.draw_gradient((72, 60, 42), (44, 34, 26))
    canvas.draw_ring(width * 0.5, height * 0.5, min(width, height) * 0.46, 6, (214, 188, 132, 130))
    return canvas


def render_spritesheet(kind: str, frame_w: int, frame_h: int, frames: int, logical_id: str) -> Canvas:
    canvas = Canvas(frame_w * frames, frame_h, (0, 0, 0, 0))
    accent = accent_for_name(kind)
    body = darken(accent, 0.12)
    ink = (230, 224, 210, 240)
    for i in range(frames):
        ox = i * frame_w
        shift = math.sin(i / max(1, frames - 1) * math.pi * 2.0) * frame_w * 0.08
        cx = ox + frame_w * 0.5 + shift
        ground = frame_h * 0.88
        canvas.draw_line(cx, ground - frame_h * 0.56, cx, ground - frame_h * 0.20, frame_w * 0.16, body)
        canvas.draw_circle(cx, ground - frame_h * 0.70, frame_w * 0.12, ink)
        canvas.draw_line(cx, ground - frame_h * 0.20, cx - frame_w * 0.12, ground, frame_w * 0.10, body)
        canvas.draw_line(cx, ground - frame_h * 0.20, cx + frame_w * 0.12, ground, frame_w * 0.10, body)
        arm = frame_w * 0.18 if i % 2 == 0 else frame_w * 0.24
        canvas.draw_line(cx, ground - frame_h * 0.42, cx + arm, ground - frame_h * 0.28, frame_w * 0.08, accent)
        canvas.draw_line(cx, ground - frame_h * 0.40, cx - arm * 0.8, ground - frame_h * 0.30, frame_w * 0.08, body)
        if "boss" in kind:
            canvas.draw_ring(cx, ground - frame_h * 0.50, frame_w * 0.24, frame_w * 0.04, (accent[0], accent[1], accent[2], 100))
    return canvas


def render_effect(kind: str, frame_w: int, frame_h: int, frames: int, logical_id: str) -> Canvas:
    canvas = Canvas(frame_w * frames, frame_h, (0, 0, 0, 0))
    accent = accent_for_name(kind)
    for i in range(frames):
        ox = i * frame_w
        strength = 0.3 + i / max(1, frames - 1) * 0.7
        if "whirlwind" in kind:
            canvas.draw_ring(ox + frame_w * 0.5, frame_h * 0.5, frame_h * 0.22 + i * 2, 12, (accent[0], accent[1], accent[2], int(140 * strength)))
            canvas.draw_ring(ox + frame_w * 0.5, frame_h * 0.5, frame_h * 0.32 + i * 2, 6, (255, 240, 220, int(90 * strength)))
        elif "blood" in kind or "crit" in kind:
            canvas.draw_line(ox + frame_w * 0.2, frame_h * 0.8, ox + frame_w * 0.8, frame_h * 0.2, 18, (accent[0], accent[1], accent[2], int(170 * strength)))
            canvas.draw_line(ox + frame_w * 0.28, frame_h * 0.74, ox + frame_w * 0.72, frame_h * 0.26, 8, (255, 230, 220, int(120 * strength)))
        elif "thunder" in kind:
            canvas.draw_line(ox + frame_w * 0.4, frame_h * 0.05, ox + frame_w * 0.56, frame_h * 0.38, 12, (accent[0], accent[1], accent[2], int(180 * strength)))
            canvas.draw_line(ox + frame_w * 0.56, frame_h * 0.38, ox + frame_w * 0.44, frame_h * 0.58, 12, (255, 245, 220, int(180 * strength)))
            canvas.draw_line(ox + frame_w * 0.44, frame_h * 0.58, ox + frame_w * 0.62, frame_h * 0.95, 12, (accent[0], accent[1], accent[2], int(180 * strength)))
        elif "beam" in kind:
            canvas.draw_rect(int(ox + frame_w * 0.45), 0, int(ox + frame_w * 0.55), frame_h, (accent[0], accent[1], accent[2], int(170 * strength)))
            canvas.draw_ring(ox + frame_w * 0.5, frame_h * 0.16, frame_w * 0.16 + i * 2, 6, (255, 240, 220, int(140 * strength)))
        else:
            canvas.draw_circle(ox + frame_w * 0.5, frame_h * 0.5, frame_h * 0.20 + i * 2, (accent[0], accent[1], accent[2], int(160 * strength)))
    return canvas


def parse_size(size_text: str) -> Tuple[int, int]:
    w_text, h_text = size_text.lower().split("x")
    return int(w_text), int(h_text)


def generate_asset(spec: AssetSpec) -> None:
    out_path = ROOT / spec.output_path
    size = spec.meta.get("sheet_size", spec.target_size)
    width, height = parse_size(size)
    if spec.generator == "background":
        canvas = render_background(spec.meta["theme"], width, height, spec.logical_id)
    elif spec.generator == "portrait":
        canvas = render_portrait(spec.meta["kind"], width, height, spec.logical_id)
    elif spec.generator == "icon":
        canvas = render_icon(spec.meta["kind"], width, height, spec.logical_id)
    elif spec.generator == "frame":
        canvas = render_frame(spec.meta["kind"], width, height, spec.logical_id)
    elif spec.generator == "result_card":
        canvas = render_result_card(spec.meta["kind"], width, height, spec.logical_id)
    elif spec.generator == "button":
        canvas = render_button(spec.meta["kind"], width, height, spec.logical_id)
    elif spec.generator == "scroll":
        canvas = render_scroll_bar(width, height, spec.logical_id)
    elif spec.generator == "spritesheet":
        frame_w = int(spec.meta["frame_w"])
        frame_h = int(spec.meta["frame_h"])
        frames = int(spec.meta["frames"])
        canvas = render_spritesheet(spec.meta["kind"], frame_w, frame_h, frames, spec.logical_id)
    elif spec.generator == "effect":
        frame_w = int(spec.meta["frame_w"])
        frame_h = int(spec.meta["frame_h"])
        frames = int(spec.meta["frames"])
        canvas = render_effect(spec.meta["kind"], frame_w, frame_h, frames, spec.logical_id)
    else:
        raise ValueError("Unknown generator: %s" % spec.generator)
    canvas.save_png(out_path)


def current_spec(
    logical_id: str,
    category: str,
    output_path: str,
    target_size: str,
    prompt_suffix: str,
    generator: str,
    **meta: str,
) -> AssetSpec:
    return AssetSpec(
        logical_id=logical_id,
        category=category,
        wired_now=True,
        output_path=output_path,
        target_size=target_size,
        background_mode="transparent" if category in {"bosses", "characters", "icons", "ui", "portraits"} else "opaque",
        prompt="%s, %s" % (GLOBAL_PROMPT, prompt_suffix),
        negative_prompt=NEGATIVE_PROMPT,
        source_doc="文档/11_美术资源清单.md + 工程当前真实引用",
        replace_mode="same_path" if "new_ref" not in meta else "new_path_and_rewire",
        generator=generator,
        meta={k: str(v) for k, v in meta.items() if k != "new_ref"},
    )


def future_spec(
    logical_id: str,
    category: str,
    output_path: str,
    target_size: str,
    prompt_suffix: str,
    generator: str,
    **meta: str,
) -> AssetSpec:
    return AssetSpec(
        logical_id=logical_id,
        category=category,
        wired_now=False,
        output_path=output_path,
        target_size=target_size,
        background_mode="transparent" if category in {"bosses", "characters", "icons", "ui", "portraits", "effects"} else "opaque",
        prompt="%s, %s" % (GLOBAL_PROMPT, prompt_suffix),
        negative_prompt=NEGATIVE_PROMPT,
        source_doc="文档/11_美术资源清单.md",
        replace_mode="new_file_only",
        generator=generator,
        meta={k: str(v) for k, v in meta.items()},
    )


def build_specs() -> List[AssetSpec]:
    specs: List[AssetSpec] = []
    hero_sequence_descriptor = (
        "same AFK-RPG hero in every frame, full-body young martial disciple, stern youthful face, "
        "same black-gray layered robe, same brown sash, same dark topknot, same single-edged sword and wooden scabbard at waist, "
        "same right-facing 3/4 side profile, same camera distance, same body proportions, same silhouette scale, "
        "same lighting direction, transparent background, animation-sheet consistency, only pose and cloth motion change between frames"
    )

    # Wired backgrounds.
    specs.extend(
        [
            current_spec("bg_taoxi_waidu_v2a", "backgrounds", "assets/generated/afk_rpg_formal/backgrounds/bg_taoxi_waidu_v2a.png", "1280x720", "wuxia foothill road, bridge, sparse lanterns, misty greenery, combat-safe center", "background", theme="taoxi_outskirts_a"),
            current_spec("bg_taoxi_waidu_v2b", "backgrounds", "assets/generated/afk_rpg_formal/backgrounds/bg_taoxi_waidu_v2b.png", "1280x720", "wuxia riverside crossing, wooden bridge, village edge, dusk lanterns, combat-safe center", "background", theme="taoxi_outskirts_b"),
            current_spec("bg_cixia_lingtian_v2a", "backgrounds", "assets/generated/afk_rpg_formal/backgrounds/bg_cixia_lingtian_v2a.png", "1280x720", "ruined martial field, abandoned shrine ruins, dark green ink wash, combat-safe center", "background", theme="cixia_ruins_a"),
            current_spec("bg_cixia_lingtian_v2b", "backgrounds", "assets/generated/afk_rpg_formal/backgrounds/bg_cixia_lingtian_v2b.png", "1280x720", "collapsed ritual hall, ruined martial valley, dim torches, combat-safe center", "background", theme="cixia_ruins_b"),
            current_spec("bg_tiesuo_zhen_v1a", "backgrounds", "assets/generated/afk_rpg_formal/backgrounds/bg_tiesuo_zhen_v1a.png", "1280x720", "busy jianghu market town, hanging lanterns, lock-gang district, warm-dark contrast, combat-safe center", "background", theme="tiesuo_market", new_ref="1"),
            current_spec("bg_tiesuo_zhen_v1b", "backgrounds", "assets/generated/afk_rpg_formal/backgrounds/bg_tiesuo_zhen_v1b.png", "1280x720", "dockside underworld town, piers, black-flag warehouse, underground gambling vibe, combat-safe center", "background", theme="tiesuo_docks", new_ref="1"),
        ]
    )

    # Wired bosses / portraits / hero.
    specs.extend(
        [
            current_spec("boss_fuci_shanjun_v2", "bosses", "assets/generated/afk_rpg_formal/bosses/boss_fuci_shanjun_v2.png", "768x768", "ferocious mountain bandit boss, horned iron mask, heavy robe, strong silhouette, transparent background", "portrait", kind="boss_fuci_shanjun"),
            current_spec("boss_jilu_jianyuan_v2", "bosses", "assets/generated/afk_rpg_formal/bosses/boss_jilu_jianyuan_v2.png", "768x768", "ritual forge overseer boss, ash priest armor, bronze ritual frame, transparent background", "portrait", kind="boss_jilu_overseer"),
            current_spec("boss_yingou_laoren_v1", "bosses", "assets/generated/afk_rpg_formal/bosses/boss_yingou_laoren_v1.png", "768x768", "old hook master boss, sly elder, silver hook weapon, town underworld leader, transparent background", "portrait", kind="boss_hook_elder", new_ref="1"),
            current_spec("hero_idle_v2", "characters", "assets/generated/afk_rpg_formal/characters/hero_idle_v2.png", "768x768", "young martial disciple idle portrait, clean wuxia silhouette, transparent background", "portrait", kind="hero_idle"),
            current_spec("hero_move_hint_v2", "characters", "assets/generated/afk_rpg_formal/characters/hero_move_hint_v2.png", "768x768", "young martial disciple movement pose, flowing robe, transparent background", "portrait", kind="hero_move"),
            current_spec("hero_combat_pose_v2", "characters", "assets/generated/afk_rpg_formal/characters/hero_combat_pose_v2.png", "768x768", "young martial disciple combat pose, ready stance, strong silhouette, transparent background", "portrait", kind="hero_combat"),
            current_spec("hero_move_anim_01", "characters", "assets/generated/afk_rpg_formal/characters/hero_move_anim_01.png", "768x768", "%s, run cycle frame 1 of 4, right foot planted forward, left leg pushing off, sword stays sheathed, cloak trailing backward, keep framing identical to the rest of the move cycle" % hero_sequence_descriptor, "portrait", kind="hero_move_anim_01"),
            current_spec("hero_move_anim_02", "characters", "assets/generated/afk_rpg_formal/characters/hero_move_anim_02.png", "768x768", "%s, run cycle frame 2 of 4, passing step, both feet close under body, robe hem swinging, sword stays sheathed, keep framing identical to the rest of the move cycle" % hero_sequence_descriptor, "portrait", kind="hero_move_anim_02"),
            current_spec("hero_move_anim_03", "characters", "assets/generated/afk_rpg_formal/characters/hero_move_anim_03.png", "768x768", "%s, run cycle frame 3 of 4, left foot planted forward, right leg pushing off, cloak trailing backward, sword stays sheathed, keep framing identical to the rest of the move cycle" % hero_sequence_descriptor, "portrait", kind="hero_move_anim_03"),
            current_spec("hero_move_anim_04", "characters", "assets/generated/afk_rpg_formal/characters/hero_move_anim_04.png", "768x768", "%s, run cycle frame 4 of 4, passing step mirrored, robe hem swinging, sword stays sheathed, keep framing identical to the rest of the move cycle" % hero_sequence_descriptor, "portrait", kind="hero_move_anim_04"),
            current_spec("hero_attack_anim_01", "characters", "assets/generated/afk_rpg_formal/characters/hero_attack_anim_01.png", "768x768", "%s, attack cycle frame 1 of 4, guarded wind-up stance, sword drawn in right hand, left hand stabilizing posture, keep framing identical to the rest of the attack cycle" % hero_sequence_descriptor, "portrait", kind="hero_attack_anim_01"),
            current_spec("hero_attack_anim_02", "characters", "assets/generated/afk_rpg_formal/characters/hero_attack_anim_02.png", "768x768", "%s, attack cycle frame 2 of 4, decisive forward slash, sword clearly visible, same camera and body scale, keep framing identical to the rest of the attack cycle" % hero_sequence_descriptor, "portrait", kind="hero_attack_anim_02"),
            current_spec("hero_attack_anim_03", "characters", "assets/generated/afk_rpg_formal/characters/hero_attack_anim_03.png", "768x768", "%s, attack cycle frame 3 of 4, follow-through slash with torso rotation, sword clearly visible, same camera and body scale, keep framing identical to the rest of the attack cycle" % hero_sequence_descriptor, "portrait", kind="hero_attack_anim_03"),
            current_spec("hero_attack_anim_04", "characters", "assets/generated/afk_rpg_formal/characters/hero_attack_anim_04.png", "768x768", "%s, attack cycle frame 4 of 4, recovery stance after slash, sword lowering back toward guard, same camera and body scale, keep framing identical to the rest of the attack cycle" % hero_sequence_descriptor, "portrait", kind="hero_attack_anim_04"),
            current_spec("enemy_normal_placeholder", "portraits", "assets/generated/portraits/enemy_normal_placeholder.png", "768x768", "generic jianghu thug portrait, simple silhouette, transparent background", "portrait", kind="enemy_normal"),
            current_spec("enemy_elite_placeholder", "portraits", "assets/generated/portraits/enemy_elite_placeholder.png", "768x768", "generic elite martial foe portrait, stronger silhouette, transparent background", "portrait", kind="enemy_elite"),
        ]
    )

    # Wired icons and frames.
    wired_icon_specs = [
        ("drop_daily_reward", "drop_daily_reward"),
        ("drop_equipment", "drop_equipment"),
        ("drop_event_reward", "drop_event_reward"),
        ("drop_rare", "drop_rare"),
        ("resource_cihui", "resource_cihui"),
        ("resource_linghe", "resource_linghe"),
        ("resource_xianghuoqian", "resource_xianghuoqian"),
        ("resource_zhenyi_canpian", "resource_zhenyi_canpian"),
        ("school_wuleidao_highlight", "school_wulei_highlight"),
        ("school_xuejiedao_highlight", "school_xuejie_highlight"),
        ("school_yufengdao_highlight", "school_yufeng_highlight"),
        ("system_biguan_suode", "system_biguan_suode"),
        ("system_jinrijiyuan", "system_jinrijiyuan"),
        ("system_jiyuantuiyan", "system_jiyuantuiyan"),
        ("system_wudao", "system_wudao"),
        ("system_yiwenlu", "system_yiwenlu"),
    ]
    for file_name, kind in wired_icon_specs:
        specs.append(
            current_spec(
                file_name,
                "icons",
                f"assets/generated/afk_rpg_formal/icons/{file_name}.png",
                "256x256",
                f"wuxia game icon, {kind.replace('_', ' ')}",
                "icon",
                kind=kind,
            )
        )

    for file_name, kind in [
        ("drop_salvage", "drop_salvage"),
        ("equip_armor", "armor"),
        ("equip_gloves", "glove"),
        ("equip_helmet", "helmet"),
        ("equip_weapon", "weapon"),
        ("nav_inventory", "nav_inventory"),
    ]:
        specs.append(
            current_spec(
                file_name,
                "icons",
                f"assets/generated/icons/{file_name}.png",
                "256x256",
                f"wuxia ui icon, {kind}",
                "icon",
                kind=kind,
            )
        )

    for frame_name, kind in [
        ("frame_common", "frame_common"),
        ("frame_rare", "frame_rare"),
        ("frame_epic", "frame_epic"),
        ("frame_legendary", "frame_legendary"),
        ("frame_ancient", "frame_ancient"),
    ]:
        specs.append(
            current_spec(
                frame_name,
                "ui",
                f"assets/generated/ui/{frame_name}.png",
                "256x256",
                f"wuxia quality frame, {kind}",
                "frame",
                kind=kind,
            )
        )

    for card_name, kind in [
        ("result_card_template_common", "result_common"),
        ("result_card_template_rare", "result_rare"),
    ]:
        specs.append(
            current_spec(
                card_name,
                "ui",
                f"assets/generated/afk_rpg_formal/ui/{card_name}.png",
                "1024x512",
                f"dark wuxia result card panel, {kind}",
                "result_card",
                kind=kind,
            )
        )

    # Unwired portraits and character sheets.
    specs.extend(
        [
            future_spec("disciple_male_portrait", "characters", "assets/generated/afk_rpg_formal/characters/disciple_male_portrait.png", "512x512", "male outer disciple portrait, transparent background", "portrait", kind="disciple_male"),
            future_spec("disciple_female_portrait", "characters", "assets/generated/afk_rpg_formal/characters/disciple_female_portrait.png", "512x512", "female outer disciple portrait, transparent background", "portrait", kind="disciple_female"),
            future_spec("disciple_male_sheet", "characters", "assets/generated/afk_rpg_formal/characters/disciple_male_sheet.png", "512x64", "male disciple combat spritesheet, 8 frames, transparent background", "spritesheet", kind="disciple_male_sheet", frame_w="64", frame_h="64", frames="8", sheet_size="512x64"),
            future_spec("disciple_female_sheet", "characters", "assets/generated/afk_rpg_formal/characters/disciple_female_sheet.png", "512x64", "female disciple combat spritesheet, 8 frames, transparent background", "spritesheet", kind="disciple_female_sheet", frame_w="64", frame_h="64", frames="8", sheet_size="512x64"),
            future_spec("elder_portrait", "characters", "assets/generated/afk_rpg_formal/characters/elder_portrait.png", "512x512", "martial elder portrait, transparent background", "portrait", kind="elder"),
            future_spec("headmaster_portrait", "characters", "assets/generated/afk_rpg_formal/characters/headmaster_portrait.png", "512x512", "sect headmaster portrait, transparent background", "portrait", kind="headmaster"),
            future_spec("smith_portrait", "characters", "assets/generated/afk_rpg_formal/characters/smith_portrait.png", "512x512", "forge craftsman portrait, transparent background", "portrait", kind="smith"),
        ]
    )

    # Unwired enemy sheets from the document.
    for logical_id, file_name, sheet_size, frame_w, frame_h, frames, prompt_suffix in [
        ("enemy_shanye_shuqun_sheet", "enemy_shanye_shuqun_sheet", "128x32", 32, 32, 4, "mountain rat pack spritesheet, 4 frames"),
        ("enemy_shanfei_louluo_sheet", "enemy_shanfei_louluo_sheet", "288x48", 48, 48, 6, "bandit lackey spritesheet, 6 frames"),
        ("enemy_shanfei_junshi_sheet", "enemy_shanfei_junshi_sheet", "288x48", 48, 48, 6, "bandit strategist elite spritesheet, 6 frames"),
        ("boss_tiemian_qiuranke_sheet", "boss_tiemian_qiuranke_sheet", "768x96", 96, 96, 8, "iron-faced bandit boss spritesheet, 8 frames"),
        ("enemy_yelang_sheet", "enemy_yelang_sheet", "128x32", 32, 32, 4, "wild wolf spritesheet, 4 frames"),
        ("enemy_luoyan_canbing_sheet", "enemy_luoyan_canbing_sheet", "288x48", 48, 48, 6, "fallen valley remnant soldier spritesheet, 6 frames"),
        ("enemy_guzhong_lishi_sheet", "enemy_guzhong_lishi_sheet", "288x48", 48, 48, 6, "valley brute spritesheet, 6 frames"),
        ("elite_luoyan_fuzhang_sheet", "elite_luoyan_fuzhang_sheet", "288x48", 48, 48, 6, "deputy master elite spritesheet, 6 frames"),
        ("elite_luoyan_shushi_sheet", "elite_luoyan_shushi_sheet", "288x48", 48, 48, 6, "valley warlock elite spritesheet, 6 frames"),
        ("boss_kugu_jianke_sheet", "boss_kugu_jianke_sheet", "768x96", 96, 96, 8, "skeletal swordsman boss spritesheet, 8 frames"),
    ]:
        specs.append(
            future_spec(
                logical_id,
                "enemies",
                f"assets/generated/afk_rpg_formal/enemies/{file_name}.png",
                sheet_size,
                prompt_suffix,
                "spritesheet",
                kind=logical_id,
                frame_w=str(frame_w),
                frame_h=str(frame_h),
                frames=str(frames),
                sheet_size=sheet_size,
            )
        )

    # Future backgrounds.
    for logical_id, theme, file_name in [
        ("bg_main_menu_qingyun", "qingyun_main", "bg_main_menu_qingyun.png"),
        ("bg_rift_trial", "rift_trial", "bg_rift_trial.png"),
        ("bg_xuedao_ling", "xuedao_ling", "bg_xuedao_ling.png"),
        ("bg_jianzhong", "jianzhong", "bg_jianzhong.png"),
    ]:
        specs.append(
            future_spec(
                logical_id,
                "backgrounds",
                f"assets/generated/afk_rpg_formal/backgrounds/{file_name}",
                "1920x1080",
                f"wuxia background scene, {theme.replace('_', ' ')}",
                "background",
                theme=theme,
            )
        )

    # Equipment icon families.
    for base_kind in ["blade", "axe", "spear", "orb", "staff", "helmet", "armor", "glove", "legs", "boots", "accessory", "belt"]:
        for rarity in ["common", "rare", "epic"]:
            specs.append(
                future_spec(
                    f"icon_{base_kind}_{rarity}",
                    "icons",
                    f"assets/generated/afk_rpg_formal/icons/icon_{base_kind}_{rarity}.png",
                    "256x256",
                    f"wuxia equipment icon, {base_kind}, {rarity} quality",
                    "icon",
                    kind=f"{base_kind}_{rarity}",
                )
            )

    # Unwired quality and set frames.
    for frame_kind in ["frame_uncommon", "frame_set", "frame_common", "frame_rare", "frame_epic", "frame_legendary", "frame_ancient"]:
        specs.append(
            future_spec(
                frame_kind,
                "ui",
                f"assets/generated/afk_rpg_formal/ui/{frame_kind}.png",
                "256x256",
                f"wuxia item frame, {frame_kind}",
                "frame",
                kind=frame_kind,
            )
        )
    for set_id in ["set_wind", "set_blood", "set_thunder", "set_iron"]:
        specs.append(
            future_spec(
                f"{set_id}_frame",
                "ui",
                f"assets/generated/afk_rpg_formal/ui/{set_id}_frame.png",
                "256x256",
                f"wuxia set frame, {set_id}",
                "frame",
                kind=set_id,
            )
        )

    # Gem and key icons.
    for gem_id in ["gem_wind_echo", "gem_blood_oath", "gem_thunder_vein"]:
        specs.append(
            future_spec(
                gem_id,
                "icons",
                f"assets/generated/afk_rpg_formal/icons/{gem_id}.png",
                "256x256",
                f"wuxia gem icon, {gem_id}",
                "icon",
                kind=gem_id,
            )
        )
    for key_id in ["rift_key_common", "rift_key_greater"]:
        specs.append(
            future_spec(
                key_id,
                "icons",
                f"assets/generated/afk_rpg_formal/icons/{key_id}.png",
                "256x256",
                f"trial key icon, {key_id}",
                "icon",
                kind=key_id,
            )
        )

    # UI controls.
    specs.extend(
        [
            future_spec("panel_frame_9patch", "ui", "assets/generated/afk_rpg_formal/ui/panel_frame_9patch.png", "256x256", "dark wuxia panel frame 9patch", "frame", kind="panel_frame"),
            future_spec("button_common_normal", "ui", "assets/generated/afk_rpg_formal/ui/button_common_normal.png", "128x48", "wuxia button normal state", "button", kind="button_normal"),
            future_spec("button_common_hover", "ui", "assets/generated/afk_rpg_formal/ui/button_common_hover.png", "128x48", "wuxia button hover state", "button", kind="button_hover"),
            future_spec("button_common_pressed", "ui", "assets/generated/afk_rpg_formal/ui/button_common_pressed.png", "128x48", "wuxia button pressed state", "button", kind="button_pressed"),
            future_spec("scroll_texture_bar", "ui", "assets/generated/afk_rpg_formal/ui/scroll_texture_bar.png", "256x64", "wuxia parchment title strip", "scroll"),
            future_spec("equipment_slot_base", "ui", "assets/generated/afk_rpg_formal/ui/equipment_slot_base.png", "72x72", "wuxia equipment slot base", "frame", kind="equipment_slot"),
            future_spec("skill_slot_base", "ui", "assets/generated/afk_rpg_formal/ui/skill_slot_base.png", "48x48", "wuxia skill slot base", "frame", kind="skill_slot"),
        ]
    )

    # Effects.
    for logical_id, sheet_size, frame_w, frame_h, frames, kind in [
        ("effect_whirlwind_sheet", "1024x128", 128, 128, 8, "whirlwind"),
        ("effect_blood_blade_sheet", "768x64", 128, 64, 6, "blood_blade"),
        ("effect_thunder_arc_sheet", "384x64", 64, 64, 6, "thunder_arc"),
        ("effect_crit_sheet", "384x96", 96, 96, 4, "crit"),
        ("effect_set_flash_sheet", "384x128", 128, 128, 3, "set_flash"),
        ("effect_loot_beam_sheet", "64x128", 16, 128, 4, "loot_beam"),
    ]:
        specs.append(
            future_spec(
                logical_id,
                "effects",
                f"assets/generated/afk_rpg_formal/effects/{logical_id}.png",
                sheet_size,
                f"wuxia effect sheet, {kind}, transparent background",
                "effect",
                kind=kind,
                frame_w=str(frame_w),
                frame_h=str(frame_h),
                frames=str(frames),
                sheet_size=sheet_size,
            )
        )

    return specs


def write_markdown_table(path: Path, title: str, rows: Sequence[AssetSpec], include_prompts: bool) -> None:
    header = (
        "# %s\n\n" % title
        + "由 `tools/generate_art_assets.py` 自动生成。当前风格基线：水墨写意 + 暗黑like 武侠材质。\n\n"
    )
    if include_prompts:
        header += "全局正向母版：`%s`\n\n全局负向母版：`%s`\n\n" % (GLOBAL_PROMPT, NEGATIVE_PROMPT)
    lines = [header]
    if include_prompts:
        lines.append("| logical_id | category | wired_now | output_path | target_size | prompt | negative_prompt |")
        lines.append("|---|---|---|---|---|---|---|")
        for spec in rows:
            lines.append(
                "| `%s` | `%s` | `%s` | `%s` | `%s` | %s | %s |"
                % (
                    spec.logical_id,
                    spec.category,
                    str(spec.wired_now).lower(),
                    spec.output_path,
                    spec.target_size,
                    spec.prompt.replace("|", "/"),
                    spec.negative_prompt.replace("|", "/"),
                )
            )
    else:
        lines.append("| logical_id | category | wired_now | output_path | target_size | background_mode | source_doc | replace_mode |")
        lines.append("|---|---|---|---|---|---|---|---|")
        for spec in rows:
            lines.append(
                "| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |"
                % (
                    spec.logical_id,
                    spec.category,
                    str(spec.wired_now).lower(),
                    spec.output_path,
                    spec.target_size,
                    spec.background_mode,
                    spec.source_doc,
                    spec.replace_mode,
                )
            )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_summary(specs: Sequence[AssetSpec]) -> None:
    summary_lines = [
        "# AFK-RPG 美术资源生成摘要",
        "",
        "本文件由 `tools/generate_art_assets.py` 自动生成。",
        "",
        "- 总资源数: %d" % len(specs),
        "- 当前工程已接线资源: %d" % len([s for s in specs if s.wired_now]),
        "- 文档未接线入库资源: %d" % len([s for s in specs if not s.wired_now]),
        "",
    ]
    (ROOT / "文档" / "美术资源生成摘要_v1.md").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")


def verify_sizes(specs: Sequence[AssetSpec]) -> None:
    for spec in specs:
        path = ROOT / spec.output_path
        if not path.exists():
            raise FileNotFoundError(spec.output_path)
        expected_w, expected_h = parse_size(spec.meta.get("sheet_size", spec.target_size))
        output = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)], text=True)
        pixels = {}
        for line in output.splitlines():
            line = line.strip()
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            pixels[key.strip()] = int(value.strip())
        if pixels.get("pixelWidth") != expected_w or pixels.get("pixelHeight") != expected_h:
            raise RuntimeError("Size mismatch for %s: got %sx%s expected %sx%s" % (
                spec.output_path,
                pixels.get("pixelWidth"),
                pixels.get("pixelHeight"),
                expected_w,
                expected_h,
            ))


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate AFK-RPG placeholder assets and manifests.")
    parser.add_argument(
        "--regenerate-assets",
        action="store_true",
        help="Rewrite placeholder assets on disk before refreshing manifests.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    specs = build_specs()
    if args.regenerate_assets:
        for spec in specs:
            generate_asset(spec)

    docs_dir = ROOT / "文档"
    write_markdown_table(docs_dir / "美术资源执行清单_v1.md", "AFK-RPG 美术资源执行清单 v1", specs, include_prompts=False)
    write_markdown_table(docs_dir / "美术提示词清单_v1.md", "AFK-RPG 美术提示词清单 v1", specs, include_prompts=True)
    write_summary(specs)
    verify_sizes(specs)
    if args.regenerate_assets:
        print("Generated %d assets and wrote manifests." % len(specs))
    else:
        print("Wrote manifests and verified %d existing assets." % len(specs))


if __name__ == "__main__":
    main()
