using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Entities;

public partial class EnemyActor : Node2D
{
    [Export] public string EnemyId { get; set; } = "";
    [Export] public string NodeType { get; set; } = "normal";
    [Export] public double MaxHp { get; set; } = 50;
    [Export] public double Attack { get; set; } = 5;
    [Export] public double Defense { get; set; } = 0;
    [Export] public double AttackSpeed { get; set; } = 0.8;
    [Export] public double MoveSpeed { get; set; } = 60;

    public double CurrentHp { get; set; }
    public bool IsAlive => CurrentHp > 0;
    public bool IsElite => NodeType == "elite";
    public bool IsBoss => NodeType == "boss";

    private double _attackTimer;
    private AnimatedSprite2D? _sprite;
    private Node2D? _target;

    public override void _Ready()
    {
        CurrentHp = MaxHp;
        _sprite = GetNodeOrNull<AnimatedSprite2D>("AnimatedSprite2D");
        _sprite?.Play("idle");
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!IsAlive) return;

        if (_target != null && IsInstanceValid(_target))
        {
            float dist = Position.DistanceTo(_target.Position);
            if (dist > 80)
            {
                var dir = (_target.Position - Position).Normalized();
                Position += dir * (float)(MoveSpeed * delta);
            }
            else
            {
                _attackTimer += delta;
                if (_attackTimer >= 1.0 / AttackSpeed)
                {
                    _attackTimer = 0;
                    if (_target is PlayerActor player && player.IsAlive)
                    {
                        double dmg = Combat.DamageResolver.ApplyDefense(Attack, 0);
                        player.TakeDamage(dmg);
                    }
                }
            }
        }
    }

    public void SetTarget(Node2D? target) => _target = target;

    public void TakeDamage(double amount, bool isCrit)
    {
        double mitigated = Combat.DamageResolver.ApplyDefense(amount, Defense);
        CurrentHp = Mathf.Max(0, CurrentHp - mitigated);

        if (CurrentHp <= 0)
            Die();
    }

    private void Die()
    {
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.EnemyKilled, EnemyId, NodeType);

        var gm = GameManager.Instance;
        gm.TotalKills++;

        long expReward = NodeType switch
        {
            "boss" => 50,
            "elite" => 25,
            _ => 10,
        };
        gm.GainExperience(expReward);

        long goldReward = NodeType switch
        {
            "boss" => 30,
            "elite" => 15,
            _ => 5,
        };
        gm.AddGold(goldReward);

        QueueFree();
    }
}
