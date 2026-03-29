"""
Slice UI concept art into individual control assets for Godot project.
Input:  Two reference images (battle bar + inventory panel)
Output: Individual PNG files with transparency for each UI element.
"""

from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math

WORKSPACE = Path(__file__).resolve().parent.parent
OUT_DIR = WORKSPACE / "assets" / "generated" / "afk_rpg_formal" / "ui" / "sliced"
OUT_DIR.mkdir(parents=True, exist_ok=True)

IMG_BATTLE_BAR = Path(r"C:\Users\huang\.cursor\projects\d-GodotProject-traetestproject01\assets\c__Users_huang_AppData_Roaming_Cursor_User_workspaceStorage_62648f5697e16dbcd8109f101c0db815_images_image-e46900dd-52ce-4b0e-8e52-0575e08921d0.png")
IMG_INVENTORY = Path(r"C:\Users\huang\.cursor\projects\d-GodotProject-traetestproject01\assets\c__Users_huang_AppData_Roaming_Cursor_User_workspaceStorage_62648f5697e16dbcd8109f101c0db815_images_img_v3_02108_ce1f1621-1478-44ce-94cc-6da01eb97e7g-db655ff2-bac8-409d-b0c9-22a611a62b20.png")


def circle_crop(img: Image.Image, cx: int, cy: int, radius: int) -> Image.Image:
    """Crop a circular region with alpha mask."""
    left = cx - radius
    top = cy - radius
    right = cx + radius
    bottom = cy + radius
    cropped = img.crop((max(0, left), max(0, top), min(img.width, right), min(img.height, bottom)))
    cropped = cropped.convert("RGBA")
    size = radius * 2
    cropped = cropped.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, size - 1, size - 1], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1))
    cropped.putalpha(mask)
    return cropped


def ring_mask(size: int, outer_r: int, inner_r: int) -> Image.Image:
    """Create a ring-shaped alpha mask."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    cx = cy = size // 2
    draw.ellipse([cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r], fill=255)
    draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=0)
    return mask


def extract_battle_bar(img_path: Path) -> None:
    """Extract elements from the battle bar concept."""
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    print(f"Battle bar source: {w}x{h}")

    # ── 1. Full bar background (strip) ──
    bar_bg = img.crop((0, 0, w, h))
    bar_bg.save(OUT_DIR / "battle_bar_bg.png")
    print(f"  -> battle_bar_bg.png ({w}x{h})")

    # ── 2. Red HP orb (left) ──
    # The red orb is in the left portion, centered approximately at (92, 102)
    # with radius ~72
    orb_cx, orb_cy, orb_r = 92, 102, 72
    hp_orb = circle_crop(img, orb_cx, orb_cy, orb_r)
    hp_orb.save(OUT_DIR / "orb_hp.png")
    print(f"  -> orb_hp.png ({orb_r * 2}x{orb_r * 2})")

    # ── 3. Blue MP orb (right) ──
    orb_cx_r = w - 92
    mp_orb = circle_crop(img, orb_cx_r, orb_cy, orb_r)
    mp_orb.save(OUT_DIR / "orb_mp.png")
    print(f"  -> orb_mp.png ({orb_r * 2}x{orb_r * 2})")

    # ── 4. Orb frame (golden ring) ──
    # Extract the ring border around the left orb, slightly larger
    frame_r = 82
    orb_frame_region = img.crop((
        max(0, 92 - frame_r), max(0, 102 - frame_r),
        min(w, 92 + frame_r), min(h, 102 + frame_r)
    )).convert("RGBA")
    frame_size = frame_r * 2
    orb_frame_region = orb_frame_region.resize((frame_size, frame_size), Image.LANCZOS)
    orb_frame_region.save(OUT_DIR / "orb_frame.png")
    print(f"  -> orb_frame.png ({frame_size}x{frame_size})")

    # ── 5. Skill slots (center area between orbs) ──
    # The skill icons are between ~x=265 and ~x=475, each roughly 56x56
    # There appear to be ~4 skill slots plus some smaller icons
    slot_y_top = 72
    slot_height = 68
    slot_width = 56
    slot_gap = 8
    first_slot_x = 268

    for i in range(4):
        sx = first_slot_x + i * (slot_width + slot_gap)
        slot = img.crop((sx, slot_y_top, sx + slot_width, slot_y_top + slot_height)).convert("RGBA")
        slot.save(OUT_DIR / f"skill_slot_{i}.png")
        print(f"  -> skill_slot_{i}.png ({slot_width}x{slot_height})")

    # ── 6. A single clean skill slot frame (use slot 0 area, slightly expanded) ──
    frame_padding = 4
    frame_slot = img.crop((
        first_slot_x - frame_padding,
        slot_y_top - frame_padding,
        first_slot_x + slot_width + frame_padding,
        slot_y_top + slot_height + frame_padding
    )).convert("RGBA")
    frame_slot.save(OUT_DIR / "skill_slot_frame.png")
    print(f"  -> skill_slot_frame.png")

    # ── 7. Center bar strip (the wooden bar background without orbs) ──
    center_strip = img.crop((170, 55, w - 170, h - 8)).convert("RGBA")
    center_strip.save(OUT_DIR / "bar_center_strip.png")
    print(f"  -> bar_center_strip.png ({center_strip.width}x{center_strip.height})")


def extract_inventory(img_path: Path) -> None:
    """Extract elements from the inventory panel concept."""
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    print(f"\nInventory source: {w}x{h}")

    # ── 1. Full panel background ──
    img.save(OUT_DIR / "inventory_panel_bg.png")
    print(f"  -> inventory_panel_bg.png ({w}x{h})")

    # ── 2. Panel frame - top border ──
    top_border = img.crop((0, 0, w, 32)).convert("RGBA")
    top_border.save(OUT_DIR / "panel_frame_top.png")
    print(f"  -> panel_frame_top.png")

    # ── 3. Panel frame - bottom border ──
    bottom_border = img.crop((0, h - 38, w, h)).convert("RGBA")
    bottom_border.save(OUT_DIR / "panel_frame_bottom.png")
    print(f"  -> panel_frame_bottom.png")

    # ── 4. Panel frame - left border ──
    left_border = img.crop((0, 0, 28, h)).convert("RGBA")
    left_border.save(OUT_DIR / "panel_frame_left.png")
    print(f"  -> panel_frame_left.png")

    # ── 5. Panel frame - right border ──
    right_border = img.crop((w - 28, 0, w, h)).convert("RGBA")
    right_border.save(OUT_DIR / "panel_frame_right.png")
    print(f"  -> panel_frame_right.png")

    # ── 6. Panel frame corners ──
    corner_size = 64
    img.crop((0, 0, corner_size, corner_size)).convert("RGBA").save(OUT_DIR / "panel_corner_tl.png")
    img.crop((w - corner_size, 0, w, corner_size)).convert("RGBA").save(OUT_DIR / "panel_corner_tr.png")
    img.crop((0, h - corner_size, corner_size, h)).convert("RGBA").save(OUT_DIR / "panel_corner_bl.png")
    img.crop((w - corner_size, h - corner_size, w, h)).convert("RGBA").save(OUT_DIR / "panel_corner_br.png")
    print(f"  -> panel_corner_tl/tr/bl/br.png")

    # ── 7. Equipment slots (left side around paper doll) ──
    # From the image: 6 equipment slots positioned around the character
    # Left column (3 slots): head armor, body armor, boots
    # Right column (2 slots): weapon top, ring bottom
    # Plus necklace at top

    # Equipment slot positions (approximate) - each slot roughly 62x62
    equip_slots = {
        "equip_slot_head": (53, 72, 125, 144),
        "equip_slot_body": (53, 185, 125, 257),
        "equip_slot_necklace": (53, 296, 125, 368),
        "equip_slot_boots": (53, 402, 125, 474),
        "equip_slot_weapon": (314, 72, 386, 144),
        "equip_slot_ring": (314, 402, 386, 474),
    }
    for name, (x1, y1, x2, y2) in equip_slots.items():
        slot = img.crop((x1, y1, x2, y2)).convert("RGBA")
        slot.save(OUT_DIR / f"{name}.png")
        print(f"  -> {name}.png ({x2 - x1}x{y2 - y1})")

    # ── 8. Single equipment slot frame (clean, for reuse) ──
    # Take the weapon slot as the reference (usually cleanest)
    equip_frame = img.crop((53, 72, 125, 144)).convert("RGBA")
    equip_frame_scaled = equip_frame.resize((80, 80), Image.LANCZOS)
    equip_frame_scaled.save(OUT_DIR / "equip_slot_frame.png")
    print(f"  -> equip_slot_frame.png (80x80)")

    # ── 9. Inventory grid area ──
    # The grid is on the right side, approximately x=395 to x=950, y=68 to y=490
    grid_area = img.crop((395, 68, 950, 490)).convert("RGBA")
    grid_area.save(OUT_DIR / "inventory_grid_area.png")
    print(f"  -> inventory_grid_area.png ({grid_area.width}x{grid_area.height})")

    # ── 10. Single inventory cell (from the grid) ──
    # Grid cells are roughly 85x85 each, arranged in 5 cols x 4 rows
    # Take an empty-ish cell from bottom-right
    cell_w, cell_h = 85, 85
    grid_start_x, grid_start_y = 395, 68
    col_count, row_count = 5, 4
    for row in range(row_count):
        for col in range(col_count):
            cx = grid_start_x + col * cell_w + col * 10
            cy = grid_start_y + row * cell_h + row * 10
            cell = img.crop((cx, cy, cx + cell_w, cy + cell_h)).convert("RGBA")
            if row == row_count - 1 and col == col_count - 1:
                cell.save(OUT_DIR / "inventory_cell_empty.png")
                print(f"  -> inventory_cell_empty.png ({cell_w}x{cell_h})")

    # ── 11. Paper doll background area ──
    paper_doll = img.crop((28, 30, 390, 530)).convert("RGBA")
    paper_doll.save(OUT_DIR / "paper_doll_area.png")
    print(f"  -> paper_doll_area.png ({paper_doll.width}x{paper_doll.height})")

    # ── 12. Bottom scroll/ribbon decoration ──
    ribbon = img.crop((28, h - 64, w - 28, h - 10)).convert("RGBA")
    ribbon.save(OUT_DIR / "bottom_ribbon.png")
    print(f"  -> bottom_ribbon.png ({ribbon.width}x{ribbon.height})")

    # ── 13. 9-patch panel frame ──
    # Create a 9-patch-style frame by compositing the borders
    margin = 48
    nine_patch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Top strip
    nine_patch.paste(img.crop((0, 0, w, margin)), (0, 0))
    # Bottom strip
    nine_patch.paste(img.crop((0, h - margin, w, h)), (0, h - margin))
    # Left strip
    nine_patch.paste(img.crop((0, margin, margin, h - margin)), (0, margin))
    # Right strip
    nine_patch.paste(img.crop((w - margin, margin, w, h - margin)), (w - margin, margin))
    nine_patch.save(OUT_DIR / "panel_9patch_frame.png")
    print(f"  -> panel_9patch_frame.png ({w}x{h})")


def main():
    print("=" * 60)
    print("UI Asset Slicer")
    print("=" * 60)

    if not IMG_BATTLE_BAR.exists():
        print(f"ERROR: Battle bar image not found: {IMG_BATTLE_BAR}")
        return
    if not IMG_INVENTORY.exists():
        print(f"ERROR: Inventory image not found: {IMG_INVENTORY}")
        return

    extract_battle_bar(IMG_BATTLE_BAR)
    extract_inventory(IMG_INVENTORY)

    print(f"\nAll assets saved to: {OUT_DIR}")
    print("Done!")


if __name__ == "__main__":
    main()
