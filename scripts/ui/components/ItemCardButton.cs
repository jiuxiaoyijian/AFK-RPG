using Godot;
using DesktopIdle.Models;
using DesktopIdle.Utils;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Reusable item card component: quality border frame + icon + name + level badge.
/// Used in inventory grid, loot preview, cube panel, etc.
/// </summary>
public partial class ItemCardButton : Button
{
    public ItemData? BoundItem { get; private set; }

    private ColorRect _qualityFrame = null!;
    private Label _nameLabel = null!;
    private Label _levelBadge = null!;
    private ColorRect _iconPlaceholder = null!;

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
}
