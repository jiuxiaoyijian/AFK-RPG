using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// Codex (异闻录) panel: collection catalog, discovery progress, tracking targets.
/// 修复：首屏与刷新使用统一的 Refresh()，避免格式不一致 bug。
/// </summary>
public partial class CodexPanelController : Control
{
    private VBoxContainer _listContainer = null!;
    private Label _progressLabel = null!;
    private EmptyState _emptyState = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.LootDropped += (_, _) => Refresh();

        Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "codex",
            Title = "异 闻 录",
            Subtitle = "收集 / 探索 / 图鉴",
            AccentColor = UIStyle.NavCodex,
            PanelWidth = UIStyle.PanelWidthStandard,
            PanelHeight = 480,
        };
        AddChild(chrome);

        var content = new VBoxContainer();
        content.SizeFlagsVertical = SizeFlags.ExpandFill;
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        chrome.Body.AddChild(content);

        _progressLabel = new Label
        {
            Text = "收集进度：0 种已发现",
        };
        _progressLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        _progressLabel.AddThemeColorOverride("font_color", UIStyle.Accent);
        content.AddChild(_progressLabel);

        content.AddChild(new SectionHeader("已发现物品"));

        var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddChild(scroll);

        _listContainer = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        _listContainer.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        scroll.AddChild(_listContainer);

        _emptyState = new EmptyState("尚未发现任何物品", "前往历练拾取装备解锁图鉴", "?");
        _emptyState.Visible = false;
        content.AddChild(_emptyState);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        if (_listContainer == null) return;
        foreach (var child in _listContainer.GetChildren()) child.QueueFree();

        var codex = GetNode<LootCodexSystem>("/root/LootCodexSystem");

        bool empty = codex.TotalDiscovered == 0;
        _emptyState.Visible = empty;
        _listContainer.Visible = !empty;
        _progressLabel.Text = $"收集进度：{codex.TotalDiscovered} 种已发现";

        foreach (var baseId in codex.DiscoveredBaseIds)
        {
            int count = codex.GetDropCount(baseId);
            _listContainer.AddChild(new KeyValueRow(baseId, $"× {count}", UIStyle.TextPrimary));
        }
    }
}
