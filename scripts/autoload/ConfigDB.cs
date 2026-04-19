using System.Collections.Generic;
using System.Text.Json;
using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Loads and caches all JSON data files from res://data/.
/// Provides typed accessors for each data domain.
/// </summary>
public partial class ConfigDB : Node
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
    };

    // ── Cached raw dictionaries (lazy loaded) ──
    private Dictionary<string, Models.ChapterDef>? _chapters;
    private Dictionary<string, Models.NodeDef>? _nodes;
    private List<Models.SkillDef>? _skills;
    private JsonDocument? _equipmentBases;
    private JsonDocument? _affixes;
    private JsonDocument? _legendaryAffixes;
    private JsonDocument? _dropTables;
    private JsonDocument? _enemyDefs;
    private JsonDocument? _setDefs;
    private JsonDocument? _gems;
    private JsonDocument? _cubeRecipes;
    private JsonDocument? _heroLevels;
    private JsonDocument? _researchTree;
    private JsonDocument? _riftScaling;
    private JsonDocument? _riftKeys;

    public IReadOnlyDictionary<string, Models.ChapterDef> Chapters => _chapters ??= LoadChapters();
    public IReadOnlyDictionary<string, Models.NodeDef> Nodes => _nodes ??= LoadNodes();
    public IReadOnlyList<Models.SkillDef> Skills => _skills ??= LoadSkills();

    public override void _Ready()
    {
        GD.Print("[ConfigDB] initialized — loading data files...");
        _ = Chapters;
        _ = Nodes;
        _ = Skills;
        GD.Print($"[ConfigDB] loaded {Chapters.Count} chapters, {Nodes.Count} nodes, {Skills.Count} skills");
    }

    private static string ReadJsonFile(string resPath)
    {
        using var file = FileAccess.Open(resPath, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PrintErr($"[ConfigDB] failed to open {resPath}: {FileAccess.GetOpenError()}");
            return "{}";
        }
        return file.GetAsText();
    }

    private Dictionary<string, Models.ChapterDef> LoadChapters()
    {
        var text = ReadJsonFile("res://data/chapters/chapter_defs.json");
        using var doc = JsonDocument.Parse(text);
        var result = new Dictionary<string, Models.ChapterDef>();

        if (doc.RootElement.TryGetProperty("chapters", out var arr))
        {
            foreach (var elem in arr.EnumerateArray())
            {
                var id = elem.GetProperty("id").GetString()!;
                var ch = new Models.ChapterDef
                {
                    Id = id,
                    Order = elem.GetProperty("order").GetInt32(),
                    Name = elem.GetProperty("name").GetString()!,
                    RecommendedPower = elem.GetProperty("recommended_power").GetInt32(),
                    NodeIds = DeserializeStringArray(elem.GetProperty("node_ids")),
                    BackgroundId = elem.GetProperty("background_id").GetString()!,
                    NextChapterId = elem.GetProperty("next_chapter_id").GetString() ?? "",
                };
                result[id] = ch;
            }
        }
        return result;
    }

    private Dictionary<string, Models.NodeDef> LoadNodes()
    {
        var text = ReadJsonFile("res://data/chapters/chapter_defs.json");
        using var doc = JsonDocument.Parse(text);
        var result = new Dictionary<string, Models.NodeDef>();

        if (doc.RootElement.TryGetProperty("chapter_nodes", out var arr))
        {
            foreach (var elem in arr.EnumerateArray())
            {
                var id = elem.GetProperty("id").GetString()!;
                var nd = new Models.NodeDef
                {
                    Id = id,
                    ChapterId = elem.GetProperty("chapter_id").GetString()!,
                    Name = elem.GetProperty("name").GetString()!,
                    NodeType = elem.GetProperty("node_type").GetString()!,
                    EnemyPoolId = elem.GetProperty("enemy_pool_id").GetString()!,
                    WaveCount = elem.GetProperty("wave_count").GetInt32(),
                    TimeLimit = elem.GetProperty("time_limit").GetInt32(),
                    NextNodeId = elem.GetProperty("next_node_id").GetString() ?? "",
                };
                result[id] = nd;
            }
        }
        return result;
    }

    private List<Models.SkillDef> LoadSkills()
    {
        var result = new List<Models.SkillDef>();
        string[] files = { "core_skills.json", "active_skills.json", "passive_skills.json" };

        foreach (var fileName in files)
        {
            var text = ReadJsonFile($"res://data/skills/{fileName}");
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.ValueKind != System.Text.Json.JsonValueKind.Array)
                continue;

            foreach (var elem in doc.RootElement.EnumerateArray())
            {
                string skillType = elem.TryGetProperty("skill_type", out var st) ? st.GetString() ?? ""
                    : elem.TryGetProperty("slot_type", out var slt) ? slt.GetString() ?? ""
                    : elem.TryGetProperty("effect_type", out var et) ? et.GetString() ?? ""
                    : "unknown";

                double cooldown = elem.TryGetProperty("cooldown", out var cd) ? cd.GetDouble() : 0;
                int energyCost = elem.TryGetProperty("energy_cost", out var ec) ? ec.GetInt32()
                    : elem.TryGetProperty("resource_cost", out var rc) ? rc.GetInt32() : 0;
                double baseMultiplier = elem.TryGetProperty("base_multiplier", out var bm) ? bm.GetDouble() : 1.0;
                string iconId = elem.TryGetProperty("icon_id", out var ic) ? ic.GetString() ?? ""
                    : elem.TryGetProperty("icon_path", out var ip) ? ip.GetString() ?? "" : "";

                var skill = new Models.SkillDef
                {
                    Id = elem.GetProperty("id").GetString()!,
                    Name = elem.GetProperty("name").GetString()!,
                    SkillType = skillType,
                    Description = elem.TryGetProperty("description", out var desc) ? desc.GetString() ?? "" : "",
                    UnlockLevel = elem.TryGetProperty("unlock_level", out var ul) ? ul.GetInt32() : 1,
                    MaxLevel = elem.TryGetProperty("max_level", out var ml) ? ml.GetInt32() : 20,
                    Cooldown = cooldown,
                    EnergyCost = energyCost,
                    BaseMultiplier = baseMultiplier,
                    IconId = iconId,
                };
                result.Add(skill);
            }
        }
        return result;
    }

    private static string[] DeserializeStringArray(JsonElement element)
    {
        var list = new List<string>();
        foreach (var item in element.EnumerateArray())
            list.Add(item.GetString()!);
        return list.ToArray();
    }

    /// <summary>
    /// Generic JSON file loader for systems that need raw JSON access.
    /// </summary>
    public JsonDocument? LoadRawJson(string resPath)
    {
        var text = ReadJsonFile(resPath);
        try
        {
            return JsonDocument.Parse(text);
        }
        catch (JsonException ex)
        {
            GD.PrintErr($"[ConfigDB] JSON parse error in {resPath}: {ex.Message}");
            return null;
        }
    }
}
