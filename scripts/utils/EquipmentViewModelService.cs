using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Utils;

/// <summary>
/// Equipment comparison ViewModel: generates comparison data between candidate and current equipment.
/// </summary>
public static class EquipmentViewModelService
{
    public record CompareResult(
        string StatKey,
        double CurrentValue,
        double CandidateValue,
        double Delta,
        bool IsUpgrade);

    public static CompareResult[] Compare(ItemData candidate, ItemData? current)
    {
        var statKeys = new[] { "weapon_damage", "primary_stat", "crit_rate", "crit_damage",
                               "attack_speed_percent", "max_hp_percent", "defense", "skill_damage_percent" };

        var results = new CompareResult[statKeys.Length];
        for (int i = 0; i < statKeys.Length; i++)
        {
            double curVal = GetTotalStat(current, statKeys[i]);
            double candVal = GetTotalStat(candidate, statKeys[i]);
            results[i] = new CompareResult(statKeys[i], curVal, candVal, candVal - curVal, candVal > curVal);
        }
        return results;
    }

    private static double GetTotalStat(ItemData? item, string statKey)
    {
        if (item == null) return 0;
        double total = item.BaseStats.TryGetValue(statKey, out var bv) ? bv : 0;
        foreach (var affix in item.Affixes)
        {
            if (affix.StatKey == statKey)
                total += affix.Value;
        }
        return total;
    }

    public static double GetDpsDelta(ItemData candidate)
    {
        var gm = GameManager.Instance;
        double currentDps = gm.Dps;

        gm.EquippedItems.TryGetValue(candidate.Slot, out var currentEquip);
        gm.EquipItem(candidate);
        double newDps = gm.Dps;

        if (currentEquip != null)
            gm.EquipItem(currentEquip);
        else
        {
            gm.EquippedItems[candidate.Slot] = null;
            gm.Inventory.Add(candidate);
        }
        gm.RecalculateDps();

        return newDps - currentDps;
    }
}
