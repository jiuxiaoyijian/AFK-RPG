using System.Collections.Generic;
using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Systems;

/// <summary>
/// Cube (百炼坊) system: Extract / Forge / Reforge / Convert / Temper.
/// Operates on inventory items through GameManager.
/// </summary>
public partial class CubeSystem : Node
{
    public enum CubeAction { Extract, ForgeSteel, Reforge, Convert, Temper }

    public record RecipeDef(string Id, CubeAction Action, string Description, int GoldCost, int ScrapCost);

    private readonly List<RecipeDef> _recipes = new();
    public IReadOnlyList<RecipeDef> Recipes => _recipes;

    public override void _Ready()
    {
        LoadRecipes();
        GD.Print($"[CubeSystem] loaded {_recipes.Count} recipes");
    }

    private void LoadRecipes()
    {
        var db = GetNode<ConfigDB>("/root/ConfigDB");
        var doc = db.LoadRawJson("res://data/equipment/cube_recipes.json");
        if (doc == null) return;

        foreach (var el in doc.RootElement.EnumerateArray())
        {
            var actionStr = el.GetProperty("action").GetString() ?? "Extract";
            System.Enum.TryParse<CubeAction>(actionStr, true, out var action);
            _recipes.Add(new RecipeDef(
                el.GetProperty("id").GetString() ?? "",
                action,
                el.TryGetProperty("description", out var d) ? d.GetString() ?? "" : "",
                el.TryGetProperty("gold_cost", out var g) ? g.GetInt32() : 0,
                el.TryGetProperty("scrap_cost", out var s) ? s.GetInt32() : 0));
        }
    }

    public bool CanExecute(RecipeDef recipe, ItemData? item)
    {
        var gm = GameManager.Instance;
        if (gm.Gold < recipe.GoldCost || gm.Scrap < recipe.ScrapCost) return false;

        return recipe.Action switch
        {
            CubeAction.Extract => item is { Quality: ItemQuality.Legendary },
            CubeAction.ForgeSteel => item != null,
            CubeAction.Reforge => item is { Quality: >= ItemQuality.Rare },
            CubeAction.Convert => item != null,
            CubeAction.Temper => item is { Quality: >= ItemQuality.Legendary },
            _ => false,
        };
    }

    public bool Execute(RecipeDef recipe, ItemData item)
    {
        if (!CanExecute(recipe, item)) return false;

        var gm = GameManager.Instance;
        gm.AddGold(-recipe.GoldCost);
        gm.AddScrap(-recipe.ScrapCost);

        switch (recipe.Action)
        {
            case CubeAction.Extract:
                ExtractLegendaryPower(item);
                break;
            case CubeAction.ForgeSteel:
                ForgeSteel(item);
                break;
            case CubeAction.Reforge:
                ReforgeItem(item);
                break;
            case CubeAction.Convert:
                ConvertMaterials(item);
                break;
            case CubeAction.Temper:
                TemperItem(item);
                break;
        }
        return true;
    }

    private void ExtractLegendaryPower(ItemData item)
    {
        if (string.IsNullOrEmpty(item.LegendaryAffixId)) return;
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.ItemSalvaged, item.Uid, 0);
        GameManager.Instance.Inventory.Remove(item);
    }

    private void ForgeSteel(ItemData item)
    {
        int scrapGain = item.Quality switch
        {
            ItemQuality.Common => 1,
            ItemQuality.Magic => 3,
            ItemQuality.Rare => 8,
            ItemQuality.Legendary => 25,
            _ => 50,
        };
        GameManager.Instance.AddScrap(scrapGain);
        GameManager.Instance.Inventory.Remove(item);
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.ItemSalvaged, item.Uid, scrapGain);
    }

    private void ReforgeItem(ItemData item)
    {
        var rng = new System.Random();
        foreach (var affix in item.Affixes)
            affix.Value = affix.Value * (0.8 + rng.NextDouble() * 0.4);
    }

    private void ConvertMaterials(ItemData item)
    {
        GameManager.Instance.AddScrap(5);
        GameManager.Instance.Inventory.Remove(item);
    }

    private void TemperItem(ItemData item)
    {
        var rng = new System.Random();
        if (item.Affixes.Count > 0)
        {
            var affix = item.Affixes[rng.Next(item.Affixes.Count)];
            affix.Value *= 1.1;
        }
    }
}
