using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Skill panel: 4 active skill slots + passive skill list.
/// </summary>
public partial class SkillPanelController : Control
{
    private VBoxContainer _content = null!;
    private readonly Button[] _skillSlots = new Button[4];

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        Size = new Vector2(600, 440);
        Position = new Vector2(340, 140);

        var bg = new Panel();
        bg.SetAnchorsPreset(LayoutPreset.FullRect);
        bg.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        AddChild(bg);

        var title = new Label { Text = "技 能", Position = new Vector2(20, 12) };
        title.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        title.AddThemeColorOverride("font_color", UIStyle.NavSkills);
        AddChild(title);

        _content = new VBoxContainer { Position = new Vector2(20, 50) };
        _content.AddThemeConstantOverride("separation", 8);
        AddChild(_content);

        var slotsLabel = new Label { Text = "主动技能位" };
        slotsLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        slotsLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        _content.AddChild(slotsLabel);

        var slotsRow = new HBoxContainer();
        slotsRow.AddThemeConstantOverride("separation", 12);
        _content.AddChild(slotsRow);

        var gm = GameManager.Instance;
        var db = GetNode<ConfigDB>("/root/ConfigDB");

        for (int i = 0; i < 4; i++)
        {
            var slotIdx = i;
            var btn = new Button
            {
                CustomMinimumSize = new Vector2(120, 80),
                Text = gm.EquippedSkillIds[i] ?? $"[空位 {i + 1}]",
            };
            btn.AddThemeStyleboxOverride("normal", UIStyle.MakeButtonBox(UIStyle.NavSkills));
            btn.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
            btn.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
            slotsRow.AddChild(btn);
            _skillSlots[i] = btn;
        }

        _content.AddChild(new HSeparator());

        var passiveLabel = new Label { Text = "被动技能" };
        passiveLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        passiveLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        _content.AddChild(passiveLabel);

        var passiveList = new VBoxContainer();
        _content.AddChild(passiveList);

        foreach (var skill in db.Skills)
        {
            var row = new Label { Text = $"  {skill.Name} — {skill.Description}" };
            row.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
            row.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
            passiveList.AddChild(row);
        }
    }
}
