using System.Collections.Generic;
using System.Text.Json;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Models;

namespace DesktopIdle.Systems;

/// <summary>
/// Newbie guide engine: manages mandatory sequence (7 steps) and soft tips.
/// Tracks completion, supports interrupt recovery, and red-dot guidance.
/// </summary>
public partial class NewbieGuideSystem : Node
{
    private readonly List<GuideStepDef> _mandatorySteps = new();
    private readonly List<GuideStepDef> _softTips = new();
    private readonly HashSet<string> _completedSteps = new();

    private int _currentMandatoryIndex;
    private double _waitTimer;
    private bool _guideActive;

    public string? CurrentStepId => _guideActive && _currentMandatoryIndex < _mandatorySteps.Count
        ? _mandatorySteps[_currentMandatoryIndex].Id : null;
    public bool IsGuideComplete { get; private set; }

    public override void _Ready()
    {
        LoadSteps();
        var demo = GetNode<DemoManager>("/root/DemoManager");
        if (demo.HasCompletedTutorial)
        {
            IsGuideComplete = true;
            return;
        }
        _guideActive = true;
        AdvanceToStep(0);
        GD.Print($"[GuideSystem] loaded {_mandatorySteps.Count} mandatory + {_softTips.Count} soft tips");
    }

    private void LoadSteps()
    {
        var db = GetNode<ConfigDB>("/root/ConfigDB");
        var doc = db.LoadRawJson("res://data/guide/guide_steps.json");
        if (doc == null) return;

        foreach (var el in doc.RootElement.EnumerateArray())
        {
            var step = new GuideStepDef
            {
                Id = el.GetProperty("id").GetString() ?? "",
                Type = el.GetProperty("type").GetString() == "mandatory" ? GuideType.Mandatory : GuideType.SoftTip,
                Order = el.GetProperty("order").GetInt32(),
                TriggerCondition = el.TryGetProperty("trigger_condition", out var tc) ? tc.GetString() ?? "" : "",
                HighlightTarget = el.TryGetProperty("highlight_target", out var ht) ? ht.GetString() ?? "" : "",
                CompletionCondition = el.TryGetProperty("completion_condition", out var cc) ? cc.GetString() ?? "" : "",
                Message = el.TryGetProperty("message", out var m) ? m.GetString() ?? "" : "",
                TimeoutSeconds = el.TryGetProperty("timeout_seconds", out var ts) ? ts.GetDouble() : 0,
            };

            if (step.Type == GuideType.Mandatory)
                _mandatorySteps.Add(step);
            else
                _softTips.Add(step);
        }

        _mandatorySteps.Sort((a, b) => a.Order.CompareTo(b.Order));
    }

    public override void _Process(double delta)
    {
        if (!_guideActive || IsGuideComplete) return;
        if (_currentMandatoryIndex >= _mandatorySteps.Count) return;

        var step = _mandatorySteps[_currentMandatoryIndex];

        if (step.TimeoutSeconds > 0)
        {
            _waitTimer += delta;
            if (_waitTimer >= step.TimeoutSeconds)
                CompleteCurrentStep();
        }

        if (step.CompletionCondition == "auto")
            CompleteCurrentStep();
    }

    public void NotifyCondition(string condition)
    {
        if (!_guideActive || IsGuideComplete) return;
        if (_currentMandatoryIndex >= _mandatorySteps.Count) return;

        var step = _mandatorySteps[_currentMandatoryIndex];
        if (step.CompletionCondition == condition)
            CompleteCurrentStep();

        foreach (var tip in _softTips)
        {
            if (_completedSteps.Contains(tip.Id)) continue;
            if (tip.TriggerCondition == condition)
            {
                _completedSteps.Add(tip.Id);
                var bus = GetNode<EventBus>("/root/EventBus");
                bus.EmitSignal(EventBus.SignalName.GuideStepTriggered, tip.Id);
            }
        }
    }

    private void CompleteCurrentStep()
    {
        if (_currentMandatoryIndex >= _mandatorySteps.Count) return;

        var step = _mandatorySteps[_currentMandatoryIndex];
        _completedSteps.Add(step.Id);

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.GuideStepTriggered, step.Id);

        _currentMandatoryIndex++;
        if (_currentMandatoryIndex >= _mandatorySteps.Count)
        {
            IsGuideComplete = true;
            _guideActive = false;
            bus.EmitSignal(EventBus.SignalName.GuideCompleted);

            var demo = GetNode<DemoManager>("/root/DemoManager");
            demo.HasCompletedTutorial = true;
            demo.SaveConfig();
            GD.Print("[GuideSystem] tutorial complete!");
        }
        else
        {
            AdvanceToStep(_currentMandatoryIndex);
        }
    }

    private void AdvanceToStep(int index)
    {
        _waitTimer = 0;
        if (index < _mandatorySteps.Count)
            GD.Print($"[GuideSystem] step: {_mandatorySteps[index].Id} — {_mandatorySteps[index].Message}");
    }

    public void SkipGuide()
    {
        IsGuideComplete = true;
        _guideActive = false;

        var demo = GetNode<DemoManager>("/root/DemoManager");
        demo.HasCompletedTutorial = true;
        demo.SaveConfig();

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.GuideCompleted);
    }
}
