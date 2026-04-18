using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Settings panel: 3 volume sliders (Master/BGM/SFX), save/load buttons, debug toggle.
/// Opened from nav bar "settings" or launch menu.
/// </summary>
public partial class SettingsPanelController : Control
{
    private SaveManager _saveManager = null!;
    private DemoManager _demoManager = null!;

    private HSlider _masterSlider = null!;
    private HSlider _bgmSlider = null!;
    private HSlider _sfxSlider = null!;
    private CheckBox _debugCheck = null!;

    public override void _Ready()
    {
        _saveManager = GetNode<SaveManager>("/root/SaveManager");
        _demoManager = GetNode<DemoManager>("/root/DemoManager");

        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(440, 400);
        Position = new Vector2(420, 160);

        BuildUI();
    }

    private void BuildUI()
    {
        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var vbox = new VBoxContainer();
        vbox.SetAnchorsPreset(LayoutPreset.FullRect);
        vbox.Position = new Vector2(20, 20);
        vbox.Size = new Vector2(400, 360);
        vbox.AddThemeConstantOverride("separation", 10);
        AddChild(vbox);

        var title = new Label { Text = "设 置" };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.Accent);
        title.HorizontalAlignment = HorizontalAlignment.Center;
        vbox.AddChild(title);

        vbox.AddChild(new HSeparator());

        _masterSlider = AddVolumeRow(vbox, "主音量", "Master");
        _bgmSlider = AddVolumeRow(vbox, "背景音乐", "BGM");
        _sfxSlider = AddVolumeRow(vbox, "音效", "SFX");

        vbox.AddChild(new HSeparator());

        var saveLoadRow = new HBoxContainer();
        saveLoadRow.Alignment = BoxContainer.AlignmentMode.Center;
        saveLoadRow.AddThemeConstantOverride("separation", 12);
        vbox.AddChild(saveLoadRow);

        var saveBtn = MakeButton("存档 (F5)", UIStyle.Success);
        saveBtn.Pressed += () => _saveManager.Save(_saveManager.ActiveSlot);
        saveLoadRow.AddChild(saveBtn);

        var loadBtn = MakeButton("读档 (F8)", UIStyle.NavInventory);
        loadBtn.Pressed += () => _saveManager.Load(_saveManager.ActiveSlot);
        saveLoadRow.AddChild(loadBtn);

        vbox.AddChild(new HSeparator());

        var debugRow = new HBoxContainer();
        debugRow.AddThemeConstantOverride("separation", 8);
        vbox.AddChild(debugRow);

        var debugLabel = new Label { Text = "调试模式" };
        debugLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        debugLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        debugRow.AddChild(debugLabel);

        _debugCheck = new CheckBox { ButtonPressed = _demoManager.IsDebugMode };
        _debugCheck.Toggled += OnDebugToggled;
        debugRow.AddChild(_debugCheck);

        var closeBtn = MakeButton("关闭", UIStyle.NavSettings);
        closeBtn.Pressed += () =>
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.UiPanelClosed, "settings");
        };
        vbox.AddChild(closeBtn);
    }

    private HSlider AddVolumeRow(VBoxContainer parent, string label, string busName)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 8);
        parent.AddChild(row);

        var lbl = new Label { Text = label, CustomMinimumSize = new Vector2(100, 0) };
        lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        lbl.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        row.AddChild(lbl);

        var slider = new HSlider
        {
            MinValue = 0,
            MaxValue = 100,
            Value = 80,
            CustomMinimumSize = new Vector2(200, 20),
            Step = 1,
        };

        int busIdx = AudioServer.GetBusIndex(busName);
        if (busIdx >= 0)
        {
            float db = AudioServer.GetBusVolumeDb(busIdx);
            slider.Value = Mathf.DbToLinear(db) * 100;
        }

        slider.ValueChanged += val =>
        {
            int idx = AudioServer.GetBusIndex(busName);
            if (idx >= 0)
                AudioServer.SetBusVolumeDb(idx, Mathf.LinearToDb((float)(val / 100.0)));
        };
        row.AddChild(slider);

        var valLabel = new Label { Text = "80%" };
        valLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        valLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        row.AddChild(valLabel);

        slider.ValueChanged += val => valLabel.Text = $"{(int)val}%";

        return slider;
    }

    private void OnDebugToggled(bool pressed)
    {
        _demoManager.IsDebugMode = pressed;
        _demoManager.SaveConfig();
    }

    private static Button MakeButton(string text, Color accent)
    {
        var btn = new Button
        {
            Text = text,
            CustomMinimumSize = new Vector2(120, 36),
            FocusMode = FocusModeEnum.None,
        };
        btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(accent));
        btn.AddThemeStyleboxOverride("hover", UIStyle.MakeButtonBox(accent.Lightened(0.15f)));
        btn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        btn.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        return btn;
    }
}
