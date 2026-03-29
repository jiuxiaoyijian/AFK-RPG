# AFK-RPG 正式替换级样张评审 v1

## 样张清单

- `hero_formal_stand_v1`: `assets/generated/formal_replacement_samples/characters/hero_formal_stand_v1.png`
- `hero_formal_action_v1`: `assets/generated/formal_replacement_samples/characters/hero_formal_action_v1.png`
- `enemy_bandit_formal_v1`: `assets/generated/formal_replacement_samples/characters/enemy_bandit_formal_v1.png`
- `boss_silver_hook_formal_v1`: `assets/generated/formal_replacement_samples/characters/boss_silver_hook_formal_v1.png`
- `chapter1_travel_road_formal_far_v1`: `assets/generated/formal_replacement_samples/backgrounds/chapter1_travel_road_formal__far.png`
- `chapter1_travel_road_formal_mid_v1`: `assets/generated/formal_replacement_samples/backgrounds/chapter1_travel_road_formal__mid.png`
- `chapter1_travel_road_formal_near_v1`: `assets/generated/formal_replacement_samples/backgrounds/chapter1_travel_road_formal__near.png`
- `main_hud_formal_v1`: `assets/generated/formal_replacement_samples/ui/main_hud_formal_v1.png`
- `inventory_formal_v1`: `assets/generated/formal_replacement_samples/ui/inventory_formal_v1.png`
- `cube_formal_v1`: `assets/generated/formal_replacement_samples/ui/cube_formal_v1.png`

## 本轮目标

- 角色不再做纯风格探索，而是收口到可替换的主角 / 普通敌人 / Boss 体系
- 第一章背景按正式量产逻辑直接给出 `far / mid / near` 三层协同样张
- 主 HUD、背包、百炼坊各给一张更接近可直接实装的界面样张

## 评审标准

- 主角与敌我角色是否共享同一世界观和比例语言
- Boss 是否比普通敌人更有压迫感，但仍保持 Q 版体系统一
- 第一章三层背景是否像同一地点，而不是三张随机图
- HUD 是否真正为战斗让出舞台
- 背包与百炼坊是否更像真实运行界面，而不是展示海报

## 实际评审结论

### 1. 主角

`hero_formal_stand_v1` 方向成立，但还没有完全进入“最终可替换”状态。

优点：

- 比第一轮和第二轮更接近“可直接入项目”的正式主角
- 比例已经稳定在 `2.3` 头身附近
- 配色、披肩、刀、腰封、发髻这些武侠识别物明确
- 表情较松弛，符合“轻旅行感江湖”

问题：

- 仍有一点偏“精致日系插画”而不是“Steam 独立武侠”
- 武器和服装细节偏细，缩小到实际战斗尺寸时可能会损失辨识度

结论：

- 可作为主角正式方向的第一版基准
- 后续再做一次“缩略图可读性”强化即可

### 2. 主角动作方向

`hero_formal_action_v1` 可作为动作设计基准，但更适合作为“动作语义样张”，而不是直接作为最终立绘替代。

优点：

- 已经明确了“向右推进式横版战斗”的动作语言
- 和当前项目“主角在左三分之一、持续向右推进”的演出逻辑匹配

问题：

- 动作略保守，速度感还不够强
- 后续若用于动作帧参考，需要再强调步幅和斗篷尾迹

结论：

- 可采用为动作方向参考
- 不建议直接当最终正式宣传立绘

### 3. 普通敌人与 Boss

`enemy_bandit_formal_v1` 与 `boss_silver_hook_formal_v1` 基本达到了“同体系样张”的要求。

优点：

- 普通敌人与 Boss 共用同一比例语言
- Boss 明显更年长、更压迫，但没有跳出 Q 版体系
- 敌人红棕、Boss 深蓝金，与主角青灰形成了良好阵营区分

问题：

- 普通敌人有一点偏“可爱小盗贼”，需要再增加一点江湖威胁感
- Boss 造型很好，但钩刃特征还可以再强化一点

结论：

- 这组已经足够作为后续敌人/Boss 量产基准

### 4. 第一章正式横版三层背景

这组是本轮最成功的部分之一。

`chapter1_travel_road_formal__far`

- 远景氛围成立
- 天光、山体、水面、远楼阁都很适合“旅行式江湖”
- 明度和透气感非常适合挂机长期观看

`chapter1_travel_road_formal__mid`

- 中景主场景可读性非常强
- 横版战斗走廊清晰
- 已经很接近“第一章正式背景可替换样张”

`chapter1_travel_road_formal__near`

- 近景方向对，但当前独立看更像“黄昏摊位前景卡”
- 和 `far / mid` 的同地点一致性稍弱

结论：

- `far` 和 `mid` 可直接作为第一章正式背景方向的强参考
- `near` 需要再生成一版，更强调与中景同地点的前景遮挡物

### 5. 主 HUD

`main_hud_formal_v1` 结构是对的，但视觉气质还没完全贴合当前项目。

优点：

- 信息架构与当前 HUD 重构目标一致
- 双资源球、任务卡、左上角色信息、右上关卡进度的结构都可以直接吸收
- 战斗舞台让位意识明显

问题：

- 头像和人物比例偏写实，与 Q 版角色体系不统一
- 资源球和边框还是偏传统幻想 ARPG，不够轻盈
- 装饰仍偏多，和“旅行感新国风”相比稍重

结论：

- 结构采用
- 视觉减重
- 头像改成 Q 版角色语言后，可以进入正式 HUD 细化阶段

### 6. 背包

`inventory_formal_v1` 已经明显比之前的概念图更接近真正可用的运行界面。

优点：

- 纸娃娃、格子库存、右侧信息区三段结构明确
- 整体更接近当前项目的 RPG 化交互方向
- 配色和器物感比早期方案更统一

问题：

- 纸娃娃区人物仍然偏写意灰影，不够像正式角色位
- 格子区视觉偏工整展示，缺一点“运行中的可操作感”

结论：

- 可作为背包正式界面的强参考
- 已经进入“可继续往项目 UI 靠”的阶段

### 7. 百炼坊

`cube_formal_v1` 当前更像高保真锻造概念图，而不是最终交互界面。

优点：

- 中央锻造核心舞台很好
- 整体气质非常符合“潮流新国风武侠 + 轻器物感”

问题：

- 左侧候选列表还不像真实可滚动候选物列表
- 右侧材料区和结果区也更像陈列板
- 交互功能区不够明确

结论：

- 保留中央锻造舞台气质
- 不直接采用整体结构
- 百炼坊还需要做一轮更强交互导向的 UI 样张

## 最终结论

本轮正式替换级样张里，当前优先级建议如下：

1. 第一章 `far / mid` 背景方向：可优先采用
2. 主角站姿、普通敌人、Boss 体系：可优先采用为量产基准
3. 背包界面：可作为正式界面参考继续细化
4. HUD：采用结构，不直接采用整图视觉
5. 百炼坊：采用气质，不直接采用整图结构

## 下一步建议

1. 继续做一版：
   - `chapter1_travel_road_formal__near_v2`
2. 继续做一版：
   - 更 Q 版化的 `main_hud_formal_v2`
3. 继续做一版：
   - 更交互导向的 `cube_formal_v2`
4. 若要开始进入正式替换，优先替换：
   - 第一章背景
   - 主角 / 普通敌人 / Boss 角色基准
