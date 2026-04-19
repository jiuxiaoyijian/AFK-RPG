using Godot;
using DesktopIdle.Models;
using DesktopIdle.Utils;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Reusable item card component: quality border frame + icon + name + level badge.
/// Used in inventory grid, loot preview, cube panel, etc.
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.8
/// </summary>
public partial class ItemCardButton : Button
{
    public ItemData? BoundItem { get; private set; }

    private ColorRect _qualityFrame = null!;
    private ColorRect _selectedBorder = null!;
    private Label _nameLabel = null!;
    private Label _levelBadge = null!;
    private ColorRect _iconPlaceholder = null!;
    private bool _isSelected;

    public override void _Ready()
    {
        CustomMinimumSize = new Vector2(64, 80);
        FocusMode = FocusModeEnum.None;
        ClipText = true;

        _qualityFrame = new ColorRect { Size = new Vector2(64, 80), Color = UIStyle.Common };
        AddChild(_qualityFrame);

        _iconPlaceholder = new ColorRect
        {
            Position = new Vector2(4, 4),
            Size = new Vector2(56, 48),
            Color = UIStyle.BgDark,
        };
        _qualityFrame.AddChild(_iconPlaceholder);

        _nameLabel = new Label
        {
            Position = new Vector2(2, 54),
            Size = new Vector2(60, 14),
            ClipText = true,
        };
        _nameLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
        _nameLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        _qualityFrame.AddChild(_nameLabel);

        _levelBadge = new Label
        {
            Position = new Vector2(2, 68),
            Size = new Vector2(60, 12),
        };
        _levelBadge.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
        _levelBadge.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        _qualityFrame.AddChild(_levelBadge);

        _selectedBorder = new ColorRect
        {
            Size = new Vector2(64, 80),
            Color = new Color(UIStyle.Accent.R, UIStyle.Accent.G, UIStyle.Accent.B, 0),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        AddChild(_selectedBorder);
    }

    public void Bind(ItemData item)
    {
        BoundItem = item;
        _qualityFrame.Color = ItemPresentationService.GetQualityColor(item.Quality).Darkened(0.4f);
        _iconPlaceholder.Color = ItemPresentationService.GetQualityColor(item.Quality).Darkened(0.6f);
        _nameLabel.Text = string.IsNullOrEmpty(item.Name) ? item.BaseId : item.Name;
        _levelBadge.Text = $"Lv.{item.ItemLevel}";
        TooltipText = ItemPresentationService.BuildTooltip(item);
    }

    public void Clear()
    {
        BoundItem = null;
        _qualityFrame.Color = UIStyle.BgDark;
        _iconPlaceholder.Color = UIStyle.BgDark;
        _nameLabel.Text = "";
        _levelBadge.Text = "";
        TooltipText = "";
    }

    public void SetSelected(bool selected)
    {
        _isSelected = selected;
        if (selected)
        {
            // 用一个内描边代替（border 通过四个细矩形模拟，避免覆盖整个图标）
            BuildSelectedBorder();
        }
        else
        {
            ClearSelectedBorder();
        }
    }

    public bool IsSelected => _isSelected;

    private void BuildSelectedBorder()
    {
        ClearSelectedBorder();
        const int t = 2;
        var top = new ColorRect { Color = UIStyle.Accent, Position = Vector2.Zero, Size = new Vector2(64, t), MouseFilter = MouseFilterEnum.Ignore };
        var bottom = new ColorRect { Color = UIStyle.Accent, Position = new Vector2(0, 80 - t), Size = new Vector2(64, t), MouseFilter = MouseFilterEnum.Ignore };
        var left = new ColorRect { Color = UIStyle.Accent, Position = Vector2.Zero, Size = new Vector2(t, 80), MouseFilter = MouseFilterEnum.Ignore };
        var right = new ColorRect { Color = UIStyle.Accent, Position = new Vector2(64 - t, 0), Size = new Vector2(t, 80), MouseFilter = MouseFilterEnum.Ignore };
        top.Name = "_selTop"; bottom.Name = "_selBottom"; left.Name = "_selLeft"; right.Name = "_selRight";
        AddChild(top); AddChild(bottom); AddChild(left); AddChild(right);
    }

    private void ClearSelectedBorder()
    {
        foreach (var name in new[] { "_selTop", "_selBottom", "_selLeft", "_selRight" })
        {
            var n = GetNodeOrNull(name);
            n?.QueueFree();
        }
    }
}
