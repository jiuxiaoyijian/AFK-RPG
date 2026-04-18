using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Systems;

namespace DesktopIdle.UI;

/// <summary>
/// Drop Stats / Rift panel (推演): drop analysis, rift entry, gem management.
/// </summary>
public partial class DropStatsPanelController : Control
{
    private TabContainer _tabs = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(680, 480);
        Position = new Vector2(300, 120);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "推 演", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.NavStats);
        AddChild(title);

        _tabs = new TabContainer { Position = new Vector2(10, 44), Size = new Vector2(660, 420) };
        AddChild(_tabs);

        BuildDropStatsTab();
        BuildRiftTab();
        BuildGemsTab();
    }

    private void BuildDropStatsTab()
    {
        var page = new VBoxContainer { Name = "掉落统计" };
        page.AddThemeConstantOverride("separation", 8);
        _tabs.AddChild(page);

        var meta = GetNodeOrNull<MetaProgressionSystem>("/root/MetaProgressionSystem");
        var info = new Label
        {
            Text = $"总物品发现: {meta?.TotalItemsFound ?? 0}\n" +
                   $"传说级发现: {meta?.TotalLegendariesFound ?? 0}\n" +
                   $"游戏时长: {meta?.GetPlaytimeDisplay() ?? "0h 0m"}"
        };
        info.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        info.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        page.AddChild(info);
    }

    private void BuildRiftTab()
    {
        var page = new VBoxContainer { Name = "秘境" };
        page.AddThemeConstantOverride("separation", 8);
        _tabs.AddChild(page);

        var desc = new Label { Text = "消耗钥石开启秘境，限时挑战，击败所有敌人获得奖励。" };
        desc.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        desc.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        page.AddChild(desc);

        var startBtn = new Button { Text = "开启秘境", CustomMinimumSize = new Vector2(160, 40) };
        startBtn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavStats));
        startBtn.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        page.AddChild(startBtn);
    }

    private void BuildGemsTab()
    {
        var page = new VBoxContainer { Name = "传奇宝石" };
        page.AddThemeConstantOverride("separation", 8);
        _tabs.AddChild(page);

        var desc = new Label { Text = "镶嵌传奇宝石获得持续增强效果。最多装备 6 颗。" };
        desc.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        desc.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        page.AddChild(desc);

        var slots = new HBoxContainer();
        slots.AddThemeConstantOverride("separation", 8);
        page.AddChild(slots);

        for (int i = 0; i < GemSystem.MaxGemSlots; i++)
        {
            var slot = new Panel { CustomMinimumSize = new Vector2(64, 64) };
            slot.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgDark, UIStyle.Border, 1, 4));
            slots.AddChild(slot);

            var lbl = new Label { Text = $"宝石{i + 1}", Position = new Vector2(4, 22) };
            lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
            lbl.AddThemeColorOverride("font_color", UIStyle.TextMuted);
            slot.AddChild(lbl);
        }
    }
}
