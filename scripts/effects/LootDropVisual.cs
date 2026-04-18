using Godot;
using DesktopIdle.Models;

namespace DesktopIdle.Effects;

/// <summary>
/// Visual representation of a loot drop: colored light beam + pickup animation.
/// Instantiated by LootSystem when items drop.
/// </summary>
public partial class LootDropVisual : Node2D
{
    [Export] public string ItemUid { get; set; } = "";
    [Export] public string QualityKey { get; set; } = "common";

    private ColorRect? _beam;
    private float _lifeTimer;
    private const float PickupDelay = 0.8f;
    private const float FlyDuration = 0.4f;
    private bool _pickedUp;

    public override void _Ready()
    {
        var quality = ItemQualityExtensions.FromJsonKey(QualityKey);
        var color = quality.ToColor();

        _beam = new ColorRect
        {
            Size = new Vector2(8, 40),
            Color = new Color(color.R, color.G, color.B, 0.8f),
            Position = new Vector2(-4, -40),
        };
        AddChild(_beam);

        var label = new Label
        {
            Text = QualityKey,
            Position = new Vector2(-20, -55),
        };
        label.AddThemeColorOverride("font_color", color);
        label.AddThemeFontSizeOverride("font_size", 10);
        AddChild(label);
    }

    public override void _Process(double delta)
    {
        _lifeTimer += (float)delta;

        if (!_pickedUp && _lifeTimer >= PickupDelay)
        {
            _pickedUp = true;
            var tween = CreateTween();
            tween.TweenProperty(this, "position", new Vector2(640, 0), FlyDuration)
                 .SetEase(Tween.EaseType.In)
                 .SetTrans(Tween.TransitionType.Quad);
            tween.TweenProperty(this, "modulate:a", 0f, 0.1f);
            tween.TweenCallback(Callable.From(QueueFree));
        }
    }
}
