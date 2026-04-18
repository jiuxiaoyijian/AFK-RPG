using System;
using System.Collections.Generic;
using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Systems;

/// <summary>
/// Generates equipment items with random affixes based on quality, item level, and base definitions.
/// </summary>
public partial class EquipmentGeneratorSystem : Node
{
    private static readonly string[] SlotKeys = { "weapon", "helmet", "armor", "gloves", "boots", "belt", "legs", "accessory" };

    private record EquipBase(string Id, string Slot, string Name, int ItemLevel, Dictionary<string, double> BaseStats);
    private record AffixDef(string Id, string Bucket, string StatKey, double MinValue, double MaxValue);

    private List<EquipBase>? _bases;
    private List<AffixDef>? _affixes;
    private List<AffixDef>? _legendaryAffixes;
    private int _uidCounter;

    public override void _Ready()
    {
        LoadData();
        GD.Print($"[EquipmentGenerator] loaded {_bases?.Count ?? 0} bases, {_affixes?.Count ?? 0} affixes");
    }

    private void LoadData()
    {
        var configDb = GetNode<ConfigDB>("/root/ConfigDB");

        _bases = new();
        using var basesDoc = configDb.LoadRawJson("res://data/equipment/equipment_bases.json");
        if (basesDoc != null)
        {
            foreach (var elem in basesDoc.RootElement.EnumerateArray())
            {
                var stats = new Dictionary<string, double>();
                if (elem.TryGetProperty("base_stats", out var statsArr))
                {
                    foreach (var s in statsArr.EnumerateArray())
                        stats[s.GetProperty("stat_key").GetString()!] = s.GetProperty("value").GetDouble();
                }
                _bases.Add(new EquipBase(
                    elem.GetProperty("id").GetString()!,
                    elem.GetProperty("slot").GetString()!,
                    elem.GetProperty("name").GetString()!,
                    elem.TryGetProperty("item_level", out var il) ? il.GetInt32() : 1,
                    stats));
            }
        }

        _affixes = LoadAffixFile(configDb, "res://data/equipment/affixes.json");
        _legendaryAffixes = LoadAffixFile(configDb, "res://data/equipment/legendary_affixes.json");
    }

    private static List<AffixDef> LoadAffixFile(ConfigDB configDb, string path)
    {
        var result = new List<AffixDef>();
        using var doc = configDb.LoadRawJson(path);
        if (doc == null) return result;

        foreach (var elem in doc.RootElement.EnumerateArray())
        {
            string bucket = elem.TryGetProperty("bucket", out var b) ? b.GetString()! : "generic";
            string statKey = elem.TryGetProperty("stat_key", out var sk) ? sk.GetString()! : "";
            double minVal = elem.TryGetProperty("min_value", out var mn) ? mn.GetDouble() : 0;
            double maxVal = elem.TryGetProperty("max_value", out var mx) ? mx.GetDouble() : 0;
            result.Add(new AffixDef(elem.GetProperty("id").GetString()!, bucket, statKey, minVal, maxVal));
        }
        return result;
    }

    public ItemData? Generate(int itemLevel, ItemQuality quality)
    {
        if (_bases == null || _bases.Count == 0) return null;

        var baseDef = _bases[(int)(GD.Randi() % _bases.Count)];

        var item = new ItemData
        {
            Uid = $"item_{++_uidCounter}_{Time.GetTicksMsec()}",
            BaseId = baseDef.Id,
            Name = baseDef.Name,
            Slot = EquipmentSlotExtensions.FromJsonKey(baseDef.Slot),
            Quality = quality,
            ItemLevel = itemLevel,
            BaseStats = new Dictionary<string, double>(baseDef.BaseStats),
            AcquiredTimestamp = (long)Time.GetUnixTimeFromSystem(),
        };

        ScaleBaseStats(item, itemLevel);
        RollAffixes(item, quality);

        if (quality >= ItemQuality.Legendary && _legendaryAffixes is { Count: > 0 })
        {
            var leg = _legendaryAffixes[(int)(GD.Randi() % _legendaryAffixes.Count)];
            item.LegendaryAffixId = leg.Id;
        }

        return item;
    }

    private static void ScaleBaseStats(ItemData item, int itemLevel)
    {
        double scale = 1.0 + (itemLevel - 1) * 0.12;
        var keys = new List<string>(item.BaseStats.Keys);
        foreach (var key in keys)
            item.BaseStats[key] *= scale;
    }

    private void RollAffixes(ItemData item, ItemQuality quality)
    {
        if (_affixes == null || _affixes.Count == 0) return;

        int affixCount = quality switch
        {
            ItemQuality.Primal => 6,
            ItemQuality.Ancient => 5,
            ItemQuality.Legendary or ItemQuality.Set => 4,
            ItemQuality.Rare => (int)GD.RandRange(3, 4),
            ItemQuality.Magic => (int)GD.RandRange(1, 2),
            _ => 0,
        };

        var usedBuckets = new HashSet<string>();
        for (int i = 0; i < affixCount && i < _affixes.Count; i++)
        {
            int attempts = 0;
            AffixDef? chosen = null;
            while (attempts < 20)
            {
                var candidate = _affixes[(int)(GD.Randi() % _affixes.Count)];
                if (!usedBuckets.Contains(candidate.Bucket))
                {
                    chosen = candidate;
                    break;
                }
                attempts++;
            }
            if (chosen == null) break;

            usedBuckets.Add(chosen.Bucket);

            double value;
            if (quality == ItemQuality.Primal)
                value = chosen.MaxValue;
            else if (quality == ItemQuality.Ancient)
                value = chosen.MinValue + (chosen.MaxValue - chosen.MinValue) * (0.7 + GD.Randf() * 0.3);
            else
                value = chosen.MinValue + (chosen.MaxValue - chosen.MinValue) * GD.Randf();

            item.Affixes.Add(new AffixInstance
            {
                AffixId = chosen.Id,
                Bucket = chosen.Bucket,
                StatKey = chosen.StatKey,
                Value = Math.Round(value, 4),
                MinRange = chosen.MinValue,
                MaxRange = chosen.MaxValue,
            });
        }
    }
}
