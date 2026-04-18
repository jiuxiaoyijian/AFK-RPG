using System.Collections.Generic;
using System.Linq;
using Godot;
using DesktopIdle.Models;

namespace DesktopIdle.Autoload;

public partial class GameManager : Node
{
    public static GameManager Instance { get; private set; } = null!;

    // ── Hero State ──
    public string HeroName { get; set; } = "无名弟子";
    public int HeroLevel { get; set; } = 1;
    public long HeroExp { get; set; }
    public string SchoolId { get; set; } = "";
    public double CurrentHp { get; set; } = 100;
    public double MaxHp { get; set; } = 100;
    public double CurrentEnergy { get; set; } = 100;
    public double MaxEnergy { get; set; } = 100;

    // ── Progress ──
    public string CurrentChapterId { get; set; } = "chapter_1";
    public string CurrentNodeId { get; set; } = "ch1_n1";
    public HashSet<string> ClearedNodes { get; } = new();
    public HashSet<string> ClearedChapters { get; } = new();
    public long TotalKills { get; set; }

    // ── Inventory ──
    public List<ItemData> Inventory { get; } = new();
    public Dictionary<EquipmentSlot, ItemData?> EquippedItems { get; } = new();
    public long Gold { get; set; } = 100;
    public long Scrap { get; set; }
    public long ZhenyiShards { get; set; }

    // ── Skills ──
    public string[] EquippedSkillIds { get; } = new string[4];
    public Dictionary<string, int> SkillLevels { get; } = new();

    // ── Computed ──
    public double Dps { get; private set; }
    public double CombatPower { get; private set; }

    public override void _Ready()
    {
        Instance = this;
        InitEquipmentSlots();
        RecalculateDps();
        GD.Print("[GameManager] initialized");
    }

    private void InitEquipmentSlots()
    {
        foreach (var slot in System.Enum.GetValues<EquipmentSlot>())
            EquippedItems.TryAdd(slot, null);
    }

    public void EquipItem(ItemData item)
    {
        if (EquippedItems.TryGetValue(item.Slot, out var old) && old != null)
            Inventory.Add(old);

        EquippedItems[item.Slot] = item;
        Inventory.Remove(item);
        RecalculateDps();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.EquipmentChanged, item.Slot.ToJsonKey());
    }

    public bool AddToInventory(ItemData item)
    {
        if (Inventory.Count >= 200)
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.InventoryFull);
            return false;
        }
        Inventory.Add(item);
        return true;
    }

    public void RecalculateDps()
    {
        var weapon = EquippedItems.GetValueOrDefault(EquipmentSlot.Weapon);
        double baseDmg = weapon?.BaseStats.GetValueOrDefault("weapon_damage", 10.0) ?? 10.0;

        double primaryStat = SumAffixStat("primary_stat");
        double critRate = SumAffixStat("crit_rate");
        double critDmg = SumAffixStat("crit_damage");
        double skillDmg = SumAffixStat("skill_damage_percent");
        double attackSpeed = 1.0 + SumAffixStat("attack_speed_percent");

        double expectedCrit = 1.0 + Mathf.Clamp((float)critRate, 0f, 1f) * critDmg;
        Dps = baseDmg * (1.0 + primaryStat) * expectedCrit * (1.0 + skillDmg) * attackSpeed;
        CombatPower = Dps * MaxHp / 100.0;
    }

    private double SumAffixStat(string statKey)
    {
        double total = 0;
        foreach (var (_, item) in EquippedItems)
        {
            if (item == null) continue;
            total += item.BaseStats.GetValueOrDefault(statKey, 0);
            total += item.Affixes.Where(a => a.StatKey == statKey).Sum(a => a.Value);
        }
        return total;
    }

    public void AdvanceToNode(string nodeId)
    {
        CurrentNodeId = nodeId;
        GD.Print($"[GameManager] advanced to node {nodeId}");
    }

    public void MarkNodeCleared(string nodeId)
    {
        ClearedNodes.Add(nodeId);
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.NodeCleared, nodeId);

        var configDb = GetNode<ConfigDB>("/root/ConfigDB");
        if (configDb.Nodes.TryGetValue(nodeId, out var node) && !string.IsNullOrEmpty(node.NextNodeId))
        {
            AdvanceToNode(node.NextNodeId);
        }
        else
        {
            var chapter = configDb.Chapters.Values.FirstOrDefault(c => c.NodeIds.Contains(nodeId));
            if (chapter != null)
            {
                ClearedChapters.Add(chapter.Id);
                bus.EmitSignal(EventBus.SignalName.ChapterCleared, chapter.Id);
                if (!string.IsNullOrEmpty(chapter.NextChapterId) &&
                    configDb.Chapters.TryGetValue(chapter.NextChapterId, out var next))
                {
                    CurrentChapterId = next.Id;
                    AdvanceToNode(next.NodeIds[0]);
                }
            }
        }
    }

    public void GainExperience(long amount)
    {
        HeroExp += amount;
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.ExperienceGained, amount);

        long needed = GetExpForLevel(HeroLevel + 1);
        while (HeroExp >= needed && HeroLevel < 100)
        {
            HeroExp -= needed;
            HeroLevel++;
            MaxHp += 10;
            CurrentHp = MaxHp;
            bus.EmitSignal(EventBus.SignalName.HeroLevelUp, HeroLevel);
            needed = GetExpForLevel(HeroLevel + 1);
        }
    }

    private static long GetExpForLevel(int level) => (long)(100 * System.Math.Pow(1.15, level - 1));

    public void AddGold(long amount) => Gold += amount;
    public void AddScrap(long amount) => Scrap += amount;

    public SavePayload ToSavePayload()
    {
        var payload = new SavePayload
        {
            SaveVersion = 4,
            SaveTimestamp = (long)Time.GetUnixTimeFromSystem(),
            HeroName = HeroName,
            HeroLevel = HeroLevel,
            HeroExp = HeroExp,
            SchoolId = SchoolId,
            CurrentChapterId = CurrentChapterId,
            CurrentNodeId = CurrentNodeId,
            ClearedNodes = new HashSet<string>(ClearedNodes),
            ClearedChapters = new HashSet<string>(ClearedChapters),
            TotalKills = TotalKills,
            Inventory = new List<ItemData>(Inventory),
            Gold = Gold,
            Scrap = Scrap,
            ZhenyiShards = ZhenyiShards,
        };
        return payload;
    }

    public void LoadFromPayload(SavePayload payload)
    {
        HeroName = payload.HeroName;
        HeroLevel = payload.HeroLevel;
        HeroExp = payload.HeroExp;
        SchoolId = payload.SchoolId;
        CurrentChapterId = payload.CurrentChapterId;
        CurrentNodeId = payload.CurrentNodeId;
        ClearedNodes.Clear();
        foreach (var n in payload.ClearedNodes) ClearedNodes.Add(n);
        ClearedChapters.Clear();
        foreach (var c in payload.ClearedChapters) ClearedChapters.Add(c);
        TotalKills = payload.TotalKills;
        Inventory.Clear();
        Inventory.AddRange(payload.Inventory);
        Gold = payload.Gold;
        Scrap = payload.Scrap;
        ZhenyiShards = payload.ZhenyiShards;
        RecalculateDps();
    }
}
