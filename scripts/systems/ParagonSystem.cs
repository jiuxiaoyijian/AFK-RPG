using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Systems;

/// <summary>
/// Paragon (宗师修为) system: 4 attribute boards, point allocation.
/// Unlocked after hero reaches max level.
/// </summary>
public partial class ParagonSystem : Node
{
    public enum ParagonBoard { Offensive, Defensive, Utility, Special }

    public int ParagonLevel { get; set; }
    public int UnspentPoints { get; set; }

    private readonly Dictionary<ParagonBoard, Dictionary<string, int>> _allocations = new()
    {
        { ParagonBoard.Offensive, new() },
        { ParagonBoard.Defensive, new() },
        { ParagonBoard.Utility, new() },
        { ParagonBoard.Special, new() },
    };

    public IReadOnlyDictionary<ParagonBoard, Dictionary<string, int>> Allocations => _allocations;

    private static readonly Dictionary<ParagonBoard, string[]> BoardStats = new()
    {
        { ParagonBoard.Offensive, new[] { "primary_stat", "crit_rate", "crit_damage", "attack_speed_percent" } },
        { ParagonBoard.Defensive, new[] { "max_hp_percent", "defense", "dodge_rate", "hp_regen" } },
        { ParagonBoard.Utility, new[] { "move_speed", "resource_find", "xp_bonus", "gold_find" } },
        { ParagonBoard.Special, new[] { "skill_damage_percent", "cooldown_reduction", "area_damage", "elite_damage" } },
    };

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.ParagonPointGained += OnParagonPointGained;
        GD.Print("[ParagonSystem] initialized");
    }

    public bool AllocatePoint(ParagonBoard board, string statKey)
    {
        if (UnspentPoints <= 0) return false;
        if (!BoardStats.ContainsKey(board)) return false;
        if (!System.Array.Exists(BoardStats[board], s => s == statKey)) return false;

        _allocations[board].TryAdd(statKey, 0);
        _allocations[board][statKey]++;
        UnspentPoints--;

        GameManager.Instance.RecalculateDps();
        return true;
    }

    public int GetStatAllocation(ParagonBoard board, string statKey)
    {
        if (_allocations.TryGetValue(board, out var boardAlloc))
            return boardAlloc.GetValueOrDefault(statKey, 0);
        return 0;
    }

    public double GetStatBonus(string statKey)
    {
        double total = 0;
        foreach (var (_, boardAlloc) in _allocations)
            total += boardAlloc.GetValueOrDefault(statKey, 0) * 0.005;
        return total;
    }

    public void ResetBoard(ParagonBoard board)
    {
        if (!_allocations.ContainsKey(board)) return;
        int refunded = 0;
        foreach (var (_, count) in _allocations[board])
            refunded += count;
        _allocations[board].Clear();
        UnspentPoints += refunded;
        GameManager.Instance.RecalculateDps();
    }

    private void OnParagonPointGained(int points)
    {
        ParagonLevel += points;
        UnspentPoints += points;
    }
}
