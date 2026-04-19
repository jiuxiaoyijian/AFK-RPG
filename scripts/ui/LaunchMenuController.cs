using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// 启动菜单：标题 / 槽位列表 / 操作按钮 / 设置 / 版本号。
/// 重构要点：槽位选中视觉反馈、按钮 enabled/disabled 状态机、ConfirmDialog 删除。
/// 见 文档/02_交互与原型/UI控件与视觉规范.md
/// </summary>
public partial class LaunchMenuController : Control
{
    private SaveManager _saveManager = null!;
    private DemoManager _demoManager = null!;
    private UIOverlayManager? _overlayManager;

    private VBoxContainer _slotContainer = null!;
    private Label _versionLabel = null!;
    private Label _hintLabel = null!;

    private IconButton _newBtn = null!;
    private IconButton _continueBtn = null!;
    private IconButton _deleteBtn = null!;
    private IconButton _settingsBtn = null!;

    private readonly System.Collections.Generic.Dictionary<int, SlotCard> _slotCards = new();
    private int _selectedSlot = SaveManager.DefaultSaveSlot;

    public override void _Ready()
    {
        _saveManager = GetNode<SaveManager>("/root/SaveManager");
        _demoManager = GetNode<DemoManager>("/root/DemoManager");
        _overlayManager = GetNodeOrNull<UIOverlayManager>("../UIOverlayManager");

        SetAnchorsPreset(LayoutPreset.FullRect);
        BuildUI();
        RefreshSlots();
        UpdateButtonStates();
    }

    private void BuildUI()
    {
        var bg = new ColorRect
        {
            Color = UIStyle.Bg0,
            MouseFilter = MouseFilterEnum.Stop,
        };
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(bg);

        var card = new PanelContainer
        {
            CustomMinimumSize = new Vector2(480, 0),
        };
        card.SetAnchorsPreset(LayoutPreset.Center);
        card.GrowHorizontal = GrowDirection.Both;
        card.GrowVertical = GrowDirection.Both;
        card.OffsetLeft = -240;
        card.OffsetRight = 240;
        var cardStyle = UIStyle.MakePanelBox(UIStyle.Bg2, UIStyle.BorderHighlight, 1, 8);
        cardStyle.ContentMarginLeft = UIStyle.Spacing24;
        cardStyle.ContentMarginRight = UIStyle.Spacing24;
        cardStyle.ContentMarginTop = UIStyle.Spacing24;
        cardStyle.ContentMarginBottom = UIStyle.Spacing24;
        card.AddThemeStyleboxOverride("panel", cardStyle);
        AddChild(card);

        var center = new VBoxContainer();
        center.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        card.AddChild(center);

        var title = new Label
        {
            Text = DemoManager.GameTitle,
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        title.AddThemeFontSizeOverride("font_size", 32);
        title.AddThemeColorOverride("font_color", UIStyle.Accent);
        center.AddChild(title);

        var subtitle = new Label
        {
            Text = "横版挂机 · 武侠 RPG",
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        subtitle.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        subtitle.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        center.AddChild(subtitle);

        var divider = new ColorRect
        {
            Color = UIStyle.Border,
            CustomMinimumSize = new Vector2(0, 1),
        };
        center.AddChild(divider);

        center.AddChild(new SectionHeader("存档槽位", "点击选中"));

        _slotContainer = new VBoxContainer();
        _slotContainer.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        center.AddChild(_slotContainer);

        _hintLabel = new Label
        {
            Text = "",
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _hintLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _hintLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        center.AddChild(_hintLabel);

        var divider2 = new ColorRect
        {
            Color = UIStyle.Border,
            CustomMinimumSize = new Vector2(0, 1),
        };
        center.AddChild(divider2);

        var btnRow = new HBoxContainer();
        btnRow.Alignment = BoxContainer.AlignmentMode.Center;
        btnRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        center.AddChild(btnRow);

        _newBtn = new IconButton("新开始", IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(120, 40),
        };
        _newBtn.Pressed += OnNewGame;
        btnRow.AddChild(_newBtn);

        _continueBtn = new IconButton("继续", IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(120, 40),
        };
        _continueBtn.Pressed += OnContinue;
        btnRow.AddChild(_continueBtn);

        _deleteBtn = new IconButton("删除", IconButton.ButtonVariant.Danger)
        {
            CustomMinimumSize = new Vector2(120, 40),
        };
        _deleteBtn.Pressed += OnDeleteSlot;
        btnRow.AddChild(_deleteBtn);

        _settingsBtn = new IconButton("设  置", IconButton.ButtonVariant.Secondary)
        {
            CustomMinimumSize = new Vector2(0, 36),
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        _settingsBtn.Pressed += OnSettings;
        center.AddChild(_settingsBtn);

        _versionLabel = new Label
        {
            Text = _demoManager.GetDisplayVersion(),
            HorizontalAlignment = HorizontalAlignment.Right,
        };
        _versionLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
        _versionLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        _versionLabel.SetAnchorsPreset(LayoutPreset.BottomRight);
        _versionLabel.GrowHorizontal = GrowDirection.Begin;
        _versionLabel.GrowVertical = GrowDirection.Begin;
        _versionLabel.OffsetLeft = -240;
        _versionLabel.OffsetTop = -28;
        AddChild(_versionLabel);
    }

    private void RefreshSlots()
    {
        foreach (var child in _slotContainer.GetChildren()) child.QueueFree();
        _slotCards.Clear();

        for (int i = 1; i <= SaveManager.SaveSlotCount; i++)
        {
            var slotIdx = i;
            var payload = _saveManager.PeekSlot(i);
            var card = new SlotCard(i, payload, slotIdx == _selectedSlot);
            card.SlotPressed += SelectSlot;
            _slotContainer.AddChild(card);
            _slotCards[i] = card;
        }
    }

    private void SelectSlot(int slot)
    {
        _selectedSlot = slot;
        foreach (var (idx, card) in _slotCards)
            card.SetSelected(idx == slot);
        UpdateButtonStates();
    }

    private void UpdateButtonStates()
    {
        bool hasSlot = _saveManager.SlotExists(_selectedSlot);
        _continueBtn.Disabled = !hasSlot;
        _deleteBtn.Disabled = !hasSlot;
        _newBtn.Disabled = false;

        _hintLabel.Text = hasSlot
            ? $"已选中槽位 {_selectedSlot}：可继续 / 新开始（覆盖）/ 删除"
            : $"已选中槽位 {_selectedSlot}：空槽，可新开始";
    }

    private void OnNewGame()
    {
        if (_saveManager.SlotExists(_selectedSlot))
        {
            ConfirmDialog.Show(this,
                "覆盖存档",
                $"槽位 {_selectedSlot} 已有存档，新开始将覆盖原有进度，确认？",
                () => DoNewGame(),
                danger: true);
            return;
        }
        DoNewGame();
    }

    private void DoNewGame()
    {
        _saveManager.DeleteSlot(_selectedSlot);
        _saveManager.ActiveSlot = _selectedSlot;
        StartGame();
    }

    private void OnContinue()
    {
        if (!_saveManager.SlotExists(_selectedSlot))
        {
            GD.Print("[LaunchMenu] no save in selected slot");
            return;
        }
        _saveManager.Load(_selectedSlot);
        StartGame();
    }

    private void OnDeleteSlot()
    {
        if (!_saveManager.SlotExists(_selectedSlot)) return;
        ConfirmDialog.Show(this,
            "删除存档",
            $"确认删除槽位 {_selectedSlot} 的存档？此操作不可撤回。",
            () =>
            {
                _saveManager.DeleteSlot(_selectedSlot);
                RefreshSlots();
                UpdateButtonStates();
            },
            danger: true);
    }

    private void OnSettings()
    {
        _overlayManager?.RequestPanel("settings");
    }

    private void StartGame()
    {
        GetTree().Paused = false;
        Visible = false;
        GD.Print($"[LaunchMenu] game started, slot {_selectedSlot}");
    }

    /// <summary>
    /// 单个存档槽位卡片：标题 + 概要 + 选中边框反馈。
    /// </summary>
    private partial class SlotCard : PanelContainer
    {
        [Signal] public delegate void SlotPressedEventHandler(int slot);

        private readonly int _slot;
        private readonly SavePayload? _payload;
        private bool _selected;
        private Button _hitArea = null!;

        public SlotCard(int slot, SavePayload? payload, bool selected)
        {
            _slot = slot;
            _payload = payload;
            _selected = selected;
        }

        public override void _Ready()
        {
            CustomMinimumSize = new Vector2(0, 56);
            Build();
            ApplyStyle();
        }

        private void Build()
        {
            var hbox = new HBoxContainer();
            hbox.AddThemeConstantOverride("separation", UIStyle.Spacing12);
            AddChild(hbox);

            var idxLabel = new Label
            {
                Text = $"#{_slot}",
                CustomMinimumSize = new Vector2(40, 0),
                VerticalAlignment = VerticalAlignment.Center,
            };
            idxLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
            idxLabel.AddThemeColorOverride("font_color", _selected ? UIStyle.Accent : UIStyle.TextSecondary);
            hbox.AddChild(idxLabel);

            var info = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
            info.AddThemeConstantOverride("separation", UIStyle.Spacing4);
            hbox.AddChild(info);

            if (_payload != null)
            {
                var nameLine = new Label
                {
                    Text = $"Lv.{_payload.HeroLevel}  {_payload.HeroName}",
                };
                nameLine.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
                nameLine.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
                info.AddChild(nameLine);

                var ts = Time.GetDatetimeStringFromUnixTime(_payload.SaveTimestamp);
                var tsLine = new Label { Text = $"上次保存：{ts}" };
                tsLine.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
                tsLine.AddThemeColorOverride("font_color", UIStyle.TextMuted);
                info.AddChild(tsLine);
            }
            else
            {
                var emptyLine = new Label { Text = "—— 空 ——" };
                emptyLine.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
                emptyLine.AddThemeColorOverride("font_color", UIStyle.TextMuted);
                info.AddChild(emptyLine);

                var hint = new Label { Text = "点击选中后开始新存档" };
                hint.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
                hint.AddThemeColorOverride("font_color", UIStyle.TextMuted);
                info.AddChild(hint);
            }

            _hitArea = new Button
            {
                Flat = true,
                FocusMode = FocusModeEnum.None,
                MouseFilter = MouseFilterEnum.Stop,
            };
            _hitArea.SetAnchorsPreset(LayoutPreset.FullRect);
            _hitArea.Pressed += () => EmitSignal(SignalName.SlotPressed, _slot);
            AddChild(_hitArea);
        }

        public void SetSelected(bool selected)
        {
            _selected = selected;
            ApplyStyle();
        }

        private void ApplyStyle()
        {
            var border = _selected ? UIStyle.Accent : UIStyle.Border;
            var bg = _selected ? UIStyle.Bg3 : UIStyle.Bg1;
            var style = UIStyle.MakePanelBox(bg, border, _selected ? 2 : 1, 6);
            style.ContentMarginLeft = UIStyle.Spacing12;
            style.ContentMarginRight = UIStyle.Spacing12;
            style.ContentMarginTop = UIStyle.Spacing8;
            style.ContentMarginBottom = UIStyle.Spacing8;
            AddThemeStyleboxOverride("panel", style);
        }
    }
}
