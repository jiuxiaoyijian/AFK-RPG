using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.UI.Components;

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

        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "settings",
            Title = "设 置",
            Subtitle = "音量 / 存档 / 调试",
            AccentColor = UIStyle.NavSettings,
            PanelWidth = UIStyle.PanelWidthCompact,
            PanelHeight = 440,
            ShowFooter = true,
        };
        AddChild(chrome);

        var content = new VBoxContainer();
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        content.SizeFlagsVertical = SizeFlags.ExpandFill;
        chrome.Body.AddChild(content);

        content.AddChild(new SectionHeader("音量"));

        _masterSlider = AddVolumeRow(content, "主音量", "Master");
        _bgmSlider = AddVolumeRow(content, "背景音乐", "BGM");
        _sfxSlider = AddVolumeRow(content, "音效", "SFX");

        content.AddChild(new SectionHeader("存档", "F5 / F8 快捷键"));

        var saveLoadRow = new HBoxContainer();
        saveLoadRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        content.AddChild(saveLoadRow);

        var saveBtn = new IconButton("存档 (F5)", IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(140, UIStyle.ButtonHeight),
        };
        saveBtn.Pressed += () => _saveManager.Save(_saveManager.ActiveSlot);
        saveLoadRow.AddChild(saveBtn);

        var loadBtn = new IconButton("读档 (F8)", IconButton.ButtonVariant.Secondary)
        {
            CustomMinimumSize = new Vector2(140, UIStyle.ButtonHeight),
        };
        loadBtn.Pressed += () => _saveManager.Load(_saveManager.ActiveSlot);
        saveLoadRow.AddChild(loadBtn);

        content.AddChild(new SectionHeader("调试"));

        var debugRow = new HBoxContainer();
        debugRow.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        content.AddChild(debugRow);

        var debugLabel = new Label
        {
            Text = "调试模式",
            CustomMinimumSize = new Vector2(150, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        debugLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        debugLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        debugRow.AddChild(debugLabel);

        _debugCheck = new CheckBox { ButtonPressed = _demoManager.IsDebugMode };
        _debugCheck.Toggled += OnDebugToggled;
        debugRow.AddChild(_debugCheck);

        var closeBtn = new IconButton("关闭", IconButton.ButtonVariant.Secondary)
        {
            CustomMinimumSize = new Vector2(110, UIStyle.ButtonHeight),
        };
        closeBtn.Pressed += () =>
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.UiPanelClosed, "settings");
        };
        chrome.Footer.AddChild(closeBtn);
    }

    private static HSlider AddVolumeRow(VBoxContainer parent, string label, string busName)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        parent.AddChild(row);

        var lbl = new Label
        {
            Text = label,
            CustomMinimumSize = new Vector2(100, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        lbl.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        row.AddChild(lbl);

        var slider = new HSlider
        {
            MinValue = 0,
            MaxValue = 100,
            Value = 80,
            CustomMinimumSize = new Vector2(180, 22),
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
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

        var valLabel = new Label
        {
            Text = $"{(int)slider.Value}%",
            CustomMinimumSize = new Vector2(48, 0),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Right,
        };
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
}
