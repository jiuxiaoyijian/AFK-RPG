using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Systems;

/// <summary>
/// Hero Progression (弟子成长): experience, level gates, stat unlocks, breakthrough events.
/// </summary>
public partial class HeroProgressionSystem : Node
{
    private static readonly int[] BreakthroughLevels = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 };

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.HeroLevelUp += OnHeroLevelUp;
        bus.ExperienceGained += OnExperienceGained;
        GD.Print("[HeroProgressionSystem] initialized");
    }

    private void OnHeroLevelUp(int newLevel)
    {
        var gm = GameManager.Instance;
        gm.MaxHp += 15;
        gm.MaxEnergy += 5;
        gm.CurrentHp = gm.MaxHp;
        gm.CurrentEnergy = gm.MaxEnergy;

        if (System.Array.Exists(BreakthroughLevels, l => l == newLevel))
        {
            string breakthroughId = $"breakthrough_{newLevel}";
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.BreakthroughReached, breakthroughId);
            GD.Print($"[HeroProgression] breakthrough at level {newLevel}!");
        }

        if (newLevel >= 70)
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.ParagonPointGained, 1);
        }
    }

    private void OnExperienceGained(long amount)
    {
        // Additional experience processing (e.g. season bonus)
    }

    public static long GetExpRequired(int level) => (long)(100 * System.Math.Pow(1.15, level - 1));

    public static double GetProgressPercent(int level, long currentExp)
    {
        long needed = GetExpRequired(level + 1);
        return needed > 0 ? (double)currentExp / needed * 100.0 : 100.0;
    }
}
