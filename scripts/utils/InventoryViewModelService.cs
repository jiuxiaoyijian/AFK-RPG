using System;
using System.Collections.Generic;
using System.Linq;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Utils;

/// <summary>
/// ViewModel for the inventory panel: paging, sorting, filtering.
/// </summary>
public static class InventoryViewModelService
{
    public enum SortMode { ByQuality, ByLevel, BySlot, ByName }
    public enum FilterMode { All, Weapon, Armor, Accessory, Legendary, Set }

    public const int PageSize = 20;

    public static List<ItemData> GetFiltered(FilterMode filter)
    {
        var items = GameManager.Instance.Inventory;
        return filter switch
        {
            FilterMode.Weapon => items.Where(i => i.Slot == EquipmentSlot.Weapon).ToList(),
            FilterMode.Armor => items.Where(i => i.Slot is EquipmentSlot.Helmet or EquipmentSlot.Armor or EquipmentSlot.Gloves or EquipmentSlot.Boots).ToList(),
            FilterMode.Accessory => items.Where(i => i.Slot is EquipmentSlot.Accessory1 or EquipmentSlot.Accessory2 or EquipmentSlot.Belt).ToList(),
            FilterMode.Legendary => items.Where(i => i.Quality >= ItemQuality.Legendary).ToList(),
            FilterMode.Set => items.Where(i => !string.IsNullOrEmpty(i.SetId)).ToList(),
            _ => items.ToList(),
        };
    }

    public static List<ItemData> GetSorted(List<ItemData> items, SortMode sort)
    {
        return sort switch
        {
            SortMode.ByQuality => items.OrderByDescending(i => i.Quality).ThenByDescending(i => i.ItemLevel).ToList(),
            SortMode.ByLevel => items.OrderByDescending(i => i.ItemLevel).ToList(),
            SortMode.BySlot => items.OrderBy(i => i.Slot).ThenByDescending(i => i.Quality).ToList(),
            SortMode.ByName => items.OrderBy(i => i.BaseId).ToList(),
            _ => items,
        };
    }

    public static List<ItemData> GetPage(List<ItemData> items, int page)
    {
        return items.Skip(page * PageSize).Take(PageSize).ToList();
    }

    public static int GetPageCount(int totalItems) => Math.Max(1, (totalItems + PageSize - 1) / PageSize);
}
