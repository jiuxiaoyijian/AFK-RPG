using System.Collections.Generic;
using DesktopIdle.Models;

namespace DesktopIdle.Utils;

/// <summary>
/// Provides loot quality weight tables and pity calculations.
/// Used by LootSystem for drop decisions and UI for probability display.
/// </summary>
public static class LootRuleService
{
    public record QualityWeight(ItemQuality Quality, double Weight);

    public static readonly IReadOnlyList<QualityWeight> NormalWeights = new QualityWeight[]
    {
        new(ItemQuality.Common, 0.45),
        new(ItemQuality.Magic, 0.35),
        new(ItemQuality.Rare, 0.15),
        new(ItemQuality.Legendary, 0.03),
        new(ItemQuality.Set, 0.015),
        new(ItemQuality.Ancient, 0.004),
        new(ItemQuality.Primal, 0.001),
    };

    public static readonly IReadOnlyList<QualityWeight> EliteWeights = new QualityWeight[]
    {
        new(ItemQuality.Common, 0.25),
        new(ItemQuality.Magic, 0.35),
        new(ItemQuality.Rare, 0.25),
        new(ItemQuality.Legendary, 0.09),
        new(ItemQuality.Set, 0.04),
        new(ItemQuality.Ancient, 0.015),
        new(ItemQuality.Primal, 0.005),
    };

    public static readonly IReadOnlyList<QualityWeight> BossWeights = new QualityWeight[]
    {
        new(ItemQuality.Common, 0.10),
        new(ItemQuality.Magic, 0.20),
        new(ItemQuality.Rare, 0.30),
        new(ItemQuality.Legendary, 0.25),
        new(ItemQuality.Set, 0.10),
        new(ItemQuality.Ancient, 0.04),
        new(ItemQuality.Primal, 0.01),
    };

    public static IReadOnlyList<QualityWeight> GetWeightsForNodeType(string nodeType) => nodeType switch
    {
        "boss" => BossWeights,
        "elite" => EliteWeights,
        _ => NormalWeights,
    };

    public static int GetAffixCount(ItemQuality quality) => quality switch
    {
        ItemQuality.Primal => 6,
        ItemQuality.Ancient => 5,
        ItemQuality.Legendary or ItemQuality.Set => 4,
        ItemQuality.Rare => 3,
        ItemQuality.Magic => 1,
        _ => 0,
    };

    public static int GetMaxAffixCount(ItemQuality quality) => quality switch
    {
        ItemQuality.Primal => 6,
        ItemQuality.Ancient => 5,
        ItemQuality.Legendary or ItemQuality.Set => 4,
        ItemQuality.Rare => 4,
        ItemQuality.Magic => 2,
        _ => 0,
    };

    public static double GetPityDropChanceBonus(int killsSinceLastDrop)
        => killsSinceLastDrop * 0.02;

    public static bool IsPityGuaranteed(int killsSinceLastDrop)
        => killsSinceLastDrop >= 15;

    public static double GetSalvageValue(ItemQuality quality) => quality switch
    {
        ItemQuality.Primal => 50,
        ItemQuality.Ancient => 25,
        ItemQuality.Legendary => 15,
        ItemQuality.Set => 12,
        ItemQuality.Rare => 5,
        ItemQuality.Magic => 2,
        _ => 1,
    };
}
