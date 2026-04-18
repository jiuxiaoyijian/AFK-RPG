using System.Collections.Generic;
using Godot;
using DesktopIdle.Autoload;
using DesktopIdle.Entities;

namespace DesktopIdle.Systems;

/// <summary>
/// Auto-combat engine: spawns waves, manages battle state, drives node progression.
/// </summary>
public partial class CombatSystem : Node
{
    private enum BattleState { Loading, Spawning, Fighting, WaveComplete, NodeComplete, PlayerDead }

    private static readonly PackedScene PlayerScene = GD.Load<PackedScene>("res://scenes/entities/player.tscn");
    private static readonly PackedScene EnemyScene = GD.Load<PackedScene>("res://scenes/entities/enemy.tscn");

    private const float WaveDelay = 1.5f;
    private const float NodeCompleteDelay = 2.0f;
    private const float RespawnDelay = 3.0f;

    private BattleState _state = BattleState.Loading;
    private PlayerActor? _player;
    private readonly List<EnemyActor> _activeEnemies = new();
    private int _currentWave;
    private int _totalWaves;
    private double _stateTimer;

    private Node2D? _playerSpawn;
    private Node2D? _enemyContainer;
    private Node2D? _lootContainer;

    public override void _Ready()
    {
        CallDeferred(MethodName.InitReferences);
    }

    private void InitReferences()
    {
        _playerSpawn = GetNodeOrNull<Node2D>("../../WorldLayer/CombatRunner/PlayerSpawn");
        _enemyContainer = GetNodeOrNull<Node2D>("../../WorldLayer/CombatRunner/EnemyContainer");
        _lootContainer = GetNodeOrNull<Node2D>("../../WorldLayer/CombatRunner/LootContainer");

        var bus = GetNode<EventBus>("/root/EventBus");
        bus.EnemyKilled += OnEnemyKilled;
        bus.PlayerDied += OnPlayerDied;

        StartNode();
    }

    public override void _PhysicsProcess(double delta)
    {
        switch (_state)
        {
            case BattleState.Spawning:
                _stateTimer += delta;
                if (_stateTimer >= WaveDelay)
                {
                    SpawnWave();
                    _state = BattleState.Fighting;
                }
                break;

            case BattleState.WaveComplete:
                _stateTimer += delta;
                if (_stateTimer >= WaveDelay)
                {
                    _currentWave++;
                    if (_currentWave >= _totalWaves)
                    {
                        _state = BattleState.NodeComplete;
                        _stateTimer = 0;
                    }
                    else
                    {
                        _state = BattleState.Spawning;
                        _stateTimer = 0;
                    }
                }
                break;

            case BattleState.NodeComplete:
                _stateTimer += delta;
                if (_stateTimer >= NodeCompleteDelay)
                {
                    GameManager.Instance.MarkNodeCleared(GameManager.Instance.CurrentNodeId);
                    StartNode();
                }
                break;

            case BattleState.PlayerDead:
                _stateTimer += delta;
                if (_stateTimer >= RespawnDelay)
                    StartNode();
                break;
        }
    }

    private void StartNode()
    {
        var configDb = GetNode<ConfigDB>("/root/ConfigDB");
        var nodeId = GameManager.Instance.CurrentNodeId;

        if (!configDb.Nodes.TryGetValue(nodeId, out var nodeDef))
        {
            GD.PrintErr($"[CombatSystem] node {nodeId} not found in ConfigDB");
            return;
        }

        _currentWave = 0;
        _totalWaves = nodeDef.WaveCount;

        ClearAllEnemies();
        SpawnPlayer();

        _state = BattleState.Spawning;
        _stateTimer = 0;

        GD.Print($"[CombatSystem] starting node {nodeDef.Name} ({nodeDef.NodeType}), {_totalWaves} waves");
    }

    private void SpawnPlayer()
    {
        if (_player != null && IsInstanceValid(_player))
            _player.QueueFree();

        _player = PlayerScene.Instantiate<PlayerActor>();
        _player.Position = _playerSpawn?.Position ?? new Vector2(392, 500);
        GetNode("../../WorldLayer/CombatRunner").AddChild(_player);

        var gm = GameManager.Instance;
        _player.MaxHp = gm.MaxHp;
        _player.CurrentHp = gm.MaxHp;
    }

    private void SpawnWave()
    {
        var configDb = GetNode<ConfigDB>("/root/ConfigDB");
        var nodeId = GameManager.Instance.CurrentNodeId;
        if (!configDb.Nodes.TryGetValue(nodeId, out var nodeDef)) return;

        int enemyCount = nodeDef.NodeType switch
        {
            "boss" => 1,
            "elite" => 2,
            _ => GD.RandRange(2, 4),
        };

        for (int i = 0; i < enemyCount; i++)
        {
            var enemy = EnemyScene.Instantiate<EnemyActor>();
            enemy.NodeType = nodeDef.NodeType;
            enemy.EnemyId = $"{nodeDef.EnemyPoolId}_{_currentWave}_{i}";

            float hpMultiplier = nodeDef.NodeType switch
            {
                "boss" => 10f,
                "elite" => 3f,
                _ => 1f,
            };
            enemy.MaxHp = 50 * hpMultiplier * (1 + GameManager.Instance.HeroLevel * 0.1);
            enemy.Attack = 5 * hpMultiplier * 0.3;
            enemy.Defense = nodeDef.NodeType == "boss" ? 10 : 0;

            float spawnX = (float)GD.RandRange(700, 1100);
            enemy.Position = new Vector2(spawnX, 500);

            _enemyContainer?.AddChild(enemy);
            _activeEnemies.Add(enemy);

            if (_player != null)
                enemy.SetTarget(_player);
        }

        if (_player != null && _activeEnemies.Count > 0)
            _player.SetTarget(_activeEnemies[0]);

        var bus = GetNode<EventBus>("/root/EventBus");
        GD.Print($"[CombatSystem] wave {_currentWave + 1}/{_totalWaves}: spawned {enemyCount} {nodeDef.NodeType} enemies");
    }

    private void OnEnemyKilled(string enemyId, string nodeType)
    {
        _activeEnemies.RemoveAll(e => !IsInstanceValid(e) || !e.IsAlive);

        if (_player != null && _activeEnemies.Count > 0)
            _player.SetTarget(_activeEnemies[0]);

        if (_activeEnemies.Count == 0)
        {
            var bus = GetNode<EventBus>("/root/EventBus");
            bus.EmitSignal(EventBus.SignalName.WaveCleared, _currentWave, _totalWaves);
            _state = BattleState.WaveComplete;
            _stateTimer = 0;
        }
    }

    private void OnPlayerDied()
    {
        _state = BattleState.PlayerDead;
        _stateTimer = 0;
        GD.Print("[CombatSystem] player died — respawning in 3s");
    }

    private void ClearAllEnemies()
    {
        foreach (var enemy in _activeEnemies)
        {
            if (IsInstanceValid(enemy))
                enemy.QueueFree();
        }
        _activeEnemies.Clear();
    }
}
