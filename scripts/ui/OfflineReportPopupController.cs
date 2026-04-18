using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Offline report popup: shows what the player earned while away.
/// </summary>
public partial class OfflineReportPopupController : Control
{
    private Label _titleLabel = null!;
    private Label _contentLabel = null!;
    private Button _closeBtn = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(400, 300);
        Position = new Vector2(440, 210);
        Visible = false;

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.Accent, 2, 8));
        AddChild(bg);

        _titleLabel = new Label { Text = "出关所得", Position = new Vector2(20, 16) };
        _titleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        _titleLabel.AddThemeColorOverride("font_color", UIStyle.Accent);
        AddChild(_titleLabel);

        _contentLabel = new Label { Text = "", Position = new Vector2(20, 60), Size = new Vector2(360, 180) };
        _contentLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _contentLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        AddChild(_contentLabel);

        _closeBtn = new Button { Text = "确认", Position = new Vector2(150, 250), CustomMinimumSize = new Vector2(100, 36) };
        _closeBtn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.Accent));
        _closeBtn.Pressed += OnClose;
        AddChild(_closeBtn);

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.OfflineReportReady += OnReport;
    }

    private void OnReport(double secondsAway, string rewardJson)
    {
        int hours = (int)(secondsAway / 3600);
        int minutes = (int)((secondsAway % 3600) / 60);

        string content = $"离线时长: {hours}h {minutes}m\n\n";

        try
        {
            using var doc = JsonDocument.Parse(rewardJson);
            var root = doc.RootElement;
            if (root.TryGetProperty("gold", out var g)) content += $"金币: +{g.GetInt64()}\n";
            if (root.TryGetProperty("exp", out var e)) content += $"经验: +{e.GetInt64()}\n";
            if (root.TryGetProperty("kills", out var k)) content += $"击杀: +{k.GetInt32()}\n";
        }
        catch { content += "(奖励数据解析失败)"; }

        _contentLabel.Text = content;
        Visible = true;
    }

    private void OnClose()
    {
        Visible = false;
        var overlay = GetNodeOrNull<UIOverlayManager>("../../UIOverlayManager");
        overlay?.UnblockUI();
    }
}
