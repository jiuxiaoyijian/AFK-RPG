using Godot;
using DesktopIdle.Autoload;

namespace DesktopIdle.Entities;

public partial class PlayerActor : Node2D
{
    [Export] public double MaxHp { get; set; } = 100;
    [Export] public double AttackSpeed { get; set; } = 1.0;
    [Export] public double MoveSpeed { get; set; } = 100;

    public double CurrentHp { get; set; }
    public bool IsAlive => CurrentHp > 0;
    public bool IsAttacking { get; private set; }

    private double _attackTimer;
    private AnimatedSprite2D? _sprite;
    private Node2D? _target;

    public override void _Ready()
    {
        CurrentHp = MaxHp;
        _sprite = GetNodeOrNull<AnimatedSprite2D>("AnimatedSprite2D");
        if (_sprite?.SpriteFrames?.HasAnimation("idle") == true)
            _sprite.Play("idle");
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!IsAlive) return;

        SyncFromGameManager();

        if (_target != null && IsInstanceValid(_target))
        {
            float dist = Position.DistanceTo(_target.Position);
            if (dist > 80)
            {
                var dir = (_target.Position - Position).Normalized();
                Position += dir * (float)(MoveSpeed * delta);
                if (_sprite?.SpriteFrames?.HasAnimation("walk") == true)
                    _sprite.Play("walk");
                IsAttacking = false;
            }
            else
            {
                IsAttacking = true;
                _attackTimer += delta;
                if (_attackTimer >= 1.0 / AttackSpeed)
                {
                    _attackTimer = 0;
                    PerformAttack();
                }
                if (_sprite?.SpriteFrames?.HasAnimation("attack") == true)
                    _sprite.Play("attack");
            }
        }
        else
        {
            if (_sprite?.SpriteFrames?.HasAnimation("idle") == true)
                _sprite.Play("idle");
            IsAttacking = false;
        }
    }

    public void SetTarget(Node2D? target) => _target = target;

    private void PerformAttack()
    {
        if (_target is not EnemyActor enemy || !enemy.IsAlive) return;

        var gm = GameManager.Instance;
        var dmgParams = new Combat.DamageResolver.DamageParams
        {
            WeaponDamage = gm.Dps / Mathf.Max(1, (float)AttackSpeed),
        };

        var result = Combat.DamageResolver.Calculate(dmgParams);
        enemy.TakeDamage(result.FinalDamage, result.IsCritical);
    }

    public void TakeDamage(double amount)
    {
        CurrentHp = Mathf.Max(0, CurrentHp - amount);
        if (CurrentHp <= 0)
            Die();
    }

    public void Heal(double amount)
    {
        CurrentHp = Mathf.Min(MaxHp, CurrentHp + amount);
    }

    private void Die()
    {
        if (_sprite?.SpriteFrames?.HasAnimation("idle") == true)
            _sprite.Play("idle");
        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EmitSignal(EventBus.SignalName.PlayerDied);
    }

    private void SyncFromGameManager()
    {
        var gm = GameManager.Instance;
        MaxHp = gm.MaxHp;
        gm.CurrentHp = CurrentHp;
    }
}
