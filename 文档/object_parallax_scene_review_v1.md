# 物件式多景深背景方案评审 v1

## 场景

- `chapter1_town_road_objects_v1`
- 第一章山镇道路，基于本地已有物件图重新组织景深关系，并把挂角装饰从世界视差层抽离到固定镜头角 overlay。

## 资源分类

- `sky_wash` -> `assets/generated/afk_rpg_formal/backgrounds/object_parts/chapter1_town_road_objects_v1/sky_wash.png` | type=`panoramic_strip` | layer=`sky` | anchor=`top_left` | scale=`2.0-2.0` | repeat=`False` | flip=`False` | lock_corner=`False`
- `far_mountain_ridge` -> `assets/generated/afk_rpg_formal/backgrounds/object_parts/chapter1_town_road_objects_v1/far_mountain_ridge.png` | type=`panoramic_strip` | layer=`far` | anchor=`horizon` | scale=`1.02-1.18` | repeat=`True` | flip=`False` | lock_corner=`False`
- `gate_bridge_cluster` -> `assets/generated/afk_rpg_formal/backgrounds/object_parts/chapter1_town_road_objects_v1/gate_bridge_cluster.png` | type=`cluster_prop` | layer=`mid` | anchor=`bottom_center` | scale=`0.62-0.82` | repeat=`False` | flip=`False` | lock_corner=`False`
- `teahouse_market_row` -> `assets/generated/afk_rpg_formal/backgrounds/object_parts/chapter1_town_road_objects_v1/teahouse_market_row.png` | type=`panoramic_strip` | layer=`mid` | anchor=`bottom_left` | scale=`0.82-1.0` | repeat=`True` | flip=`False` | lock_corner=`False`
- `stall_awning_fence` -> `assets/generated/afk_rpg_formal/backgrounds/object_parts/chapter1_town_road_objects_v1/stall_awning_fence.png` | type=`cluster_prop` | layer=`near_back` | anchor=`bottom_left` | scale=`0.72-0.9` | repeat=`False` | flip=`True` | lock_corner=`False`
- `lantern_branch_foreground` -> `assets/generated/afk_rpg_formal/backgrounds/object_parts/chapter1_town_road_objects_v1/lantern_branch_foreground.png` | type=`corner_overlay` | layer=`corner_overlay` | anchor=`top_left` | scale=`0.62-0.85` | repeat=`False` | flip=`True` | lock_corner=`True`

## 合成层

- `sky` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__sky.png`
- `far` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__far.png`
- `mid` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__mid.png`
- `near_back` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__near_back.png`
- `near_front` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__near_front.png`

## 地面条带

- `ground_band` -> `res://assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__ground_band.png` | position=`[0, 500]`

## 固定挂角 Overlay

- `top_left_lantern` -> `res://assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__corner_top_left.png` | corner=`top_left` | offset=`[-34, -16]` | scale=`0.62` | alpha=`240` | flip_x=`False`
- `top_right_branch` -> `res://assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__corner_top_right.png` | corner=`top_right` | offset=`[0, 8]` | scale=`0.84` | alpha=`216` | flip_x=`True`

## 预览输出

- `stack_preview` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__stack_preview.png`
- `overlay_preview` -> `assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_objects_v1__overlay_preview.png`

## 调试目标

- `far_mountain_ridge` 从天空层抽离，只承担远景山脊。
- `teahouse_market_row` 作为主中景条带，只保留一次主条带和一次弱重复。
- `gate_bridge_cluster` 改为单地标，不再和房屋条带等权重复。
- `stall_awning_fence` 按局部裁切后只放左右两端。
- `lantern_branch_foreground` 不再进入世界层，而是固定镜头角。
