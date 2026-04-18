using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Systems;
using DesktopIdle.Utils;

namespace DesktopIdle.UI;

/// <summary>
/// Cube (百炼坊) panel: 5 function tabs (Extract/ForgeSteel/Reforge/Convert/Temper).
/// </summary>
public partial class CubePanelController : Control
{
    private TabContainer _tabs = null!;
    private Label _statusLabel = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(640, 460);
        Position = new Vector2(320, 130);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "百 炼 坊", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.NavCube);
        AddChild(title);

        _tabs = new TabContainer { Position = new Vector2(10, 44), Size = new Vector2(620, 370) };
        AddChild(_tabs);

        var actions = new[] { CubeSystem.CubeAction.Extract, CubeSystem.CubeAction.ForgeSteel,
                              CubeSystem.CubeAction.Reforge, CubeSystem.CubeAction.Convert,
                              CubeSystem.CubeAction.Temper };

        foreach (var action in actions)
        {
            var page = new VBoxContainer { Name = CubeViewModelService.GetActionDisplayName(action) };
            page.AddThemeConstantOverride("separation", 8);
            _tabs.AddChild(page);

            var desc = new Label { Text = GetActionDescription(action) };
            desc.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            desc.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
            page.AddChild(desc);

            var itemSlot = new Panel { CustomMinimumSize = new Vector2(200, 80) };
            itemSlot.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgDark, UIStyle.Border));
            page.AddChild(itemSlot);

            var slotLabel = new Label { Text = "拖入装备", Position = new Vector2(12, 28) };
            slotLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            slotLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
            itemSlot.AddChild(slotLabel);

            var executeBtn = new Button { Text = "执行", CustomMinimumSize = new Vector2(120, 36) };
            executeBtn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavCube));
            executeBtn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            page.AddChild(executeBtn);
        }

        _statusLabel = new Label { Text = "", Position = new Vector2(20, 420) };
        _statusLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _statusLabel.AddThemeColorOverride("font_color", UIStyle.Success);
        AddChild(_statusLabel);
    }

    private static string GetActionDescription(CubeSystem.CubeAction action) => action switch
    {
        CubeSystem.CubeAction.Extract => "萃取传奇装备的特殊词缀，存入武学秘录",
        CubeSystem.CubeAction.ForgeSteel => "分解装备获取精钢碎片",
        CubeSystem.CubeAction.Reforge => "重新随机装备的词缀数值",
        CubeSystem.CubeAction.Convert => "将装备转化为材料",
        CubeSystem.CubeAction.Temper => "强化传奇装备的一条词缀",
        _ => "",
    };
}
