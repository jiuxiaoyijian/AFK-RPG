using Godot;

namespace DesktopIdle.UI;

/// <summary>
/// Global UI style constants: colors, font sizes, StyleBox factories.
/// All UI controllers reference this for consistent look & feel.
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

    // ── UI Base Colors ──
    public static readonly Color BgDark = new(0.08f, 0.08f, 0.10f);
    public static readonly Color BgPanel = new(0.12f, 0.12f, 0.15f, 0.95f);
    public static readonly Color BgHeader = new(0.15f, 0.14f, 0.18f);
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

    // ── Spacing ──
    public const int PadOuter = 18;
    public const int PadInner = 10;
    public const int PadTight = 4;

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
}
