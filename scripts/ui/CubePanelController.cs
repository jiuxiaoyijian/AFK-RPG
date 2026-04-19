using System.Collections.Generic;
using System.Linq;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.Systems;
using DesktopIdle.Utils;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// Cube (百炼坊) panel: 5 function tabs (Extract/ForgeSteel/Reforge/Convert/Temper).
/// 每个 tab 展示对应配方的可用装备，点击执行按钮调用 CubeSystem。
/// </summary>
public partial class CubePanelController : Control
{
    private static readonly CubeSystem.CubeAction[] AllActions = new[]
    {
        CubeSystem.CubeAction.Extract, CubeSystem.CubeAction.ForgeSteel,
        CubeSystem.CubeAction.Reforge, CubeSystem.CubeAction.Convert,
        CubeSystem.CubeAction.Temper,
    };

    private UiTabBar _tabBar = null!;
    private VBoxContainer _pageHost = null!;
    private Label _statusLabel = null!;
    private CubeSystem _cubeSystem = null!;

    private readonly Dictionary<CubeSystem.CubeAction, ActionPage> _pages = new();
    private CubeSystem.CubeAction _activeAction = CubeSystem.CubeAction.Extract;

    public override void _Ready()
    {
        _cubeSystem = GetNode<CubeSystem>("/root/GameRoot/Systems/CubeSystem");

        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.ItemSalvaged += (_, _) => Refresh();
        bus.LootDropped += (_, _) => Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "cube",
            Title = "百 炼 坊",
            Subtitle = "萃取 / 锻造 / 重铸 / 转化 / 淬火",
            AccentColor = UIStyle.NavCube,
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

        _pageHost = new VBoxContainer();
        _pageHost.SizeFlagsVertical = SizeFlags.ExpandFill;
        content.AddChild(_pageHost);

        foreach (var action in AllActions)
        {
            string id = action.ToString();
            _tabBar.AddTab(CubeViewModelService.GetActionDisplayName(action), id);

            var page = new ActionPage(action, _cubeSystem, OnExecute);
            page.Visible = false;
            _pageHost.AddChild(page);
            _pages[action] = page;
        }

        _statusLabel = new Label
        {
            Text = "",
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _statusLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _statusLabel.AddThemeColorOverride("font_color", UIStyle.Success);
        content.AddChild(_statusLabel);

        _tabBar.TabSelected += OnTabSelected;
    }

    private void OnTabSelected(string tabId)
    {
        foreach (var (action, page) in _pages)
            page.Visible = action.ToString() == tabId;
        _activeAction = System.Enum.TryParse<CubeSystem.CubeAction>(tabId, out var a) ? a : CubeSystem.CubeAction.Extract;
        Refresh();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        foreach (var (_, page) in _pages)
            page.Refresh();
    }

    private void OnExecute(CubeSystem.RecipeDef recipe, ItemData item)
    {
        string itemName = string.IsNullOrEmpty(item.Name) ? item.BaseId : item.Name;
        ConfirmDialog.Show(
            this,
            CubeViewModelService.GetActionDisplayName(recipe.Action),
            $"对【{ItemPresentationService.GetQualityName(item.Quality)}·{itemName}】执行此操作？\n消耗：{CubeViewModelService.GetCostDisplay(recipe)}",
            () => DoExecute(recipe, item),
            confirmText: "执行",
            danger: recipe.Action is CubeSystem.CubeAction.ForgeSteel or CubeSystem.CubeAction.Convert);
    }

    private void DoExecute(CubeSystem.RecipeDef recipe, ItemData item)
    {
        bool ok = _cubeSystem.Execute(recipe, item);
        _statusLabel.Text = ok ? $"✓ {CubeViewModelService.GetActionDisplayName(recipe.Action)} 完成" : "✗ 条件不满足";
        _statusLabel.AddThemeColorOverride("font_color", ok ? UIStyle.Success : UIStyle.Danger);
        Refresh();
    }

    /// <summary>
    /// 单个动作 tab 的内容：描述 + 可用物品列表 + 执行按钮。
    /// </summary>
    private partial class ActionPage : VBoxContainer
    {
        private readonly CubeSystem.CubeAction _action;
        private readonly CubeSystem _system;
        private readonly System.Action<CubeSystem.RecipeDef, ItemData> _onExecute;

        private Label _descLabel = null!;
        private VBoxContainer _itemList = null!;
        private Control _emptyState = null!;

        public ActionPage(CubeSystem.CubeAction action, CubeSystem system, System.Action<CubeSystem.RecipeDef, ItemData> onExecute)
        {
            _action = action;
            _system = system;
            _onExecute = onExecute;
        }

        public override void _Ready()
        {
            SizeFlagsVertical = SizeFlags.ExpandFill;
            AddThemeConstantOverride("separation", UIStyle.Spacing8);

            _descLabel = new Label
            {
                Text = GetActionDescription(_action),
                AutowrapMode = TextServer.AutowrapMode.Word,
            };
            _descLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            _descLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
            AddChild(_descLabel);

            AddChild(new SectionHeader("可用装备"));

            var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
            AddChild(scroll);

            _itemList = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
            _itemList.AddThemeConstantOverride("separation", UIStyle.Spacing4);
            scroll.AddChild(_itemList);

            _emptyState = new EmptyState("暂无可执行的装备", "请先获取符合条件的装备");
            _emptyState.Visible = false;
            AddChild(_emptyState);
        }

        public void Refresh()
        {
            if (!IsInsideTree() || _itemList == null) return;

            foreach (var c in _itemList.GetChildren()) c.QueueFree();

            var recipe = _system.Recipes.FirstOrDefault(r => r.Action == _action);
            if (recipe == null)
            {
                _emptyState.Visible = true;
                return;
            }

            var validItems = GameManager.Instance.Inventory.Where(i => _system.CanExecute(recipe, i)).ToList();
            _emptyState.Visible = validItems.Count == 0;
            _itemList.Visible = validItems.Count > 0;

            foreach (var item in validItems)
            {
                var row = new HBoxContainer();
                row.AddThemeConstantOverride("separation", UIStyle.Spacing12);
                _itemList.AddChild(row);

                var qualColor = ItemPresentationService.GetQualityColor(item.Quality);
                string itemName = string.IsNullOrEmpty(item.Name) ? item.BaseId : item.Name;
                var nameLabel = new Label
                {
                    Text = $"[{ItemPresentationService.GetQualityName(item.Quality)}] {itemName} (Lv.{item.ItemLevel})",
                    SizeFlagsHorizontal = SizeFlags.ExpandFill,
                    VerticalAlignment = VerticalAlignment.Center,
                };
                nameLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
                nameLabel.AddThemeColorOverride("font_color", qualColor);
                row.AddChild(nameLabel);

                var costLabel = new Label
                {
                    Text = CubeViewModelService.GetCostDisplay(recipe),
                    VerticalAlignment = VerticalAlignment.Center,
                    CustomMinimumSize = new Vector2(120, 0),
                };
                costLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
                costLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
                row.AddChild(costLabel);

                var btn = new IconButton("执行", IconButton.ButtonVariant.Primary)
                {
                    CustomMinimumSize = new Vector2(80, UIStyle.ButtonHeight),
                };
                var capturedItem = item;
                btn.Pressed += () => _onExecute(recipe, capturedItem);
                row.AddChild(btn);
            }
        }

        private static string GetActionDescription(CubeSystem.CubeAction action) => action switch
        {
            CubeSystem.CubeAction.Extract => "萃取传奇装备的特殊词缀，存入武学秘录。",
            CubeSystem.CubeAction.ForgeSteel => "分解装备获取精钢碎片，可用于铸造高品装备。",
            CubeSystem.CubeAction.Reforge => "重新随机珍品及以上装备的词缀数值。",
            CubeSystem.CubeAction.Convert => "将装备转化为通用材料。",
            CubeSystem.CubeAction.Temper => "强化传奇及以上装备的一条词缀（+10%）。",
            _ => "",
        };
    }
}
