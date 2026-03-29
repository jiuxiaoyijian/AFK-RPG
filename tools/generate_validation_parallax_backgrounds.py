#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import generate_art_assets as art


ROOT = Path("/Users/hehe/Documents/AIProject/AFK-RPG")
OUT_DIR = ROOT / "assets" / "generated" / "afk_rpg_formal" / "backgrounds"
WIDTH = 1280
HEIGHT = 720


def _draw_banner(canvas: art.Canvas, x: int, y: int, color: tuple[int, int, int, int]) -> None:
	canvas.draw_rect(x, y, x + 12, y + 96, art.darken(color, 0.55))
	canvas.draw_rect(x + 12, y + 8, x + 76, y + 44, color)


def build_far() -> art.Canvas:
	canvas = art.Canvas(WIDTH, HEIGHT, art.hex_rgba("#d5d1c7"))
	canvas.draw_gradient((210, 204, 193), (188, 176, 156))
	rng = art.seeded_rng("validation_far")
	for index in range(5):
		base_x = 80 + index * 240
		height_offset = 120 + (index % 3) * 30
		color = art.hex_rgba("#7d7569", 255)
		canvas.draw_rect(base_x, 220, base_x + 120, 460, color)
		canvas.draw_rect(base_x + 20, 180 - height_offset // 4, base_x + 100, 220, art.lighten(color, 0.1))
	for x in range(0, WIDTH, 90):
		canvas.draw_line(x, 220, x + 80, 140, 6.0, art.hex_rgba("#6a675f", 180))
	art.add_paper_noise(canvas, rng, density=1800, tint=art.hex_rgba("#f2eee6", 42))
	return canvas


def build_mid() -> art.Canvas:
	canvas = art.Canvas(WIDTH, HEIGHT, (0, 0, 0, 0))
	rng = art.seeded_rng("validation_mid")
	for index in range(7):
		base_x = 40 + index * 180
		width = 110 + (index % 2) * 24
		base_y = 280 + (index % 3) * 16
		body = art.hex_rgba("#755a3d", 235)
		canvas.draw_rect(base_x, base_y, base_x + width, 560, body)
		canvas.draw_rect(base_x + 8, base_y - 28, base_x + width - 8, base_y, art.lighten(body, 0.1))
		canvas.draw_rect(base_x + 14, base_y + 60, base_x + 34, base_y + 110, art.hex_rgba("#d98b34", 225))
	for x in range(40, WIDTH, 180):
		_draw_banner(canvas, x + 56, 210, art.hex_rgba("#b34f2d", 220))
		canvas.draw_circle(x + 92, 254, 18, art.hex_rgba("#eab15a", 180))
	art.add_paper_noise(canvas, rng, density=900, tint=art.hex_rgba("#fff7e3", 26))
	return canvas


def build_near() -> art.Canvas:
	canvas = art.Canvas(WIDTH, HEIGHT, (0, 0, 0, 0))
	rng = art.seeded_rng("validation_near")
	for x in range(0, WIDTH, 160):
		post = art.hex_rgba("#473526", 235)
		canvas.draw_rect(x + 20, 448, x + 42, HEIGHT, post)
		canvas.draw_rect(x + 42, 470, x + 126, 494, art.hex_rgba("#5a4330", 225))
		canvas.draw_rect(x + 66, 518, x + 126, 610, art.hex_rgba("#6c4f37", 210))
		canvas.draw_circle(x + 84, 548, 18, art.hex_rgba("#d9862b", 170))
	canvas.draw_rect(0, 610, WIDTH, HEIGHT, art.hex_rgba("#4b3c2f", 220))
	for x in range(40, WIDTH, 220):
		canvas.draw_circle(x, 610, 42, art.hex_rgba("#c56b2d", 140))
	art.add_paper_noise(canvas, rng, density=1200, tint=art.hex_rgba("#fff2dd", 22))
	return canvas


def main() -> int:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	base_name = "bg_validation_scroll"
	build_far().save_png(OUT_DIR / f"{base_name}__far.png")
	build_mid().save_png(OUT_DIR / f"{base_name}__mid.png")
	build_near().save_png(OUT_DIR / f"{base_name}__near.png")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
