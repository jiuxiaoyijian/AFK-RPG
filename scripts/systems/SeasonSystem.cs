using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Systems;

/// <summary>
/// Season (重入江湖) system: seasonal reset with permanent bonuses carried over.
/// </summary>
public partial class SeasonSystem : Node
{
    public int CurrentSeason { get; set; } = 1;
    public int TotalRebirths { get; set; }

    public double PermanentDpsBonus => TotalRebirths * 0.05;
    public double PermanentGoldBonus => TotalRebirths * 0.03;
    public double PermanentXpBonus => TotalRebirths * 0.02;

    public bool CanRebirth => GameManager.Instance.HeroLevel >= 70;

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.RebirthTriggered += OnRebirthTriggered;
        GD.Print($"[SeasonSystem] season {CurrentSeason}, rebirths: {TotalRebirths}");
    }

    public bool TriggerRebirth()
    {
        if (!CanRebirth) return false;

        TotalRebirths++;
        CurrentSeason++;

        var gm = GameManager.Instance;
        gm.HeroLevel = 1;
        gm.HeroExp = 0;
        gm.CurrentHp = 100;
        gm.MaxHp = 100;
        gm.CurrentEnergy = 100;
        gm.MaxEnergy = 100;
        gm.CurrentChapterId = "chapter_1";
        gm.CurrentNodeId = "ch1_n1";
        gm.ClearedNodes.Clear();
        gm.ClearedChapters.Clear();
        gm.Inventory.Clear();
        gm.Gold = 100;

        gm.RecalculateDps();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.SeasonReset, CurrentSeason);

        GD.Print($"[SeasonSystem] rebirth #{TotalRebirths}, season {CurrentSeason}");
        return true;
    }

    private void OnRebirthTriggered() => TriggerRebirth();
}
