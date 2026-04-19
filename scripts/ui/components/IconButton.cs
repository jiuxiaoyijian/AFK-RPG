using Godot;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Three-state styled button: Primary / Secondary / Danger / Ghost variants.
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.3
///
/// 用法：
///   var btn = new IconButton("装备", IconButton.ButtonVariant.Primary);
///   btn.Pressed += OnEquip;
///   container.AddChild(btn);
/// </summary>
public partial class IconButton : Button
{
    public enum ButtonVariant { Primary, Secondary, Danger, Ghost }

    private ButtonVariant _variant = ButtonVariant.Primary;
    public ButtonVariant Variant
    {
        get => _variant;
        set { _variant = value; ApplyStyle(); }
    }

    public IconButton() { }

    public IconButton(string text, ButtonVariant variant = ButtonVariant.Primary)
    {
        Text = text;
        _variant = variant;
    }

    public override void _Ready()
    {
        if (CustomMinimumSize == Vector2.Zero)
            CustomMinimumSize = new Vector2(96, UIStyle.ButtonHeight);
        FocusMode = FocusModeEnum.None;
        ApplyStyle();
    }

    private void ApplyStyle()
    {
        var color = _variant switch
        {
            ButtonVariant.Primary => UIStyle.Accent,
            ButtonVariant.Secondary => UIStyle.NavSettings,
            ButtonVariant.Danger => UIStyle.Danger,
            ButtonVariant.Ghost => UIStyle.Bg4,
            _ => UIStyle.Accent,
        };
        UIStyle.ApplyStateButton(this, color);
    }
}
