using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// GM 调试面板：金币、经验、装备生成、清空背包等开发期工具。
/// 统一使用 PanelChrome + IconButton；危险操作走 ConfirmDialog。
/// 见 文档/02_交互与原型/UI控件与视觉规范.md
/// </summary>
public partial class GmPanelController : Control
{
    private Label _statusLabel = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "gm",
            Title = "GM 调 试 面 板",
            Subtitle = "F12 打开 / 仅开发期",
            AccentColor = UIStyle.Danger,
            PanelWidth = 480,
            PanelHeight = 560,
        };
        AddChild(chrome);

        var content = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        chrome.Body.AddChild(content);

        content.AddChild(new SectionHeader("资源", "快速增加金币 / 碎片 / 经验"));

        var resGrid = new GridContainer { Columns = 2 };
        resGrid.AddThemeConstantOverride("h_separation", UIStyle.Spacing8);
        resGrid.AddThemeConstantOverride("v_separation", UIStyle.Spacing8);
        content.AddChild(resGrid);

        AddGmButton(resGrid, "+10000 金币", IconButton.ButtonVariant.Primary,
            () => GameManager.Instance.AddGold(10000));
        AddGmButton(resGrid, "+1000 碎片", IconButton.ButtonVariant.Primary,
            () => GameManager.Instance.AddScrap(1000));
        AddGmButton(resGrid, "+10 级", IconButton.ButtonVariant.Primary, () =>
        {
            for (int i = 0; i < 10; i++) GameManager.Instance.GainExperience(99999);
        });
        AddGmButton(resGrid, "满血满蓝", IconButton.ButtonVariant.Secondary, () =>
        {
            var gm = GameManager.Instance;
            gm.CurrentHp = gm.MaxHp;
            gm.CurrentEnergy = gm.MaxEnergy;
        });

        content.AddChild(new SectionHeader("装备", "生成不同品质的装备"));

        var equipGrid = new GridContainer { Columns = 2 };
        equipGrid.AddThemeConstantOverride("h_separation", UIStyle.Spacing8);
        equipGrid.AddThemeConstantOverride("v_separation", UIStyle.Spacing8);
        content.AddChild(equipGrid);

        AddGmButton(equipGrid, "生成稀有装备", IconButton.ButtonVariant.Secondary,
            () => GenerateItem(ItemQuality.Rare));
        AddGmButton(equipGrid, "生成传说装备", IconButton.ButtonVariant.Primary,
            () => GenerateItem(ItemQuality.Legendary));
        AddGmButton(equipGrid, "生成套装装备", IconButton.ButtonVariant.Secondary,
            () => GenerateItem(ItemQuality.Set));
        AddGmButton(equipGrid, "生成太古装备", IconButton.ButtonVariant.Secondary,
            () => GenerateItem(ItemQuality.Ancient));

        content.AddChild(new SectionHeader("危险", "破坏性操作 - 二次确认"));

        var dangerGrid = new GridContainer { Columns = 2 };
        dangerGrid.AddThemeConstantOverride("h_separation", UIStyle.Spacing8);
        dangerGrid.AddThemeConstantOverride("v_separation", UIStyle.Spacing8);
        content.AddChild(dangerGrid);

        AddGmButton(dangerGrid, "清空背包", IconButton.ButtonVariant.Danger, () =>
            ConfirmDialog.Show(this, "清空背包", "将清空所有未装备物品，确认？",
                () =>
                {
                    GameManager.Instance.Inventory.Clear();
                    SetStatus("背包已清空");
                }, danger: true));

        AddGmButton(dangerGrid, "重置英雄等级", IconButton.ButtonVariant.Danger, () =>
            ConfirmDialog.Show(this, "重置英雄", "将重置等级到 1，确认？",
                () =>
                {
                    var gm = GameManager.Instance;
                    gm.HeroLevel = 1;
                    gm.HeroExp = 0;
                    SetStatus("英雄已重置");
                }, danger: true));

        AddGmButton(dangerGrid, "强制保存", IconButton.ButtonVariant.Secondary, () =>
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.SaveRequested, 0);
            SetStatus("已请求保存槽 0");
        });

        AddGmButton(dangerGrid, "触发离线汇总", IconButton.ButtonVariant.Secondary, () =>
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            var json = "{\"gold\":12345,\"exp\":6789,\"kills\":42,\"scrap\":100}";
            bus.EmitSignal(EventBus.SignalName.OfflineReportReady, 7200.0, json);
            SetStatus("已触发离线弹窗");
        });

        var spacer = new Control { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddChild(spacer);

        _statusLabel = new Label
        {
            Text = "状态：就绪",
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _statusLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _statusLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        content.AddChild(_statusLabel);
    }

    private static void AddGmButton(Container parent, string text, IconButton.ButtonVariant variant, System.Action action)
    {
        var btn = new IconButton(text, variant)
        {
            CustomMinimumSize = new Vector2(0, UIStyle.ButtonHeight),
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
        };
        btn.Pressed += action;
        parent.AddChild(btn);
    }

    private void GenerateItem(ItemQuality quality)
    {
        var gen = GetNodeOrNull<Systems.EquipmentGeneratorSystem>("/root/GameRoot/Systems/EquipmentGeneratorSystem");
        if (gen == null)
        {
            SetStatus("EquipmentGeneratorSystem 未找到");
            return;
        }
        var item = gen.Generate(GameManager.Instance.HeroLevel, quality);
        if (item == null)
        {
            SetStatus($"生成 {quality} 失败");
            return;
        }
        if (GameManager.Instance.AddToInventory(item))
            SetStatus($"已生成 {quality} {item.BaseId}");
        else
            SetStatus("背包已满");
    }

    private void SetStatus(string msg)
    {
        if (_statusLabel != null) _statusLabel.Text = $"状态：{msg}";
    }
}
