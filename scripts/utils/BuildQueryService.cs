using System.Collections.Generic;
using System.Linq;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Utils;

/// <summary>
/// Calculates effective DPS, equipment scores, and build diagnostics.
/// Implements the 7-bucket multiplicative DPS formula.
/// </summary>
public static class BuildQueryService
{
    public record DpsBreakdown(
        double WeaponBase,
        double PrimaryStatMultiplier,
        double CritMultiplier,
        double SkillMultiplier,
        double ElementalMultiplier,
        double SetMultiplier,
        double LegendaryMultiplier,
        double AttackSpeedMultiplier,
        double FinalDps
    );

    public static DpsBreakdown CalculateFullDps(GameManager gm)
    {
        var weapon = gm.EquippedItems.GetValueOrDefault(EquipmentSlot.Weapon);
        double weaponBase = weapon?.BaseStats.GetValueOrDefault("weapon_damage", 10.0) ?? 10.0;

        double primaryStat = SumStat(gm, "primary_stat");
        double critRate = SumStat(gm, "crit_rate");
        double critDmg = SumStat(gm, "crit_damage");
        double skillDmg = SumStat(gm, "skill_damage_percent");
        double elemental = SumStat(gm, "elemental_damage_percent");
        double setBonus = SumStat(gm, "set_bonus_percent");
        double legendary = SumStat(gm, "legendary_effect_percent");
        double attackSpeed = 1.0 + SumStat(gm, "attack_speed_percent");

        double primaryMult = 1.0 + primaryStat;
        double critMult = Combat.DamageResolver.GetExpectedCritMultiplier(critRate, critDmg);
        double skillMult = 1.0 + skillDmg;
        double eleMult = 1.0 + elemental;
        double setMult = 1.0 + setBonus;
        double legMult = 1.0 + legendary;

        double finalDps = weaponBase * primaryMult * critMult * skillMult * eleMult * setMult * legMult * attackSpeed;

        return new DpsBreakdown(
            weaponBase, primaryMult, critMult, skillMult, eleMult, setMult, legMult, attackSpeed, finalDps);
    }

    public static double GetEquipmentScore(ItemData item)
    {
        double score = item.Quality switch
        {
            ItemQuality.Primal => 100,
            ItemQuality.Ancient => 80,
            ItemQuality.Legendary => 60,
            ItemQuality.Set => 55,
            ItemQuality.Rare => 30,
            ItemQuality.Magic => 10,
            _ => 1,
        };

        score += item.Affixes.Count * 5;
        score += item.ItemLevel * 0.5;

        foreach (var affix in item.Affixes)
        {
            double range = affix.MaxRange - affix.MinRange;
            if (range > 0)
                score += (affix.Value - affix.MinRange) / range * 10;
        }

        return score;
    }

    public static bool IsUpgrade(ItemData candidate, ItemData? current)
    {
        if (current == null) return true;
        return GetEquipmentScore(candidate) > GetEquipmentScore(current);
    }

    public static Dictionary<string, double> GetStatSummary(GameManager gm)
    {
        var stats = new Dictionary<string, double>();
        foreach (var (_, item) in gm.EquippedItems)
        {
            if (item == null) continue;
            foreach (var (key, value) in item.BaseStats)
                stats[key] = stats.GetValueOrDefault(key) + value;
            foreach (var affix in item.Affixes)
                stats[affix.StatKey] = stats.GetValueOrDefault(affix.StatKey) + affix.Value;
        }
        return stats;
    }

    private static double SumStat(GameManager gm, string statKey)
    {
        double total = 0;
        foreach (var (_, item) in gm.EquippedItems)
        {
            if (item == null) continue;
            total += item.BaseStats.GetValueOrDefault(statKey, 0);
            total += item.Affixes.Where(a => a.StatKey == statKey).Sum(a => a.Value);
        }
        return total;
    }
}
