using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// HUD 控制器：F-Pattern 锁点布局，所有卡片使用 anchor + offset，分辨率自适应。
///
/// 锁点 (规范 §4 F-Pattern)：
///   ┌─────────────────────────────────────────────┐
///   │ PlayerHeader(TL)              StageHeader(TR)│
///   │                                              │
///   │              CombatHighlight(C)              │
///   │                                              │
///   │ LootCard(BL)                ObjectiveCard(BR)│
///   └─────────────────────────────────────────────┘
///   底部 52px 留给 MainNavBar，HUD 不进入此区域。
/// </summary>
public partial class HudController : Control
{
    // ── Player Header (TopLeft) ──
    private Label _playerNameLabel = null!;
    private Label _playerLevelLabel = null!;
    private Label _playerStyleLabel = null!;
    private ProgressBar _hpBar = null!;
    private ProgressBar _energyBar = null!;
    private Label _hpLabel = null!;
    private Label _energyLabel = null!;

    // ── Stage Header (TopRight) ──
    private Label _chapterLabel = null!;
    private Label _nodeProgressLabel = null!;
    private Label _killCountLabel = null!;
    private Label _waveLabel = null!;

    // ── Combat Highlight (Center) ──
    private Control _combatHighlight = null!;
    private Label _highlightLabel = null!;

    // ── Objective Card (BottomRight) ──
    private Label _objectiveLabel = null!;

    // ── Loot Card (BottomLeft) ──
    private Control _lootCard = null!;
    private Label _lootSummaryLabel = null!;

    // ── Drop Toast (TopCenter) ──
    private Control _dropToast = null!;
    private Label _dropToastLabel = null!;
    private double _toastTimer;

    private GameManager _gm = null!;
    private int _killCount;

    public override void _Ready()
    {
        _gm = GameManager.Instance;
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildPlayerHeader();
        BuildStageHeader();
        BuildCombatHighlight();
        BuildObjectiveCard();
        BuildLootCard();
        BuildDropToast();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EnemyKilled += OnEnemyKilled;
        bus.WaveCleared += OnWaveCleared;
        bus.NodeCleared += OnNodeCleared;
        bus.LootDropped += OnLootDropped;
        bus.BossKilled += OnBossKilled;
        bus.HeroLevelUp += OnLevelUp;
        bus.ExperienceGained += OnExperienceGained;
        bus.DropToastRequested += OnDropToast;
    }

    public override void _Process(double delta)
    {
        UpdatePlayerHeader();
        UpdateStageHeader();
        UpdateToastTimer(delta);
    }

    // ═══════════════════════════════════════════
    //  Build methods - 全部用 anchor + offset
    // ═══════════════════════════════════════════

    private void BuildPlayerHeader()
    {
        var card = new PanelContainer
        {
            CustomMinimumSize = new Vector2(360, 110),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        card.SetAnchorsPreset(LayoutPreset.TopLeft);
        card.OffsetLeft = UIStyle.Spacing16;
        card.OffsetTop = UIStyle.Spacing16;
        card.OffsetRight = UIStyle.Spacing16 + 360;
        card.OffsetBottom = UIStyle.Spacing16 + 110;
        var style = UIStyle.MakePanelBox(UIStyle.Bg2, UIStyle.BorderHighlight, 1, 6);
        style.ContentMarginLeft = UIStyle.Spacing12;
        style.ContentMarginRight = UIStyle.Spacing12;
        style.ContentMarginTop = UIStyle.Spacing8;
        style.ContentMarginBottom = UIStyle.Spacing8;
        card.AddThemeStyleboxOverride("panel", style);
        AddChild(card);

        var vbox = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        vbox.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        card.AddChild(vbox);

        var topRow = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        topRow.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        vbox.AddChild(topRow);

        _playerNameLabel = MakeLabel("侠客", UIStyle.FontHeader, UIStyle.TextPrimary);
        _playerNameLabel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        topRow.AddChild(_playerNameLabel);

        _playerLevelLabel = MakeLabel("Lv 1", UIStyle.FontHeader, UIStyle.Accent);
        topRow.AddChild(_playerLevelLabel);

        _playerStyleLabel = MakeLabel("无门无派", UIStyle.FontSmall, UIStyle.TextSecondary);
        vbox.AddChild(_playerStyleLabel);

        _hpBar = MakeProgressBar(UIStyle.HpBar);
        vbox.AddChild(MakeBarRow("HP", _hpBar, out _hpLabel));

        _energyBar = MakeProgressBar(UIStyle.EnergyBar);
        vbox.AddChild(MakeBarRow("真气", _energyBar, out _energyLabel));
    }

    private static HBoxContainer MakeBarRow(string label, ProgressBar bar, out Label valueLabel)
    {
        var row = new HBoxContainer { MouseFilter = Control.MouseFilterEnum.Ignore };
        row.AddThemeConstantOverride("separation", UIStyle.Spacing8);

        var lbl = new Label { Text = label, CustomMinimumSize = new Vector2(36, 0) };
        lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        lbl.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        row.AddChild(lbl);

        bar.SizeFlagsHorizontal = Control.SizeFlags.ExpandFill;
        row.AddChild(bar);

        valueLabel = new Label { Text = "0/0", CustomMinimumSize = new Vector2(70, 0) };
        valueLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        valueLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        valueLabel.HorizontalAlignment = HorizontalAlignment.Right;
        row.AddChild(valueLabel);

        return row;
    }

    private void BuildStageHeader()
    {
        var card = new PanelContainer
        {
            CustomMinimumSize = new Vector2(280, 90),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        card.SetAnchorsPreset(LayoutPreset.TopRight);
        card.OffsetLeft = -(UIStyle.Spacing16 + 280);
        card.OffsetTop = UIStyle.Spacing16;
        card.OffsetRight = -UIStyle.Spacing16;
        card.OffsetBottom = UIStyle.Spacing16 + 90;
        var style = UIStyle.MakePanelBox(UIStyle.Bg2, UIStyle.BorderHighlight, 1, 6);
        style.ContentMarginLeft = UIStyle.Spacing12;
        style.ContentMarginRight = UIStyle.Spacing12;
        style.ContentMarginTop = UIStyle.Spacing8;
        style.ContentMarginBottom = UIStyle.Spacing8;
        card.AddThemeStyleboxOverride("panel", style);
        AddChild(card);

        var vbox = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        vbox.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        card.AddChild(vbox);

        _chapterLabel = MakeLabel("第一章", UIStyle.FontHeader, UIStyle.TextPrimary);
        _chapterLabel.HorizontalAlignment = HorizontalAlignment.Right;
        vbox.AddChild(_chapterLabel);

        _nodeProgressLabel = MakeLabel("节点 1/5", UIStyle.FontBody, UIStyle.TextSecondary);
        _nodeProgressLabel.HorizontalAlignment = HorizontalAlignment.Right;
        vbox.AddChild(_nodeProgressLabel);

        var statsRow = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        statsRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        statsRow.Alignment = BoxContainer.AlignmentMode.End;
        vbox.AddChild(statsRow);

        _waveLabel = MakeLabel("波次 1/3", UIStyle.FontSmall, UIStyle.TextMuted);
        statsRow.AddChild(_waveLabel);

        _killCountLabel = MakeLabel("击杀: 0", UIStyle.FontSmall, UIStyle.TextMuted);
        statsRow.AddChild(_killCountLabel);
    }

    private void BuildCombatHighlight()
    {
        _combatHighlight = new PanelContainer
        {
            CustomMinimumSize = new Vector2(420, 56),
            MouseFilter = MouseFilterEnum.Ignore,
            Visible = false,
        };
        _combatHighlight.SetAnchorsPreset(LayoutPreset.CenterTop);
        _combatHighlight.OffsetLeft = -210;
        _combatHighlight.OffsetTop = 140;
        _combatHighlight.OffsetRight = 210;
        _combatHighlight.OffsetBottom = 140 + 56;
        var style = UIStyle.MakePanelBox(UIStyle.Danger.Darkened(0.7f), UIStyle.Danger, 2, 4);
        style.ContentMarginLeft = UIStyle.Spacing16;
        style.ContentMarginRight = UIStyle.Spacing16;
        style.ContentMarginTop = UIStyle.Spacing8;
        style.ContentMarginBottom = UIStyle.Spacing8;
        _combatHighlight.AddThemeStyleboxOverride("panel", style);
        AddChild(_combatHighlight);

        _highlightLabel = MakeLabel("", UIStyle.FontTitle, UIStyle.Danger);
        _highlightLabel.HorizontalAlignment = HorizontalAlignment.Center;
        _combatHighlight.AddChild(_highlightLabel);
    }

    private void BuildObjectiveCard()
    {
        var card = new PanelContainer
        {
            CustomMinimumSize = new Vector2(280, 64),
            MouseFilter = MouseFilterEnum.Ignore,
        };
        card.SetAnchorsPreset(LayoutPreset.BottomRight);
        const int navBar = UIStyle.NavBarHeight + UIStyle.Spacing12;
        card.OffsetLeft = -(UIStyle.Spacing16 + 280);
        card.OffsetTop = -(navBar + 64);
        card.OffsetRight = -UIStyle.Spacing16;
        card.OffsetBottom = -navBar;
        var style = UIStyle.MakePanelBox(UIStyle.Bg2, UIStyle.Accent, 1, 6);
        style.ContentMarginLeft = UIStyle.Spacing12;
        style.ContentMarginRight = UIStyle.Spacing12;
        style.ContentMarginTop = UIStyle.Spacing8;
        style.ContentMarginBottom = UIStyle.Spacing8;
        card.AddThemeStyleboxOverride("panel", style);
        AddChild(card);

        var vbox = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        vbox.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        card.AddChild(vbox);

        var title = MakeLabel("当前目标", UIStyle.FontSmall, UIStyle.TextMuted);
        vbox.AddChild(title);

        _objectiveLabel = MakeLabel("清除当前节点", UIStyle.FontBody, UIStyle.TextPrimary);
        _objectiveLabel.AutowrapMode = TextServer.AutowrapMode.Word;
        vbox.AddChild(_objectiveLabel);
    }

    private void BuildLootCard()
    {
        _lootCard = new PanelContainer
        {
            CustomMinimumSize = new Vector2(280, 64),
            MouseFilter = MouseFilterEnum.Ignore,
            Visible = false,
        };
        _lootCard.SetAnchorsPreset(LayoutPreset.BottomLeft);
        const int navBar = UIStyle.NavBarHeight + UIStyle.Spacing12;
        _lootCard.OffsetLeft = UIStyle.Spacing16;
        _lootCard.OffsetTop = -(navBar + 64);
        _lootCard.OffsetRight = UIStyle.Spacing16 + 280;
        _lootCard.OffsetBottom = -navBar;
        var style = UIStyle.MakePanelBox(UIStyle.Bg2, UIStyle.Accent, 1, 6);
        style.ContentMarginLeft = UIStyle.Spacing12;
        style.ContentMarginRight = UIStyle.Spacing12;
        style.ContentMarginTop = UIStyle.Spacing8;
        style.ContentMarginBottom = UIStyle.Spacing8;
        _lootCard.AddThemeStyleboxOverride("panel", style);
        AddChild(_lootCard);

        var vbox = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        vbox.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        _lootCard.AddChild(vbox);

        var title = MakeLabel("最近掉落", UIStyle.FontSmall, UIStyle.TextMuted);
        vbox.AddChild(title);

        _lootSummaryLabel = MakeLabel("", UIStyle.FontBody, UIStyle.Accent);
        vbox.AddChild(_lootSummaryLabel);
    }

    private void BuildDropToast()
    {
        _dropToast = new PanelContainer
        {
            CustomMinimumSize = new Vector2(420, 36),
            MouseFilter = MouseFilterEnum.Ignore,
            Visible = false,
        };
        _dropToast.SetAnchorsPreset(LayoutPreset.CenterTop);
        _dropToast.OffsetLeft = -210;
        _dropToast.OffsetTop = UIStyle.Spacing16;
        _dropToast.OffsetRight = 210;
        _dropToast.OffsetBottom = UIStyle.Spacing16 + 36;
        var style = UIStyle.MakePanelBox(UIStyle.Legendary.Darkened(0.7f), UIStyle.Legendary, 2, 6);
        style.ContentMarginLeft = UIStyle.Spacing16;
        style.ContentMarginRight = UIStyle.Spacing16;
        style.ContentMarginTop = UIStyle.Spacing4;
        style.ContentMarginBottom = UIStyle.Spacing4;
        _dropToast.AddThemeStyleboxOverride("panel", style);
        AddChild(_dropToast);

        _dropToastLabel = MakeLabel("", UIStyle.FontBody, UIStyle.Legendary);
        _dropToastLabel.HorizontalAlignment = HorizontalAlignment.Center;
        _dropToast.AddChild(_dropToastLabel);
    }

    // ═══════════════════════════════════════════
    //  Update methods
    // ═══════════════════════════════════════════

    private void UpdatePlayerHeader()
    {
        _playerNameLabel.Text = _gm.HeroName;
        _playerStyleLabel.Text = _gm.HeroStyle;
        _playerLevelLabel.Text = $"Lv {_gm.HeroLevel}";

        _hpBar.Value = _gm.MaxHp > 0 ? _gm.CurrentHp / _gm.MaxHp * 100.0 : 0;
        _hpLabel.Text = $"{_gm.CurrentHp:F0}/{_gm.MaxHp:F0}";
        _energyBar.Value = _gm.MaxEnergy > 0 ? _gm.CurrentEnergy / _gm.MaxEnergy * 100.0 : 0;
        _energyLabel.Text = $"{_gm.CurrentEnergy:F0}/{_gm.MaxEnergy:F0}";
    }

    private void UpdateStageHeader()
    {
        _chapterLabel.Text = _gm.CurrentChapterName;
        _nodeProgressLabel.Text = $"节点 {_gm.CurrentNodeIndex + 1}/{_gm.TotalNodes}";
    }

    private void UpdateToastTimer(double delta)
    {
        if (!_dropToast.Visible) return;
        _toastTimer -= delta;
        if (_toastTimer <= 0) _dropToast.Visible = false;
    }

    // ═══════════════════════════════════════════
    //  Signal handlers
    // ═══════════════════════════════════════════

    private void OnEnemyKilled(string enemyId, string nodeType)
    {
        _killCount++;
        _killCountLabel.Text = $"击杀: {_killCount}";
    }

    private void OnWaveCleared(int waveIndex, int totalWaves)
    {
        _waveLabel.Text = $"波次 {waveIndex + 1}/{totalWaves}";
    }

    private void OnNodeCleared(string nodeId)
    {
        _killCount = 0;
        _killCountLabel.Text = "击杀: 0";
    }

    private void OnLootDropped(string itemId, string quality)
    {
        _lootSummaryLabel.Text = $"[{quality}] {itemId}";
        _lootCard.Visible = true;
    }

    private void OnBossKilled(string bossId, bool isFirstKill)
    {
        _highlightLabel.Text = isFirstKill ? $"首杀！{bossId}" : $"击败 {bossId}";
        _combatHighlight.Visible = true;

        var tween = CreateTween();
        tween.TweenInterval(2.5);
        tween.TweenCallback(Callable.From(() => _combatHighlight.Visible = false));
    }

    private void OnLevelUp(int newLevel)
    {
        _playerLevelLabel.Text = $"Lv {newLevel}";
        _highlightLabel.Text = $"突破！Lv {newLevel}";
        _highlightLabel.AddThemeColorOverride("font_color", UIStyle.Accent);
        _combatHighlight.Visible = true;

        var tween = CreateTween();
        tween.TweenInterval(2.0);
        tween.TweenCallback(Callable.From(() =>
        {
            _combatHighlight.Visible = false;
            _highlightLabel.AddThemeColorOverride("font_color", UIStyle.Danger);
        }));
    }

    private void OnExperienceGained(long amount)
    {
        // Lv 标签会在下次 _Process 自动刷新（HeroLevel 改变时也会）
        _playerLevelLabel.Text = $"Lv {_gm.HeroLevel}";
    }

    private void OnDropToast(string itemId, string quality)
    {
        _dropToastLabel.Text = $"获得 [{quality}] {itemId}";
        _dropToast.Visible = true;
        _toastTimer = 2.0;
    }

    // ── Utility ──

    private static Label MakeLabel(string text, int fontSize, Color color)
    {
        var lbl = new Label { Text = text };
        lbl.AddThemeFontSizeOverride("font_size", fontSize);
        lbl.AddThemeColorOverride("font_color", color);
        return lbl;
    }

    private static ProgressBar MakeProgressBar(Color fillColor)
    {
        var bar = new ProgressBar
        {
            CustomMinimumSize = new Vector2(0, 16),
            MaxValue = 100,
            Value = 100,
            ShowPercentage = false,
        };

        var bg = new StyleBoxFlat
        {
            BgColor = UIStyle.Bg0,
            CornerRadiusTopLeft = 3,
            CornerRadiusTopRight = 3,
            CornerRadiusBottomLeft = 3,
            CornerRadiusBottomRight = 3,
        };
        var fill = new StyleBoxFlat
        {
            BgColor = fillColor,
            CornerRadiusTopLeft = 3,
            CornerRadiusTopRight = 3,
            CornerRadiusBottomLeft = 3,
            CornerRadiusBottomRight = 3,
        };

        bar.AddThemeStyleboxOverride("background", bg);
        bar.AddThemeStyleboxOverride("fill", fill);
        return bar;
    }
}
