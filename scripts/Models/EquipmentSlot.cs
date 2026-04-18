namespace DesktopIdle.Models;

public enum EquipmentSlot
{
    Weapon,
    Helmet,
    Armor,
    Gloves,
    Boots,
    Belt,
    Legs,
    Accessory1,
    Accessory2,
}

public static class EquipmentSlotExtensions
{
    public static string ToJsonKey(this EquipmentSlot slot) => slot switch
    {
        EquipmentSlot.Weapon => "weapon",
        EquipmentSlot.Helmet => "helmet",
        EquipmentSlot.Armor => "armor",
        EquipmentSlot.Gloves => "gloves",
        EquipmentSlot.Boots => "boots",
        EquipmentSlot.Belt => "belt",
        EquipmentSlot.Legs => "legs",
        EquipmentSlot.Accessory1 => "accessory",
        EquipmentSlot.Accessory2 => "accessory",
        _ => "unknown",
    };

    public static EquipmentSlot FromJsonKey(string key) => key switch
    {
        "weapon" => EquipmentSlot.Weapon,
        "helmet" => EquipmentSlot.Helmet,
        "armor" => EquipmentSlot.Armor,
        "gloves" => EquipmentSlot.Gloves,
        "boots" => EquipmentSlot.Boots,
        "belt" => EquipmentSlot.Belt,
        "legs" => EquipmentSlot.Legs,
        "accessory" => EquipmentSlot.Accessory1,
        _ => EquipmentSlot.Weapon,
    };
}
