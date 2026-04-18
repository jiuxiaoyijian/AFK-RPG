using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.Utils;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// Inventory panel: item grid + detail pane + sort/filter + equip/salvage actions.
/// </summary>
public partial class InventoryPanelController : Control
{
    private GridContainer _grid = null!;
    private VBoxContainer _detailPane = null!;
    private Label _detailLabel = null!;
    private Label _pageLabel = null!;
    private OptionButton _sortPicker = null!;
    private OptionButton _filterPicker = null!;

    private int _currentPage;
    private InventoryViewModelService.SortMode _sortMode = InventoryViewModelService.SortMode.ByQuality;
    private InventoryViewModelService.FilterMode _filterMode = InventoryViewModelService.FilterMode.All;
    private ItemData? _selectedItem;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(800, 520);
        Position = new Vector2(240, 100);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "背 包", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.Accent);
        AddChild(title);

        var toolbar = new HBoxContainer { Position = new Vector2(20, 44) };
        toolbar.AddThemeConstantOverride("separation", 8);
        AddChild(toolbar);

        _sortPicker = new OptionButton();
        _sortPicker.AddItem("品质排序"); _sortPicker.AddItem("等级排序");
        _sortPicker.AddItem("部位排序"); _sortPicker.AddItem("名称排序");
        _sortPicker.ItemSelected += idx => { _sortMode = (InventoryViewModelService.SortMode)(int)idx; Refresh(); };
        toolbar.AddChild(_sortPicker);

        _filterPicker = new OptionButton();
        _filterPicker.AddItem("全部"); _filterPicker.AddItem("武器");
        _filterPicker.AddItem("防具"); _filterPicker.AddItem("饰品");
        _filterPicker.AddItem("传说"); _filterPicker.AddItem("传承");
        _filterPicker.ItemSelected += idx => { _filterMode = (InventoryViewModelService.FilterMode)(int)idx; _currentPage = 0; Refresh(); };
        toolbar.AddChild(_filterPicker);

        _grid = new GridContainer { Columns = 8, Position = new Vector2(20, 76) };
        _grid.AddThemeConstantOverride("h_separation", 4);
        _grid.AddThemeConstantOverride("v_separation", 4);
        AddChild(_grid);

        var navRow = new HBoxContainer { Position = new Vector2(20, 490) };
        navRow.AddThemeConstantOverride("separation", 8);
        AddChild(navRow);

        var prevBtn = new Button { Text = "<" }; prevBtn.Pressed += () => { if (_currentPage > 0) { _currentPage--; Refresh(); } };
        navRow.AddChild(prevBtn);
        _pageLabel = new Label { Text = "1/1" };
        _pageLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        navRow.AddChild(_pageLabel);
        var nextBtn = new Button { Text = ">" }; nextBtn.Pressed += () => { _currentPage++; Refresh(); };
        navRow.AddChild(nextBtn);

        _detailPane = new VBoxContainer { Position = new Vector2(570, 76), Size = new Vector2(210, 400) };
        AddChild(_detailPane);
        _detailLabel = new Label { Text = "选择一件装备" };
        _detailLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _detailLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        _detailPane.AddChild(_detailLabel);

        var equipBtn = new Button { Text = "装备", CustomMinimumSize = new Vector2(100, 32) };
        equipBtn.Pressed += OnEquip;
        _detailPane.AddChild(equipBtn);

        var salvageBtn = new Button { Text = "分解", CustomMinimumSize = new Vector2(100, 32) };
        salvageBtn.Pressed += OnSalvage;
        _detailPane.AddChild(salvageBtn);

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EquipmentChanged += _ => Refresh();
        bus.LootDropped += (_, _) => Refresh();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        foreach (var child in _grid.GetChildren()) child.QueueFree();

        var filtered = InventoryViewModelService.GetFiltered(_filterMode);
        var sorted = InventoryViewModelService.GetSorted(filtered, _sortMode);
        int totalPages = InventoryViewModelService.GetPageCount(sorted.Count);
        _currentPage = Mathf.Clamp(_currentPage, 0, totalPages - 1);
        var page = InventoryViewModelService.GetPage(sorted, _currentPage);

        _pageLabel.Text = $"{_currentPage + 1}/{totalPages}";

        foreach (var item in page)
        {
            var card = new ItemCardButton();
            _grid.AddChild(card);
            card.Bind(item);
            var captured = item;
            card.Pressed += () => SelectItem(captured);
        }
    }

    private void SelectItem(ItemData item)
    {
        _selectedItem = item;
        _detailLabel.Text = ItemPresentationService.BuildTooltip(item);
    }

    private void OnEquip()
    {
        if (_selectedItem == null) return;
        GameManager.Instance.EquipItem(_selectedItem);
        _selectedItem = null;
        Refresh();
    }

    private void OnSalvage()
    {
        if (_selectedItem == null) return;
        GameManager.Instance.Inventory.Remove(_selectedItem);
        int scrap = (int)_selectedItem.Quality * 3 + 1;
        GameManager.Instance.AddScrap(scrap);
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.ItemSalvaged, _selectedItem.Uid, scrap);
        _selectedItem = null;
        Refresh();
    }
}
