using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Chapter select panel: chapter list, node chain, manual replay, Boss gate display.
/// </summary>
public partial class ChapterSelectPanel : Control
{
    private VBoxContainer _chapterList = null!;
    private Label _infoLabel = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(600, 440);
        Position = new Vector2(340, 140);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "章节选关", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.Accent);
        AddChild(title);

        var scroll = new ScrollContainer { Position = new Vector2(10, 50), Size = new Vector2(380, 370) };
        AddChild(scroll);

        _chapterList = new VBoxContainer();
        _chapterList.AddThemeConstantOverride("separation", 6);
        scroll.AddChild(_chapterList);

        _infoLabel = new Label { Position = new Vector2(400, 50), Size = new Vector2(190, 370) };
        _infoLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _infoLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        AddChild(_infoLabel);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationVisibilityChanged && Visible) Refresh();
    }

    private void Refresh()
    {
        foreach (var child in _chapterList.GetChildren()) child.QueueFree();

        var db = GetNode<ConfigDB>("/root/ConfigDB");
        var gm = GameManager.Instance;

        foreach (var (chapterId, chapter) in db.Chapters)
        {
            bool cleared = gm.ClearedChapters.Contains(chapterId);
            bool isCurrent = chapterId == gm.CurrentChapterId;

            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            _chapterList.AddChild(row);

            string status = cleared ? "[已通关]" : isCurrent ? "[当前]" : "[未解锁]";
            var lbl = new Label { Text = $"{status} {chapter.Name}" };
            lbl.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            lbl.AddThemeColorOverride("font_color", cleared ? UIStyle.Success : isCurrent ? UIStyle.Accent : UIStyle.TextMuted);
            lbl.CustomMinimumSize = new Vector2(260, 0);
            row.AddChild(lbl);

            if (cleared || isCurrent)
            {
                var replayBtn = new Button { Text = "回刷", CustomMinimumSize = new Vector2(60, 28) };
                replayBtn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavInventory));
                replayBtn.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
                var cid = chapterId;
                replayBtn.Pressed += () => OnReplay(cid);
                row.AddChild(replayBtn);
            }

            if (!cleared && !isCurrent)
            {
                var lockLbl = new Label { Text = $"需战力 {chapter.RecommendedPower}" };
                lockLbl.AddThemeFontSizeOverride("font_size", UIStyle.FontTiny);
                lockLbl.AddThemeColorOverride("font_color", UIStyle.Danger);
                row.AddChild(lockLbl);
            }
        }
    }

    private void OnReplay(string chapterId)
    {
        var db = GetNode<ConfigDB>("/root/ConfigDB");
        if (!db.Chapters.TryGetValue(chapterId, out var chapter)) return;
        if (chapter.NodeIds.Length == 0) return;

        var gm = GameManager.Instance;
        gm.CurrentChapterId = chapterId;
        gm.AdvanceToNode(chapter.NodeIds[0]);

        _infoLabel.Text = $"已切换到: {chapter.Name}\n节点: {chapter.NodeIds[0]}";
        GD.Print($"[ChapterSelect] replay {chapterId}");
    }
}
