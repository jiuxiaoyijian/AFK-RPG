using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// 出关所得弹窗：离线奖励汇总，使用 PanelChrome + KeyValueRow。
/// 弹出时切换 OverlayManager 到 Blocking 状态；点击"确认"恢复。
/// 见 文档/02_交互与原型/UI控件与视觉规范.md
/// </summary>
public partial class OfflineReportPopupController : Control
{
    private PanelChrome _chrome = null!;
    private VBoxContainer _list = null!;
    private Label _hintLabel = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;
        Visible = false;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.OfflineReportReady += OnReport;
    }

    private void BuildUI()
    {
        _chrome = new PanelChrome
        {
            PanelId = "offline_report",
            Title = "出 关 所 得",
            Subtitle = "离线奖励汇总",
            AccentColor = UIStyle.Accent,
            PanelWidth = 480,
            PanelHeight = 380,
            ShowFooter = true,
        };
        AddChild(_chrome);

        var content = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        _chrome.Body.AddChild(content);

        content.AddChild(new SectionHeader("奖励明细"));

        _list = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        _list.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        content.AddChild(_list);

        var spacer = new Control { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddChild(spacer);

        _hintLabel = new Label
        {
            Text = "感谢挂机修行，按确认领取并继续。",
            HorizontalAlignment = HorizontalAlignment.Center,
            AutowrapMode = TextServer.AutowrapMode.Word,
        };
        _hintLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _hintLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        content.AddChild(_hintLabel);

        var confirmBtn = new IconButton("确  认", IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(140, UIStyle.ButtonHeight),
        };
        confirmBtn.Pressed += OnClose;
        _chrome.Footer.AddChild(confirmBtn);
    }

    private void OnReport(double secondsAway, string rewardJson)
    {
        if (_list == null) return;
        foreach (var child in _list.GetChildren()) child.QueueFree();

        int hours = (int)(secondsAway / 3600);
        int minutes = (int)(secondsAway % 3600 / 60);
        _list.AddChild(new KeyValueRow("离线时长", $"{hours}h {minutes}m", UIStyle.TextPrimary));

        try
        {
            using var doc = JsonDocument.Parse(rewardJson);
            var root = doc.RootElement;
            if (root.TryGetProperty("gold", out var g))
                _list.AddChild(new KeyValueRow("金币", $"+{g.GetInt64():N0}", UIStyle.Accent));
            if (root.TryGetProperty("exp", out var e))
                _list.AddChild(new KeyValueRow("经验", $"+{e.GetInt64():N0}", UIStyle.Success));
            if (root.TryGetProperty("kills", out var k))
                _list.AddChild(new KeyValueRow("击杀", $"+{k.GetInt32():N0}", UIStyle.NavSkills));
            if (root.TryGetProperty("scrap", out var s))
                _list.AddChild(new KeyValueRow("碎片", $"+{s.GetInt64():N0}", UIStyle.NavCube));
        }
        catch
        {
            _list.AddChild(new KeyValueRow("错误", "奖励数据解析失败", UIStyle.Danger));
        }

        Visible = true;
    }

    private void OnClose()
    {
        Visible = false;
        var overlay = GetNodeOrNull<UIOverlayManager>("../UIOverlayManager");
        overlay?.UnblockUI();
    }

    public override void _UnhandledInput(InputEvent ev)
    {
        if (!Visible) return;
        if (ev is InputEventKey { Pressed: true, Keycode: Key.Escape or Key.Enter or Key.KpEnter })
        {
            OnClose();
            GetViewport().SetInputAsHandled();
        }
    }
}
