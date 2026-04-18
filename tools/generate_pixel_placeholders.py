"""
Pixel Placeholder Generator
Scans assets/generated/ for all .png files and replaces them with
simple pixel-art placeholder images, categorized by directory path.
Original files are backed up to _legacy/assets/ before replacement.
"""

import os
import shutil
import hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets" / "generated"
LEGACY_DIR = PROJECT_ROOT / "_legacy" / "assets" / "generated"

PALETTE = {
    "bg_dark": (18, 18, 24),
    "bg_mid": (30, 30, 42),
    "bg_light": (50, 50, 65),
    "outline": (80, 80, 100),
    "text": (180, 180, 200),
    "char_body": (60, 100, 180),
    "char_light": (100, 150, 220),
    "char_dark": (40, 70, 130),
    "enemy_body": (160, 50, 50),
    "enemy_light": (200, 80, 80),
    "enemy_dark": (110, 30, 30),
    "boss_body": (130, 20, 20),
    "boss_light": (180, 50, 50),
    "boss_dark": (80, 10, 10),
    "icon_fill": (100, 100, 120),
    "icon_outline": (160, 160, 180),
    "ui_border": (90, 85, 75),
    "ui_fill": (35, 33, 30),
    "ui_highlight": (130, 120, 100),
    "effect_glow": (255, 220, 100),
    "effect_flash": (200, 200, 255),
    "sky_top": (20, 15, 40),
    "sky_bottom": (40, 50, 80),
    "ground": (45, 40, 35),
    "trees": (30, 50, 35),
    "portrait_bg": (40, 40, 55),
}


def classify_asset(rel_path: str) -> str:
    """Classify asset by its relative path into a category."""
    p = rel_path.replace("\\", "/").lower()
    if "characters/" in p or "hero_" in p or "disciple_" in p or "elder_" in p or "headmaster_" in p or "smith_" in p:
        return "character"
    if "bosses/" in p or "boss_" in p:
        return "boss"
    if "enemies/" in p and ("boss_" in p or "boss" in p):
        return "boss_enemy"
    if "enemies/" in p:
        return "enemy"
    if "effects/" in p:
        return "effect"
    if "portraits/" in p:
        return "portrait"
    if "_debug_masks/" in p:
        return "debug_mask"
    if "backgrounds/" in p or "bg_" in p:
        return "background"
    if "icons/" in p:
        return "icon"
    if "hud/" in p:
        return "ui_hud"
    if "inventory/" in p:
        return "ui_inventory"
    if "controls/" in p:
        return "ui_controls"
    if "extracted_ps_sheet" in p:
        return "ui_extracted"
    if "ui/" in p or "frame_" in p:
        return "ui"
    if "formal_replacement" in p:
        return "ui"
    return "misc"


def label_from_path(rel_path: str) -> str:
    """Extract a short label from the file path."""
    name = Path(rel_path).stem
    name = name.replace("_", " ")
    if len(name) > 20:
        name = name[:18] + ".."
    return name


def seed_from_path(rel_path: str) -> int:
    return int(hashlib.md5(rel_path.encode()).hexdigest()[:8], 16)


def draw_pixel_rect(draw, x, y, w, h, color):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def gen_character(size, label, seed_val):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w // 2, h // 2

    head_s = max(w // 5, 4)
    draw_pixel_rect(draw, cx - head_s // 2, cy - h // 3, head_s, head_s, PALETTE["char_light"])
    draw_pixel_rect(draw, cx - head_s // 2 - 1, cy - h // 3 - 1, head_s + 2, head_s + 2, PALETTE["char_dark"])
    draw_pixel_rect(draw, cx - head_s // 2, cy - h // 3, head_s, head_s, PALETTE["char_light"])

    body_w = max(w // 3, 6)
    body_h = max(h // 3, 6)
    draw_pixel_rect(draw, cx - body_w // 2, cy - h // 3 + head_s, body_w, body_h, PALETTE["char_body"])

    leg_w = max(w // 8, 2)
    leg_h = max(h // 4, 4)
    draw_pixel_rect(draw, cx - body_w // 4, cy - h // 3 + head_s + body_h, leg_w, leg_h, PALETTE["char_dark"])
    draw_pixel_rect(draw, cx + body_w // 4 - leg_w, cy - h // 3 + head_s + body_h, leg_w, leg_h, PALETTE["char_dark"])

    try:
        draw.text((1, h - 8), label[:12], fill=PALETTE["text"])
    except Exception:
        pass
    return img


def gen_enemy(size, label, seed_val):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w // 2, h // 2

    body_s = max(min(w, h) // 3, 6)
    draw_pixel_rect(draw, cx - body_s // 2 - 1, cy - body_s // 2 - 1, body_s + 2, body_s + 2, PALETTE["enemy_dark"])
    draw_pixel_rect(draw, cx - body_s // 2, cy - body_s // 2, body_s, body_s, PALETTE["enemy_body"])

    eye_s = max(body_s // 4, 2)
    draw_pixel_rect(draw, cx - body_s // 4, cy - body_s // 4, eye_s, eye_s, PALETTE["enemy_light"])
    draw_pixel_rect(draw, cx + body_s // 8, cy - body_s // 4, eye_s, eye_s, PALETTE["enemy_light"])

    try:
        draw.text((1, h - 8), label[:12], fill=PALETTE["text"])
    except Exception:
        pass
    return img


def gen_boss(size, label, seed_val):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w // 2, h // 2

    body_w = max(w // 2, 10)
    body_h = max(h // 2, 10)
    draw_pixel_rect(draw, cx - body_w // 2 - 1, cy - body_h // 2 - 1, body_w + 2, body_h + 2, PALETTE["boss_dark"])
    draw_pixel_rect(draw, cx - body_w // 2, cy - body_h // 2, body_w, body_h, PALETTE["boss_body"])

    horn_w = max(body_w // 6, 2)
    horn_h = max(body_h // 3, 3)
    draw_pixel_rect(draw, cx - body_w // 3, cy - body_h // 2 - horn_h, horn_w, horn_h, PALETTE["boss_light"])
    draw_pixel_rect(draw, cx + body_w // 3 - horn_w, cy - body_h // 2 - horn_h, horn_w, horn_h, PALETTE["boss_light"])

    eye_s = max(body_w // 5, 3)
    draw_pixel_rect(draw, cx - body_w // 4, cy - body_h // 6, eye_s, eye_s, PALETTE["effect_glow"])
    draw_pixel_rect(draw, cx + body_w // 8, cy - body_h // 6, eye_s, eye_s, PALETTE["effect_glow"])

    try:
        draw.text((1, h - 8), label[:16], fill=PALETTE["text"])
    except Exception:
        pass
    return img


def gen_icon(size, label, seed_val):
    img = Image.new("RGBA", size, PALETTE["bg_dark"])
    draw = ImageDraw.Draw(img)
    w, h = size

    draw.rectangle([0, 0, w - 1, h - 1], outline=PALETTE["icon_outline"])

    inner_m = max(w // 4, 2)
    draw_pixel_rect(draw, inner_m, inner_m, w - inner_m * 2, h - inner_m * 2, PALETTE["icon_fill"])

    if w >= 16 and h >= 16:
        diamond_cx, diamond_cy = w // 2, h // 2
        ds = max(w // 6, 2)
        for i in range(ds):
            draw_pixel_rect(draw, diamond_cx - i, diamond_cy - ds + i, 1, 1, PALETTE["icon_outline"])
            draw_pixel_rect(draw, diamond_cx + i, diamond_cy - ds + i, 1, 1, PALETTE["icon_outline"])
            draw_pixel_rect(draw, diamond_cx - i, diamond_cy + ds - i, 1, 1, PALETTE["icon_outline"])
            draw_pixel_rect(draw, diamond_cx + i, diamond_cy + ds - i, 1, 1, PALETTE["icon_outline"])

    return img


def gen_background(size, label, seed_val):
    img = Image.new("RGBA", size, PALETTE["sky_top"])
    draw = ImageDraw.Draw(img)
    w, h = size

    horizon = int(h * 0.6)
    for y in range(horizon):
        ratio = y / max(horizon, 1)
        r = int(PALETTE["sky_top"][0] * (1 - ratio) + PALETTE["sky_bottom"][0] * ratio)
        g = int(PALETTE["sky_top"][1] * (1 - ratio) + PALETTE["sky_bottom"][1] * ratio)
        b = int(PALETTE["sky_top"][2] * (1 - ratio) + PALETTE["sky_bottom"][2] * ratio)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    draw.rectangle([0, horizon, w, h], fill=PALETTE["ground"])

    rng = seed_val
    for i in range(5):
        rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
        tx = (rng % w)
        tw = max(w // 20, 8)
        th = max(h // 6, 20)
        draw_pixel_rect(draw, tx, horizon - th, tw, th, PALETTE["trees"])

    try:
        draw.text((4, h - 12), label[:24], fill=PALETTE["text"])
    except Exception:
        pass
    return img


def gen_ui(size, label, seed_val):
    img = Image.new("RGBA", size, PALETTE["ui_fill"])
    draw = ImageDraw.Draw(img)
    w, h = size

    draw.rectangle([0, 0, w - 1, h - 1], outline=PALETTE["ui_border"])
    if w > 4 and h > 4:
        draw.rectangle([1, 1, w - 2, h - 2], outline=PALETTE["ui_highlight"])

    if w >= 16:
        corner = max(w // 8, 2)
        draw_pixel_rect(draw, 2, 2, corner, corner, PALETTE["ui_border"])
        draw_pixel_rect(draw, w - 2 - corner, 2, corner, corner, PALETTE["ui_border"])
        draw_pixel_rect(draw, 2, h - 2 - corner, corner, corner, PALETTE["ui_border"])
        draw_pixel_rect(draw, w - 2 - corner, h - 2 - corner, corner, corner, PALETTE["ui_border"])

    try:
        draw.text((3, h // 2 - 4), label[:16], fill=PALETTE["text"])
    except Exception:
        pass
    return img


def gen_effect(size, label, seed_val):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w // 2, h // 2

    r = max(min(w, h) // 4, 3)
    for i in range(r, 0, -1):
        alpha = int(255 * (i / r))
        color = (PALETTE["effect_glow"][0], PALETTE["effect_glow"][1], PALETTE["effect_glow"][2], alpha)
        draw.ellipse([cx - i, cy - i, cx + i, cy + i], fill=color)

    spark_s = max(r // 2, 2)
    draw_pixel_rect(draw, cx - spark_s // 2, cy - r - spark_s, spark_s, spark_s, PALETTE["effect_flash"])
    draw_pixel_rect(draw, cx + r, cy - spark_s // 2, spark_s, spark_s, PALETTE["effect_flash"])

    return img


def gen_portrait(size, label, seed_val):
    img = Image.new("RGBA", size, PALETTE["portrait_bg"])
    draw = ImageDraw.Draw(img)
    w, h = size

    draw.rectangle([0, 0, w - 1, h - 1], outline=PALETTE["outline"])

    head_s = max(w // 3, 4)
    cx, cy = w // 2, h // 3
    draw.ellipse([cx - head_s, cy - head_s, cx + head_s, cy + head_s], fill=PALETTE["char_light"])

    body_w = max(w // 2, 6)
    body_top = cy + head_s
    draw.rectangle([cx - body_w // 2, body_top, cx + body_w // 2, h - 4], fill=PALETTE["char_body"])

    try:
        draw.text((2, h - 8), label[:10], fill=PALETTE["text"])
    except Exception:
        pass
    return img


def gen_debug_mask(size, label, seed_val):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    stripe = max(w // 10, 4)
    for x in range(0, w, stripe * 2):
        draw.rectangle([x, 0, x + stripe - 1, h - 1], fill=(100, 100, 100, 80))
    try:
        draw.text((2, 2), "mask", fill=(150, 150, 150, 128))
    except Exception:
        pass
    return img


GENERATORS = {
    "character": gen_character,
    "enemy": gen_enemy,
    "boss": gen_boss,
    "boss_enemy": gen_boss,
    "icon": gen_icon,
    "background": gen_background,
    "ui": gen_ui,
    "ui_hud": gen_ui,
    "ui_inventory": gen_ui,
    "ui_controls": gen_ui,
    "ui_extracted": gen_ui,
    "effect": gen_effect,
    "portrait": gen_portrait,
    "debug_mask": gen_debug_mask,
    "misc": gen_ui,
}

TARGET_SIZES = {
    "character": (32, 32),
    "enemy": (32, 32),
    "boss": (64, 64),
    "boss_enemy": (64, 64),
    "icon": (16, 16),
    "effect": (32, 32),
    "portrait": (32, 32),
    "debug_mask": None,
    "background": (1280, 720),
    "ui": (64, 64),
    "ui_hud": (64, 64),
    "ui_inventory": (64, 64),
    "ui_controls": (64, 64),
    "ui_extracted": (64, 64),
    "misc": (32, 32),
}


def get_actual_size(png_path: Path) -> tuple:
    """Read the actual size from the existing PNG, falling back to category default."""
    try:
        with Image.open(png_path) as img:
            return img.size
    except Exception:
        return None


def process_all():
    if not ASSETS_DIR.exists():
        print(f"ERROR: {ASSETS_DIR} does not exist")
        return

    png_files = sorted(ASSETS_DIR.rglob("*.png"))
    png_files = [f for f in png_files if not f.name.endswith(".import")]

    print(f"Found {len(png_files)} PNG files to process")

    stats = {}
    backed_up = 0
    generated = 0

    for png_path in png_files:
        rel = png_path.relative_to(ASSETS_DIR)
        rel_str = str(rel)
        category = classify_asset(rel_str)
        stats[category] = stats.get(category, 0) + 1

        legacy_path = LEGACY_DIR / rel
        legacy_path.parent.mkdir(parents=True, exist_ok=True)
        if not legacy_path.exists():
            shutil.copy2(png_path, legacy_path)
            backed_up += 1

        actual_size = get_actual_size(png_path)
        target_size = TARGET_SIZES.get(category)

        if target_size is None:
            size = actual_size if actual_size else (64, 64)
        else:
            size = target_size

        label = label_from_path(rel_str)
        sv = seed_from_path(rel_str)
        generator = GENERATORS.get(category, gen_ui)

        placeholder = generator(size, label, sv)
        placeholder.save(png_path, "PNG")
        generated += 1

    print(f"\nBackup: {backed_up} files -> _legacy/assets/generated/")
    print(f"Generated: {generated} pixel placeholders")
    print(f"\nCategory breakdown:")
    for cat, count in sorted(stats.items()):
        print(f"  {cat}: {count}")


if __name__ == "__main__":
    process_all()
