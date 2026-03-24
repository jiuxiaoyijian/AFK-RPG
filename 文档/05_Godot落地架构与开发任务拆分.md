# Godot落地架构与开发任务拆分

> 本文档说明当前代码架构，以及P1-P3各阶段需要新增/修改的模块。

---

## 一、已实现架构（P0）

### 1.1 Autoload（全局单例）

| 脚本 | 职责 | 状态 |
|------|------|------|
| `GameManager` | 全局状态管理、品质/流派配置、玩家数据 | ✅ 已实现 |
| `EventBus` | 全局事件总线（信号中心） | ✅ 已实现 |
| `ConfigDB` | JSON配置文件读取与缓存 | ✅ 已实现 |
| `SaveManager` | 存档读写、版本管理(v2)、多槽位 | ✅ 已实现 |
| `OfflineSystem` | 离线收益计算 | ✅ 已实现 |
| `MetaProgressionSystem` | 武学参悟（研究树）被动加成 | ✅ 已实现 |
| `LootCodexSystem` | 江湖见闻录（图鉴） | ✅ 已实现 |
| `DailyGoalSystem` | 每日修行（日常任务） | ✅ 已实现 |
| `StageEventSystem` | 江湖奇遇（随机事件） | ✅ 已实现 |

### 1.2 战斗/系统脚本

| 脚本 | 职责 | 路径 |
|------|------|------|
| `CombatSystem` | 战斗逻辑、回合计算 | `scripts/combat/combat_system.gd` |
| `DamageResolver` | 7乘区伤害公式计算 | `scripts/combat/damage_resolver.gd` |
| `LootSystem` | 掉落表查询、掉落物生成 | `scripts/systems/loot_system.gd` |
| `EquipmentGeneratorSystem` | 装备生成（词缀随机、bucket互斥） | `scripts/systems/equipment_generator_system.gd` |

### 1.3 UI脚本

| 脚本 | 职责 | 路径 |
|------|------|------|
| `HudController` | 主HUD（9槽装备、属性面板） | `scripts/ui/hud_controller.gd` |
| `InventoryPanelController` | 背包面板 | `scripts/ui/inventory_panel_controller.gd` |
| `GMPanelController` | GM调试面板 | `scripts/ui/gm_panel_controller.gd` |

### 1.4 场景结构

```
game_root.tscn
├── GameWorld (Node2D)
│   ├── Background
│   ├── PlayerCharacter
│   └── EnemySpawnArea
├── UILayer (CanvasLayer)
│   ├── HUD
│   ├── InventoryPanel
│   └── GMPanel
└── AudioManager
```

### 1.5 数据目录结构

```
data/
├── chapters/
│   └── chapter_defs.json        # 章节定义
├── drops/
│   └── drop_tables.json         # 掉落表
├── enemies/
│   └── enemy_defs.json          # 敌人定义
├── equipment/
│   ├── affixes.json             # 词缀池(38条)
│   ├── equipment_bases.json     # 装备基底
│   └── legendary_affixes.json   # 传奇词缀
├── skills/
│   └── core_skills.json         # 核心技能
└── progression/
    └── research_tree.json       # 武学参悟树
```

---

## 二、P1需新增模块

### 2.1 新增系统脚本

| 脚本 | 职责 | 路径 | 优先级 |
|------|------|------|--------|
| `SetSystem` | 传承(套装)效果管理、件数追踪、效果激活 | `scripts/systems/set_system.gd` | P1.1 |
| `CubeSystem` | 百炼坊功能（5大操作） | `scripts/systems/cube_system.gd` | P1.3 |
| `CodexSlotSystem` | 武学秘录（传奇特效激活槽） | `scripts/systems/codex_slot_system.gd` | P1.4 |

### 2.2 新增数据文件

| 文件 | 内容 | 路径 |
|------|------|------|
| `set_defs.json` | 四大传承的件数/效果定义 | `data/sets/set_defs.json` |
| `cube_recipes.json` | 百炼坊操作的消耗/产出定义 | `data/equipment/cube_recipes.json` |

### 2.3 需修改的现有模块

| 模块 | 修改内容 |
|------|---------|
| `EquipmentGeneratorSystem` | 添加传承件生成逻辑（套装标记、传承词缀） |
| `DamageResolver` | 添加乘区E（套装加成）和武学秘录效果的计算 |
| `GameManager` | 添加传承件追踪、武学秘录状态管理 |
| `SaveManager` | 存档结构新增套装穿戴状态、武学秘录数据（版本号+1） |
| `HudController` | 添加传承件数显示、套装效果提示 |
| `LootSystem` | 掉落表添加传承件掉落权重 |

### 2.4 新增UI

| UI | 功能 | 场景路径 |
|----|------|---------|
| 百炼坊面板 | 5大功能入口+操作界面 | `scenes/ui/cube_panel.tscn` |
| 武学秘录面板 | 已解锁列表+3槽激活 | `scenes/ui/codex_panel.tscn` |
| 传承信息面板 | 当前传承件数+效果预览 | `scenes/ui/set_info_panel.tscn` |

---

## 三、P2需新增模块

### 3.1 新增系统

| 脚本 | 职责 | 路径 |
|------|------|------|
| `RiftSystem` | 试剑秘境逻辑（层数/缩放/限时/钥石） | `scripts/systems/rift_system.gd` |
| `GemSystem` | 传奇宝石管理（镶嵌/升级/效果） | `scripts/systems/gem_system.gd` |

### 3.2 新增数据

| 文件 | 内容 |
|------|------|
| `data/rift/rift_scaling.json` | 秘境层数缩放表 |
| `data/rift/rift_keys.json` | 钥石定义 |
| `data/equipment/gems.json` | 传奇宝石定义 |

---

## 四、P3需新增模块

### 4.1 新增系统

| 脚本 | 职责 | 路径 |
|------|------|------|
| `ParagonSystem` | 宗师修为（巅峰等级+属性分配） | `scripts/systems/paragon_system.gd` |
| `SeasonSystem` | 重入江湖（赛季重置+永久加成） | `scripts/systems/season_system.gd` |

---

## 五、P1开发任务拆分

### 阶段P1.1: 传承数据定义（2天）

| 任务 | 产出 | 验收 |
|------|------|------|
| 创建 `data/sets/` 目录 | 目录存在 | — |
| 编写 `set_defs.json` | 4套传承×6件的完整定义 | JSON schema验证通过 |
| 在 `equipment_bases.json` 中添加传承装备基底 | 24个传承装备基底 | — |

### 阶段P1.2: SetSystem实现（3天）

| 任务 | 产出 | 验收 |
|------|------|------|
| 创建 `set_system.gd` | 系统脚本 | 单元测试通过 |
| 实现套装件数追踪 | 穿/脱传承件时自动计数 | 穿6件正确显示6件效果 |
| 实现2/4/6件效果激活 | 效果应用到 DamageResolver | 伤害计算正确包含套装乘区 |
| 修改 `DamageResolver` | 乘区E生效 | 验证公式正确 |

### 阶段P1.3: 百炼坊数据定义（1天）

| 任务 | 产出 | 验收 |
|------|------|------|
| 编写 `cube_recipes.json` | 5种操作的消耗/产出定义 | JSON schema验证通过 |

### 阶段P1.4: CubeSystem实现（4天）

| 任务 | 产出 | 验收 |
|------|------|------|
| 创建 `cube_system.gd` | 系统脚本 | 单元测试通过 |
| 实现萃取武学 | 分解真意装备→解锁传奇特效 | 萃取后特效出现在秘录中 |
| 实现精钢化真 | 玄品→真意 | 品质正确提升，词缀正确增加 |
| 实现回炉重铸 | 重随所有词缀 | 品质/套装不变，词缀全新 |
| 实现传承互转 | 传承件换槽位 | 同套内正确转换 |
| 实现淬火精炼 | 重随1条词缀 | 精炼槽锁定生效 |
| 创建 `codex_slot_system.gd` | 武学秘录系统 | 3槽激活正确 |

### 阶段P1.5: 武学秘录UI（2天）

| 任务 | 产出 | 验收 |
|------|------|------|
| 创建 `codex_panel.tscn` | UI场景 | 可打开/关闭 |
| 实现已解锁列表展示 | 列出所有已萃取的传奇特效 | 显示正确 |
| 实现3槽拖放/选择 | 选择激活的特效 | 效果正确应用 |

### 阶段P1.6: 传承UI显示（2天）

| 任务 | 产出 | 验收 |
|------|------|------|
| HUD添加传承信息 | 当前穿戴传承件数+效果 | 穿/脱时实时更新 |
| 装备tooltip添加套装标记 | 绿色套装名+件数 | 显示正确 |
| 创建 `set_info_panel.tscn` | 套装详情面板 | 显示所有传承的已穿/未穿件 |

### 阶段P1.7: 集成测试（2天）

| 任务 | 验收标准 |
|------|---------|
| Build完整性测试 | 从凡品到传承6件的完整流程可走通 |
| 伤害公式验证 | 参照 `07_配置示例与测试用例.md` 中的用例 |
| 百炼坊功能测试 | 5个功能全部可正常操作 |
| 存档兼容性测试 | 旧存档正确触发清空重置 |

---

## 六、代码规范提醒

1. 新增系统脚本使用 `class_name` 声明全局类名
2. 所有信号通过 `EventBus` 发送，不直接连接场景内信号（除UI内部信号外）
3. 数据文件修改后同步更新 `06_配置表字段说明.md`
4. 每个新系统提供 `_ready()` 中的自检 `print` 确认加载成功
5. 调试功能放入 `GMPanelController`，不散落在其他脚本中
