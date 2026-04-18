using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Global signal hub. All cross-system communication goes through here.
/// Registered as an Autoload singleton in project.godot.
/// </summary>
public partial class EventBus : Node
{
    // ── Combat ──
    [Signal] public delegate void EnemyKilledEventHandler(string enemyId, string nodeType);
    [Signal] public delegate void WaveClearedEventHandler(int waveIndex, int totalWaves);
    [Signal] public delegate void NodeClearedEventHandler(string nodeId);
    [Signal] public delegate void ChapterClearedEventHandler(string chapterId);
    [Signal] public delegate void BossKilledEventHandler(string bossId, bool isFirstKill);
    [Signal] public delegate void PlayerDiedEventHandler();

    // ── Loot & Equipment ──
    [Signal] public delegate void LootDroppedEventHandler(string itemId, string quality);
    [Signal] public delegate void LootPickedUpEventHandler(string itemId);
    [Signal] public delegate void EquipmentChangedEventHandler(string slot);
    [Signal] public delegate void InventoryFullEventHandler();
    [Signal] public delegate void ItemSalvagedEventHandler(string itemId, int scrapGained);

    // ── Progression ──
    [Signal] public delegate void HeroLevelUpEventHandler(int newLevel);
    [Signal] public delegate void BreakthroughReachedEventHandler(string breakthroughId);
    [Signal] public delegate void ExperienceGainedEventHandler(long amount);
    [Signal] public delegate void ParagonPointGainedEventHandler(int points);

    // ── UI ──
    [Signal] public delegate void UiPanelRequestedEventHandler(string panelId);
    [Signal] public delegate void UiPanelClosedEventHandler(string panelId);
    [Signal] public delegate void UiCloseAllRequestedEventHandler();
    [Signal] public delegate void DropToastRequestedEventHandler(string itemId, string quality);
    [Signal] public delegate void RedDotChangedEventHandler(string panelId, bool visible);

    // ── Save / Load ──
    [Signal] public delegate void SaveRequestedEventHandler(int slot);
    [Signal] public delegate void LoadRequestedEventHandler(int slot);
    [Signal] public delegate void SaveCompletedEventHandler(int slot, bool success);

    // ── Stage Events ──
    [Signal] public delegate void StageEventTriggeredEventHandler(string eventType, string payload);
    [Signal] public delegate void OfflineReportReadyEventHandler(double secondsAway, string rewardJson);

    // ── Daily ──
    [Signal] public delegate void DailyGoalCompletedEventHandler(string goalId);
    [Signal] public delegate void DailyResetEventHandler();

    // ── Season / Rebirth ──
    [Signal] public delegate void SeasonResetEventHandler(int seasonNumber);
    [Signal] public delegate void RebirthTriggeredEventHandler();

    // ── Guide ──
    [Signal] public delegate void GuideStepTriggeredEventHandler(string stepId);
    [Signal] public delegate void GuideCompletedEventHandler();

    // ── Achievement ──
    [Signal] public delegate void AchievementUnlockedEventHandler(string achievementId);
    [Signal] public delegate void TitleChangedEventHandler(string titleId);

    public override void _Ready()
    {
        GD.Print("[EventBus] initialized");
    }
}
