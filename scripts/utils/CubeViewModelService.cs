using System.Collections.Generic;
using System.Linq;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.Systems;

namespace DesktopIdle.Utils;

/// <summary>
/// ViewModel for the Cube (百炼坊) panel: recipe filtering, material validation, cost display.
/// </summary>
public static class CubeViewModelService
{
    public record RecipeViewModel(
        CubeSystem.RecipeDef Recipe,
        bool CanAfford,
        List<ItemData> ValidItems);

    public static List<RecipeViewModel> GetRecipeViewModels(CubeSystem cubeSystem)
    {
        var gm = GameManager.Instance;
        var result = new List<RecipeViewModel>();

        foreach (var recipe in cubeSystem.Recipes)
        {
            bool canAfford = gm.Gold >= recipe.GoldCost && gm.Scrap >= recipe.ScrapCost;
            var validItems = gm.Inventory.Where(item => cubeSystem.CanExecute(recipe, item)).ToList();
            result.Add(new RecipeViewModel(recipe, canAfford, validItems));
        }
        return result;
    }

    public static string GetActionDisplayName(CubeSystem.CubeAction action)
    {
        return action switch
        {
            CubeSystem.CubeAction.Extract => "萃取",
            CubeSystem.CubeAction.ForgeSteel => "精钢化真",
            CubeSystem.CubeAction.Reforge => "回炉重铸",
            CubeSystem.CubeAction.Convert => "材料互转",
            CubeSystem.CubeAction.Temper => "淬火强化",
            _ => action.ToString(),
        };
    }

    public static string GetCostDisplay(CubeSystem.RecipeDef recipe)
    {
        var parts = new List<string>();
        if (recipe.GoldCost > 0) parts.Add($"金币 {recipe.GoldCost}");
        if (recipe.ScrapCost > 0) parts.Add($"碎片 {recipe.ScrapCost}");
        return parts.Count > 0 ? string.Join(" + ", parts) : "免费";
    }
}
