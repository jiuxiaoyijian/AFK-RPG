using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Systems;

/// <summary>
/// Rift (秘境) system: infinite push, timed challenges, keystone consumption, milestones.
/// </summary>
public partial class RiftSystem : Node
{
    public enum RiftState { Idle, InProgress, Completed, Failed }

    public int HighestRiftCleared { get; set; }
    public int CurrentRiftLevel { get; private set; }
    public RiftState State { get; private set; } = RiftState.Idle;
    public double TimeLimitSeconds { get; private set; } = 180.0;
    public double ElapsedSeconds { get; private set; }
    public int KeystoneCount { get; set; } = 3;

    private GameManager _gm = null!;

    public override void _Ready()
    {
        _gm = GameManager.Instance;
        GD.Print($"[RiftSystem] initialized, highest cleared: {HighestRiftCleared}");
    }

    public bool CanStartRift(int level)
    {
        if (State != RiftState.Idle) return false;
        if (KeystoneCount <= 0) return false;
        if (level > HighestRiftCleared + 5) return false;
        return true;
    }

    public bool StartRift(int level)
    {
        if (!CanStartRift(level)) return false;

        KeystoneCount--;
        CurrentRiftLevel = level;
        ElapsedSeconds = 0;
        TimeLimitSeconds = 180.0 + level * 5.0;
        State = RiftState.InProgress;

        GD.Print($"[RiftSystem] started level {level}");
        return true;
    }

    public override void _PhysicsProcess(double delta)
    {
        if (State != RiftState.InProgress) return;

        ElapsedSeconds += delta;
        if (ElapsedSeconds >= TimeLimitSeconds)
        {
            State = RiftState.Failed;
            GD.Print($"[RiftSystem] failed level {CurrentRiftLevel} (timeout)");
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.StageEventTriggered, "rift_failed", CurrentRiftLevel.ToString());
        }
    }

    public void CompleteRift()
    {
        if (State != RiftState.InProgress) return;

        State = RiftState.Completed;
        if (CurrentRiftLevel > HighestRiftCleared)
            HighestRiftCleared = CurrentRiftLevel;

        int bonusKeystones = CurrentRiftLevel % 5 == 0 ? 1 : 0;
        KeystoneCount += bonusKeystones;

        GD.Print($"[RiftSystem] completed level {CurrentRiftLevel} in {ElapsedSeconds:F1}s");

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.StageEventTriggered, "rift_cleared", CurrentRiftLevel.ToString());

        State = RiftState.Idle;
    }

    public void ReturnToIdle()
    {
        State = RiftState.Idle;
        CurrentRiftLevel = 0;
    }

    public double GetScalingMultiplier(int level)
    {
        return System.Math.Pow(1.17, level);
    }
}
