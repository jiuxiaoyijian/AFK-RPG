using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Manages version info, demo/debug flags, and quick-start markers.
/// </summary>
public partial class DemoManager : Node
{
    public const string GameVersion = "0.3.0-dev";
    public const string GameTitle = "桌面挂机原型";

    public bool IsDebugMode { get; set; }
    public bool QuickStartEnabled { get; set; }
    public bool HasCompletedTutorial { get; set; }

    private const string DemoConfigPath = "user://public_demo_settings.cfg";

    public override void _Ready()
    {
        LoadConfig();
        GD.Print($"[DemoManager] {GameTitle} v{GameVersion} | debug={IsDebugMode}");
    }

    private void LoadConfig()
    {
        var cfg = new ConfigFile();
        if (cfg.Load(DemoConfigPath) != Error.Ok) return;

        IsDebugMode = (bool)cfg.GetValue("demo", "debug_mode", false);
        QuickStartEnabled = (bool)cfg.GetValue("demo", "quick_start", false);
        HasCompletedTutorial = (bool)cfg.GetValue("demo", "tutorial_done", false);
    }

    public void SaveConfig()
    {
        var cfg = new ConfigFile();
        cfg.SetValue("demo", "debug_mode", IsDebugMode);
        cfg.SetValue("demo", "quick_start", QuickStartEnabled);
        cfg.SetValue("demo", "tutorial_done", HasCompletedTutorial);
        cfg.Save(DemoConfigPath);
    }

    public string GetDisplayVersion() => $"v{GameVersion}";
}
