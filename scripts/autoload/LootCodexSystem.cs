using System.Collections.Generic;
using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Loot Codex (掉落图鉴): tracks all items ever found, discovery progress, and fortune tracking.
/// </summary>
public partial class LootCodexSystem : Node
{
    private readonly HashSet<string> _discoveredBaseIds = new();
    private readonly HashSet<string> _discoveredLegendaryIds = new();
    private readonly HashSet<string> _discoveredSetIds = new();
    private readonly Dictionary<string, int> _dropCounts = new();

    public IReadOnlySet<string> DiscoveredBaseIds => _discoveredBaseIds;
    public IReadOnlySet<string> DiscoveredLegendaryIds => _discoveredLegendaryIds;
    public IReadOnlySet<string> DiscoveredSetIds => _discoveredSetIds;

    public int TotalDiscovered => _discoveredBaseIds.Count + _discoveredLegendaryIds.Count + _discoveredSetIds.Count;

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.LootDropped += OnLootDropped;
        GD.Print("[LootCodexSystem] initialized");
    }

    private void OnLootDropped(string itemId, string quality)
    {
        _dropCounts.TryAdd(itemId, 0);
        _dropCounts[itemId]++;

        _discoveredBaseIds.Add(itemId);

        if (quality is "Legendary" or "Ancient" or "Primal")
            _discoveredLegendaryIds.Add(itemId);
        else if (quality is "Set")
            _discoveredSetIds.Add(itemId);
    }

    public int GetDropCount(string itemId) => _dropCounts.GetValueOrDefault(itemId, 0);

    public bool IsDiscovered(string baseId) => _discoveredBaseIds.Contains(baseId);

    public double GetCollectionProgress(int totalItemCount)
    {
        return totalItemCount > 0 ? (double)TotalDiscovered / totalItemCount * 100.0 : 0;
    }
}
