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

        var root = doc.RootElement;
        var setArray = root.TryGetProperty("set_defs", out var sd) ? sd : root;

        foreach (var el in setArray.EnumerateArray())
        {
            string id = el.TryGetProperty("id", out var idProp) ? idProp.GetString() ?? "" : "";
            var bonuses = new List<SetBonus>();
            if (el.TryGetProperty("bonuses", out var bArr))
            {
                foreach (var b in bArr.EnumerateArray())
                    bonuses.Add(new SetBonus(
                        b.GetProperty("pieces").GetInt32(),
                        b.TryGetProperty("effect_key", out var ek) ? ek.GetString() ?? ""
                            : b.TryGetProperty("stat_key", out var sk) ? sk.GetString() ?? "" : "",
                        b.TryGetProperty("effect_value", out var ev) ? ev.GetDouble()
                            : b.TryGetProperty("value", out var v) ? v.GetDouble() : 0));
            }
            _setDefs[id] = new SetDef(
                id,
                el.TryGetProperty("name", out var nm) ? nm.GetString() ?? id : id,
                el.TryGetProperty("piece_base_ids", out var pids)
                    ? pids.EnumerateArray().Select(x => x.GetString() ?? "").ToArray()
                    : el.TryGetProperty("piece_slots", out var ps)
                        ? ps.EnumerateArray().Select(x => x.GetString() ?? "").ToArray()
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
