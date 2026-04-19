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
    private const int GridColumns = 8;

    private GridContainer _grid = null!;
    private VBoxContainer _detailPane = null!;
    private RichTextLabel _detailLabel = null!;
    private Label _emptyDetailHint = null!;
    private Label _pageLabel = null!;
    private OptionButton _sortPicker = null!;
    private OptionButton _filterPicker = null!;
    private Button _prevBtn = null!;
    private Button _nextBtn = null!;
    private IconButton _equipBtn = null!;
    private IconButton _salvageBtn = null!;
    private Control _emptyOverlay = null!;
    private Control _gridContainer = null!;

    private int _currentPage;
    private InventoryViewModelService.SortMode _sortMode = InventoryViewModelService.SortMode.ByQuality;
    private InventoryViewModelService.FilterMode _filterMode = InventoryViewModelService.FilterMode.All;
    private ItemData? _selectedItem;
    private readonly List<ItemCardButton> _cards = new();

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EquipmentChanged += _ => Refresh();
        bus.LootDropped += (_, _) => Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "inventory",
            Title = "背 包",
            Subtitle = "装备 / 整理 / 分解",
            AccentColor = UIStyle.NavInventory,
            PanelWidth = UIStyle.PanelWidthStandard + 80,
            PanelHeight = 540,
        };
        AddChild(chrome);

        var rootRow = new HBoxContainer();
        rootRow.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        rootRow.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        rootRow.SizeFlagsVertical = SizeFlags.ExpandFill;
        chrome.Body.AddChild(rootRow);

        BuildLeftColumn(rootRow);
        BuildRightColumn(rootRow);
    }

    private void BuildLeftColumn(HBoxContainer parent)
    {
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        col.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        col.SizeFlagsVertical = SizeFlags.ExpandFill;
        parent.AddChild(col);

        var toolbar = new HBoxContainer();
        toolbar.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        col.AddChild(toolbar);

        _sortPicker = new OptionButton { CustomMinimumSize = new Vector2(110, UIStyle.ButtonHeight) };
        _sortPicker.AddItem("品质排序"); _sortPicker.AddItem("等级排序");
        _sortPicker.AddItem("部位排序"); _sortPicker.AddItem("名称排序");
        _sortPicker.ItemSelected += idx => { _sortMode = (InventoryViewModelService.SortMode)(int)idx; Refresh(); };
        toolbar.AddChild(_sortPicker);

        _filterPicker = new OptionButton { CustomMinimumSize = new Vector2(110, UIStyle.ButtonHeight) };
        _filterPicker.AddItem("全部"); _filterPicker.AddItem("武器");
        _filterPicker.AddItem("防具"); _filterPicker.AddItem("饰品");
        _filterPicker.AddItem("传说"); _filterPicker.AddItem("传承");
        _filterPicker.ItemSelected += idx => { _filterMode = (InventoryViewModelService.FilterMode)(int)idx; _currentPage = 0; Refresh(); };
        toolbar.AddChild(_filterPicker);

        _gridContainer = new Control { SizeFlagsVertical = SizeFlags.ExpandFill, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        col.AddChild(_gridContainer);

        _grid = new GridContainer { Columns = GridColumns };
        _grid.SetAnchorsPreset(LayoutPreset.TopLeft);
        _grid.AddThemeConstantOverride("h_separation", UIStyle.Spacing4);
        _grid.AddThemeConstantOverride("v_separation", UIStyle.Spacing4);
        _gridContainer.AddChild(_grid);

        _emptyOverlay = new EmptyState("背包空空如也", "前往历练拾取装备", "包");
        _emptyOverlay.Visible = false;
        _gridContainer.AddChild(_emptyOverlay);

        var navRow = new HBoxContainer();
        navRow.Alignment = BoxContainer.AlignmentMode.Center;
        navRow.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        col.AddChild(navRow);

        _prevBtn = new IconButton("<", IconButton.ButtonVariant.Secondary) { CustomMinimumSize = new Vector2(48, UIStyle.ButtonHeight) };
        _prevBtn.Pressed += () => { if (_currentPage > 0) { _currentPage--; Refresh(); } };
        navRow.AddChild(_prevBtn);

        _pageLabel = new Label
        {
            Text = "1/1",
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            CustomMinimumSize = new Vector2(80, 0),
        };
        _pageLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _pageLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        navRow.AddChild(_pageLabel);

        _nextBtn = new IconButton(">", IconButton.ButtonVariant.Secondary) { CustomMinimumSize = new Vector2(48, UIStyle.ButtonHeight) };
        _nextBtn.Pressed += () => { _currentPage++; Refresh(); };
        navRow.AddChild(_nextBtn);
    }

    private void BuildRightColumn(HBoxContainer parent)
    {
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        col.CustomMinimumSize = new Vector2(240, 0);
        col.SizeFlagsVertical = SizeFlags.ExpandFill;
        parent.AddChild(col);

        col.AddChild(new SectionHeader("装备详情"));

        _detailPane = new VBoxContainer();
        _detailPane.SizeFlagsVertical = SizeFlags.ExpandFill;
        _detailPane.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        col.AddChild(_detailPane);

        _emptyDetailHint = new Label
        {
            Text = "← 选择一件装备查看详情",
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        _emptyDetailHint.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _emptyDetailHint.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        _detailPane.AddChild(_emptyDetailHint);

        _detailLabel = new RichTextLabel
        {
            FitContent = true,
            ScrollActive = true,
            BbcodeEnabled = false,
            Visible = false,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        _detailLabel.AddThemeFontSizeOverride("normal_font_size", UIStyle.FontSmall);
        _detailLabel.AddThemeColorOverride("default_color", UIStyle.TextSecondary);
        _detailPane.AddChild(_detailLabel);

        var btnRow = new HBoxContainer();
        btnRow.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        col.AddChild(btnRow);

        _equipBtn = new IconButton("装备", IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(112, UIStyle.ButtonHeight),
            Disabled = true,
        };
        _equipBtn.Pressed += OnEquip;
        btnRow.AddChild(_equipBtn);

        _salvageBtn = new IconButton("分解", IconButton.ButtonVariant.Danger)
        {
            CustomMinimumSize = new Vector2(112, UIStyle.ButtonHeight),
            Disabled = true,
        };
        _salvageBtn.Pressed += OnSalvageRequested;
        btnRow.AddChild(_salvageBtn);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        foreach (var child in _grid.GetChildren()) child.QueueFree();
        _cards.Clear();

        var filtered = InventoryViewModelService.GetFiltered(_filterMode);
        var sorted = InventoryViewModelService.GetSorted(filtered, _sortMode);
        int totalPages = InventoryViewModelService.GetPageCount(sorted.Count);
        _currentPage = Mathf.Clamp(_currentPage, 0, totalPages - 1);
        var page = InventoryViewModelService.GetPage(sorted, _currentPage);

        _pageLabel.Text = $"{_currentPage + 1}/{totalPages}";
        _prevBtn.Disabled = _currentPage <= 0;
        _nextBtn.Disabled = _currentPage >= totalPages - 1;
        _emptyOverlay.Visible = sorted.Count == 0;
        _grid.Visible = sorted.Count > 0;

        foreach (var item in page)
        {
            var card = new ItemCardButton();
            _grid.AddChild(card);
            card.Bind(item);
            _cards.Add(card);
            var captured = item;
            card.Pressed += () => SelectItem(captured);
            if (_selectedItem != null && captured.Uid == _selectedItem.Uid)
                card.SetSelected(true);
        }

        UpdateDetailPane();
    }

    private void SelectItem(ItemData item)
    {
        _selectedItem = item;
        foreach (var c in _cards)
            c.SetSelected(c.BoundItem != null && c.BoundItem.Uid == item.Uid);
        UpdateDetailPane();
    }

    private void UpdateDetailPane()
    {
        bool hasItem = _selectedItem != null;
        _emptyDetailHint.Visible = !hasItem;
        _detailLabel.Visible = hasItem;
        _equipBtn.Disabled = !hasItem;
        _salvageBtn.Disabled = !hasItem;

        if (hasItem)
            _detailLabel.Text = ItemPresentationService.BuildTooltip(_selectedItem!);
    }

    private void OnEquip()
    {
        if (_selectedItem == null) return;
        GameManager.Instance.EquipItem(_selectedItem);
        _selectedItem = null;
        Refresh();
    }

    private void OnSalvageRequested()
    {
        if (_selectedItem == null) return;
        var item = _selectedItem;
        int scrap = (int)item.Quality * 3 + 1;
        string name = string.IsNullOrEmpty(item.Name) ? item.BaseId : item.Name;
        ConfirmDialog.Show(
            this,
            "分解装备",
            $"确认分解【{ItemPresentationService.GetQualityName(item.Quality)}·{name}】？\n将获得 {scrap} 锻造碎片。",
            () => DoSalvage(item, scrap),
            confirmText: "分解",
            danger: true);
    }

    private void DoSalvage(ItemData item, int scrap)
    {
        GameManager.Instance.Inventory.Remove(item);
        GameManager.Instance.AddScrap(scrap);
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.ItemSalvaged, item.Uid, scrap);
        if (_selectedItem != null && _selectedItem.Uid == item.Uid)
            _selectedItem = null;
        Refresh();
    }
}
