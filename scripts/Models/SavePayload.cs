using System.Collections.Generic;

namespace DesktopIdle.Models;

/// <summary>
/// Top-level save file structure, serialized to user://desktop_idle_save_{slot}.json
/// </summary>
public class SavePayload
{
    public int SaveVersion { get; set; } = 4;
    public long SaveTimestamp { get; set; }

    // ── Hero ──
    public string HeroName { get; set; } = "";
    public int HeroLevel { get; set; } = 1;
    public long HeroExp { get; set; }
    public string SchoolId { get; set; } = "";

    // ── Progress ──
    public string CurrentChapterId { get; set; } = "chapter_1";
    public string CurrentNodeId { get; set; } = "ch1_n1";
    public HashSet<string> ClearedNodes { get; set; } = new();
    public HashSet<string> ClearedChapters { get; set; } = new();
    public long TotalKills { get; set; }

    // ── Inventory ──
    public List<ItemData> Inventory { get; set; } = new();
    public Dictionary<string, ItemData?> EquippedItems { get; set; } = new();

    // ── Currency ──
    public long Gold { get; set; }
    public long Scrap { get; set; }
    public long ZhenyiShards { get; set; }

    // ── Skills ──
    public string[] EquippedSkillIds { get; set; } = new string[4];
    public Dictionary<string, int> SkillLevels { get; set; } = new();

    // ── Systems ──
    public Dictionary<string, object>? ParagonData { get; set; }
    public Dictionary<string, object>? CodexData { get; set; }
    public Dictionary<string, object>? CubeData { get; set; }
    public Dictionary<string, object>? GemData { get; set; }
    public Dictionary<string, object>? RiftData { get; set; }
    public Dictionary<string, object>? SeasonData { get; set; }
    public Dictionary<string, object>? DailyData { get; set; }
    public Dictionary<string, object>? GuideData { get; set; }
    public Dictionary<string, object>? AchievementData { get; set; }

    // ── Offline ──
    public long LastOnlineTimestamp { get; set; }
}
