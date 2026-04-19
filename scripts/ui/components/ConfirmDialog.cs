using System;
using Godot;

namespace DesktopIdle.UI.Components;

/// <summary>
/// 二次确认弹窗，用于不可逆/破坏性操作（分解、出售、删除存档、重入江湖等）。
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.4
///
/// 用法：
///   ConfirmDialog.Show(rootControl, "分解装备", "确认分解【太古·秋水】？", () => DoSalvage(), danger: true);
/// </summary>
public partial class ConfirmDialog : Control
{
    private Action? _onConfirm;
    private Action? _onCancel;

    private Label _titleLabel = null!;
    private Label _messageLabel = null!;
    private IconButton _confirmBtn = null!;
    private IconButton _cancelBtn = null!;

    /// <summary>
    /// 在指定父节点（通常是顶级 UI 层）上创建并显示一个确认对话框。
    /// </summary>
    public static ConfirmDialog Show(
        Node parent,
        string title,
        string message,
        Action onConfirm,
        string confirmText = "确认",
        string cancelText = "取消",
        bool danger = false,
        Action? onCancel = null)
    {
        var dialog = new ConfirmDialog
        {
            _titleText = title,
            _messageText = message,
            _confirmText = confirmText,
            _cancelText = cancelText,
            _isDanger = danger,
            _onConfirm = onConfirm,
            _onCancel = onCancel,
        };
        parent.AddChild(dialog);
        return dialog;
    }

    private string _titleText = "";
    private string _messageText = "";
    private string _confirmText = "确认";
    private string _cancelText = "取消";
    private bool _isDanger;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Stop;
        ZIndex = 100;

        BuildBackdrop();
        BuildDialog();
    }

    private void BuildBackdrop()
    {
        var backdrop = new ColorRect
        {
            Color = new Color(0, 0, 0, 0.6f),
        };
        backdrop.SetAnchorsPreset(LayoutPreset.FullRect);
        backdrop.MouseFilter = MouseFilterEnum.Stop;
        backdrop.GuiInput += ev =>
        {
            if (ev is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left })
                OnCancel();
        };
        AddChild(backdrop);
    }

    private void BuildDialog()
    {
        var card = new Panel();
        card.SetAnchorsPreset(LayoutPreset.Center);
        card.CustomMinimumSize = new Vector2(380, 180);
        card.Size = new Vector2(380, 180);
        card.OffsetLeft = -190;
        card.OffsetTop = -90;
        card.OffsetRight = 190;
        card.OffsetBottom = 90;
        card.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, _isDanger ? UIStyle.Danger : UIStyle.Accent, 2, 8));
        card.MouseFilter = MouseFilterEnum.Stop;
        AddChild(card);

        var vbox = new VBoxContainer();
        vbox.SetAnchorsPreset(LayoutPreset.FullRect);
        vbox.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        vbox.OffsetLeft = UIStyle.Spacing16;
        vbox.OffsetRight = -UIStyle.Spacing16;
        vbox.OffsetTop = UIStyle.Spacing16;
        vbox.OffsetBottom = -UIStyle.Spacing16;
        card.AddChild(vbox);

        _titleLabel = new Label { Text = _titleText, HorizontalAlignment = HorizontalAlignment.Center };
        _titleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontHeader);
        _titleLabel.AddThemeColorOverride("font_color", _isDanger ? UIStyle.Danger : UIStyle.Accent);
        vbox.AddChild(_titleLabel);

        _messageLabel = new Label
        {
            Text = _messageText,
            HorizontalAlignment = HorizontalAlignment.Center,
            AutowrapMode = TextServer.AutowrapMode.Word,
            SizeFlagsVertical = SizeFlags.ExpandFill,
        };
        _messageLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontBody);
        _messageLabel.AddThemeColorOverride("font_color", UIStyle.TextPrimary);
        vbox.AddChild(_messageLabel);

        var btnRow = new HBoxContainer();
        btnRow.Alignment = BoxContainer.AlignmentMode.Center;
        btnRow.AddThemeConstantOverride("separation", UIStyle.Spacing16);
        vbox.AddChild(btnRow);

        _cancelBtn = new IconButton(_cancelText, IconButton.ButtonVariant.Secondary)
        {
            CustomMinimumSize = new Vector2(110, UIStyle.ButtonHeight),
        };
        _cancelBtn.Pressed += OnCancel;
        btnRow.AddChild(_cancelBtn);

        _confirmBtn = new IconButton(_confirmText, _isDanger ? IconButton.ButtonVariant.Danger : IconButton.ButtonVariant.Primary)
        {
            CustomMinimumSize = new Vector2(110, UIStyle.ButtonHeight),
        };
        _confirmBtn.Pressed += OnConfirm;
        btnRow.AddChild(_confirmBtn);
    }

    private void OnConfirm()
    {
        _onConfirm?.Invoke();
        QueueFree();
    }

    private void OnCancel()
    {
        _onCancel?.Invoke();
        QueueFree();
    }

    public override void _UnhandledInput(InputEvent ev)
    {
        if (ev is InputEventKey { Pressed: true, Keycode: Key.Escape })
        {
            OnCancel();
            GetViewport().SetInputAsHandled();
        }
    }
}
