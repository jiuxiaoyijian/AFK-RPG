# UI 控件与视觉规范

> 本文档定义本项目所有 UI 面板的**控件库**、**视觉 token**、**布局模板**与**反馈状态**等具体规范。
> 是 [交互设计规范](交互设计规范.md) 的具体落地，所有 UI 实现（C# 控制器、`.tscn`）必须遵循。

**管线位置**：[研发流程总览](../00_项目总纲/研发流程总览.md) S3+S4+S5 阶段
**适用范围**：所有 `scripts/UI/*.cs`、`scenes/ui/*.tscn`

---

## 一、设计原则简述

参考业界游戏 UI/UX 实践，本项目采纳以下五项核心原则：

| # | 原则 | 来源 | 落地约束 |
|---|------|------|---------|
| 1 | **干净的简单界面** | 挂机游戏需要低学习曲线 | 单面板控件数 ≤ 12；信息分层不超过 3 级 |
| 2 | **F-Pattern 视觉扫描** | 眼动追踪研究 | HUD 关键信息靠左上；面板标题始终在顶部左侧 |
| 3 | **峰值边缘视觉感知** | 玩家观战时无法盯紧 HUD | HP/能量等关键状态用颜色+形状双重编码 |
| 4 | **三态反馈** | Fitt's Law + Affordance | 所有按钮 normal/hover/pressed 完整；选中态有边框 |
| 5 | **破坏性操作可撤回** | 容错优先 | 分解/出售/重置必须 ConfirmDialog 二次确认 |

---

## 二、设计 Token 体系

所有数值常量必须定义在 [UIStyle.cs](../../scripts/UI/UIStyle.cs) 中。**禁止**在面板代码内出现裸字面量（`20`、`#FF0000`、`Vector2(440, 120)` 等）。

### 2.1 颜色阶梯

#### 灰度（Bg）

| Token | RGB | 用途 |
|-------|-----|------|
| `Bg0` | 0.05 / 0.05 / 0.07 | 最深背景（模态遮罩、阴影） |
| `Bg1` = 现有 `BgDark` | 0.08 / 0.08 / 0.10 | 主背景 |
| `Bg2` = 现有 `BgPanel` | 0.12 / 0.12 / 0.15 | 面板填充 |
| `Bg3` = 现有 `BgHeader` | 0.15 / 0.14 / 0.18 | 头部条 / 子区段 |
| `Bg4` | 0.20 / 0.19 / 0.22 | 悬浮/选中态填充 |
| `Bg5` | 0.28 / 0.27 / 0.30 | 输入框/槽位边框 |

#### 文本

| Token | 用途 |
|-------|------|
| `TextPrimary` | 主标题、关键数值 |
| `TextSecondary` | 副标题、说明文字 |
| `TextMuted` | 禁用态、辅助说明 |

#### 状态色

| Token | 用途 |
|-------|------|
| `Accent` | 选中、链接、品牌强调 |
| `Success` | 成功、提升 |
| `Danger` | 危险操作、损失、HP |
| `EnergyBar` | 内力/能量 |

#### 品质色（7 阶）

`Common` / `Magic` / `Rare` / `Legendary` / `Set` / `Ancient` / `Primal`

**hover 增亮规则**：`color.Lightened(0.15f)`；**pressed 减暗规则**：`color.Darkened(0.15f)`。

### 2.2 字阶

| Token | 字号 | 用途 |
|-------|------|------|
| `FontTitle` | 22 | 面板标题（PanelChrome 头部） |
| `FontHeader` | 18 | 子区段标题（SectionHeader） |
| `FontBody` | 14 | 正文、按钮 |
| `FontSmall` | 11 | 辅助说明、次级数值 |
| `FontTiny` | 9 | 角标、徽章 |

### 2.3 间距阶梯（4px 网格）

| Token | 像素 | 用途 |
|-------|------|------|
| `Spacing4` | 4 | 控件内细节间距 |
| `Spacing8` | 8 | 默认控件间距 |
| `Spacing12` | 12 | 中等组间距 |
| `Spacing16` | 16 | 区段间距、内容内边距 |
| `Spacing24` | 24 | 大块视觉分组 |
| `Spacing32` | 32 | 面板顶/底安全区 |

弃用旧的 `PadOuter` / `PadInner` / `PadTight`（保留兼容，但新代码不再使用）。

### 2.4 关键尺寸

| Token | 像素 | 用途 |
|-------|------|------|
| `HeaderHeight` | 40 | PanelChrome 头部固定高度 |
| `FooterHeight` | 52 | PanelChrome 底部固定高度 |
| `NavBarHeight` | 52 | 底部导航栏 |
| `ButtonHeight` | 32 | 标准按钮高度 |
| `ItemCellSize` | 64 | 物品格子尺寸 |

---

## 三、控件库清单

所有控件在 [scripts/UI/Components/](../../scripts/UI/Components/) 下，作为 `partial class` 暴露给所有面板复用。

### 3.1 PanelChrome（面板外壳）

**用途**：所有 L2 系统面板和 L3 子面板的统一外壳。
**结构**：

```
PanelChrome (Control, FullRect)
├── Backdrop (Panel, FullRect, Bg2 + Border)
├── Header (HBoxContainer, Top, HeaderHeight, Bg3)
│   ├── TitleLabel (Label, FontTitle, Accent)
│   ├── SubtitleLabel (Label, FontSmall, TextSecondary)
│   ├── (spacer)
│   └── CloseButton (IconButton, "×")
├── Body (Container, expand fill)
│   └── (面板自定义内容挂载点)
└── Footer (HBoxContainer, Bottom, FooterHeight, 可选)
    └── (面板自定义按钮)
```

**API**：

```csharp
public partial class PanelChrome : Control
{
    public string PanelId { get; set; }       // 用于 OverlayManager 自动关闭
    public string Title { get; set; }
    public string Subtitle { get; set; }
    public Container Body { get; private set; } // 子类挂载内容
    public Container Footer { get; private set; }// 子类挂载操作按钮
    public bool ShowFooter { get; set; }
}
```

**必行为**：
- 关闭按钮 `Pressed` → 通过 `EventBus.UiPanelClosed` 通知 OverlayManager
- 面板自身使用 `LayoutPreset.Center` + 通过 `CustomMinimumSize` 控制大小
- Body 使用 `MarginContainer`（内边距 = `Spacing16`）

### 3.2 SectionHeader（子区段标题）

**用途**：面板 Body 内分组标题。

```csharp
new SectionHeader("装备列表", "共 23 件");
```

结构：左侧标题文字（FontHeader）+ 右侧副信息文字（FontSmall, TextMuted）+ 底部 1px Accent 分隔线。

### 3.3 IconButton（图标按钮，三态）

**用途**：替代所有手写 `MakeButtonBox` 调用，强制三态。

```csharp
public enum ButtonVariant { Primary, Secondary, Danger, Ghost }

public partial class IconButton : Button
{
    public ButtonVariant Variant { get; set; }
    public string IconText { get; set; } // 当前用文字图标"×""+""<"等
}
```

**自动行为**：在 `_Ready` 中根据 `Variant` 调用 `UIStyle.MakeStateButton()` 设置 normal/hover/pressed/disabled。

### 3.4 ConfirmDialog（二次确认）

**用途**：分解、出售、重置、删除存档等不可逆操作。

```csharp
ConfirmDialog.Show(
    title: "分解装备",
    message: "确认分解【太古·秋水】？将获得 24 锻造碎片。",
    onConfirm: () => InventorySystem.Salvage(item),
    confirmText: "分解",
    danger: true
);
```

**实现**：单例 popup（挂在 `UIOverlayManager` 父节点），同时支持点击遮罩关闭/ESC 取消。

### 3.5 EmptyState（空状态占位）

**用途**：空背包、未发现成就、空章节列表。

```csharp
new EmptyState("背包空空如也", "前往历练获取装备", iconText: "📦");
```

垂直居中于父容器，单色图标 + 主标题 + 副标题三段式。

### 3.6 TabBar（自定义 tab 选择器）

**用途**：替代 `TabContainer`，支持红点和自定义样式。

```csharp
var tabBar = new TabBar();
tabBar.AddTab("提取", "extract");
tabBar.AddTab("锻造", "forge").SetRedDot(true);
tabBar.TabSelected += tabId => { /* ... */ };
```

视觉：选中 tab 显示底部 2px Accent 下划线，非选中态文字 TextSecondary。

### 3.7 KeyValueRow（标签:值 行）

**用途**：详情面板的属性行。

```csharp
container.AddChild(new KeyValueRow("武器伤害", "120 - 180"));
container.AddChild(new KeyValueRow("暴击率", "+12.5%", valueColor: UIStyle.Success));
```

固定布局：左标签（150px, TextSecondary）+ 右值（flex, TextPrimary）。

### 3.8 ItemCardButton（已存在，需扩展）

补充：`SetSelected(bool)` 方法，选中时品质边框加粗到 3px 并外发光。

---

## 四、面板构图模板

所有 L2 / L3 面板必须遵循以下三段式：

```
┌─────────────────────────────────────────┐
│ Title             Subtitle        [×]  │  Header  (40px)
├─────────────────────────────────────────┤
│                                         │
│              Body 区域                  │
│        (TabBar / List / Grid /         │  Body    (flex)
│              Detail)                    │
│                                         │
├─────────────────────────────────────────┤
│ [次要按钮]              [主要按钮]    │  Footer  (52px, 可选)
└─────────────────────────────────────────┘
```

**约束**：
- 面板宽度按内容选择：紧凑型 440 / 标准型 720 / 宽屏型 960
- 面板高度统一不超过 600px（保证小屏幕可见）
- 居中显示（`LayoutPreset.Center`）
- Header 和 Footer 不滚动，仅 Body 内部按需滚动

---

## 五、HUD 信息架构（F-Pattern）

```
┌──────────────────────────────────────────────┐
│ [玩家头像/HP/能量/Lv]      [章节/节点/波次] │  ← 上区（高优先）
│                                              │
│  [拾取浮窗]                  [目标卡片]     │  ← 中区
│                                              │
│        ====== 战斗走廊 ======                │  ← 战斗区（绝对禁覆盖）
│                                              │
│ [掉落 Toast]                                 │  ← 下区
├──────────────────────────────────────────────┤
│  [背包][技能][百炼][成长][异闻][推演][设置]│  ← 导航栏（固定 52px）
└──────────────────────────────────────────────┘
```

**约束**：
- 玩家信息位于左上（F-Pattern 第一关注点）
- 关卡信息位于右上（次关注点）
- 战斗走廊（中央 Y=400~520 高度）必须留空
- 所有 HUD 元素使用 `MouseFilter = Ignore` 不拦截点击

---

## 六、响应式与布局策略

### 6.1 锚点优先

**禁止**在面板代码中出现：
- `node.Position = new Vector2(x, y)` （除 HUD 中纯展示节点外）
- 硬编码视口尺寸（`1280`、`720`）

**必须**使用：
- `SetAnchorsPreset(LayoutPreset.X)` 锚定到父容器某区域
- `OffsetLeft / Right / Top / Bottom` 表示偏移
- `CustomMinimumSize` 设定最小尺寸
- `Container` 系（`HBoxContainer` / `VBoxContainer` / `GridContainer` / `MarginContainer`）让子节点自动布局

### 6.2 PanelChrome 居中模板

```csharp
SetAnchorsPreset(LayoutPreset.Center);
GrowHorizontal = GrowDirection.Both;
GrowVertical = GrowDirection.Both;
CustomMinimumSize = new Vector2(720, 520);
```

---

## 七、反馈与状态规范

### 7.1 按钮三态

| 状态 | 视觉变化 | 实现 |
|------|---------|------|
| Normal | 默认底色 | `MakeStateButton(accent)` |
| Hover | 底色 +15% 亮度 | `accent.Lightened(0.15f)` |
| Pressed | 底色 -15% 亮度 | `accent.Darkened(0.15f)` |
| Disabled | 灰度 + Alpha 0.5 | 自动应用 |

### 7.2 选中态

- **列表/网格选中项**：增加 2px Accent 边框 + 背景 `Bg4`
- **Tab 选中项**：底部 2px Accent 下划线，文字 TextPrimary
- **存档槽位选中**：3px Accent 边框 + 内发光（`BorderHighlight`）

### 7.3 数据刷新

```csharp
public override void _Notification(int what)
{
    if (what == NotificationVisibilityChanged && Visible)
        Refresh();
}
```

所有面板必须在可见性变化时触发 `Refresh()`，**不依赖**事件总线在面板隐藏时漏掉数据。

### 7.4 反馈时间

呼应 [交互设计规范 3.2](交互设计规范.md#32-反馈模式)：
- 普通点击 ≤ 50ms 视觉反馈
- 装备穿戴 ≤ 300ms 完成
- 错误操作 ≤ 100ms 抖动提示

---

## 八、可达性 / 键盘导航

### 8.1 焦点

- **禁止**全局设置 `FocusMode = None`（除装饰元素如红点 Panel）
- 主要交互按钮使用默认 `FocusMode = All`，支持 Tab 键切换

### 8.2 ESC 处理

- 由 [UIOverlayManager](../../scripts/UI/UIOverlayManager.cs) 统一处理
- 面板**不应**自定义 ESC 处理（避免冲突）

### 8.3 快捷键映射

| 键 | 动作 |
|----|------|
| `I` | 背包 |
| `K` | 技能 |
| `B` | 百炼坊 |
| `U` | 成长 |
| `O` | 异闻录 |
| `P` | 推演 |
| `Esc` | 关闭当前面板 |
| `` ` `` (反引号) | GM 面板（仅 Debug 构建） |

---

## 九、命名约定

| 规则 | 示例 |
|------|------|
| 控件类后缀 | `XxxController` (面板) / `XxxButton` (按钮组件) / `XxxRow` (列表行) |
| 私有字段 | `_camelCase` (有下划线前缀) |
| 槽位资源 | `panel_xxx.tscn` 在 `scenes/ui/` 下 |
| 颜色变量 | PascalCase 单词 (`BgHeader`, `Accent`) 不带 `Color` 后缀 |

---

## 十、迁移检查清单

新建/重构面板时按以下顺序检查：

- [ ] 是否使用 `PanelChrome` 作为根
- [ ] 标题/副标题/关闭按钮三件套通过 `Title`/`Subtitle` 属性而非自绘
- [ ] 所有间距使用 `Spacing4/8/12/16/24/32` token
- [ ] 所有按钮使用 `IconButton` 或 `MakeStateButton`，不裸用 `Button`
- [ ] 列表/网格选中项有视觉反馈
- [ ] 破坏性操作前用 `ConfirmDialog`
- [ ] 空数据时显示 `EmptyState`
- [ ] 可见性变化触发 `Refresh()`
- [ ] 没有硬编码 `Position = Vector2(...)`
- [ ] `dotnet build` 0 错误，`ReadLints` 0 报错

---

*本文档最后更新：2026-03-19*
