using Godot;

namespace DesktopIdle.UI.Components;

/// <summary>
/// 标签:值 行控件，用于详情面板的属性展示。
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.7
/// 固定布局：左标签（150px, TextSecondary）+ 右值（flex, TextPrimary）
/// </summary>
public partial class KeyValueRow : HBoxContainer
{
    private readonly string _key;
    private readonly string _value;
    private readonly Color _valueColor;

    private Label _keyLabel = null!;
    private Label _valueLabel = null!;

    public KeyValueRow(string key, string value)
    {
        _key = key;
        _value = value;
        _valueColor = UIStyle.TextPrimary;
    }

    public KeyValueRow(string key, string value, Color valueColor)
    {
        _key = key;
        _value = value;
        _valueColor = valueColor;
    }

    public string Value
    {
        get => _valueLabel?.Text ?? _value;
        set { if (_valueLabel != null) _valueLabel.Text = value; }
    }

    public override void _Ready()
    {
        AddThemeConstantOverride("separation", UIStyle.Spacing12);

        _keyLabel = new Label
        {
            Text = _key,
            CustomMinimumSize = new Vector2(150, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        _keyLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _keyLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        AddChild(_keyLabel);

        _valueLabel = new Label
        {
            Text = _value,
            VerticalAlignment = VerticalAlignment.Center,
            SizeFlagsHorizontal = SizeFlags.ExpandFill,
        };
        _valueLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _valueLabel.AddThemeColorOverride("font_color", _valueColor);
        AddChild(_valueLabel);
    }
}
