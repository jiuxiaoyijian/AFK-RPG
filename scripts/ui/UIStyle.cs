using Godot;

namespace DesktopIdle.UI;

/// <summary>
/// Global UI style constants: colors, font sizes, StyleBox factories.
/// All UI controllers reference this for consistent look &amp; feel.
/// 详细规范见 文档/02_交互与原型/UI控件与视觉规范.md
/// </summary>
public static class UIStyle
{
    // ── Quality Colors ──
    public static readonly Color Common = new(0.6f, 0.6f, 0.6f);
    public static readonly Color Magic = new(0.3f, 0.5f, 1f);
    public static readonly Color Rare = new(1f, 0.9f, 0.2f);
    public static readonly Color Legendary = new(1f, 0.6f, 0f);
    public static readonly Color Set = new(0.2f, 0.9f, 0.3f);
    public static readonly Color Ancient = new(0.8f, 0.65f, 0f);
    public static readonly Color Primal = new(0.9f, 0.15f, 0.15f);

    // ── Greyscale Ladder (规范 §2.1) ──
    public static readonly Color Bg0 = new(0.05f, 0.05f, 0.07f);
    public static readonly Color Bg1 = new(0.08f, 0.08f, 0.10f);
    public static readonly Color Bg2 = new(0.12f, 0.12f, 0.15f, 0.95f);
    public static readonly Color Bg3 = new(0.15f, 0.14f, 0.18f);
    public static readonly Color Bg4 = new(0.20f, 0.19f, 0.22f);
    public static readonly Color Bg5 = new(0.28f, 0.27f, 0.30f);

    // 别名（向后兼容）
    public static readonly Color BgDark = Bg1;
    public static readonly Color BgPanel = Bg2;
    public static readonly Color BgHeader = Bg3;

    public static readonly Color Border = new(0.35f, 0.33f, 0.30f);
    public static readonly Color BorderHighlight = new(0.55f, 0.50f, 0.40f);
    public static readonly Color TextPrimary = new(0.92f, 0.90f, 0.85f);
    public static readonly Color TextSecondary = new(0.65f, 0.63f, 0.58f);
    public static readonly Color TextMuted = new(0.45f, 0.43f, 0.40f);
    public static readonly Color Accent = new(0.85f, 0.70f, 0.35f);
    public static readonly Color Danger = new(0.85f, 0.25f, 0.20f);
    public static readonly Color Success = new(0.30f, 0.75f, 0.40f);
    public static readonly Color HpBar = new(0.75f, 0.20f, 0.20f);
    public static readonly Color EnergyBar = new(0.20f, 0.45f, 0.80f);

    // ── Nav Button Colors ──
    public static readonly Color NavInventory = new(0.3f, 0.5f, 1f);
    public static readonly Color NavSkills = new(0.3f, 0.8f, 0.4f);
    public static readonly Color NavCube = new(0.85f, 0.45f, 0.55f);
    public static readonly Color NavResearch = new(0.85f, 0.70f, 0.30f);
    public static readonly Color NavCodex = new(0.3f, 0.75f, 0.75f);
    public static readonly Color NavStats = new(0.75f, 0.45f, 0.55f);
    public static readonly Color NavSettings = new(0.5f, 0.5f, 0.5f);

    // ── Font Sizes ──
    public const int FontTitle = 22;
    public const int FontHeader = 18;
    public const int FontBody = 14;
    public const int FontSmall = 11;
    public const int FontTiny = 9;

    // ── Spacing (4px grid, 规范 §2.3) ──
    public const int Spacing4 = 4;
    public const int Spacing8 = 8;
    public const int Spacing12 = 12;
    public const int Spacing16 = 16;
    public const int Spacing24 = 24;
    public const int Spacing32 = 32;

    // 旧常量（保留向后兼容）
    public const int PadOuter = 18;
    public const int PadInner = 10;
    public const int PadTight = 4;

    // ── Key Sizes (规范 §2.4) ──
    public const int HeaderHeight = 40;
    public const int FooterHeight = 52;
    public const int NavBarHeight = 52;
    public const int ButtonHeight = 32;
    public const int ItemCellSize = 64;

    // ── Standard Panel Widths ──
    public const int PanelWidthCompact = 440;
    public const int PanelWidthStandard = 720;
    public const int PanelWidthWide = 960;

    // ═══════════════════════════════════════════
    // StyleBox factories
    // ═══════════════════════════════════════════

    public static StyleBoxFlat MakePanelBox(Color? bg = null, Color? border = null, int borderWidth = 1, int cornerRadius = 4)
    {
        var box = new StyleBoxFlat
        {
            BgColor = bg ?? BgPanel,
            BorderColor = border ?? Border,
            CornerRadiusTopLeft = cornerRadius,
            CornerRadiusTopRight = cornerRadius,
            CornerRadiusBottomLeft = cornerRadius,
            CornerRadiusBottomRight = cornerRadius,
            BorderWidthLeft = borderWidth,
            BorderWidthRight = borderWidth,
            BorderWidthTop = borderWidth,
            BorderWidthBottom = borderWidth,
            ContentMarginLeft = PadInner,
            ContentMarginRight = PadInner,
            ContentMarginTop = PadInner,
            ContentMarginBottom = PadInner,
        };
        return box;
    }

    public static StyleBoxFlat MakeHeaderBox()
        => MakePanelBox(BgHeader, BorderHighlight, 2, 2);

    public static StyleBoxFlat MakeButtonBox(Color accent)
    {
        var box = MakePanelBox(accent.Darkened(0.6f), accent.Darkened(0.2f), 1, 3);
        box.ContentMarginLeft = 8;
        box.ContentMarginRight = 8;
        box.ContentMarginTop = 4;
        box.ContentMarginBottom = 4;
        return box;
    }

    /// <summary>
    /// Hover 状态：底色提亮 15%
    /// </summary>
    public static StyleBoxFlat MakeHoverBox(Color accent)
        => MakeButtonBox(accent.Lightened(0.15f));

    /// <summary>
    /// Pressed 状态：底色变暗 15%
    /// </summary>
    public static StyleBoxFlat MakePressedBox(Color accent)
        => MakeButtonBox(accent.Darkened(0.15f));

    /// <summary>
    /// Disabled 状态：去饱和 + 透明度
    /// </summary>
    public static StyleBoxFlat MakeDisabledBox(Color accent)
    {
        var disabled = new Color(accent.R, accent.G, accent.B, 0.35f);
        return MakeButtonBox(disabled);
    }

    /// <summary>
    /// 一次性给按钮挂上 normal / hover / pressed / disabled 四态样式。
    /// 替代各处重复的 MakeButtonBox 调用。
    /// </summary>
    public static void ApplyStateButton(Button btn, Color accent, int fontSize = FontBody)
    {
        btn.AddThemeStyleboxOverride("normal", MakeButtonBox(accent));
        btn.AddThemeStyleboxOverride("hover", MakeHoverBox(accent));
        btn.AddThemeStyleboxOverride("pressed", MakePressedBox(accent));
        btn.AddThemeStyleboxOverride("disabled", MakeDisabledBox(accent));
        btn.AddThemeFontSizeOverride("font_size", fontSize);
        btn.AddThemeColorOverride("font_color", TextPrimary);
        btn.AddThemeColorOverride("font_disabled_color", TextMuted);
    }

    /// <summary>
    /// 灰度阶梯背景盒
    /// </summary>
    public static StyleBoxFlat MakeBg(int level, int borderWidth = 0, int cornerRadius = 4)
    {
        var color = level switch
        {
            0 => Bg0, 1 => Bg1, 2 => Bg2, 3 => Bg3, 4 => Bg4, 5 => Bg5, _ => Bg2,
        };
        return MakePanelBox(color, Border, borderWidth, cornerRadius);
    }

    /// <summary>
    /// 选中态边框（2px Accent，背景 Bg4）
    /// </summary>
    public static StyleBoxFlat MakeSelectedBox()
    {
        var box = MakePanelBox(Bg4, Accent, 2, 4);
        box.ContentMarginLeft = 0;
        box.ContentMarginRight = 0;
        box.ContentMarginTop = 0;
        box.ContentMarginBottom = 0;
        return box;
    }
}
