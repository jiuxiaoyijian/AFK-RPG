using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Systems;

/// <summary>
/// Legendary Gem (传奇宝石) system: 6 gem slots, socketing, leveling, effects.
/// </summary>
public partial class GemSystem : Node
{
    public const int MaxGemSlots = 6;
    public const int MaxGemLevel = 25;

    public record GemInstance(string GemId, string Name, string EffectKey, int Level, double EffectBase);

    private readonly GemInstance?[] _equippedGems = new GemInstance?[MaxGemSlots];
    private readonly List<GemInstance> _ownedGems = new();

    public IReadOnlyList<GemInstance?> EquippedGems => _equippedGems;
    public IReadOnlyList<GemInstance> OwnedGems => _ownedGems;

    public override void _Ready()
    {
        GD.Print("[GemSystem] initialized");
    }

    public void AddGem(string gemId, string name, string effectKey, double effectBase)
    {
        _ownedGems.Add(new GemInstance(gemId, name, effectKey, 1, effectBase));
    }

    public bool SocketGem(int slotIndex, int ownedIndex)
    {
        if (slotIndex < 0 || slotIndex >= MaxGemSlots) return false;
        if (ownedIndex < 0 || ownedIndex >= _ownedGems.Count) return false;

        var gem = _ownedGems[ownedIndex];
        if (_equippedGems[slotIndex] != null)
            _ownedGems.Add(_equippedGems[slotIndex]!);

        _equippedGems[slotIndex] = gem;
        _ownedGems.RemoveAt(ownedIndex);
        GameManager.Instance.RecalculateDps();
        return true;
    }

    public bool UnsocketGem(int slotIndex)
    {
        if (slotIndex < 0 || slotIndex >= MaxGemSlots) return false;
        if (_equippedGems[slotIndex] == null) return false;

        _ownedGems.Add(_equippedGems[slotIndex]!);
        _equippedGems[slotIndex] = null;
        GameManager.Instance.RecalculateDps();
        return true;
    }

    public bool LevelUpGem(int slotIndex)
    {
        if (slotIndex < 0 || slotIndex >= MaxGemSlots) return false;
        var gem = _equippedGems[slotIndex];
        if (gem == null || gem.Level >= MaxGemLevel) return false;

        var gm = GameManager.Instance;
        long cost = 100L * gem.Level;
        if (gm.Gold < cost) return false;

        gm.AddGold(-cost);
        _equippedGems[slotIndex] = gem with { Level = gem.Level + 1 };
        gm.RecalculateDps();
        return true;
    }

    public double GetTotalGemBonus(string effectKey)
    {
        double total = 0;
        foreach (var gem in _equippedGems)
        {
            if (gem == null || gem.EffectKey != effectKey) continue;
            total += gem.EffectBase * (1.0 + (gem.Level - 1) * 0.1);
        }
        return total;
    }
}
