using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI.Components;

/// <summary>
/// Standard panel shell: backdrop + Header (title + close) + Body + optional Footer.
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md §3.1
///
/// 用法：
///   var chrome = new PanelChrome { PanelId = "inventory", Title = "背 包", PanelWidth = 720, PanelHeight = 520 };
///   AddChild(chrome);
///   chrome.Body.AddChild(yourContent);
///   chrome.ShowFooter = true;
///   chrome.Footer.AddChild(yourButtons);
/// </summary>
public partial class PanelChrome : Control
{
    public string PanelId { get; set; } = "";
    public Color AccentColor { get; set; } = UIStyle.Accent;
    public int PanelWidth { get; set; } = UIStyle.PanelWidthStandard;
    public int PanelHeight { get; set; } = 520;

    private string _title = "";
    public string Title
    {
        get => _title;
        set { _title = value; if (_titleLabel != null) _titleLabel.Text = value; }
    }

    private string _subtitle = "";
    public string Subtitle
    {
        get => _subtitle;
        set { _subtitle = value; if (_subtitleLabel != null) { _subtitleLabel.Text = value; _subtitleLabel.Visible = !string.IsNullOrEmpty(value); } }
    }

    private bool _showFooter;
    public bool ShowFooter
    {
        get => _showFooter;
        set { _showFooter = value; if (_footerContainer != null) _footerContainer.Visible = value; }
    }

    /// <summary>
    /// 内容区挂载点（含 Spacing16 内边距），子类把控件 AddChild 到这里
    /// </summary>
    public MarginContainer Body { get; private set; } = null!;

    /// <summary>
    /// 底部按钮挂载点（HBoxContainer，居右对齐）
    /// </summary>
    public HBoxContainer Footer { get; private set; } = null!;

    private Label _titleLabel = null!;
    private Label _subtitleLabel = null!;
    private Button _closeButton = null!;
    private MarginContainer _footerContainer = null!;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.Center);
        GrowHorizontal = GrowDirection.Both;
        GrowVertical = GrowDirection.Both;
        CustomMinimumSize = new Vector2(PanelWidth, PanelHeight);
        Size = new Vector2(PanelWidth, PanelHeight);

        BuildBackdrop();
        BuildLayout();
    }

    private void BuildBackdrop()
    {
        var backdrop = new Panel();
        backdrop.SetAnchorsPreset(LayoutPreset.FullRect);
        backdrop.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.BgPanel, UIStyle.BorderHighlight, 2, 8));
        backdrop.MouseFilter = MouseFilterEnum.Stop;
        AddChild(backdrop);
    }

    private void BuildLayout()
    {
        var root = new VBoxContainer();
        root.SetAnchorsPreset(LayoutPreset.FullRect);
        root.AddThemeConstantOverride("separation", 0);
        AddChild(root);

        BuildHeader(root);
        BuildBody(root);
        BuildFooter(root);
    }

    private void BuildHeader(VBoxContainer parent)
    {
        var header = new PanelContainer();
        header.CustomMinimumSize = new Vector2(0, UIStyle.HeaderHeight);
        var headerStyle = UIStyle.MakePanelBox(UIStyle.BgHeader, UIStyle.BorderHighlight, 0, 0);
        headerStyle.BorderWidthBottom = 1;
        headerStyle.ContentMarginLeft = UIStyle.Spacing16;
        headerStyle.ContentMarginRight = UIStyle.Spacing8;
        headerStyle.ContentMarginTop = 0;
        headerStyle.ContentMarginBottom = 0;
        header.AddThemeStyleboxOverride("panel", headerStyle);
        parent.AddChild(header);

        var hbox = new HBoxContainer();
        hbox.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        header.AddChild(hbox);

        _titleLabel = new Label { Text = _title, VerticalAlignment = VerticalAlignment.Center };
        _titleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontTitle);
        _titleLabel.AddThemeColorOverride("font_color", AccentColor);
        hbox.AddChild(_titleLabel);

        _subtitleLabel = new Label
        {
            Text = _subtitle,
            VerticalAlignment = VerticalAlignment.Center,
            Visible = !string.IsNullOrEmpty(_subtitle),
        };
        _subtitleLabel.AddThemeFontSizeOverride("font_size", UIStyle.FontSmall);
        _subtitleLabel.AddThemeColorOverride("font_color", UIStyle.TextSecondary);
        hbox.AddChild(_subtitleLabel);

        var spacer = new Control { SizeFlagsHorizontal = SizeFlags.ExpandFill };
        hbox.AddChild(spacer);

        _closeButton = new Button
        {
            Text = "×",
            CustomMinimumSize = new Vector2(28, 28),
            FocusMode = FocusModeEnum.None,
        };
        UIStyle.ApplyStateButton(_closeButton, UIStyle.NavSettings, UIStyle.FontHeader);
        _closeButton.Pressed += OnClose;
        hbox.AddChild(_closeButton);
    }

    private void BuildBody(VBoxContainer parent)
    {
        Body = new MarginContainer();
        Body.SizeFlagsVertical = SizeFlags.ExpandFill;
        Body.AddThemeConstantOverride("margin_left", UIStyle.Spacing16);
        Body.AddThemeConstantOverride("margin_right", UIStyle.Spacing16);
        Body.AddThemeConstantOverride("margin_top", UIStyle.Spacing12);
        Body.AddThemeConstantOverride("margin_bottom", UIStyle.Spacing12);
        parent.AddChild(Body);
    }

    private void BuildFooter(VBoxContainer parent)
    {
        _footerContainer = new MarginContainer { Visible = _showFooter };
        _footerContainer.CustomMinimumSize = new Vector2(0, UIStyle.FooterHeight);
        _footerContainer.AddThemeConstantOverride("margin_left", UIStyle.Spacing16);
        _footerContainer.AddThemeConstantOverride("margin_right", UIStyle.Spacing16);
        _footerContainer.AddThemeConstantOverride("margin_top", UIStyle.Spacing8);
        _footerContainer.AddThemeConstantOverride("margin_bottom", UIStyle.Spacing12);

        var topBorder = new Panel { CustomMinimumSize = new Vector2(0, 1) };
        topBorder.AddThemeStyleboxOverride("panel", UIStyle.MakePanelBox(UIStyle.Border, UIStyle.Border, 0, 0));

        var footerOuter = new VBoxContainer();
        footerOuter.AddThemeConstantOverride("separation", 0);
        footerOuter.AddChild(topBorder);
        footerOuter.AddChild(_footerContainer);
        parent.AddChild(footerOuter);

        Footer = new HBoxContainer();
        Footer.Alignment = BoxContainer.AlignmentMode.End;
        Footer.AddThemeConstantOverride("separation", UIStyle.Spacing12);
        Footer.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _footerContainer.AddChild(Footer);
    }

    private void OnClose()
    {
        if (string.IsNullOrEmpty(PanelId))
        {
            Visible = false;
            return;
        }
        var bus = GetNodeOrNull<EventBus>("/root/EventBus");
        bus?.EmitSignal(EventBus.SignalName.UiPanelClosed, PanelId);
    }
}
