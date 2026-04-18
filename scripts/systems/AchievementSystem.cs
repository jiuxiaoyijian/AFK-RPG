using System.Collections.Generic;
using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Systems;

/// <summary>
/// Achievement system: condition checking, unlock notifications, persistence.
/// Checks conditions on relevant signals and unlocks achievements.
/// </summary>
public partial class AchievementSystem : Node
{
    private readonly List<AchievementDef> _achievements = new();
    private readonly List<TitleDef> _titles = new();
    private readonly HashSet<string> _unlocked = new();

    public string? ActiveTitleId { get; set; }
    public IReadOnlyList<AchievementDef> AllAchievements => _achievements;
    public IReadOnlyList<TitleDef> AllTitles => _titles;
    public IReadOnlySet<string> UnlockedIds => _unlocked;

    public override void _Ready()
    {
        LoadAchievements();
        LoadTitles();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EnemyKilled += (_, _) => CheckAll();
        bus.LootDropped += (_, _) => CheckAll();
        bus.NodeCleared += _ => CheckAll();
        bus.ChapterCleared += _ => CheckAll();
        bus.HeroLevelUp += _ => CheckAll();
        bus.SeasonReset += _ => CheckAll();
        bus.AchievementUnlocked += OnAchievementUnlocked;
        bus.TitleChanged += OnTitleChanged;

        GD.Print($"[AchievementSystem] loaded {_achievements.Count} achievements, {_titles.Count} titles");
    }

    private void LoadAchievements()
    {
        var db = GetNode<ConfigDB>("/root/ConfigDB");
        var doc = db.LoadRawJson("res://data/achievements/achievements.json");
        if (doc == null) return;

        foreach (var el in doc.RootElement.EnumerateArray())
        {
            System.Enum.TryParse<AchievementCategory>(
                el.GetProperty("category").GetString() ?? "combat", true, out var cat);

            _achievements.Add(new AchievementDef
            {
                Id = el.GetProperty("id").GetString() ?? "",
                Name = el.GetProperty("name").GetString() ?? "",
                Description = el.TryGetProperty("description", out var d) ? d.GetString() ?? "" : "",
                Category = cat,
                ConditionType = el.GetProperty("condition_type").GetString() ?? "",
                ConditionTarget = el.GetProperty("condition_target").GetInt64(),
                RewardType = el.TryGetProperty("reward_type", out var rt) ? rt.GetString() ?? "" : "",
                RewardValue = el.TryGetProperty("reward_value", out var rv) ? rv.GetString() ?? "" : "",
                Hidden = el.TryGetProperty("hidden", out var h) && h.GetBoolean(),
            });
        }
    }

    private void LoadTitles()
    {
        var db = GetNode<ConfigDB>("/root/ConfigDB");
        var doc = db.LoadRawJson("res://data/achievements/titles.json");
        if (doc == null) return;

        foreach (var el in doc.RootElement.EnumerateArray())
        {
            _titles.Add(new TitleDef
            {
                Id = el.GetProperty("id").GetString() ?? "",
                Name = el.GetProperty("name").GetString() ?? "",
                Description = el.TryGetProperty("description", out var d) ? d.GetString() ?? "" : "",
                RequiredAchievementId = el.TryGetProperty("required_achievement_id", out var ra) ? ra.GetString() ?? "" : "",
            });
        }
    }

    public void CheckAll()
    {
        var gm = GameManager.Instance;
        foreach (var ach in _achievements)
        {
            if (_unlocked.Contains(ach.Id)) continue;

            bool met = ach.ConditionType switch
            {
                "total_kills" => gm.TotalKills >= ach.ConditionTarget,
                "hero_level" => gm.HeroLevel >= ach.ConditionTarget,
                "total_gold" => gm.Gold >= ach.ConditionTarget,
                _ => false,
            };

            if (met) Unlock(ach);
        }
    }

    private void Unlock(AchievementDef ach)
    {
        _unlocked.Add(ach.Id);
        GD.Print($"[Achievement] unlocked: {ach.Name}");

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.AchievementUnlocked, ach.Id);

        if (ach.RewardType == "gold" && long.TryParse(ach.RewardValue, out var gold))
            GameManager.Instance.AddGold(gold);
    }

    public bool IsUnlocked(string achievementId) => _unlocked.Contains(achievementId);

    public bool CanEquipTitle(string titleId)
    {
        var title = _titles.Find(t => t.Id == titleId);
        return title != null && _unlocked.Contains(title.RequiredAchievementId);
    }

    public bool EquipTitle(string titleId)
    {
        if (!CanEquipTitle(titleId)) return false;
        ActiveTitleId = titleId;
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.TitleChanged, titleId);
        return true;
    }

    private void OnAchievementUnlocked(string achievementId) { }
    private void OnTitleChanged(string titleId) { }

    public double GetCategoryProgress(AchievementCategory category)
    {
        int total = 0, done = 0;
        foreach (var ach in _achievements)
        {
            if (ach.Category != category) continue;
            total++;
            if (_unlocked.Contains(ach.Id)) done++;
        }
        return total > 0 ? (double)done / total * 100.0 : 0;
    }
}
