using System.Linq;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;
using DesktopIdle.UI.Components;

namespace DesktopIdle.UI;

/// <summary>
/// 章节选择面板：左侧章节列表，右侧详情 + 回刷按钮。统一使用 PanelChrome。
/// 见 文档/02_交互与原型/UI控件与视觉规范.md
/// </summary>
public partial class ChapterSelectPanel : Control
{
    private VBoxContainer _chapterList = null!;
    private VBoxContainer _detailPane = null!;
    private EmptyState _emptyState = null!;
    private string? _selectedChapterId;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        BuildUI();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.ChapterCleared += _ => Refresh();
        bus.NodeCleared += _ => Refresh();
    }

    private void BuildUI()
    {
        var chrome = new PanelChrome
        {
            PanelId = "chapters",
            Title = "章 节 选 关",
            Subtitle = "回刷 / 切换历练之地",
            AccentColor = UIStyle.NavInventory,
            PanelWidth = 760,
            PanelHeight = 480,
        };
        AddChild(chrome);

        var hbox = new HBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        hbox.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        chrome.Body.AddChild(hbox);

        var leftCol = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsStretchRatio = 1.5f,
        };
        leftCol.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        hbox.AddChild(leftCol);

        leftCol.AddChild(new SectionHeader("章节列表"));

        var scroll = new ScrollContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        leftCol.AddChild(scroll);

        _chapterList = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        _chapterList.AddThemeConstantOverride("separation", UIStyle.Spacing4);
        scroll.AddChild(_chapterList);

        var rightCol = new VBoxContainer
        {
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
            SizeFlagsStretchRatio = 1f,
        };
        rightCol.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        hbox.AddChild(rightCol);

        rightCol.AddChild(new SectionHeader("章节详情"));

        _detailPane = new VBoxContainer { SizeFlagsVertical = SizeFlags.ExpandFill };
        _detailPane.AddThemeConstantOverride("separation", UIStyle.Spacing8);
        rightCol.AddChild(_detailPane);

        _emptyState = new EmptyState("点击左侧章节查看详情", "", "?");
        _emptyState.SizeFlagsVertical = SizeFlags.ExpandFill;
        _detailPane.AddChild(_emptyState);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        if (_chapterList == null) return;
        foreach (var child in _chapterList.GetChildren()) child.QueueFree();

        var db = GetNodeOrNull<ConfigDB>("/root/ConfigDB");
        if (db == null) return;

        var gm = GameManager.Instance;
        var ordered = db.Chapters.Values.OrderBy(c => c.Order).ToList();

        if (ordered.Count == 0)
        {
            var empty = new EmptyState("暂无章节配置", "", "?");
            _chapterList.AddChild(empty);
            return;
        }

        if (string.IsNullOrEmpty(_selectedChapterId))
            _selectedChapterId = gm.CurrentChapterId;

        foreach (var ch in ordered)
        {
            bool cleared = gm.ClearedChapters.Contains(ch.Id);
            bool isCurrent = ch.Id == gm.CurrentChapterId;
            bool isSelected = ch.Id == _selectedChapterId;

            var btn = new Button
            {
                Text = $"{(cleared ? "★" : isCurrent ? "●" : "○")}  {ch.Name}",
                CustomMinimumSize = new Vector2(0, 36),
                Alignment = HorizontalAlignment.Left,
                FocusMode = FocusModeEnum.None,
            };
            var color = isSelected ? UIStyle.Accent
                       : cleared ? UIStyle.Success
                       : isCurrent ? UIStyle.NavInventory
                       : UIStyle.Bg4;
            UIStyle.ApplyStateButton(btn, color, UIStyle.FontBody);

            var chId = ch.Id;
            btn.Pressed += () => OnChapterSelected(chId);
            _chapterList.AddChild(btn);
        }

        BuildDetail();
    }

    private void OnChapterSelected(string chapterId)
    {
        _selectedChapterId = chapterId;
        Refresh();
    }

    private void BuildDetail()
    {
        foreach (var child in _detailPane.GetChildren()) child.QueueFree();

        var db = GetNodeOrNull<ConfigDB>("/root/ConfigDB");
        if (db == null || string.IsNullOrEmpty(_selectedChapterId) || !db.Chapters.TryGetValue(_selectedChapterId, out var chapter))
        {
            _emptyState = new EmptyState("点击左侧章节查看详情", "", "?");
            _emptyState.SizeFlagsVertical = SizeFlags.ExpandFill;
            _detailPane.AddChild(_emptyState);
            return;
        }

        var gm = GameManager.Instance;
        bool cleared = gm.ClearedChapters.Contains(chapter.Id);
        bool isCurrent = chapter.Id == gm.CurrentChapterId;

        _detailPane.AddChild(new KeyValueRow("章节", chapter.Name, UIStyle.Accent));
        _detailPane.AddChild(new KeyValueRow("推荐战力", chapter.RecommendedPower.ToString(), UIStyle.TextPrimary));
        _detailPane.AddChild(new KeyValueRow("节点数", chapter.NodeIds.Length.ToString(), UIStyle.TextPrimary));
        _detailPane.AddChild(new KeyValueRow("状态",
            cleared ? "已通关" : isCurrent ? "当前" : "未解锁",
            cleared ? UIStyle.Success : isCurrent ? UIStyle.Accent : UIStyle.TextMuted));

        var spacer = new Control { SizeFlagsVertical = SizeFlags.ExpandFill };
        _detailPane.AddChild(spacer);

        bool canReplay = (cleared || isCurrent) && chapter.NodeIds.Length > 0;
        var replayBtn = new IconButton(
            isCurrent ? "已在此章" : "回刷此章",
            IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(0, UIStyle.ButtonHeight),
            Disabled = !canReplay || isCurrent,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        var chapterId = chapter.Id;
        var firstNode = chapter.NodeIds.Length > 0 ? chapter.NodeIds[0] : "";
        replayBtn.Pressed += () => ConfirmDialog.Show(
            this,
            "回刷章节",
            $"确认回刷【{chapter.Name}】？\n当前进度将重置到首个节点。",
            () => DoReplay(chapterId, firstNode),
            danger: false);
        _detailPane.AddChild(replayBtn);
    }

    private void DoReplay(string chapterId, string firstNodeId)
    {
        if (string.IsNullOrEmpty(firstNodeId)) return;
        var gm = GameManager.Instance;
        gm.CurrentChapterId = chapterId;
        gm.AdvanceToNode(firstNodeId);
        GD.Print($"[ChapterSelect] replay {chapterId} → {firstNodeId}");
        Refresh();
    }
}
