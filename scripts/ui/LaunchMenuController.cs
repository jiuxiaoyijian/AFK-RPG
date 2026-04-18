using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Main menu shown at game start.
/// Displays game title, version, 3 save slots, and New/Continue/Delete/Settings buttons.
/// </summary>
public partial class LaunchMenuController : Control
{
    private SaveManager _saveManager = null!;
    private DemoManager _demoManager = null!;
    private UIOverlayManager? _overlayManager;

    private VBoxContainer _slotContainer = null!;
    private Label _versionLabel = null!;

    private int _selectedSlot = SaveManager.DefaultSaveSlot;

    public override void _Ready()
    {
        _saveManager = GetNode<SaveManager>("/root/SaveManager");
        _demoManager = GetNode<DemoManager>("/root/DemoManager");
        _overlayManager = GetNodeOrNull<UIOverlayManager>("../UIOverlayManager");

        SetAnchorsPreset(LayoutPreset.FullRect);
        BuildUI();
        RefreshSlots();
    }

    private void BuildUI()
    {
        var bg = new ColorRect();
        bg.Color = UIStyle.BgDark;
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(bg);

        var center = new VBoxContainer();
        center.SetAnchorsPreset(LayoutPreset.Center);
        center.Position = new Vector2(440, 120);
        center.Size = new Vector2(400, 480);
        center.AddThemeConstantOverride("separation", 12);
        AddChild(center);

        var title = new Label { Text = DemoManager.GameTitle };
        title.AddThemeFontSizeOverride("font_size", 32);
        title.AddThemeColorOverride("font_color", UIStyle.Accent);
        title.HorizontalAlignment = HorizontalAlignment.Center;
        center.AddChild(title);

        var subtitle = new Label { Text = "横版挂机 · 武侠RPG" };
        subtitle.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        subtitle.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        subtitle.HorizontalAlignment = HorizontalAlignment.Center;
        center.AddChild(subtitle);

        center.AddChild(new HSeparator());

        var slotsLabel = new Label { Text = "── 存档槽位 ──" };
        slotsLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        slotsLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        slotsLabel.HorizontalAlignment = HorizontalAlignment.Center;
        center.AddChild(slotsLabel);

        _slotContainer = new VBoxContainer();
        _slotContainer.AddThemeConstantOverride("separation", 8);
        center.AddChild(_slotContainer);

        center.AddChild(new HSeparator());

        var btnRow = new HBoxContainer();
        btnRow.Alignment = BoxContainer.AlignmentMode.Center;
        btnRow.AddThemeConstantOverride("separation", 12);
        center.AddChild(btnRow);

        var newBtn = MakeMenuButton("新开始", UIStyle.Success);
        newBtn.Pressed += OnNewGame;
        btnRow.AddChild(newBtn);

        var continueBtn = MakeMenuButton("继续", UIStyle.Accent);
        continueBtn.Pressed += OnContinue;
        btnRow.AddChild(continueBtn);

        var deleteBtn = MakeMenuButton("删除", UIStyle.Danger);
        deleteBtn.Pressed += OnDeleteSlot;
        btnRow.AddChild(deleteBtn);

        var settingsBtn = MakeMenuButton("设置", UIStyle.NavSettings);
        settingsBtn.Pressed += OnSettings;
        center.AddChild(settingsBtn);

        _versionLabel = new Label { Text = _demoManager.GetDisplayVersion() };
        _versionLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
        _versionLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        _versionLabel.HorizontalAlignment = HorizontalAlignment.Right;
        _versionLabel.SetAnchorsPreset(LayoutPreset.BottomRight);
        _versionLabel.Position = new Vector2(1200, 696);
        AddChild(_versionLabel);
    }

    private void RefreshSlots()
    {
        foreach (var child in _slotContainer.GetChildren())
            child.QueueFree();

        for (int i = 1; i <= SaveManager.SaveSlotCount; i++)
        {
            var slotIdx = i;
            var payload = _saveManager.PeekSlot(i);
            var btn = new Button();
            btn.CustomMinimumSize = new Vector2(360, 48);
            btn.FocusMode = FocusModeEnum.None;

            if (payload != null)
            {
                var ts = Time.GetDatetimeStringFromUnixTime(payload.SaveTimestamp);
                btn.Text = $"[{i}] Lv.{payload.HeroLevel} {payload.HeroName} | {ts}";
                btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavInventory));
            }
            else
            {
                btn.Text = $"[{i}] — 空 —";
                btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.TextMuted));
            }
            btn.AddThemeStyleboxOverride("hover", UIStyle.MakeButtonBox(UIStyle.Accent.Darkened(0.2f)));
            btn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            btn.AddThemeColorOverride("font_color", UIStyle.TextPrimary);

            btn.Pressed += () => SelectSlot(slotIdx);
            _slotContainer.AddChild(btn);
        }
    }

    private void SelectSlot(int slot)
    {
        _selectedSlot = slot;
        GD.Print($"[LaunchMenu] selected slot {slot}");
    }

    private void OnNewGame()
    {
        _saveManager.DeleteSlot(_selectedSlot);
        _saveManager.ActiveSlot = _selectedSlot;
        StartGame();
    }

    private void OnContinue()
    {
        if (!_saveManager.SlotExists(_selectedSlot))
        {
            GD.Print("[LaunchMenu] no save in selected slot, starting new");
            StartGame();
            return;
        }
        _saveManager.Load(_selectedSlot);
        StartGame();
    }

    private void OnDeleteSlot()
    {
        _saveManager.DeleteSlot(_selectedSlot);
        RefreshSlots();
    }

    private void OnSettings()
    {
        _overlayManager?.RequestPanel("settings");
    }

    private void StartGame()
    {
        GetTree().Paused = false;
        Visible = false;
        GD.Print("[LaunchMenu] game started");
    }

    private static Button MakeMenuButton(string text, Color accent)
    {
        var btn = new Button
        {
            Text = text,
            CustomMinimumSize = new Vector2(110, 40),
            FocusMode = FocusModeEnum.None,
        };
        btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(accent));
        btn.AddThemeStyleboxOverride("hover", UIStyle.MakeButtonBox(accent.Lightened(0.15f)));
        btn.AddThemeStyleboxOverride("pressed", UIStyle.MakeButtonBox(accent.Darkened(0.15f)));
        btn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        btn.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        return btn;
    }
}
