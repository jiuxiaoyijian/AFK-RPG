using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Systems;

/// <summary>
/// Martial Codex (武学秘录): Manages extracted legendary powers.
/// 3 active slots for passive legendary effects.
/// </summary>
public partial class MartialCodexSystem : Node
{
    public const int MaxActiveSlots = 3;

    private readonly HashSet<string> _unlockedPowers = new();
    private readonly string[] _activeSlots = new string[MaxActiveSlots];

    public IReadOnlySet<string> UnlockedPowers => _unlockedPowers;
    public IReadOnlyList<string> ActiveSlots => _activeSlots;

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.ItemSalvaged += OnItemSalvaged;
        GD.Print("[MartialCodexSystem] initialized");
    }

    public bool UnlockPower(string legendaryAffixId)
    {
        if (string.IsNullOrEmpty(legendaryAffixId)) return false;
        return _unlockedPowers.Add(legendaryAffixId);
    }

    public bool ActivatePower(int slot, string legendaryAffixId)
    {
        if (slot < 0 || slot >= MaxActiveSlots) return false;
        if (!_unlockedPowers.Contains(legendaryAffixId)) return false;

        _activeSlots[slot] = legendaryAffixId;
        GameManager.Instance.RecalculateDps();
        return true;
    }

    public void DeactivateSlot(int slot)
    {
        if (slot < 0 || slot >= MaxActiveSlots) return;
        _activeSlots[slot] = "";
    }

    public bool IsPowerActive(string legendaryAffixId)
    {
        foreach (var s in _activeSlots)
            if (s == legendaryAffixId) return true;
        return false;
    }

    private void OnItemSalvaged(string itemId, int scrapGained)
    {
        // Cube Extract flow triggers this
    }

    public List<string> GetActiveEffectIds()
    {
        var list = new List<string>();
        foreach (var s in _activeSlots)
            if (!string.IsNullOrEmpty(s)) list.Add(s);
        return list;
    }
}
