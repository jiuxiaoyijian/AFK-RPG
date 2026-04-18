using System.Collections.Generic;

namespace DesktopIdle.Models;

public enum ItemQuality
{
    Common,
    Magic,
    Rare,
    Legendary,
    Set,
    Ancient,
    Primal,
}

public static class ItemQualityExtensions
{
    public static string ToJsonKey(this ItemQuality q) => q switch
    {
        ItemQuality.Common => "common",
        ItemQuality.Magic => "magic",
        ItemQuality.Rare => "rare",
        ItemQuality.Legendary => "legendary",
        ItemQuality.Set => "set",
        ItemQuality.Ancient => "ancient",
        ItemQuality.Primal => "primal",
        _ => "common",
    };

    public static ItemQuality FromJsonKey(string key) => key switch
    {
        "common" => ItemQuality.Common,
        "magic" => ItemQuality.Magic,
        "rare" => ItemQuality.Rare,
        "legendary" => ItemQuality.Legendary,
        "set" => ItemQuality.Set,
        "ancient" => ItemQuality.Ancient,
        "primal" => ItemQuality.Primal,
        _ => ItemQuality.Common,
    };

    public static Godot.Color ToColor(this ItemQuality q) => q switch
    {
        ItemQuality.Common => new Godot.Color(0.6f, 0.6f, 0.6f),
        ItemQuality.Magic => new Godot.Color(0.3f, 0.5f, 1f),
        ItemQuality.Rare => new Godot.Color(1f, 0.9f, 0.2f),
        ItemQuality.Legendary => new Godot.Color(1f, 0.6f, 0f),
        ItemQuality.Set => new Godot.Color(0.2f, 0.9f, 0.3f),
        ItemQuality.Ancient => new Godot.Color(0.8f, 0.65f, 0f),
        ItemQuality.Primal => new Godot.Color(0.9f, 0.15f, 0.15f),
        _ => new Godot.Color(1, 1, 1),
    };
}

public class AffixInstance
{
    public string AffixId { get; set; } = "";
    public string Bucket { get; set; } = "";
    public string StatKey { get; set; } = "";
    public double Value { get; set; }
    public double MinRange { get; set; }
    public double MaxRange { get; set; }
    public bool IsLegendary { get; set; }
}

public class ItemData
{
    public string Uid { get; set; } = "";
    public string BaseId { get; set; } = "";
    public string Name { get; set; } = "";
    public EquipmentSlot Slot { get; set; }
    public ItemQuality Quality { get; set; }
    public int ItemLevel { get; set; }
    public List<AffixInstance> Affixes { get; set; } = new();
    public string? LegendaryAffixId { get; set; }
    public string? SetId { get; set; }
    public bool IsLocked { get; set; }
    public long AcquiredTimestamp { get; set; }

    public Dictionary<string, double> BaseStats { get; set; } = new();
}
