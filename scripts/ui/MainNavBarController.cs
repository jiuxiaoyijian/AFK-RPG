using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Bottom navigation bar with 7 buttons.
/// Each button opens/closes a panel via UIOverlayManager.
/// Supports red dot notifications per button.
/// </summary>
public partial class MainNavBarController : Control
{
    private record NavDef(string PanelId, string Label, string Action, Color Accent);

    private static readonly NavDef[] Buttons = new[]
    {
        new NavDef("inventory",  "背包",   "ui_inventory",  UIStyle.NavInventory),
        new NavDef("skills",     "技能",   "ui_skills",     UIStyle.NavSkills),
        new NavDef("cube",       "百炼坊", "ui_cube",       UIStyle.NavCube),
        new NavDef("research",   "成长",   "ui_research",   UIStyle.NavResearch),
        new NavDef("codex",      "异闻录", "ui_codex",      UIStyle.NavCodex),
        new NavDef("drop_stats", "推演",   "ui_drop_stats", UIStyle.NavStats),
        new NavDef("settings",   "设置",   "",              UIStyle.NavSettings),
    };

    private readonly Dictionary<string, Button> _buttonMap = new();
    private readonly Dictionary<string, Panel> _redDots = new();
    private UIOverlayManager? _overlayManager;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.BottomWide);
        OffsetTop = -52;
        CallDeferred(Control.MethodName.SetSize, new Vector2(1280, 52));

        _overlayManager = GetNodeOrNull<UIOverlayManager>("../../UIOverlayManager");

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgHeader, UIStyle.Border, 1, 0));
        AddChild(bg);

        var hbox = new HBoxContainer();
        hbox.Alignment = BoxContainer.AlignmentMode.Center;
        hbox.SetAnchorsPreset(LayoutPreset.FullRect);
        hbox.AddThemeConstantOverride("separation", 8);
        AddChild(hbox);

        foreach (var def in Buttons)
        {
            var btn = new Button
            {
                Text = def.Label,
                CustomMinimumSize = new Vector2(100, 40),
                FocusMode = FocusModeEnum.None,
            };
            btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(def.Accent));
            btn.AddThemeStyleboxOverride("hover", UIStyle.MakeButtonBox(def.Accent.Lightened(0.15f)));
            btn.AddThemeStyleboxOverride("pressed", UIStyle.MakeButtonBox(def.Accent.Darkened(0.15f)));
            btn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            btn.AddThemeColorOverride("font_color", UIStyle.TextPrimary);

            var panelId = def.PanelId;
            btn.Pressed += () => OnNavButtonPressed(panelId);
            hbox.AddChild(btn);
            _buttonMap[def.PanelId] = btn;

            var dot = new Panel();
            dot.Size = new Vector2(8, 8);
            dot.Position = new Vector2(btn.CustomMinimumSize.X - 14, 4);
            dot.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.Danger, UIStyle.Danger, 0, 4));
            dot.Visible = false;
            btn.AddChild(dot);
            _redDots[def.PanelId] = dot;
        }

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.RedDotChanged += OnRedDotChanged;
    }

    private void OnNavButtonPressed(string panelId)
    {
        if (_overlayManager == null) return;

        if (_overlayManager.ActivePanelId == panelId)
            _overlayManager.CloseAll();
        else
            _overlayManager.RequestPanel(panelId);
    }

    private void OnRedDotChanged(string panelId, bool visible)
    {
        if (_redDots.TryGetValue(panelId, out var dot))
            dot.Visible = visible;
    }
}
