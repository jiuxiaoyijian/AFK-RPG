using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.Systems;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// 成就面板：5 类成就 tab + 称号 tab，统一使用 PanelChrome + UiTabBar。
/// 见 文档/02_交互与原型/UI控件与视觉规范.md
/// </summary>
public partial class AchievementPanelController : Control
{
    private UiTabBar _tabBar = null!;
    private VBoxContainer _pageContainer = null!;
    private readonly System.Collections.Generic.Dictionary<string, VBoxContainer> _pages = new();

    private static readonly (string Id, string Label, AchievementCategory? Category)[] TabDefs = new[]
    {
        ("combat",      "战斗",   (AchievementCategory?)AchievementCategory.Combat),
        ("collection",  "收集",   (AchievementCategory?)AchievementCategory.Collection),
        ("exploration", "探索",   (AchievementCategory?)AchievementCategory.Exploration),
        ("rebirth",     "轮回",   (AchievementCategory?)AchievementCategory.Rebirth),
        ("milestone",   "里程碑", (AchievementCategory?)AchievementCategory.Milestone),
        ("titles",      "称号",   (AchievementCategory?)null),
    };

    private AchievementSystem? _achievements;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.AchievementUnlocked += _ => Refresh();
        bus.TitleChanged += _ => Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "achievement",
            Title = "成就 与 称号",
            Subtitle = "解锁里程碑 / 佩戴荣誉",
            AccentColor = UIStyle.Accent,
            PanelWidth = UIStyle.PanelWidthStandard,
            PanelHeight = 520,
        };
        AddChild(chrome);

        var content = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        chrome.Body.AddChild(content);

        _tabBar = new UiTabBar();
        content.AddChild(_tabBar);

        _pageContainer = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _pageContainer.AddThemeConstantOverride("separation", 0);
        content.AddChild(_pageContainer);

        foreach (var (id, label, _) in TabDefs)
        {
            _tabBar.AddTab(label, id);
            var page = new VBoxContainer
            {
                SizeFlagsVertical = SizeFlags.ExpandFill,
                Visible = false,
            };
            page.AddThemeConstantOverride("separation", UIStyle.Spacing8);
            _pageContainer.AddChild(page);
            _pages[id] = page;
        }

        _tabBar.TabSelected += OnTabSelected;
    }

    private void OnTabSelected(string tabId)
    {
        foreach (var (id, page) in _pages)
            page.Visible = id == tabId;
        Refresh();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private AchievementSystem? GetAchievementSystem()
    {
        if (_achievements != null && IsInstanceValid(_achievements)) return _achievements;
        _achievements = GetNodeOrNull<AchievementSystem>("/root/GameRoot/Systems/AchievementSystem");
        return _achievements;
    }

    private void Refresh()
    {
        var sys = GetAchievementSystem();
        if (sys == null) return;

        foreach (var (id, _, category) in TabDefs)
        {
            var page = _pages[id];
            if (!page.Visible) continue;

            foreach (var child in page.GetChildren()) child.QueueFree();

            if (category.HasValue)
                BuildCategoryPage(page, sys, category.Value);
            else
                BuildTitlePage(page, sys);
        }
    }

    private static void BuildCategoryPage(VBoxContainer page, AchievementSystem sys, AchievementCategory category)
    {
        int total = 0, done = 0;
        foreach (var ach in sys.AllAchievements)
        {
            if (ach.Category != category) continue;
            if (ach.Hidden && !sys.IsUnlocked(ach.Id)) continue;
            total++;
            if (sys.IsUnlocked(ach.Id)) done++;
        }

        page.AddChild(new SectionHeader(GetCategoryName(category), $"{done} / {total} 已解锁"));

        if (total == 0)
        {
            var empty = new EmptyState("暂无可显示成就", "继续游戏解锁更多内容", "?");
            empty.SizeFlagsVertical = SizeFlags.ExpandFill;
            page.AddChild(empty);
            return;
        }

        var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        page.AddChild(scroll);

        var list = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        list.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        scroll.AddChild(list);

        foreach (var ach in sys.AllAchievements)
        {
            if (ach.Category != category) continue;
            if (ach.Hidden && !sys.IsUnlocked(ach.Id)) continue;

            bool unlocked = sys.IsUnlocked(ach.Id);

            var row = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
            var rowStyle = UIStyle.MakePanelBox(unlocked ? UIStyle.Bg3 : UIStyle.Bg1, unlocked ? UIStyle.Accent : UIStyle.Border, 1, 4);
            rowStyle.ContentMarginLeft = UIStyle.Spacing12;
            rowStyle.ContentMarginRight = UIStyle.Spacing12;
            rowStyle.ContentMarginTop = UIStyle.Spacing8;
            rowStyle.ContentMarginBottom = UIStyle.Spacing8;
            row.AddThemeStyleboxOverride("panel", rowStyle);
            list.AddChild(row);

            var hbox = new HBoxContainer();
            hbox.AddThemeConstantOverride("separation", UIStyle.Spacing12);
            row.AddChild(hbox);

            var marker = new Label
            {
                Text = unlocked ? "★" : "☆",
                CustomMinimumSize = new Vector2(20, 0),
                VerticalAlignment = VerticalAlignment.Center,
            };
            marker.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
            marker.AddThemeColorOverride("font_color", unlocked ? UIStyle.Accent : UIStyle.TextMuted);
            hbox.AddChild(marker);

            var info = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
            info.AddThemeConstantOverride("separation", UIStyle.Spacing4);
            hbox.AddChild(info);

            var name = new Label { Text = ach.Name };
            name.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            name.AddThemeColorOverride("font_color", unlocked ? UIStyle.TextPrimary : UIStyle.TextSecondary);
            info.AddChild(name);

            var desc = new Label
            {
                Text = ach.Description,
                AutowrapMode = TextServer.AutowrapMode.Word,
            };
            desc.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            desc.AddThemeColorOverride("font_color", UIStyle.TextMuted);
            info.AddChild(desc);

            if (!string.IsNullOrEmpty(ach.RewardType) && !string.IsNullOrEmpty(ach.RewardValue))
            {
                var reward = new Label
                {
                    Text = $"奖励: {ach.RewardType} {ach.RewardValue}",
                };
                reward.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
                reward.AddThemeColorOverride("font_color", UIStyle.Success);
                info.AddChild(reward);
            }
        }
    }

    private static void BuildTitlePage(VBoxContainer page, AchievementSystem sys)
    {
        page.AddChild(new SectionHeader("称号", $"已激活：{(string.IsNullOrEmpty(sys.ActiveTitleId) ? "无" : sys.ActiveTitleId)}"));

        if (sys.AllTitles.Count == 0)
        {
            var empty = new EmptyState("暂无称号配置", "稍后解锁内容将开放", "?");
            empty.SizeFlagsVertical = SizeFlags.ExpandFill;
            page.AddChild(empty);
            return;
        }

        var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        page.AddChild(scroll);

        var list = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        list.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        scroll.AddChild(list);

        foreach (var t in sys.AllTitles)
        {
            bool canEquip = sys.CanEquipTitle(t.Id);
            bool isActive = sys.ActiveTitleId == t.Id;

            var row = new PanelContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
            var rowStyle = UIStyle.MakePanelBox(canEquip ? UIStyle.Bg3 : UIStyle.Bg1, isActive ? UIStyle.Success : UIStyle.Border, 1, 4);
            rowStyle.ContentMarginLeft = UIStyle.Spacing12;
            rowStyle.ContentMarginRight = UIStyle.Spacing12;
            rowStyle.ContentMarginTop = UIStyle.Spacing8;
            rowStyle.ContentMarginBottom = UIStyle.Spacing8;
            row.AddThemeStyleboxOverride("panel", rowStyle);
            list.AddChild(row);

            var hbox = new HBoxContainer();
            hbox.AddThemeConstantOverride("separation", UIStyle.Spacing12);
            row.AddChild(hbox);

            var info = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
            info.AddThemeConstantOverride("separation", UIStyle.Spacing4);
            hbox.AddChild(info);

            var name = new Label { Text = t.Name };
            name.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            name.AddThemeColorOverride("font_color", canEquip ? UIStyle.TextPrimary : UIStyle.TextMuted);
            info.AddChild(name);

            var desc = new Label
            {
                Text = t.Description,
                AutowrapMode = TextServer.AutowrapMode.Word,
            };
            desc.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            desc.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
            info.AddChild(desc);

            var btn = new IconButton(
                isActive ? "已佩戴" : (canEquip ? "佩戴" : "未解锁"),
                isActive ? IconButton.ButtonVariant.Secondary
                        : canEquip ? IconButton.ButtonVariant.Primary
                                   : IconButton.ButtonVariant.Ghost)
            {
                CustomMinimumSize = new Vector2(96, UIStyle.ButtonHeight),
                Disabled = !canEquip || isActive,
            };
            var titleId = t.Id;
            btn.Pressed += () => sys.EquipTitle(titleId);
            hbox.AddChild(btn);
        }
    }

    private static string GetCategoryName(AchievementCategory category) => category switch
    {
        AchievementCategory.Combat => "战斗",
        AchievementCategory.Collection => "收集",
        AchievementCategory.Exploration => "探索",
        AchievementCategory.Rebirth => "轮回",
        AchievementCategory.Milestone => "里程碑",
        _ => "未知",
    };
}
