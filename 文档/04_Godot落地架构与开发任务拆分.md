# Godot 落地架构与开发任务拆分

## 1. 技术目标

目标是让其他 agent 能根据本目录文档，直接在 `Godot 4` 中搭出可玩原型。

本文件重点回答：

- 场景怎么分
- 脚本怎么分
- 数据如何加载
- 系统如何通信
- 开发顺序如何安排

## 2. 技术原则

1. 优先做 `可运行闭环`
不要先堆 UI 和特效。

2. 优先 `数据驱动`
技能、敌人、章节、词条、掉落全部走配置。

3. 优先 `系统解耦`
用 Autoload 和事件总线串联系统。

4. 优先 `可扩展`
不要把逻辑写死在某个流派里。

## 3. 推荐项目结构

```text
res://
  scenes/
    main/
      game_root.tscn
    combat/
      combat_runner.tscn
      wave_spawner.tscn
      chapter_node.tscn
    entities/
      player.tscn
      enemy.tscn
      projectile.tscn
      loot_drop.tscn
    ui/
      hud.tscn
      build_panel.tscn
      inventory_panel.tscn
      reward_popup.tscn
      offline_report_popup.tscn
  scripts/
    autoload/
      game_manager.gd
      event_bus.gd
      config_db.gd
      save_manager.gd
    systems/
      combat_system.gd
      progression_system.gd
      loot_system.gd
      offline_system.gd
      auto_rule_system.gd
      chapter_system.gd
    combat/
      damage_resolver.gd
      effect_processor.gd
      trigger_dispatcher.gd
      battle_context.gd
    entities/
      player_actor.gd
      enemy_actor.gd
      module_actor.gd
    ui/
      hud_controller.gd
      build_panel_controller.gd
      inventory_panel_controller.gd
    data/
      config_loader.gd
      stat_formula.gd
  data/
    progression/
    skills/
    equipment/
    enemies/
    chapters/
    drops/
    systems/
```

## 4. 推荐 Autoload

## 4.1 `GameManager`

职责：

- 保存全局运行状态
- 持有玩家当前构筑、章节、资源
- 提供进入关卡、结算奖励、切换章节接口

### 建议包含

- 当前玩家进度
- 当前章节与节点
- 当前 build
- 当前挂机目标
- 当前自动化规则

## 4.2 `EventBus`

职责：

- 解耦系统通信
- 广播战斗事件、掉落事件、成长事件、UI 更新事件

### 关键事件建议

- battle_started
- battle_finished
- enemy_killed
- loot_dropped
- equipment_changed
- chapter_completed
- player_progress_changed
- offline_reward_ready
- auto_rule_triggered

## 4.3 `ConfigDB`

职责：

- 统一加载所有 JSON 或 Resource 配置
- 建立按 id 检索的数据字典
- 向系统提供只读配置数据

## 4.4 `SaveManager`

职责：

- 存读档
- 记录离线时间戳
- 记录自动化规则与构筑预设

## 5. 核心系统拆分

## 5.1 `combat_system.gd`

职责：

- 驱动整场战斗节奏
- 管理战斗开始、波次推进、结束结算
- 调用伤害、触发和效果系统

不负责：

- 具体 UI
- 配置读取细节
- 存档逻辑

## 5.2 `damage_resolver.gd`

职责：

- 统一处理直接伤害、暴击、DoT、护盾、减伤、易伤等计算

要求：

- 所有伤害都必须通过该层统一计算
- 不允许在技能脚本里自己到处手算

## 5.3 `trigger_dispatcher.gd`

职责：

- 监听战斗事件
- 查找哪些装备词条、被动、模块、技能会响应
- 派发触发器

## 5.4 `effect_processor.gd`

职责：

- 执行被触发后的实际效果
- 例如加护盾、施加流血、召唤雷击、返还能量

## 5.5 `loot_system.gd`

职责：

- 根据掉落表生成装备和材料
- 处理稀有度、词条池、自动分解结果

## 5.6 `progression_system.gd`

职责：

- 管理账号经验、阶段突破、技能升级、模块升级、研究树升级

## 5.7 `offline_system.gd`

职责：

- 根据离线时长和当前稳定层计算收益
- 返回离线报告

## 5.8 `auto_rule_system.gd`

职责：

- 执行自动穿戴、自动分解、自动回退、自动刷指定章节等规则

## 5.9 `chapter_system.gd`

职责：

- 管理章节节点结构
- 判断章节解锁和 Boss 通过条件

## 6. 场景树建议

## 6.1 主场景

```text
GameRoot
├── WorldLayer
│   └── CombatRunner
│       ├── PlayerSpawn
│       ├── EnemyContainer
│       ├── ProjectileContainer
│       ├── LootContainer
│       └── GroundMarker
├── UILayer
│   ├── HUD
│   ├── BuildPanel
│   ├── InventoryPanel
│   ├── RewardPopup
│   └── OfflineReportPopup
└── Systems
    ├── CombatSystem
    ├── LootSystem
    ├── ProgressionSystem
    ├── OfflineSystem
    └── AutoRuleSystem
```

## 6.2 玩家实体

```text
Player
├── CharacterBody2D
├── AnimatedSprite2D
├── Hitbox
├── Hurtbox
├── ModuleAnchorA
├── ModuleAnchorB
└── EffectSocket
```

## 6.3 敌人实体

```text
Enemy
├── CharacterBody2D
├── AnimatedSprite2D
├── Hitbox
├── Hurtbox
└── StateRoot
```

## 7. 数据驱动要求

所有战斗内容必须优先由配置定义，不允许把具体数值硬编码在主流程里。

必须配置驱动的内容：

- 技能
- 被动
- 模块
- 装备词条
- 传奇特效
- 敌人属性
- Boss 机制参数
- 章节节点
- 掉落表
- 离线收益参数

## 8. 推荐的开发里程碑

## M1 搭骨架

任务：

- 建立目录结构
- 建立 Autoload
- 读取基础配置
- 搭主场景

验收：

- 项目可启动
- 主场景可进入
- 配置能成功加载并打印

## M2 做战斗闭环

任务：

- 角色自动前进和索敌
- 敌人生成与死亡
- 波次推进
- 关卡完成与失败

验收：

- 可完整跑完一场普通战斗

## M3 做掉落与装备

任务：

- 掉落逻辑
- 装备生成
- 背包和穿戴
- 装备属性汇总

验收：

- 更换装备后战斗表现明显变化

## M4 做构筑

任务：

- 核心技
- 战术技
- 被动
- 模块

验收：

- 至少 3 个 build 体验不同

## M5 做成长与离线

任务：

- 账号经验
- 突破
- 研究树
- 离线结算
- 自动分解

验收：

- 可挂机并形成长期成长

## 9. 推荐 agent 分工

如果多个 agent 并行开发，建议按以下方式拆：

### Agent A：战斗骨架

负责：

- CombatSystem
- Enemy/Player Actor
- 波次推进
- BattleContext

### Agent B：装备与掉落

负责：

- LootSystem
- 装备生成
- 词条系统
- 自动分解

### Agent C：成长与配置

负责：

- ConfigDB
- ProgressionSystem
- 研究树
- 突破

### Agent D：UI 与体验

负责：

- HUD
- BuildPanel
- InventoryPanel
- 离线报告弹窗

## 10. 实现约束

所有 agent 在写代码时必须遵守：

- 不允许直接在 UI 中持有复杂战斗逻辑
- 不允许让装备自己随意修改全局数据
- 不允许在多个文件重复实现伤害公式
- 不允许把离线收益写成和在线收益完全独立的一套公式

## 11. 原型验收标准

当以下条件全部满足时，可认为 Godot 原型已达成：

- 可进入游戏并开始挂机战斗
- 可推进章节并遇到 Boss
- 可掉落装备并改变 build
- 可进行至少一次成长升级
- 可退出再进入并获得离线收益
- UI 能显示最关键的挂机信息
