# AFK-RPG 核心战斗与背包 UI 单图集评审 v1

## 产物

- 图集：`assets/generated/afk_rpg_formal/ui/ui_core_combat_inventory_sheet_v1.png`
- 清单：`assets/generated/afk_rpg_formal/ui/ui_core_combat_inventory_sheet_v1.json`

## 本轮范围

- 只覆盖 HUD 与背包相关基础静态件
- 不包含成长中心、异闻录、推演、设置、GM 与完整交互态
- 统一为一张 1536x1024 透明图集，便于后续切图与接线

## 组件列表

- `player_header_frame` -> `HUD` | rect=`[16, 16, 352, 118]` | slice=`[22, 22, 22, 22]`
- `portrait_ring_frame` -> `HUD` | rect=`[392, 16, 104, 104]` | slice=`None`
- `stage_header_frame` -> `HUD` | rect=`[520, 16, 320, 64]` | slice=`[20, 18, 20, 18]`
- `drop_toast_frame` -> `HUD` | rect=`[864, 16, 248, 84]` | slice=`[18, 18, 18, 18]`
- `thin_divider` -> `HUD` | rect=`[1136, 20, 220, 24]` | slice=`None`
- `objective_card_frame` -> `HUD` | rect=`[16, 156, 252, 296]` | slice=`[18, 18, 18, 18]`
- `loot_card_frame` -> `HUD` | rect=`[292, 156, 216, 296]` | slice=`[18, 18, 18, 18]`
- `combat_plate_frame` -> `HUD` | rect=`[532, 156, 600, 148]` | slice=`[28, 24, 28, 20]`
- `left_orb_shell` -> `HUD` | rect=`[1156, 156, 156, 156]` | slice=`None`
- `right_orb_shell` -> `HUD` | rect=`[1336, 156, 156, 156]` | slice=`None`
- `skill_slot_frame` -> `HUD` | rect=`[1186, 336, 96, 96]` | slice=`None`
- `inventory_main_frame_9patch` -> `InventoryPanel` | rect=`[16, 476, 560, 258]` | slice=`[20, 20, 20, 20]`
- `inventory_header_bar_9patch` -> `InventoryPanel` | rect=`[600, 476, 420, 60]` | slice=`[18, 16, 18, 16]`
- `paper_doll_panel_9patch` -> `InventoryPanel` | rect=`[1044, 476, 180, 260]` | slice=`[18, 18, 18, 18]`
- `inventory_grid_panel_9patch` -> `InventoryPanel` | rect=`[1248, 476, 272, 260]` | slice=`[18, 18, 18, 18]`
- `detail_panel_9patch` -> `InventoryPanel` | rect=`[16, 758, 280, 160]` | slice=`[18, 18, 18, 18]`
- `toolbar_panel_9patch` -> `InventoryPanel` | rect=`[320, 758, 520, 72]` | slice=`[18, 16, 18, 16]`
- `inventory_cell_frame` -> `ItemCardButton` | rect=`[864, 758, 76, 76]` | slice=`None`
- `equipment_slot_frame` -> `InventoryPanel` | rect=`[964, 758, 84, 84]` | slice=`None`
- `section_divider` -> `InventoryPanel` | rect=`[1072, 758, 220, 52]` | slice=`None`
- `option_dropdown_base` -> `InventoryPanel` | rect=`[16, 860, 180, 52]` | slice=`[16, 16, 16, 16]`
- `page_arrow_left` -> `InventoryPanel` | rect=`[220, 860, 64, 64]` | slice=`None`
- `page_arrow_right` -> `InventoryPanel` | rect=`[308, 860, 64, 64]` | slice=`None`
- `button_primary_base` -> `InventoryPanel` | rect=`[396, 860, 180, 56]` | slice=`[16, 16, 16, 16]`
- `button_secondary_base` -> `InventoryPanel` | rect=`[600, 860, 180, 56]` | slice=`[16, 16, 16, 16]`
- `button_danger_base` -> `InventoryPanel` | rect=`[804, 860, 180, 56]` | slice=`[16, 16, 16, 16]`
- `rarity_frame_strip_common_to_ancient` -> `ItemCardButton` | rect=`[1008, 848, 512, 96]` | slice=`None`
