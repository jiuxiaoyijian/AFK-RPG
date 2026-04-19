using Godot;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Empty-state placeholder: vertically centered icon + title + subtitle.
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.5
/// 用于空背包、空成就、空章节列表等场景。
/// </summary>
public partial class EmptyState : Control
{
    private readonly string _title;
    private readonly string _subtitle;
    private readonly string _icon;

    public EmptyState(string title, string subtitle = "", string icon = "")
    {
        _title = title;
        _subtitle = subtitle;
        _icon = icon;
    }

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        var center = new VBoxContainer();
        center.SetAnchorsPreset(LayoutPreset.Center);
        center.GrowHorizontal = GrowDirection.Both;
        center.GrowVertical = GrowDirection.Both;
        center.CustomMinimumSize = new Vector2(280, 120);
        center.Alignment = BoxContainer.AlignmentMode.Center;
        center.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        AddChild(center);

        if (!string.IsNullOrEmpty(_icon))
        {
            var iconLabel = new Label
            {
                Text = _icon,
                HorizontalAlignment = HorizontalAlignment.Center,
            };
            iconLabel.AddThemeFontSizeOverride("font_size", 48);
            iconLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
            center.AddChild(iconLabel);
        }

        var titleLabel = new Label
        {
            Text = _title,
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        titleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        titleLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        center.AddChild(titleLabel);

        if (!string.IsNullOrEmpty(_subtitle))
        {
            var subLabel = new Label
            {
                Text = _subtitle,
                HorizontalAlignment = HorizontalAlignment.Center,
            };
            subLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            subLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
            center.AddChild(subLabel);
        }
    }
}
