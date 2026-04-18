using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Fires stage milestone popups: Boss first kill, chapter unlock, first legendary drop, etc.
/// </summary>
public partial class StageEventSystem : Node
{
    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.BossKilled += OnBossKilled;
        bus.ChapterCleared += OnChapterCleared;
        bus.LootDropped += OnLootDropped;
        bus.BreakthroughReached += OnBreakthrough;
        GD.Print("[StageEventSystem] initialized");
    }

    private void OnBossKilled(string bossId, bool isFirstKill)
    {
        if (!isFirstKill) return;
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.StageEventTriggered, "boss_first_kill", bossId);
    }

    private void OnChapterCleared(string chapterId)
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.StageEventTriggered, "chapter_cleared", chapterId);
    }

    private void OnLootDropped(string itemId, string quality)
    {
        if (quality is "Legendary" or "Set" or "Ancient" or "Primal")
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.DropToastRequested, itemId, quality);
        }
    }

    private void OnBreakthrough(string breakthroughId)
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.StageEventTriggered, "breakthrough", breakthroughId);
    }
}
