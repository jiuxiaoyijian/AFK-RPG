# Inventory Formal V1 UI Component Review

基于 inventory_formal_v1 切出的背包控件候选。首轮聚焦框体、槽位与格子资源，不接入 InventoryPanel。

| ID | 名称 | 映射 | 状态 | 模式 | 源框 | 9-slice | 输出 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| INV01 | inventory_main_frame_9patch | InventoryPanel > Panel | review_only | crop | 34, 44, 1188, 566 | 30, 30, 30, 30 | assets/generated/afk_rpg_formal/ui/inventory/inventory_main_frame_9patch.png | 整张主框的控件化抠除仍混入分区示意，先保留为评审参考，不作为首轮接入资源。 |
| INV02 | inventory_header_bar_9patch | InventoryPanel > Panel / HeaderBar | review_only | crop | 366, 0, 548, 74 | 24, 18, 24, 18 | assets/generated/afk_rpg_formal/ui/inventory/inventory_header_bar_9patch.png | 顶部标题条仍混入背景纹理，先保留为评审参考。 |
| INV03 | paper_doll_panel_9patch | InventoryPanel > Panel / PaperDollSection | review_only | crop | 40, 78, 292, 556 | 20, 20, 20, 20 | assets/generated/afk_rpg_formal/ui/inventory/paper_doll_panel_9patch.png | 纸娃娃区边缘仍混入装备位示意，先保留为评审参考。 |
| INV04 | inventory_grid_panel_9patch | InventoryPanel > Panel / InventorySection | review_only | crop | 398, 76, 434, 540 | 22, 22, 22, 22 | assets/generated/afk_rpg_formal/ui/inventory/inventory_grid_panel_9patch.png | 中央格包外框仍混入右侧相邻示意，先保留为评审参考。 |
| INV05 | detail_panel_9patch | InventoryPanel > Panel / DetailSection | candidate | crop | 874, 184, 332, 190 | 20, 20, 20, 20 | assets/generated/afk_rpg_formal/ui/inventory/detail_panel_9patch.png | 提取右侧详情卡边框，内部尽量挖空，只留下详情区外框。 |
| INV06 | toolbar_panel_9patch | InventoryPanel > Panel / ToolbarSection | review_only | crop | 126, 650, 1006, 58 | 20, 16, 20, 16 | assets/generated/afk_rpg_formal/ui/inventory/toolbar_panel_9patch.png | 底部快捷条仍混入器物示意，先保留为评审参考。 |
| INV07 | equipment_slot_frame | InventoryPanel > PaperDollGrid > Equipment_* | review_only | crop | 86, 92, 82, 80 | -- | assets/generated/afk_rpg_formal/ui/inventory/equipment_slot_frame.png | 装备槽小图仍残留底图，先保留为评审参考。 |
| INV08 | inventory_cell_frame | InventoryPanel > InventoryGrid > InventoryCell_* | candidate | crop | 529, 266, 64, 68 | -- | assets/generated/afk_rpg_formal/ui/inventory/inventory_cell_frame.png | 提取空白格子单元，作为动态物品按钮背景候选。 |
| INV09 | section_divider | InventoryPanel > 顶部装饰 / 可选分区横幅 | review_only | crop | 881, 78, 294, 66 | -- | assets/generated/afk_rpg_formal/ui/inventory/section_divider.png | 装饰性候选，尽量清掉横幅内部景片，只保留边框装饰，不默认纳入首轮替换。 |
