using Godot;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Sub-section header inside a panel: title (left) + optional subtitle (right).
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.2
/// </summary>
public partial class SectionHeader : VBoxContainer
{
    private readonly string _title;
    private readonly string _subtitle;

    private Label _titleLabel = null!;
    private Label _subtitleLabel = null!;

    public SectionHeader(string title, string subtitle = "")
    {
        _title = title;
        _subtitle = subtitle;
    }

    public string Title
    {
        get => _titleLabel?.Text ?? _title;
        set { if (_titleLabel != null) _titleLabel.Text = value; }
    }

    public string Subtitle
    {
        get => _subtitleLabel?.Text ?? _subtitle;
        set
        {
            if (_subtitleLabel == null) return;
            _subtitleLabel.Text = value;
            _subtitleLabel.Visible = !string.IsNullOrEmpty(value);
        }
    }

    public override void _Ready()
    {
        AddThemeConstantOverride("separation", UIStyle.Spacing4);

        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        AddChild(row);

        _titleLabel = new Label { Text = _title, VerticalAlignment = VerticalAlignment.Center };
        _titleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        _titleLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        row.AddChild(_titleLabel);

        var spacer = new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        row.AddChild(spacer);

        _subtitleLabel = new Label
        {
            Text = _subtitle,
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Right,
            Visible = !string.IsNullOrEmpty(_subtitle),
        };
        _subtitleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _subtitleLabel.AddThemeColorOverride("font_color", UIStyle.TextMuted);
        row.AddChild(_subtitleLabel);

        var divider = new ColorRect
        {
            Color = UIStyle.Accent,
            CustomMinimumSize = new Vector2(0, 1),
        };
        AddChild(divider);
    }
}
