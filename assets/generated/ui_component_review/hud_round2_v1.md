# HUD Round2 V1 UI Component Review

基于 round2_main_hud_v1 切出的 HUD 控件候选。首轮只产出评审切图，不接入 HUD 场景。

| ID | 名称 | 映射 | 状态 | 模式 | 源框 | 9-slice | 输出 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HUD01 | player_header_frame | HUD > PlayerHeader | review_only | crop | 0, 0, 352, 118 | 20, 20, 20, 20 | assets/generated/afk_rpg_formal/ui/hud/player_header_frame.png | 头像环与摘要条的抠除仍不够稳定，先保留为评审参考，不纳入首轮正式替换。 |
| HUD02 | stage_header_frame | HUD > StageHeader | review_only | crop | 988, 0, 292, 44 | 18, 16, 18, 16 | assets/generated/afk_rpg_formal/ui/hud/stage_header_frame.png | 关卡条仍混入左侧示意圆点与背景细节，先保留为评审参考。 |
| HUD03 | loot_card_frame | HUD > LootCard | review_only | crop | 42, 145, 224, 320 | 18, 18, 18, 18 | assets/generated/afk_rpg_formal/ui/hud/loot_card_frame.png | 左侧掉落卡仍混入部分示意底图，先保留为评审参考，不纳入首轮正式替换。 |
| HUD04 | objective_card_frame | HUD > ObjectiveCard | candidate | crop | 949, 145, 272, 322 | 18, 18, 18, 18 | assets/generated/afk_rpg_formal/ui/hud/objective_card_frame.png | 保留右侧任务卡边框，尽量只留下外框与纸面底，清掉勾选和列表示意。 |
| HUD05 | combat_plate_frame | HUD > BattleSafeFrame / CombatPlateTexture | candidate | crop | 270, 588, 742, 132 | 30, 22, 30, 18 | assets/generated/afk_rpg_formal/ui/hud/combat_plate_frame.png | 保留底部战斗底板，后续视确认决定是否继续把中心槽位做更细清理。 |
| HUD06 | left_orb_shell | HUD > BattleSafeFrame / LeftOrbTexture | candidate | crop | 323, 550, 242, 170 | -- | assets/generated/afk_rpg_formal/ui/hud/left_orb_shell.png | 保留完整左资源球外观，首轮作为现有 orb 贴图替代候选。 |
| HUD07 | right_orb_shell | HUD > BattleSafeFrame / RightOrbTexture | candidate | crop | 716, 550, 242, 170 | -- | assets/generated/afk_rpg_formal/ui/hud/right_orb_shell.png | 保留完整右资源球外观，首轮作为现有 orb 贴图替代候选。 |
| HUD08 | skill_slot_frame | HUD > BattleSafeFrame / SkillStrip / SkillSlot* / Frame | review_only | crop | 555, 636, 60, 60 | -- | assets/generated/afk_rpg_formal/ui/hud/skill_slot_frame.png | 技能槽边缘已收紧，但仍带入背景碎片，先保留为评审参考。 |
| HUD09 | buff_strip_frame | HUD > BattleSafeFrame / BuffStrip | keep_existing | skip | -- | -- |  | 源图未提供稳定独立的 buff strip，首轮保留代码面板。 |
