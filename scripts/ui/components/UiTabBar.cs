using System;
using System.Collections.Generic;
using Godot;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Custom tab selector with red dot &amp; underline indicator.
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.6
/// 替代 Godot 原生 TabContainer 以支持红点和自定义样式。
/// 命名为 UiTabBar 以避免与 Godot.TabBar 冲突。
///
/// 用法：
///   var tabs = new UiTabBar();
///   parent.AddChild(tabs);
///   tabs.AddTab("提取", "extract");
///   tabs.AddTab("锻造", "forge").SetRedDot(true);
///   tabs.TabSelected += tabId => SwitchPage(tabId);
///   tabs.SelectTab("extract");
/// </summary>
public partial class UiTabBar : VBoxContainer
{
    /// <summary>选中 tab 时触发，参数为 tabId。</summary>
    [Signal] public delegate void TabSelectedEventHandler(string tabId);

    private readonly List<TabItem> _tabs = new();
    private HBoxContainer _tabRow = null!;
    private Control _underline = null!;
    private string _activeTabId = "";

    public string ActiveTabId => _activeTabId;

    public override void _Ready()
    {
        AddThemeConstantOverride("separation", 0);

        _tabRow = new HBoxContainer();
        _tabRow.AddThemeConstantOverride("separation", UIStyle.Spacing24);
        _tabRow.CustomMinimumSize = new Vector2(0, 36);
        AddChild(_tabRow);

        var underlineRow = new Control { CustomMinimumSize = new Vector2(0, 2) };
        AddChild(underlineRow);

        _underline = new ColorRect
        {
            Color = UIStyle.Accent,
            CustomMinimumSize = new Vector2(0, 2),
            Visible = false,
        };
        underlineRow.AddChild(_underline);

        var divider = new ColorRect
        {
            Color = UIStyle.Border,
            CustomMinimumSize = new Vector2(0, 1),
        };
        AddChild(divider);

        Resized += UpdateUnderlinePosition;
    }

    public TabItem AddTab(string label, string tabId)
    {
        var item = new TabItem(label, tabId);
        var btn = new Button
        {
            Text = label,
            FocusMode = FocusModeEnum.None,
            Flat = true,
            CustomMinimumSize = new Vector2(0, 36),
        };
        btn.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        btn.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        btn.AddThemeColorOverride("font_hover_color", UIStyle.TextPrimary);
        btn.AddThemeColorOverride("font_pressed_color", UIStyle.Accent);

        var tabId1 = tabId;
        btn.Pressed += () => SelectTab(tabId1);
        item.Button = btn;

        var dot = new Panel
        {
            Visible = false,
            CustomMinimumSize = new Vector2(8, 8),
            Position = new Vector2(0, 4),
        };
        dot.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.Danger, UIStyle.Danger, 0, 4));
        dot.MouseFilter = MouseFilterEnum.Ignore;
        btn.AddChild(dot);
        item.RedDot = dot;

        _tabRow.AddChild(btn);
        _tabs.Add(item);

        if (_tabs.Count == 1)
            CallDeferred(MethodName.SelectTab, tabId);

        return item;
    }

    public void SelectTab(string tabId)
    {
        _activeTabId = tabId;
        foreach (var t in _tabs)
        {
            bool active = t.TabId == tabId;
            t.Button?.AddThemeColorOverride("font_color", active ? UIStyle.Accent : UIStyle.TextSecondary);
        }
        UpdateUnderlinePosition();
        EmitSignal(SignalName.TabSelected, tabId);
    }

    private void UpdateUnderlinePosition()
    {
        var active = _tabs.Find(t => t.TabId == _activeTabId);
        if (active?.Button == null)
        {
            _underline.Visible = false;
            return;
        }
        _underline.Visible = true;
        _underline.Position = new Vector2(active.Button.Position.X, 0);
        _underline.CustomMinimumSize = new Vector2(active.Button.Size.X, 2);
        _underline.Size = new Vector2(active.Button.Size.X, 2);
    }

    public class TabItem
    {
        public string Label { get; }
        public string TabId { get; }
        public Button? Button { get; set; }
        public Panel? RedDot { get; set; }

        public TabItem(string label, string tabId) { Label = label; TabId = tabId; }

        public TabItem SetRedDot(bool visible)
        {
            if (RedDot != null) RedDot.Visible = visible;
            return this;
        }
    }
}
