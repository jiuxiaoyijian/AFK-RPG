using System.Collections.Generic;
using Godot;

namespace DesktopIdle.Autoload;

/// <summary>
/// Daily goal generation and tracking (每日机缘).
/// Generates 5 daily goals at midnight, tracks completion, awards bonus at full completion.
/// </summary>
public partial class DailyGoalSystem : Node
{
    public record DailyGoal(string Id, string Description, string Type, int Target, int Current, bool Completed);

    private readonly List<DailyGoal> _goals = new();
    private long _lastResetDay;

    public IReadOnlyList<DailyGoal> Goals => _goals;
    public int CompletedCount { get; private set; }
    public bool AllComplete => CompletedCount >= _goals.Count && _goals.Count > 0;

    public override void _Ready()
    {
        _lastResetDay = GetCurrentDay();
        GenerateDailyGoals();
        GD.Print($"[DailyGoalSystem] {_goals.Count} goals generated");
    }

    public override void _Process(double delta)
    {
        long today = GetCurrentDay();
        if (today != _lastResetDay)
        {
            _lastResetDay = today;
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.DailyReset);
            GenerateDailyGoals();
        }
    }

    private void GenerateDailyGoals()
    {
        _goals.Clear();
        CompletedCount = 0;

        _goals.Add(new DailyGoal("daily_kill", "击杀 50 个敌人", "kill", 50, 0, false));
        _goals.Add(new DailyGoal("daily_gold", "获得 500 金币", "gold", 500, 0, false));
        _goals.Add(new DailyGoal("daily_equip", "获得 3 件装备", "loot", 3, 0, false));
        _goals.Add(new DailyGoal("daily_node", "通关 2 个节点", "node", 2, 0, false));
        _goals.Add(new DailyGoal("daily_cube", "百炼坊操作 1 次", "cube", 1, 0, false));

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EnemyKilled += (_, _) => IncrementGoal("daily_kill", 1);
        bus.LootDropped += (_, _) => IncrementGoal("daily_equip", 1);
        bus.NodeCleared += _ => IncrementGoal("daily_node", 1);
    }

    public void IncrementGoal(string goalId, int amount)
    {
        for (int i = 0; i < _goals.Count; i++)
        {
            if (_goals[i].Id != goalId || _goals[i].Completed) continue;

            int newCurrent = _goals[i].Current + amount;
            bool completed = newCurrent >= _goals[i].Target;
            _goals[i] = _goals[i] with { Current = newCurrent, Completed = completed };

            if (completed)
            {
                CompletedCount++;
                var bus = GetNode<EventBus>("/root/EventBus");
                bus.EmitSignal(EventBus.SignalName.DailyGoalCompleted, goalId);

                if (AllComplete)
                {
                    GameManager.Instance.AddGold(1000);
                    GD.Print("[DailyGoalSystem] all goals complete! bonus awarded");
                }
            }
            return;
        }
    }

    public void IncrementGoldGoal(long amount)
    {
        IncrementGoal("daily_gold", (int)amount);
    }

    private static long GetCurrentDay() => (long)Time.GetUnixTimeFromSystem() / 86400;
}
