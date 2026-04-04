# AFK-RPG

[![Godot](https://img.shields.io/badge/Godot-4.6.1-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Status](https://img.shields.io/badge/Status-Prototype-orange)](https://github.com/jiuxiaoyijian/AFK-RPG)
[![Play Online](https://img.shields.io/badge/Play-Web%20Demo-6f42c1)](https://jiuxiaoyijian.github.io/AFK-RPG/)
[![Version](https://img.shields.io/badge/Public%20Demo-0.1.0-2ea043)](https://jiuxiaoyijian.github.io/AFK-RPG/)

一个基于 `Godot 4.6` 制作的横版挂机 ARPG 原型。  
项目当前正沿着 `反桃花源修真` 的方向推进，核心是把“自动战斗 + 探境刷装 + 道统成长 + 闭关所得”的循环，逐步收敛成一个可在线试玩、可持续迭代的独立项目。

## 立即试玩

- 在线版本：[https://jiuxiaoyijian.github.io/AFK-RPG/](https://jiuxiaoyijian.github.io/AFK-RPG/)
- 仓库地址：[https://github.com/jiuxiaoyijian/AFK-RPG](https://github.com/jiuxiaoyijian/AFK-RPG)
- 试玩说明：[PUBLIC_DEMO.md](PUBLIC_DEMO.md)
- 反馈入口：[GitHub Issues](https://github.com/jiuxiaoyijian/AFK-RPG/issues)

> 当前阶段是“高可玩原型”，重点验证系统循环与体验方向，还不是最终美术完成版。

## 这是什么游戏

`AFK-RPG` 是一个以“挂机探境”为核心的横版 ARPG 原型，强调：

- 自动战斗也要有清晰反馈，而不是纯数值滚动
- 掉落不只是产出，还要有足够明确的视觉回报
- 中期驱动力来自装备、真意、异宝机缘与悟道成长的叠加
- UI 不只是信息堆叠，而要服务于“看懂战斗、看懂道统、看懂机缘”

如果用一句话概括当前版本：

> 这是一个正在被持续打磨的“可试玩反桃花源挂机刷宝战斗舞台”。

## 当前核心体验

### 1. 自动战斗主循环

- 主角自动索敌、追击、输出、结算并继续推进
- 敌人按节点与探境配置刷新，支持普通 / 精英 / 首领节奏
- 已对站位、刷怪方向、战斗中心和舞台安全区做了多轮体验收敛

### 2. 掉落与拾取反馈

- 装备、货币、材料等掉落已具备分层表现
- 掉落物会先做抛物线落地演出
- 靠近触发主动拾取，超时后触发被动拾取
- 收束粒子会飞向对应 UI 入口，强化“奖励归属感”

### 3. 道统与成长

- 核心道术切换
- 装备底材、真意、异宝真意
- 异闻录发现与机缘追踪
- 悟道与资源投入成长
- 闭关所得结算

### 4. 信息与调试能力

- 异闻录面板、机缘推演、背包、悟道面板
- 节点掉落样本与效率对比
- 三个本地存档位
- GM 调试面板，支持快速资源 / 物品 / 解锁测试

## 当前已实现

- 自动战斗循环
- 核心道术与道统切换
- 掉落生成、装备生成、异宝追踪
- 异闻录、悟道、闭关所得
- 机缘推演与推荐刷图节点
- 掉落物抛物线、主动 / 被动拾取、飞向 UI 收束演出
- 三存档位与 GM 调试面板
- 二级页面不透明底板、滚动详情区、战斗安全框
- Web 导出预设与 GitHub Pages 自动部署

## 当前键位

| 按键 | 功能 |
| --- | --- |
| `1 / 2 / 3` | 切换核心道统 |
| `R` | 重开当前流程 |
| `T` | 切换机缘追踪 |
| `I` | 打开背包 |
| `U` | 打开悟道 |
| `O` | 打开异闻录 |
| `P` | 打开机缘推演 |
| `G` | 打开 GM 面板 |
| `F5` | 快速存档（档位 1） |
| `F8` | 快速读档（档位 1） |
| `Esc` | 关闭当前弹窗 |

## 当前版本还缺什么

当前版本已经有完整的“系统骨架”，但离真正成品还有明显距离，主要缺口包括：

- 更完整的题材包装与世界观表达
- 更统一的角色 / 敌人 / 首领 / UI 美术资源
- 更强的战斗特效与 UI 动效
- 更进一步的二级页面信息密度整理
- 更完整的浏览器端与移动端体验适配

## 公开试玩版补充说明

- 当前公开版本已经补入启动菜单、存档位选择、试玩版设置与反馈入口。
- 公开构建默认关闭 GM 调试入口，避免把测试能力暴露给普通玩家。
- 试玩版优先面向桌面 Chrome 浏览器，移动端仍仅建议观摩，不建议作为主要体验环境。

## 路线图

### 近期重点

- 继续优化二级页面可读性与视觉层级
- 完善 Web 版表现与浏览器适配
- 补更多可用于公开展示的截图、演示图与说明

### 中期重点

- 继续扩展探境、敌人、掉落池与异宝道统
- 强化战斗演出、结果反馈与阶段目标设计
- 推进题材包装、美术替换与产品化 UI

## 本地运行

### 用 Godot 编辑器打开

1. 使用 `Godot 4.6.x`
2. 打开项目目录
3. 运行主场景 `res://scenes/main/game_root.tscn`

### 命令行导出 Web

仓库已经包含 `export_presets.cfg`，可直接使用 `Web` preset 导出：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --headless `
  --path "D:\GodotProject\桌面挂机" `
  --export-release "Web" "build/web/index.html"
```

默认输出目录：

- `build/web/index.html`

## 仓库结构

```text
assets/                  运行时使用的生成资源与占位资源
data/                    技能、敌人、掉落、探境、悟道等数据表
scenes/                  Godot 场景
scripts/                 自动加载、系统、实体、UI 控制逻辑
ComfyUI+LoRA/            美术资源生成与 LoRA 工作流维护资料
文档/                    核心系统、美术规范、配置与世界观文档
```

## 文档导航

如果想快速了解项目当前状态，建议优先阅读：

- `文档/14_暗黑3式系统框架设计.md`
- `文档/15_RPG化系统与交互重构方案.md`
- `文档/16_潮流新国风Q版美术规范.md`

如果想了解玩法与配置细节，可继续阅读：

- `文档/02_核心战斗与系统循环设计.md`
- `文档/03_装备·数值·Build系统设计.md`
- `文档/06_配置表字段说明.md`

## 部署说明

仓库已经接入 GitHub Actions 的自动导出与部署流程：

- 工作流：`.github/workflows/deploy-pages.yml`
- 线上地址：[https://jiuxiaoyijian.github.io/AFK-RPG/](https://jiuxiaoyijian.github.io/AFK-RPG/)

每次推送到 `main`，都会自动触发 Web 导出与 Pages 部署。

## License

当前仓库已补充根目录 [LICENSE](LICENSE)。  
现阶段授权方式为公开试玩展示用途下的 `All Rights Reserved`，不开放复用、分发或二次创作。
