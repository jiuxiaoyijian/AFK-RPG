using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Systems;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// Research panel (成长中心): Paragon allocation, Season rebirth, hero progression.
/// 接通：宗师 +1 → ParagonSystem.AllocatePoint
/// 接通：重入江湖 → SeasonSystem.TriggerRebirth (带 ConfirmDialog)
/// </summary>
public partial class ResearchPanelController : Control
{
    private UiTabBar _tabBar = null!;
    private VBoxContainer _pageHost = null!;

    private VBoxContainer _paragonPage = null!;
    private VBoxContainer _seasonPage = null!;
    private VBoxContainer _progressionPage = null!;

    private Label _paragonHeader = null!;
    private readonly Dictionary<(ParagonSystem.ParagonBoard, string), Label> _allocLabels = new();

    private Label _seasonInfoLabel = null!;
    private IconButton _rebirthBtn = null!;

    private Label _heroLevelLabel = null!;
    private ProgressBar _expBar = null!;
    private Label _expLabel = null!;

    private ParagonSystem _paragon = null!;
    private SeasonSystem _season = null!;

    public override void _Ready()
    {
        _paragon = GetNode<ParagonSystem>("/root/GameRoot/Systems/ParagonSystem");
        _season = GetNode<SeasonSystem>("/root/GameRoot/Systems/SeasonSystem");

        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.ParagonPointGained += _ => Refresh();
        bus.HeroLevelUp += _ => Refresh();
        bus.SeasonReset += _ => Refresh();
        bus.ExperienceGained += _ => RefreshProgression();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "research",
            Title = "成 长 中 心",
            Subtitle = "宗师 / 重入 / 弟子成长",
            AccentColor = UIStyle.NavResearch,
            PanelWidth = UIStyle.PanelWidthStandard,
            PanelHeight = 540,
        };
        AddChild(chrome);

        var content = new VBoxContainer();
        content.SizeFlagsVertical = SizeFlags.ExpandFill;
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        chrome.Body.AddChild(content);

        _tabBar = new UiTabBar();
        content.AddChild(_tabBar);

        _pageHost = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddChild(_pageHost);

        BuildParagonPage();
        BuildSeasonPage();
        BuildProgressionPage();

        _tabBar.AddTab("宗师修为", "paragon");
        _tabBar.AddTab("重入江湖", "season");
        _tabBar.AddTab("弟子成长", "progression");
        _tabBar.TabSelected += OnTabSelected;
    }

    private void OnTabSelected(string tabId)
    {
        _paragonPage.Visible = tabId == "paragon";
        _seasonPage.Visible = tabId == "season";
        _progressionPage.Visible = tabId == "progression";
        Refresh();
    }

    private void BuildParagonPage()
    {
        _paragonPage = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _paragonPage.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        _pageHost.AddChild(_paragonPage);

        _paragonHeader = new Label();
        _paragonHeader.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        _paragonHeader.AddThemeColorOverride("font_color", UIStyle.Accent);
        _paragonPage.AddChild(_paragonHeader);

        var boards = new (ParagonSystem.ParagonBoard, string, (string Stat, string Display)[])[]
        {
            (ParagonSystem.ParagonBoard.Offensive, "攻击面板", new[] { ("primary_stat", "主属性"), ("crit_rate", "暴击率"), ("crit_damage", "暴击伤害"), ("attack_speed_percent", "攻速") }),
            (ParagonSystem.ParagonBoard.Defensive, "防御面板", new[] { ("max_hp_percent", "最大生命"), ("defense", "防御"), ("dodge_rate", "闪避"), ("hp_regen", "回复") }),
            (ParagonSystem.ParagonBoard.Utility, "辅助面板", new[] { ("move_speed", "移速"), ("resource_find", "资源发现"), ("xp_bonus", "经验加成"), ("gold_find", "金币发现") }),
            (ParagonSystem.ParagonBoard.Special, "特殊面板", new[] { ("skill_damage_percent", "技能伤害"), ("cooldown_reduction", "冷却缩减"), ("area_damage", "范围伤害"), ("elite_damage", "精英伤害") }),
        };

        var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _paragonPage.AddChild(scroll);

        var list = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        list.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        scroll.AddChild(list);

        foreach (var (board, name, stats) in boards)
        {
            list.AddChild(new SectionHeader(name));
            foreach (var (stat, display) in stats)
            {
                var row = new HBoxContainer();
                row.AddThemeConstantOverride("separation", UIStyle.Spacing12);
                list.AddChild(row);

                var nameLbl = new Label
                {
                    Text = display,
                    CustomMinimumSize = new Vector2(150, 0),
                    VerticalAlignment = VerticalAlignment.Center,
                };
                nameLbl.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
                nameLbl.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
                row.AddChild(nameLbl);

                var allocLbl = new Label
                {
                    Text = "+0",
                    CustomMinimumSize = new Vector2(60, 0),
                    VerticalAlignment = VerticalAlignment.Center,
                };
                allocLbl.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
                allocLbl.AddThemeColorOverride("font_color", UIStyle.Success);
                row.AddChild(allocLbl);
                _allocLabels[(board, stat)] = allocLbl;

                var spacer = new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill };
                row.AddChild(spacer);

                var btn = new IconButton("+1", IconButton.ButtonVariant.Primary)
                {
                    CustomMinimumSize = new Vector2(60, UIStyle.ButtonHeight),
                };
                var capturedBoard = board;
                var capturedStat = stat;
                btn.Pressed += () => OnAllocate(capturedBoard, capturedStat);
                row.AddChild(btn);
            }
        }
    }

    private void BuildSeasonPage()
    {
        _seasonPage = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _seasonPage.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        _seasonPage.Visible = false;
        _pageHost.AddChild(_seasonPage);

        _seasonPage.AddChild(new SectionHeader("赛季信息"));

        _seasonInfoLabel = new Label
        {
            AutowrapMode = TextServer.AutowrapMode.Word,
        };
        _seasonInfoLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _seasonInfoLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        _seasonPage.AddChild(_seasonInfoLabel);

        var spacer = new Control { SizeFlagsVertical = SizeFlags.ExpandFill };
        _seasonPage.AddChild(spacer);

        _rebirthBtn = new IconButton("重入江湖", IconButton.ButtonVariant.Danger)
        {
            CustomMinimumSize = new Vector2(200, 44),
        };
        _rebirthBtn.Pressed += OnRebirthRequested;
        var btnRow = new HBoxContainer();
        btnRow.Alignment = BoxContainer.AlignmentMode.Center;
        btnRow.AddChild(_rebirthBtn);
        _seasonPage.AddChild(btnRow);
    }

    private void BuildProgressionPage()
    {
        _progressionPage = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _progressionPage.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        _progressionPage.Visible = false;
        _pageHost.AddChild(_progressionPage);

        _progressionPage.AddChild(new SectionHeader("弟子成长"));

        _heroLevelLabel = new Label();
        _heroLevelLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        _heroLevelLabel.AddThemeColorOverride("font_color", UIStyle.Accent);
        _progressionPage.AddChild(_heroLevelLabel);

        _expBar = new ProgressBar
        {
            CustomMinimumSize = new Vector2(0, 24),
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            ShowPercentage = false,
            MinValue = 0,
            MaxValue = 100,
        };
        _expBar.AddThemeStyleboxOverride("background", UIStyle.MakePanelBox(UIStyle.BgDark, UIStyle.Border));
        _expBar.AddThemeStyleboxOverride("fill", UIStyle.MakePanelBox(UIStyle.Accent, UIStyle.Accent));
        _progressionPage.AddChild(_expBar);

        _expLabel = new Label
        {
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _expLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _expLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        _progressionPage.AddChild(_expLabel);

        var milestones = new List<int> { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 };
        _progressionPage.AddChild(new SectionHeader("突破里程碑"));
        var grid = new GridContainer { Columns = 5 };
        grid.AddThemeConstantOverride("h_separation", UIStyle.Spacing8);
        grid.AddThemeConstantOverride("v_separation", UIStyle.Spacing8);
        _progressionPage.AddChild(grid);

        foreach (var lvl in milestones)
        {
            var lbl = new Label
            {
                Text = $"Lv.{lvl}",
                HorizontalAlignment = HorizontalAlignment.Center,
                CustomMinimumSize = new Vector2(64, 28),
            };
            lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            grid.AddChild(lbl);
            lbl.SetMeta("level", lvl);
        }
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        _paragonHeader.Text = $"宗师等级 {_paragon.ParagonLevel} · 未分配点数: {_paragon.UnspentPoints}";
        foreach (var (key, lbl) in _allocLabels)
            lbl.Text = $"+{_paragon.GetStatAllocation(key.Item1, key.Item2)}";

        _seasonInfoLabel.Text =
            $"当前赛季：第 {_season.CurrentSeason} 季\n" +
            $"重入次数：{_season.TotalRebirths}\n" +
            $"永久 DPS 加成：+{_season.PermanentDpsBonus * 100:F1}%\n" +
            $"永久金币加成：+{_season.PermanentGoldBonus * 100:F1}%\n" +
            $"永久经验加成：+{_season.PermanentXpBonus * 100:F1}%\n\n" +
            (_season.CanRebirth ? "✓ 当前可以重入江湖" : $"✗ 需要弟子达到 70 级（当前 {GameManager.Instance.HeroLevel} 级）");
        _rebirthBtn.Disabled = !_season.CanRebirth;

        RefreshProgression();
    }

    private void RefreshProgression()
    {
        if (_heroLevelLabel == null) return;
        var gm = GameManager.Instance;
        long needed = HeroProgressionSystem.GetExpRequired(gm.HeroLevel + 1);
        double pct = needed > 0 ? (double)gm.HeroExp / needed * 100.0 : 100.0;

        _heroLevelLabel.Text = $"弟子等级 Lv.{gm.HeroLevel}";
        _expBar.Value = pct;
        _expLabel.Text = $"经验 {gm.HeroExp} / {needed}  ({pct:F1}%)";
    }

    private void OnAllocate(ParagonSystem.ParagonBoard board, string stat)
    {
        bool ok = _paragon.AllocatePoint(board, stat);
        if (!ok)
        {
            ConfirmDialog.Show(this, "无法分配", "未分配点数不足或参数无效。", () => { }, confirmText: "好的", cancelText: "");
            return;
        }
        Refresh();
    }

    private void OnRebirthRequested()
    {
        if (!_season.CanRebirth) return;
        ConfirmDialog.Show(
            this,
            "重入江湖",
            $"重入江湖将重置弟子等级、装备、章节进度，但保留永久加成。\n当前重入 {_season.TotalRebirths} 次，下次将进入第 {_season.CurrentSeason + 1} 季。\n确定继续？",
            () =>
            {
                _season.TriggerRebirth();
                Refresh();
            },
            confirmText: "确认重入",
            danger: true);
    }
}
