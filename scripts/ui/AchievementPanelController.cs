using Godot;
using DesktopIdle.Models;
using DesktopIdle.Systems;

namespace DesktopIdle.UI;

/// <summary>
/// Achievement panel: 5 category tabs, progress list, title selection.
/// </summary>
public partial class AchievementPanelController : Control
{
    private TabContainer _tabs = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(640, 480);
        Position = new Vector2(320, 120);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "成就与称号", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.Accent);
        AddChild(title);

        _tabs = new TabContainer { Position = new Vector2(10, 44), Size = new Vector2(620, 420) };
        AddChild(_tabs);

        var categories = new[] {
            (AchievementCategory.Combat, "战斗"),
            (AchievementCategory.Collection, "收集"),
            (AchievementCategory.Exploration, "探索"),
            (AchievementCategory.Rebirth, "轮回"),
            (AchievementCategory.Milestone, "里程碑"),
        };

        foreach (var (cat, name) in categories)
            BuildCategoryTab(cat, name);

        BuildTitleTab();
    }

    private void BuildCategoryTab(AchievementCategory category, string tabName)
    {
        var page = new VBoxContainer { Name = tabName };
        page.AddThemeConstantOverride("separation", 6);
        _tabs.AddChild(page);

        var achieveSystem = GetNodeOrNull<AchievementSystem>("/root/GameRoot/Systems/AchievementSystem");
        if (achieveSystem == null) return;

        foreach (var ach in achieveSystem.AllAchievements)
        {
            if (ach.Category != category) continue;
            if (ach.Hidden && !achieveSystem.IsUnlocked(ach.Id)) continue;

            bool unlocked = achieveSystem.IsUnlocked(ach.Id);
            var row = new Label
            {
                Text = $"{(unlocked ? "★" : "☆")} {ach.Name} — {ach.Description}"
            };
            row.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            row.AddThemeColorOverride("font_color", unlocked ? UIStyle.Accent : UIStyle.TextMuted);
            page.AddChild(row);
        }
    }

    private void BuildTitleTab()
    {
        var page = new VBoxContainer { Name = "称号" };
        page.AddThemeConstantOverride("separation", 6);
        _tabs.AddChild(page);

        var achieveSystem = GetNodeOrNull<AchievementSystem>("/root/GameRoot/Systems/AchievementSystem");
        if (achieveSystem == null) return;

        foreach (var t in achieveSystem.AllTitles)
        {
            bool canEquip = achieveSystem.CanEquipTitle(t.Id);
            bool isActive = achieveSystem.ActiveTitleId == t.Id;

            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            page.AddChild(row);

            var lbl = new Label
            {
                Text = $"{t.Name} — {t.Description}",
                CustomMinimumSize = new Vector2(400, 0),
            };
            lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            lbl.AddThemeColorOverride("font_color", canEquip ? UIStyle.TextPrimary : UIStyle.TextMuted);
            row.AddChild(lbl);

            if (canEquip)
            {
                var btn = new Button { Text = isActive ? "已佩戴" : "佩戴", CustomMinimumSize = new Vector2(60, 24) };
                btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(isActive ? UIStyle.Success : UIStyle.NavResearch));
                btn.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
                var titleId = t.Id;
                btn.Pressed += () => achieveSystem.EquipTitle(titleId);
                row.AddChild(btn);
            }
        }
    }
}
