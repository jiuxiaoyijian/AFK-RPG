using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Controls the 7-region HUD overlay:
///   PlayerHeader, StageHeader, CombatHighlight,
///   ObjectiveCard, LootCard, BattleSafeFrame, DropToast.
/// Subscribes to EventBus signals to update displayed data.
/// </summary>
public partial class HudController : Control
{
    // ── Child node references (set in _Ready) ──
    private Control _playerHeader = null!;
    private Label _playerNameLabel = null!;
    private Label _playerStyleLabel = null!;
    private ProgressBar _hpBar = null!;
    private ProgressBar _energyBar = null!;
    private Label _hpLabel = null!;
    private Label _energyLabel = null!;

    private Control _stageHeader = null!;
    private Label _chapterLabel = null!;
    private Label _nodeProgressLabel = null!;
    private Label _killCountLabel = null!;
    private Label _waveLabel = null!;

    private Control _combatHighlight = null!;
    private Label _highlightLabel = null!;

    private Control _objectiveCard = null!;
    private Label _objectiveLabel = null!;

    private Control _lootCard = null!;
    private Label _lootSummaryLabel = null!;

    private Control _battleSafeFrame = null!;
    private ProgressBar _bossHpBar = null!;

    private Control _dropToast = null!;
    private Label _dropToastLabel = null!;
    private double _toastTimer;

    private GameManager _gm = null!;

    public override void _Ready()
    {
        _gm = GameManager.Instance;
        SetAnchorsPreset(LayoutPreset.FullRect);

        BuildPlayerHeader();
        BuildStageHeader();
        BuildCombatHighlight();
        BuildObjectiveCard();
        BuildLootCard();
        BuildBattleSafeFrame();
        BuildDropToast();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EnemyKilled += OnEnemyKilled;
        bus.WaveCleared += OnWaveCleared;
        bus.NodeCleared += OnNodeCleared;
        bus.LootDropped += OnLootDropped;
        bus.BossKilled += OnBossKilled;
        bus.HeroLevelUp += OnLevelUp;
        bus.DropToastRequested += OnDropToast;
    }

    public override void _Process(double delta)
    {
        UpdatePlayerHeader();
        UpdateStageHeader();
        UpdateToastTimer(delta);
    }

    // ═══════════════════════════════════════════
    //  Build methods (procedural UI construction)
    // ═══════════════════════════════════════════

    private void BuildPlayerHeader()
    {
        _playerHeader = new Panel();
        _playerHeader.Position = new Vector2(UIStyle.PadOuter, UIStyle.PadOuter);
        _playerHeader.Size = new Vector2(436, 122);
        _playerHeader.AddThemeStyleboxOverride("panel", UIStyle.MakeHeaderBox());
        AddChild(_playerHeader);

        _playerNameLabel = MakeLabel("侠客", UIStyle.FontHeader, UIStyle.TextPrimary);
        _playerNameLabel.Position = new Vector2(12, 8);
        _playerHeader.AddChild(_playerNameLabel);

        _playerStyleLabel = MakeLabel("无门无派", UIStyle.FontSmall, UIStyle.TextSecondary);
        _playerStyleLabel.Position = new Vector2(12, 32);
        _playerHeader.AddChild(_playerStyleLabel);

        _hpBar = MakeProgressBar(160, 18, UIStyle.HpBar);
        _hpBar.Position = new Vector2(12, 56);
        _playerHeader.AddChild(_hpBar);
        _hpLabel = MakeLabel("HP", UIStyle.FontSmall, UIStyle.TextPrimary);
        _hpLabel.Position = new Vector2(180, 56);
        _playerHeader.AddChild(_hpLabel);

        _energyBar = MakeProgressBar(160, 18, UIStyle.EnergyBar);
        _energyBar.Position = new Vector2(12, 80);
        _playerHeader.AddChild(_energyBar);
        _energyLabel = MakeLabel("真气", UIStyle.FontSmall, UIStyle.TextPrimary);
        _energyLabel.Position = new Vector2(180, 80);
        _playerHeader.AddChild(_energyLabel);

        var levelLabel = MakeLabel("Lv", UIStyle.FontBody, UIStyle.Accent);
        levelLabel.Position = new Vector2(350, 8);
        _playerHeader.AddChild(levelLabel);
    }

    private void BuildStageHeader()
    {
        _stageHeader = new Panel();
        _stageHeader.Position = new Vector2(1280 - 338, UIStyle.PadOuter);
        _stageHeader.Size = new Vector2(320, 90);
        _stageHeader.AddThemeStyleboxOverride("panel", UIStyle.MakeHeaderBox());
        AddChild(_stageHeader);

        _chapterLabel = MakeLabel("第一章", UIStyle.FontHeader, UIStyle.TextPrimary);
        _chapterLabel.Position = new Vector2(12, 8);
        _stageHeader.AddChild(_chapterLabel);

        _nodeProgressLabel = MakeLabel("节点 1/5", UIStyle.FontBody, UIStyle.TextSecondary);
        _nodeProgressLabel.Position = new Vector2(12, 32);
        _stageHeader.AddChild(_nodeProgressLabel);

        _killCountLabel = MakeLabel("击杀: 0", UIStyle.FontSmall, UIStyle.TextMuted);
        _killCountLabel.Position = new Vector2(12, 54);
        _stageHeader.AddChild(_killCountLabel);

        _waveLabel = MakeLabel("波次 1/3", UIStyle.FontSmall, UIStyle.TextMuted);
        _waveLabel.Position = new Vector2(160, 54);
        _stageHeader.AddChild(_waveLabel);
    }

    private void BuildCombatHighlight()
    {
        _combatHighlight = new Panel();
        _combatHighlight.Position = new Vector2(440, 86);
        _combatHighlight.Size = new Vector2(400, 40);
        _combatHighlight.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.Danger.Darkened(0.7f), UIStyle.Danger, 2, 2));
        _combatHighlight.Visible = false;
        AddChild(_combatHighlight);

        _highlightLabel = MakeLabel("", UIStyle.FontHeader, UIStyle.Danger);
        _highlightLabel.Position = new Vector2(12, 8);
        _combatHighlight.AddChild(_highlightLabel);
    }

    private void BuildObjectiveCard()
    {
        _objectiveCard = new Panel();
        _objectiveCard.Position = new Vector2(1280 - 338, 148);
        _objectiveCard.Size = new Vector2(320, 122);
        _objectiveCard.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox());
        AddChild(_objectiveCard);

        _objectiveLabel = MakeLabel("目标: 清除当前节点", UIStyle.FontBody, UIStyle.TextPrimary);
        _objectiveLabel.Position = new Vector2(12, 12);
        _objectiveCard.AddChild(_objectiveLabel);
    }

    private void BuildLootCard()
    {
        _lootCard = new Panel();
        _lootCard.Position = new Vector2(UIStyle.PadOuter, 244);
        _lootCard.Size = new Vector2(304, 114);
        _lootCard.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox());
        _lootCard.Visible = false;
        AddChild(_lootCard);

        _lootSummaryLabel = MakeLabel("", UIStyle.FontBody, UIStyle.Accent);
        _lootSummaryLabel.Position = new Vector2(12, 12);
        _lootCard.AddChild(_lootSummaryLabel);
    }

    private void BuildBattleSafeFrame()
    {
        _battleSafeFrame = new Panel();
        _battleSafeFrame.Position = new Vector2(340, 720 - 186);
        _battleSafeFrame.Size = new Vector2(600, 168);
        _battleSafeFrame.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(
            new Color(0.08f, 0.08f, 0.10f, 0.7f), UIStyle.Border, 1, 6));
        AddChild(_battleSafeFrame);

        _bossHpBar = MakeProgressBar(560, 14, UIStyle.Danger);
        _bossHpBar.Position = new Vector2(20, 12);
        _bossHpBar.Visible = false;
        _battleSafeFrame.AddChild(_bossHpBar);

        var skillSlots = new HBoxContainer();
        skillSlots.Position = new Vector2(180, 110);
        _battleSafeFrame.AddChild(skillSlots);

        for (int i = 0; i < 4; i++)
        {
            var slot = new Panel();
            slot.CustomMinimumSize = new Vector2(48, 48);
            slot.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgDark, UIStyle.Border, 1, 4));
            skillSlots.AddChild(slot);

            var lbl = MakeLabel($"{i + 1}", UIStyle.FontTiny, UIStyle.TextMuted);
            lbl.Position = new Vector2(2, 2);
            slot.AddChild(lbl);
        }
    }

    private void BuildDropToast()
    {
        _dropToast = new Panel();
        _dropToast.Position = new Vector2(440, 12);
        _dropToast.Size = new Vector2(400, 36);
        _dropToast.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.Legendary.Darkened(0.7f), UIStyle.Legendary, 2, 4));
        _dropToast.Visible = false;
        AddChild(_dropToast);

        _dropToastLabel = MakeLabel("", UIStyle.FontBody, UIStyle.Legendary);
        _dropToastLabel.Position = new Vector2(12, 8);
        _dropToast.AddChild(_dropToastLabel);
    }

    // ═══════════════════════════════════════════
    //  Update methods
    // ═══════════════════════════════════════════

    private void UpdatePlayerHeader()
    {
        _playerNameLabel.Text = _gm.HeroName;
        _playerStyleLabel.Text = _gm.HeroStyle;
        _hpBar.Value = _gm.MaxHp > 0 ? (_gm.CurrentHp / _gm.MaxHp * 100.0) : 0;
        _hpLabel.Text = $"{_gm.CurrentHp:F0}/{_gm.MaxHp:F0}";
        _energyBar.Value = _gm.MaxEnergy > 0 ? (_gm.CurrentEnergy / _gm.MaxEnergy * 100.0) : 0;
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
        if (_toastTimer <= 0)
            _dropToast.Visible = false;
    }

    // ═══════════════════════════════════════════
    //  Signal handlers
    // ═══════════════════════════════════════════

    private int _killCount;

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
    }

    private void OnLootDropped(string itemId, string quality)
    {
        _lootSummaryLabel.Text = $"[{quality}] {itemId}";
        _lootCard.Visible = true;
    }

    private void OnBossKilled(string bossId, bool isFirstKill)
    {
        _highlightLabel.Text = isFirstKill ? $"首杀! {bossId}" : $"击败 {bossId}";
        _combatHighlight.Visible = true;

        var tween = CreateTween();
        tween.TweenInterval(2.5);
        tween.TweenCallback(Callable.From(() => _combatHighlight.Visible = false));
    }

    private void OnLevelUp(int newLevel) { }

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

    private static ProgressBar MakeProgressBar(int width, int height, Color fillColor)
    {
        var bar = new ProgressBar();
        bar.CustomMinimumSize = new Vector2(width, height);
        bar.Size = new Vector2(width, height);
        bar.MaxValue = 100;
        bar.Value = 100;
        bar.ShowPercentage = false;

        var bg = new StyleBoxFlat { BgColor = UIStyle.BgDark, CornerRadiusTopLeft = 2, CornerRadiusTopRight = 2, CornerRadiusBottomLeft = 2, CornerRadiusBottomRight = 2 };
        var fill = new StyleBoxFlat { BgColor = fillColor, CornerRadiusTopLeft = 2, CornerRadiusTopRight = 2, CornerRadiusBottomLeft = 2, CornerRadiusBottomRight = 2 };

        bar.AddThemeStyleboxOverride("background", bg);
        bar.AddThemeStyleboxOverride("fill", fill);
        return bar;
    }
}
