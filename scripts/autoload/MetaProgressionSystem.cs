using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Aggregates cross-system progression data for display in research/codex panels.
/// </summary>
public partial class MetaProgressionSystem : Node
{
    public long TotalGoldEarned { get; set; }
    public long TotalExpEarned { get; set; }
    public int TotalItemsFound { get; set; }
    public int TotalLegendariesFound { get; set; }
    public int HighestRiftCleared { get; set; }
    public double PlaytimeSeconds { get; set; }

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.ExperienceGained += amt => TotalExpEarned += amt;
        bus.LootDropped += OnLootDropped;
        bus.EnemyKilled += (_, _) => GameManager.Instance.TotalKills++;
        GD.Print("[MetaProgressionSystem] initialized");
    }

    public override void _Process(double delta)
    {
        PlaytimeSeconds += delta;
    }

    private void OnLootDropped(string itemId, string quality)
    {
        TotalItemsFound++;
        if (quality is "Legendary" or "Ancient" or "Primal")
            TotalLegendariesFound++;
    }

    public string GetPlaytimeDisplay()
    {
        int hours = (int)(PlaytimeSeconds / 3600);
        int minutes = (int)((PlaytimeSeconds % 3600) / 60);
        return $"{hours}h {minutes}m";
    }
}
