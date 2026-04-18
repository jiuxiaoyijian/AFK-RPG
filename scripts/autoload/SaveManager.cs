using System.Text.Json;
using Godot;
using DesktopIdle.Models;

namespace DesktopIdle.Autoload;

/// <summary>
/// Multi-slot JSON save/load manager.
/// 3 slots, paths: user://desktop_idle_save_{slot}.json
/// Auto-saves on WM_CLOSE_REQUEST.
/// </summary>
public partial class SaveManager : Node
{
    public const int SaveSlotCount = 3;
    public const int DefaultSaveSlot = 1;
    public const int CurrentSaveVersion = 4;

    public int ActiveSlot { get; set; } = DefaultSaveSlot;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.SaveRequested += OnSaveRequested;
        bus.LoadRequested += OnLoadRequested;
        GD.Print("[SaveManager] initialized");
    }

    public override void _Notification(int what)
    {
        if (what == NotificationWMCloseRequest)
        {
            GD.Print("[SaveManager] auto-saving on close...");
            Save(ActiveSlot);
            GetTree().Quit();
        }
    }

    public override void _UnhandledInput(InputEvent ev)
    {
        if (ev is not InputEventKey k || !k.Pressed || k.Echo) return;
        if (ev.IsAction("ui_quick_save"))
        {
            Save(ActiveSlot);
            GetViewport().SetInputAsHandled();
        }
        else if (ev.IsAction("ui_quick_load"))
        {
            Load(ActiveSlot);
            GetViewport().SetInputAsHandled();
        }
    }

    public bool Save(int slot)
    {
        if (slot < 1 || slot > SaveSlotCount) return false;

        var gm = GameManager.Instance;
        var payload = gm.ToSavePayload();
        payload.SaveVersion = CurrentSaveVersion;
        payload.SaveTimestamp = (long)Time.GetUnixTimeFromSystem();

        string json;
        try { json = JsonSerializer.Serialize(payload, JsonOpts); }
        catch (System.Exception ex) { GD.PrintErr($"[SaveManager] serialize error: {ex.Message}"); return false; }

        var path = GetSavePath(slot);
        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Write);
        if (file == null)
        {
            GD.PrintErr($"[SaveManager] cannot write {path}: {FileAccess.GetOpenError()}");
            return false;
        }

        file.StoreString(json);
        GD.Print($"[SaveManager] saved slot {slot}");

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.SaveCompleted, slot, true);
        return true;
    }

    public bool Load(int slot)
    {
        if (slot < 1 || slot > SaveSlotCount) return false;
        var path = GetSavePath(slot);
        if (!FileAccess.FileExists(path))
        {
            GD.Print($"[SaveManager] no save at slot {slot}");
            return false;
        }

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null) return false;

        var json = file.GetAsText();
        SavePayload? payload;
        try { payload = JsonSerializer.Deserialize<SavePayload>(json, JsonOpts); }
        catch (System.Exception ex) { GD.PrintErr($"[SaveManager] parse error: {ex.Message}"); return false; }

        if (payload == null) return false;

        ActiveSlot = slot;
        GameManager.Instance.LoadFromPayload(payload);
        GD.Print($"[SaveManager] loaded slot {slot}");
        return true;
    }

    public bool DeleteSlot(int slot)
    {
        var path = GetSavePath(slot);
        if (FileAccess.FileExists(path))
        {
            DirAccess.RemoveAbsolute(path);
            GD.Print($"[SaveManager] deleted slot {slot}");
            return true;
        }
        return false;
    }

    public SavePayload? PeekSlot(int slot)
    {
        var path = GetSavePath(slot);
        if (!FileAccess.FileExists(path)) return null;

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null) return null;

        try { return JsonSerializer.Deserialize<SavePayload>(file.GetAsText(), JsonOpts); }
        catch { return null; }
    }

    public bool SlotExists(int slot) => FileAccess.FileExists(GetSavePath(slot));

    private static string GetSavePath(int slot) => $"user://desktop_idle_save_{slot}.json";

    private void OnSaveRequested(int slot) => Save(slot);
    private void OnLoadRequested(int slot) => Load(slot);
}
