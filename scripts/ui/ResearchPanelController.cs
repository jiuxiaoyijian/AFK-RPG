using Godot;
using DesktopIdle.Systems;

namespace DesktopIdle.UI;

/// <summary>
/// Research panel (成长中心): contains sub-tabs for Paragon, Season info, and hero progression.
/// </summary>
public partial class ResearchPanelController : Control
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

        var title = new Label { Text = "成 长 中 心", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.NavResearch);
        AddChild(title);

        _tabs = new TabContainer { Position = new Vector2(10, 44), Size = new Vector2(660, 420) };
        AddChild(_tabs);

        BuildParagonTab();
        BuildSeasonTab();
        BuildProgressionTab();
    }

    private void BuildParagonTab()
    {
        var page = new VBoxContainer { Name = "宗师修为" };
        page.AddThemeConstantOverride("separation", 10);
        _tabs.AddChild(page);

        var boards = new[] {
            (ParagonSystem.ParagonBoard.Offensive, "攻击面板", "主属性/暴击/暴击伤害/攻速"),
            (ParagonSystem.ParagonBoard.Defensive, "防御面板", "生命/防御/闪避/回复"),
            (ParagonSystem.ParagonBoard.Utility, "辅助面板", "移速/资源发现/经验/金币"),
            (ParagonSystem.ParagonBoard.Special, "特殊面板", "技能伤害/冷缩/范围伤害/精英伤害"),
        };

        foreach (var (board, name, desc) in boards)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            page.AddChild(row);

            var lbl = new Label { Text = $"{name}: {desc}", CustomMinimumSize = new Vector2(400, 0) };
            lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            lbl.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
            row.AddChild(lbl);

            var btn = new Button { Text = "+1 点", CustomMinimumSize = new Vector2(80, 28) };
            btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavResearch));
            row.AddChild(btn);
        }
    }

    private void BuildSeasonTab()
    {
        var page = new VBoxContainer { Name = "重入江湖" };
        page.AddThemeConstantOverride("separation", 10);
        _tabs.AddChild(page);

        var info = new Label { Text = "赛季重置：保留永久加成，重新挑战江湖。\n需要达到 70 级才能触发。" };
        info.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        info.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        page.AddChild(info);

        var rebirthBtn = new Button { Text = "重入江湖", CustomMinimumSize = new Vector2(160, 40) };
        rebirthBtn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.Danger));
        rebirthBtn.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        page.AddChild(rebirthBtn);
    }

    private void BuildProgressionTab()
    {
        var page = new VBoxContainer { Name = "弟子成长" };
        page.AddThemeConstantOverride("separation", 10);
        _tabs.AddChild(page);

        var info = new Label { Text = "弟子等级、经验进度、突破里程碑" };
        info.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        info.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        page.AddChild(info);

        var expBar = new ProgressBar { CustomMinimumSize = new Vector2(500, 24), Value = 45 };
        page.AddChild(expBar);
    }
}
