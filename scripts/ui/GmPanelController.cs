using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// GM debug panel: add gold, add items, set level, clear progress, etc.
/// Only accessible in debug mode.
/// </summary>
public partial class GmPanelController : Control
{
    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(400, 440);
        Position = new Vector2(440, 140);
        Visible = false;

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.Danger, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "GM 调试面板", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.Danger);
        AddChild(title);

        var vbox = new VBoxContainer { Position = new Vector2(20, 50), Size = new Vector2(360, 380) };
        vbox.AddThemeConstantOverride("separation", 8);
        AddChild(vbox);

        AddGmButton(vbox, "+10000 金币", () => GameManager.Instance.AddGold(10000));
        AddGmButton(vbox, "+1000 碎片", () => GameManager.Instance.AddScrap(1000));
        AddGmButton(vbox, "+10 级", () => {
            for (int i = 0; i < 10; i++) GameManager.Instance.GainExperience(99999);
        });
        AddGmButton(vbox, "满血满蓝", () => {
            var gm = GameManager.Instance;
            gm.CurrentHp = gm.MaxHp;
            gm.CurrentEnergy = gm.MaxEnergy;
        });
        AddGmButton(vbox, "生成传说装备", () => {
            var gen = GetNodeOrNull<Systems.EquipmentGeneratorSystem>("/root/GameRoot/Systems/EquipmentGeneratorSystem");
            if (gen == null) return;
            var item = gen.Generate(GameManager.Instance.HeroLevel, Models.ItemQuality.Legendary);
            if (item != null) GameManager.Instance.AddToInventory(item);
        });
        AddGmButton(vbox, "清空背包", () => GameManager.Instance.Inventory.Clear());

        var closeBtn = new Button { Text = "关闭", CustomMinimumSize = new Vector2(100, 32) };
        closeBtn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavSettings));
        closeBtn.Pressed += () => Visible = false;
        vbox.AddChild(closeBtn);
    }

    private static void AddGmButton(VBoxContainer parent, string text, System.Action action)
    {
        var btn = new Button { Text = text, CustomMinimumSize = new Vector2(200, 32) };
        btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.Danger.Darkened(0.3f)));
        btn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        btn.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        btn.Pressed += action;
        parent.AddChild(btn);
    }
}
