using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Systems;

/// <summary>
/// Handles loot drop decisions when enemies are killed.
/// Delegates equipment generation to EquipmentGeneratorSystem.
/// </summary>
public partial class LootSystem : Node
{
    private const double BaseDropChance = 0.35;
    private const int PityThreshold = 15;

    private int _killsSinceLastDrop;

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EnemyKilled += OnEnemyKilled;
        GD.Print("[LootSystem] initialized");
    }

    private void OnEnemyKilled(string enemyId, string nodeType)
    {
        _killsSinceLastDrop++;
        double chance = CalculateDropChance(nodeType);

        if (GD.Randf() < chance || _killsSinceLastDrop >= PityThreshold)
        {
            _killsSinceLastDrop = 0;
            var quality = RollQuality(nodeType);
            int itemLevel = GameManager.Instance.HeroLevel;

            var equipGen = GetNodeOrNull<EquipmentGeneratorSystem>("../EquipmentGeneratorSystem");
            if (equipGen != null)
            {
                var item = equipGen.Generate(itemLevel, quality);
                if (item != null)
                {
                    GameManager.Instance.AddToInventory(item);

                    var bus = GetNode<EventBus>("/root/EventBus");
                    bus.EmitSignal(EventBus.SignalName.LootDropped, item.Uid, quality.ToJsonKey());
                    bus.EmitSignal(EventBus.SignalName.LootPickedUp, item.Uid);

                    if (quality >= ItemQuality.Legendary)
                        bus.EmitSignal(EventBus.SignalName.DropToastRequested, item.Uid, quality.ToJsonKey());

                    GD.Print($"[LootSystem] dropped {quality} {item.Name} (ilvl {itemLevel})");
                }
            }

            long scrapReward = quality >= ItemQuality.Rare ? 3 : 1;
            GameManager.Instance.AddScrap(scrapReward);
        }
    }

    private double CalculateDropChance(string nodeType)
    {
        double multiplier = nodeType switch
        {
            "boss" => 3.0,
            "elite" => 1.8,
            _ => 1.0,
        };
        double pityBonus = _killsSinceLastDrop * 0.02;
        return BaseDropChance * multiplier + pityBonus;
    }

    private ItemQuality RollQuality(string nodeType)
    {
        double roll = GD.Randf();

        if (nodeType == "boss")
        {
            return roll switch
            {
                < 0.01 => ItemQuality.Primal,
                < 0.05 => ItemQuality.Ancient,
                < 0.15 => ItemQuality.Set,
                < 0.40 => ItemQuality.Legendary,
                < 0.70 => ItemQuality.Rare,
                < 0.90 => ItemQuality.Magic,
                _ => ItemQuality.Common,
            };
        }

        if (nodeType == "elite")
        {
            return roll switch
            {
                < 0.005 => ItemQuality.Primal,
                < 0.02 => ItemQuality.Ancient,
                < 0.06 => ItemQuality.Set,
                < 0.15 => ItemQuality.Legendary,
                < 0.40 => ItemQuality.Rare,
                < 0.75 => ItemQuality.Magic,
                _ => ItemQuality.Common,
            };
        }

        return roll switch
        {
            < 0.001 => ItemQuality.Primal,
            < 0.005 => ItemQuality.Ancient,
            < 0.02 => ItemQuality.Set,
            < 0.05 => ItemQuality.Legendary,
            < 0.20 => ItemQuality.Rare,
            < 0.55 => ItemQuality.Magic,
            _ => ItemQuality.Common,
        };
    }
}
