using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Systems;

/// <summary>
/// Detects equipped set piece counts and activates 2/4/6-piece bonuses.
/// Listens to EquipmentChanged to recalculate active set effects.
/// </summary>
public partial class SetSystem : Node
{
    public record SetBonus(int PiecesRequired, string EffectKey, double EffectValue);
    public record SetDef(string Id, string Name, string[] PieceBaseIds, List<SetBonus> Bonuses);

    private Dictionary<string, SetDef> _setDefs = new();
    private readonly Dictionary<string, int> _activeSetCounts = new();
    private readonly List<SetBonus> _activeBonuses = new();

    public IReadOnlyList<SetBonus> ActiveBonuses => _activeBonuses;
    public IReadOnlyDictionary<string, int> ActiveSetCounts => _activeSetCounts;

    public override void _Ready()
    {
        LoadSetDefs();
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EquipmentChanged += _ => Recalculate();
        Recalculate();
    }

    private void LoadSetDefs()
    {
        var db = GetNode<ConfigDB>("/root/ConfigDB");
        var doc = db.LoadRawJson("res://data/sets/set_defs.json");
        if (doc == null) return;

        foreach (var prop in doc.RootElement.EnumerateObject())
        {
            var el = prop.Value;
            var bonuses = new List<SetBonus>();
            if (el.TryGetProperty("bonuses", out var bArr))
            {
                foreach (var b in bArr.EnumerateArray())
                    bonuses.Add(new SetBonus(
                        b.GetProperty("pieces").GetInt32(),
                        b.GetProperty("effect_key").GetString() ?? "",
                        b.GetProperty("effect_value").GetDouble()));
            }
            _setDefs[prop.Name] = new SetDef(
                prop.Name,
                el.GetProperty("name").GetString() ?? prop.Name,
                el.TryGetProperty("piece_base_ids", out var pids)
                    ? pids.EnumerateArray().Select(x => x.GetString() ?? "").ToArray()
                    : [],
                bonuses);
        }
    }

    public void Recalculate()
    {
        _activeSetCounts.Clear();
        _activeBonuses.Clear();

        var gm = GameManager.Instance;
        foreach (var (_, item) in gm.EquippedItems)
        {
            if (item == null || string.IsNullOrEmpty(item.SetId)) continue;
            _activeSetCounts.TryAdd(item.SetId, 0);
            _activeSetCounts[item.SetId]++;
        }

        foreach (var (setId, count) in _activeSetCounts)
        {
            if (!_setDefs.TryGetValue(setId, out var def)) continue;
            foreach (var bonus in def.Bonuses)
            {
                if (count >= bonus.PiecesRequired)
                    _activeBonuses.Add(bonus);
            }
        }
    }
}
