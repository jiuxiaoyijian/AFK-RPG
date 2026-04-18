using Godot;

namespace DesktopIdle.Utils;

/// <summary>
/// Loads textures at runtime from res:// paths.
/// Handles missing files gracefully with a fallback placeholder.
/// </summary>
public static class RuntimeTextureLoader
{
    private static Texture2D? _fallback;

    public static Texture2D Fallback
    {
        get
        {
            if (_fallback != null) return _fallback;
            var img = Image.CreateEmpty(32, 32, false, Image.Format.Rgba8);
            img.Fill(new Color(0.5f, 0.2f, 0.5f));
            _fallback = ImageTexture.CreateFromImage(img);
            return _fallback;
        }
    }

    public static Texture2D Load(string resPath)
    {
        if (string.IsNullOrEmpty(resPath))
            return Fallback;

        if (!ResourceLoader.Exists(resPath))
        {
            GD.PrintErr($"[TextureLoader] not found: {resPath}");
            return Fallback;
        }

        var res = GD.Load<Texture2D>(resPath);
        return res ?? Fallback;
    }

    public static Texture2D? TryLoad(string resPath)
    {
        if (string.IsNullOrEmpty(resPath) || !ResourceLoader.Exists(resPath))
            return null;
        return GD.Load<Texture2D>(resPath);
    }

    public static Texture2D CreateSolidColor(int width, int height, Color color)
    {
        var img = Image.CreateEmpty(width, height, false, Image.Format.Rgba8);
        img.Fill(color);
        return ImageTexture.CreateFromImage(img);
    }
}
