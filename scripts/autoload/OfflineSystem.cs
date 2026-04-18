using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Autoload;

/// <summary>
/// Calculates offline rewards when the player returns after being away.
/// Simulates combat progression and generates a reward report.
/// </summary>
public partial class OfflineSystem : Node
{
    private const double MaxOfflineHours = 12.0;
    private const double GoldPerSecond = 2.0;
    private const double ExpPerSecond = 5.0;
    private const double KillsPerSecond = 0.5;

    private long _lastOnlineTimestamp;

    public override void _Ready()
    {
        _lastOnlineTimestamp = (long)Time.GetUnixTimeFromSystem();
        GD.Print("[OfflineSystem] initialized");
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusIn)
            CheckOfflineReward();
        else if (what == NotificationApplicationFocusOut)
            _lastOnlineTimestamp = (long)Time.GetUnixTimeFromSystem();
    }

    public void CheckOfflineReward()
    {
        long now = (long)Time.GetUnixTimeFromSystem();
        double secondsAway = now - _lastOnlineTimestamp;
        _lastOnlineTimestamp = now;

        if (secondsAway < 60) return;

        double cappedSeconds = System.Math.Min(secondsAway, MaxOfflineHours * 3600);

        var gm = GameManager.Instance;
        double dpsMulti = gm.Dps / 100.0;

        long goldGained = (long)(cappedSeconds * GoldPerSecond * (1.0 + dpsMulti * 0.1));
        long expGained = (long)(cappedSeconds * ExpPerSecond * (1.0 + dpsMulti * 0.05));
        int killsSimulated = (int)(cappedSeconds * KillsPerSecond);

        gm.AddGold(goldGained);
        gm.GainExperience(expGained);
        gm.TotalKills += killsSimulated;

        string rewardJson = $"{{\"gold\":{goldGained},\"exp\":{expGained},\"kills\":{killsSimulated}}}";

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.OfflineReportReady, secondsAway, rewardJson);

        GD.Print($"[OfflineSystem] offline {secondsAway:F0}s → gold:{goldGained} exp:{expGained} kills:{killsSimulated}");
    }
}
