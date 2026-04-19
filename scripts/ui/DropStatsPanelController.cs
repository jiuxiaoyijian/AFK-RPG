using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Systems;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// Drop Stats / Rift panel (推演): 3 tabs - drop analysis / rift entry / gem management.
/// 接通：开启秘境 → RiftSystem.StartRift；宝石槽位点击 → 装/卸宝石 popup。
/// </summary>
public partial class DropStatsPanelController : Control
{
    private UiTabBar _tabBar = null!;
    private VBoxContainer _pageHost = null!;

    private VBoxContainer _statsPage = null!;
    private VBoxContainer _riftPage = null!;
    private VBoxContainer _gemsPage = null!;

    private Label _statsLabel = null!;
    private Label _riftStatusLabel = null!;
    private IconButton _startRiftBtn = null!;
    private SpinBox _riftLevelSpin = null!;
    private GridContainer _gemSlotsGrid = null!;

    private RiftSystem _riftSystem = null!;
    private GemSystem _gemSystem = null!;
    private MetaProgressionSystem _meta = null!;

    public override void _Ready()
    {
        _riftSystem = GetNode<RiftSystem>("/root/GameRoot/Systems/RiftSystem");
        _gemSystem = GetNode<GemSystem>("/root/GameRoot/Systems/GemSystem");
        _meta = GetNode<MetaProgressionSystem>("/root/MetaProgressionSystem");

        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.LootDropped += (_, _) => Refresh();
        bus.StageEventTriggered += (_, _) => Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "drop_stats",
            Title = "推 演",
            Subtitle = "统计 / 秘境 / 宝石",
            AccentColor = UIStyle.NavStats,
            PanelWidth = UIStyle.PanelWidthStandard,
            PanelHeight = 540,
        };
        AddChild(chrome);

        var content = new VBoxContainer();
        content.SizeFlagsVertical = SizeFlags.ExpandFill;
        content.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        chrome.Body.AddChild(content);

        _tabBar = new UiTabBar();
        content.AddChild(_tabBar);

        _pageHost = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        content.AddChild(_pageHost);

        BuildStatsPage();
        BuildRiftPage();
        BuildGemsPage();

        _tabBar.AddTab("掉落统计", "stats");
        _tabBar.AddTab("秘境", "rift");
        _tabBar.AddTab("传奇宝石", "gems");
        _tabBar.TabSelected += OnTabSelected;
    }

    private void OnTabSelected(string tabId)
    {
        _statsPage.Visible = tabId == "stats";
        _riftPage.Visible = tabId == "rift";
        _gemsPage.Visible = tabId == "gems";
        Refresh();
    }

    private void BuildStatsPage()
    {
        _statsPage = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _statsPage.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        _pageHost.AddChild(_statsPage);

        _statsPage.AddChild(new SectionHeader("总览"));

        _statsLabel = new Label
        {
            AutowrapMode = TextServer.AutowrapMode.Word,
        };
        _statsLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _statsLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        _statsPage.AddChild(_statsLabel);
    }

    private void BuildRiftPage()
    {
        _riftPage = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _riftPage.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        _riftPage.Visible = false;
        _pageHost.AddChild(_riftPage);

        _riftPage.AddChild(new SectionHeader("秘境信息"));

        _riftStatusLabel = new Label
        {
            AutowrapMode = TextServer.AutowrapMode.Word,
        };
        _riftStatusLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _riftStatusLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        _riftPage.AddChild(_riftStatusLabel);

        var levelRow = new HBoxContainer();
        levelRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        _riftPage.AddChild(levelRow);

        var levelLabel = new Label
        {
            Text = "目标等级",
            CustomMinimumSize = new Vector2(120, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        levelLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        levelLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        levelRow.AddChild(levelLabel);

        _riftLevelSpin = new SpinBox
        {
            MinValue = 1,
            MaxValue = 999,
            Value = 1,
            Step = 1,
            CustomMinimumSize = new Vector2(120, UIStyle.ButtonHeight),
        };
        levelRow.AddChild(_riftLevelSpin);

        var spacer = new Control { SizeFlagsVertical = SizeFlags.ExpandFill };
        _riftPage.AddChild(spacer);

        _startRiftBtn = new IconButton("开启秘境", IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(200, 44),
        };
        _startRiftBtn.Pressed += OnStartRift;
        var btnRow = new HBoxContainer();
        btnRow.Alignment = BoxContainer.AlignmentMode.Center;
        btnRow.AddChild(_startRiftBtn);
        _riftPage.AddChild(btnRow);
    }

    private void BuildGemsPage()
    {
        _gemsPage = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _gemsPage.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        _gemsPage.Visible = false;
        _pageHost.AddChild(_gemsPage);

        _gemsPage.AddChild(new SectionHeader("宝石槽位", "最多镶嵌 6 颗"));

        _gemSlotsGrid = new GridContainer { Columns = 6 };
        _gemSlotsGrid.AddThemeConstantOverride("h_separation", UIStyle.Spacing12);
        _gemSlotsGrid.AddThemeConstantOverride("v_separation", UIStyle.Spacing12);
        _gemsPage.AddChild(_gemSlotsGrid);

        _gemsPage.AddChild(new SectionHeader("说明"));

        var info = new Label
        {
            Text = "镶嵌传奇宝石获得持续增强效果。\n点击空槽位查看可用宝石；点击已镶嵌宝石可升级或卸下。",
            AutowrapMode = TextServer.AutowrapMode.Word,
        };
        info.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        info.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        _gemsPage.AddChild(info);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        if (_statsLabel == null) return;

        _statsLabel.Text =
            $"总物品发现：{_meta.TotalItemsFound}\n" +
            $"传说级发现：{_meta.TotalLegendariesFound}\n" +
            $"游戏时长：{_meta.GetPlaytimeDisplay()}\n" +
            $"总击杀：{GameManager.Instance.TotalKills}\n" +
            $"金币：{GameManager.Instance.Gold}\n" +
            $"碎片：{GameManager.Instance.Scrap}";

        _riftStatusLabel.Text =
            $"最高通关层数：{_riftSystem.HighestRiftCleared}\n" +
            $"持有钥石：{_riftSystem.KeystoneCount}\n" +
            $"当前状态：{GetRiftStateName(_riftSystem.State)}\n" +
            (_riftSystem.State == RiftSystem.RiftState.InProgress
                ? $"剩余时间：{_riftSystem.TimeLimitSeconds - _riftSystem.ElapsedSeconds:F1}s"
                : "可挑战范围：1 - " + (_riftSystem.HighestRiftCleared + 5));
        _startRiftBtn.Disabled = _riftSystem.KeystoneCount <= 0 || _riftSystem.State != RiftSystem.RiftState.Idle;

        RefreshGemSlots();
    }

    private void RefreshGemSlots()
    {
        if (_gemSlotsGrid == null) return;
        foreach (var c in _gemSlotsGrid.GetChildren()) c.QueueFree();

        for (int i = 0; i < GemSystem.MaxGemSlots; i++)
        {
            var idx = i;
            var gem = _gemSystem.EquippedGems[i];
            var slot = new Button
            {
                CustomMinimumSize = new Vector2(80, 80),
                FocusMode = FocusModeEnum.None,
                ClipText = true,
            };
            UIStyle.ApplyStateButton(slot, gem != null ? UIStyle.NavStats : UIStyle.Bg4);
            slot.Pressed += () => OnGemSlotPressed(idx);
            _gemSlotsGrid.AddChild(slot);

            var lbl = new Label
            {
                Text = gem != null ? $"{gem.Name}\nLv.{gem.Level}" : $"槽 {idx + 1}\n[空]",
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Size = new Vector2(80, 80),
                Position = Vector2.Zero,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
            lbl.AddThemeColorOverride("font_color", gem != null ? UIStyle.TextPrimary : UIStyle.TextMuted);
            slot.AddChild(lbl);
        }
    }

    private void OnStartRift()
    {
        int level = (int)_riftLevelSpin.Value;
        if (!_riftSystem.CanStartRift(level))
        {
            ConfirmDialog.Show(this, "无法开启秘境",
                $"等级 {level} 超过可挑战范围（最高 {_riftSystem.HighestRiftCleared + 5}），或钥石不足。",
                () => { }, confirmText: "好的", cancelText: "");
            return;
        }
        ConfirmDialog.Show(
            this,
            "开启秘境",
            $"消耗 1 颗钥石挑战 {level} 层秘境（限时 {180 + level * 5}s），确认？",
            () =>
            {
                _riftSystem.StartRift(level);
                Refresh();
            },
            confirmText: "开启",
            danger: true);
    }

    private void OnGemSlotPressed(int slotIdx)
    {
        var gem = _gemSystem.EquippedGems[slotIdx];
        if (gem != null)
        {
            ConfirmDialog.Show(
                this,
                $"宝石槽 {slotIdx + 1}",
                $"【{gem.Name} Lv.{gem.Level}】\n效果：{gem.EffectKey} 基础 +{gem.EffectBase * (1 + (gem.Level - 1) * 0.1):F2}\n升级花费：{100 * gem.Level} 金币。",
                () => { _gemSystem.LevelUpGem(slotIdx); Refresh(); },
                confirmText: "升级",
                cancelText: "卸下",
                onCancel: () => { _gemSystem.UnsocketGem(slotIdx); Refresh(); });
        }
        else
        {
            if (_gemSystem.OwnedGems.Count == 0)
            {
                ConfirmDialog.Show(this, "暂无宝石", "击败 BOSS 或秘境通关有概率获得宝石。",
                    () => { }, confirmText: "好的", cancelText: "");
                return;
            }
            var first = _gemSystem.OwnedGems[0];
            ConfirmDialog.Show(
                this,
                "镶嵌宝石",
                $"将【{first.Name}】镶嵌到槽位 {slotIdx + 1}？",
                () => { _gemSystem.SocketGem(slotIdx, 0); Refresh(); },
                confirmText: "镶嵌");
        }
    }

    private static string GetRiftStateName(RiftSystem.RiftState state) => state switch
    {
        RiftSystem.RiftState.Idle => "空闲",
        RiftSystem.RiftState.InProgress => "进行中",
        RiftSystem.RiftState.Completed => "已完成",
        RiftSystem.RiftState.Failed => "已失败",
        _ => "未知",
    };
}
