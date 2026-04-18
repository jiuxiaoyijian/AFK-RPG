using System.Text;
using DesktopIdle.Models;
using DesktopIdle.UI;
using Godot;

namespace DesktopIdle.Utils;

/// <summary>
/// Generates display text, tooltips, and color info for items.
/// </summary>
public static class ItemPresentationService
{
    public static string GetQualityName(ItemQuality quality) => quality switch
    {
        ItemQuality.Common => "凡品",
        ItemQuality.Magic => "灵品",
        ItemQuality.Rare => "珍品",
        ItemQuality.Legendary => "传说",
        ItemQuality.Set => "传承",
        ItemQuality.Ancient => "太古",
        ItemQuality.Primal => "鸿蒙",
        _ => "未知",
    };

    public static Color GetQualityColor(ItemQuality quality) => quality switch
    {
        ItemQuality.Common => UIStyle.Common,
        ItemQuality.Magic => UIStyle.Magic,
        ItemQuality.Rare => UIStyle.Rare,
        ItemQuality.Legendary => UIStyle.Legendary,
        ItemQuality.Set => UIStyle.Set,
        ItemQuality.Ancient => UIStyle.Ancient,
        ItemQuality.Primal => UIStyle.Primal,
        _ => UIStyle.Common,
    };

    public static string GetSlotName(EquipmentSlot slot) => slot switch
    {
        EquipmentSlot.Weapon => "兵器",
        EquipmentSlot.Helmet => "头盔",
        EquipmentSlot.Armor => "甲胄",
        EquipmentSlot.Gloves => "护手",
        EquipmentSlot.Boots => "鞋履",
        EquipmentSlot.Belt => "腰带",
        EquipmentSlot.Legs => "腿甲",
        EquipmentSlot.Accessory1 => "饰品·壹",
        EquipmentSlot.Accessory2 => "饰品·贰",
        _ => "未知",
    };

    public static string GetStatDisplayName(string statKey) => statKey switch
    {
        "weapon_damage" => "武器伤害",
        "primary_stat" => "主属性",
        "crit_rate" => "暴击率",
        "crit_damage" => "暴击伤害",
        "attack_speed_percent" => "攻击速度",
        "max_hp_percent" => "最大生命%",
        "defense" => "防御",
        "skill_damage_percent" => "技能伤害%",
        "move_speed" => "移动速度",
        "resource_find" => "资源发现",
        "gold_find" => "金币发现",
        "xp_bonus" => "经验加成",
        "dodge_rate" => "闪避率",
        "hp_regen" => "生命回复",
        _ => statKey,
    };

    public static string BuildTooltip(ItemData item)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"[{GetQualityName(item.Quality)}] {item.BaseId}");
        sb.AppendLine($"装备位: {GetSlotName(item.Slot)} | 物品等级: {item.ItemLevel}");
        sb.AppendLine();

        foreach (var (key, value) in item.BaseStats)
            sb.AppendLine($"  {GetStatDisplayName(key)}: {value:F1}");

        if (item.Affixes.Count > 0)
        {
            sb.AppendLine();
            foreach (var affix in item.Affixes)
            {
                string prefix = affix.IsLegendary ? "★ " : "  ";
                sb.AppendLine($"{prefix}{GetStatDisplayName(affix.StatKey)}: +{affix.Value:F1}");
            }
        }

        if (!string.IsNullOrEmpty(item.SetId))
            sb.AppendLine($"\n传承: {item.SetId}");

        return sb.ToString();
    }
}
