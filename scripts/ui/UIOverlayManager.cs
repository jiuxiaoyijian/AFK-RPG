using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.UI;

/// <summary>
/// Manages panel mutual exclusion and the top-level UI state machine.
/// States: Idle → PanelOpen / Blocking.
/// Only one panel can be open at a time; requesting a new one closes the old.
/// </summary>
public partial class UIOverlayManager : Node
{
    public enum UIState { Idle, PanelOpen, Blocking }

    public UIState CurrentState { get; private set; } = UIState.Idle;
    public string? ActivePanelId { get; private set; }

    private readonly Dictionary<string, Control> _panels = new();
    private Control? _dimmer;

    private static readonly Dictionary<string, string> HotkeyMap = new()
    {
        { "ui_inventory", "inventory" },
        { "ui_skills", "skills" },
        { "ui_cube", "cube" },
        { "ui_research", "research" },
        { "ui_codex", "codex" },
        { "ui_drop_stats", "drop_stats" },
        { "ui_achievement", "achievement" },
        { "ui_chapters", "chapters" },
        { "ui_gm_panel", "gm" },
    };

    private static readonly Dictionary<string, string> PanelNodeMap = new()
    {
        { "InventoryPanel", "inventory" },
        { "SkillPanel", "skills" },
        { "CubePanel", "cube" },
        { "ResearchPanel", "research" },
        { "CodexPanel", "codex" },
        { "DropStatsPanel", "drop_stats" },
        { "SettingsPanel", "settings" },
        { "AchievementPanel", "achievement" },
        { "ChapterSelectPanel", "chapters" },
        { "GmPanel", "gm" },
    };

    public override void _Ready()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.UiPanelRequested += OnPanelRequested;
        bus.UiPanelClosed += OnPanelClosed;
        bus.UiCloseAllRequested += CloseAll;
        bus.StageEventTriggered += OnStageEvent;
        bus.OfflineReportReady += OnBlockingEvent;

        CallDeferred(MethodName.AutoRegister);
    }

    private void AutoRegister()
    {
        var parent = GetParent();
        if (parent == null) return;

        foreach (var (nodeName, panelId) in PanelNodeMap)
        {
            var panel = parent.GetNodeOrNull<Control>(nodeName);
            if (panel != null)
                RegisterPanel(panelId, panel);
        }

        var dimmer = parent.GetNodeOrNull<Control>("UIDimmer");
        if (dimmer != null)
            RegisterDimmer(dimmer);
    }

    public void RegisterDimmer(Control dimmer)
    {
        _dimmer = dimmer;
        _dimmer.Visible = false;
        _dimmer.GuiInput += OnDimmerInput;
    }

    private void OnDimmerInput(InputEvent ev)
    {
        if (ev is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left })
            CloseAll();
    }

    public void RegisterPanel(string panelId, Control panel)
    {
        _panels[panelId] = panel;
        panel.Visible = false;
    }

    public override void _UnhandledInput(InputEvent ev)
    {
        if (ev is not InputEventKey keyEvent || !keyEvent.Pressed || keyEvent.Echo) return;

        if (keyEvent.Keycode == Key.Escape)
        {
            if (CurrentState == UIState.PanelOpen)
            {
                CloseAll();
                GetViewport().SetInputAsHandled();
            }
            return;
        }

        foreach (var (action, panelId) in HotkeyMap)
        {
            if (!InputMap.HasAction(action)) continue;
            if (!ev.IsAction(action)) continue;

            if (CurrentState == UIState.PanelOpen && ActivePanelId == panelId)
                CloseAll();
            else
                RequestPanel(panelId);

            GetViewport().SetInputAsHandled();
            return;
        }
    }

    public void RequestPanel(string panelId)
    {
        if (CurrentState == UIState.Blocking) return;

        if (ActivePanelId == panelId) return;

        if (ActivePanelId != null)
            HidePanel(ActivePanelId);

        ShowPanel(panelId);
    }

    public void CloseAll()
    {
        var prev = ActivePanelId;
        ActivePanelId = null;
        CurrentState = UIState.Idle;

        if (prev != null)
            HidePanel(prev);

        SetDimmer(false);
    }

    private void ShowPanel(string panelId)
    {
        if (_panels.TryGetValue(panelId, out var panel))
            panel.Visible = true;

        ActivePanelId = panelId;
        CurrentState = UIState.PanelOpen;
        SetDimmer(true);

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.UiPanelRequested, panelId);
    }

    private void HidePanel(string panelId)
    {
        if (_panels.TryGetValue(panelId, out var panel))
            panel.Visible = false;

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.UiPanelClosed, panelId);
    }

    private void SetDimmer(bool visible)
    {
        if (_dimmer != null)
            _dimmer.Visible = visible;
    }

    private void OnPanelRequested(string panelId)
    {
        if (ActivePanelId != panelId)
            RequestPanel(panelId);
    }

    private void OnPanelClosed(string panelId)
    {
        if (ActivePanelId == panelId)
            CloseAll();
    }

    private void OnStageEvent(string eventType, string payload)
    {
        CloseAll();
        CurrentState = UIState.Blocking;
    }

    private void OnBlockingEvent(double secondsAway, string rewardJson)
    {
        CloseAll();
        CurrentState = UIState.Blocking;
    }

    public void UnblockUI()
    {
        if (CurrentState == UIState.Blocking)
        {
            CurrentState = UIState.Idle;
            SetDimmer(false);
        }
    }
}
