using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Codex (异闻录) panel: collection catalog, discovery progress, tracking targets.
/// </summary>
public partial class CodexPanelController : Control
{
    private VBoxContainer _listContainer = null!;
    private Label _progressLabel = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(600, 440);
        Position = new Vector2(340, 140);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "异 闻 录", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.NavCodex);
        AddChild(title);

        _progressLabel = new Label { Text = "收集进度: 0%", Position = new Vector2(20, 44) };
        _progressLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _progressLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        AddChild(_progressLabel);

        var scroll = new ScrollContainer
        {
            Position = new Vector2(10, 70),
            Size = new Vector2(580, 360),
        };
        AddChild(scroll);

        _listContainer = new VBoxContainer();
        _listContainer.AddThemeConstantOverride("separation", 4);
        scroll.AddChild(_listContainer);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        foreach (var child in _listContainer.GetChildren()) child.QueueFree();

        var codex = GetNode<LootCodexSystem>("/root/LootCodexSystem");

        foreach (var baseId in codex.DiscoveredBaseIds)
        {
            int count = codex.GetDropCount(baseId);
            var row = new Label { Text = $"  {baseId} — 获得 {count} 次" };
            row.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            row.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
            _listContainer.AddChild(row);
        }

        _progressLabel.Text = $"收集进度: {codex.TotalDiscovered} 种已发现";
    }
}
