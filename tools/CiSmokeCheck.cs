using System;
using System.Collections.Generic;
using Godot;

namespace DesktopIdle.Tools;

/// <summary>
/// CI smoke check: validates scene loading, autoloads, JSON data, and key assets.
/// Run via: godot --headless --script res://tools/CiSmokeCheck.cs --quit
/// </summary>
public partial class CiSmokeCheck : SceneTree
{
    private int _passed;
    private int _failed;
    private readonly List<string> _failures = new();

    public override void _Initialize()
    {
        GD.Print("╔═══════════════════════════════════════╗");
        GD.Print("║   CI Smoke Check — 桌面挂机原型       ║");
        GD.Print("╚═══════════════════════════════════════╝");

        CheckSceneLoading();
        CheckAutoloads();
        CheckJsonData();
        CheckPixelAssets();
        CheckNoGdScriptResidue();

        GD.Print("\n══════════════════════════════════════");
        GD.Print($"  Results: {_passed} passed, {_failed} failed");

        if (_failures.Count > 0)
        {
            GD.Print("\n  Failures:");
            foreach (var f in _failures)
                GD.Print($"    ✗ {f}");
        }

        GD.Print("══════════════════════════════════════\n");
        Quit(_failed > 0 ? 1 : 0);
    }

    private void Assert(string name, bool condition)
    {
        if (condition)
        {
            _passed++;
            GD.Print($"  ✓ {name}");
        }
        else
        {
            _failed++;
            _failures.Add(name);
            GD.Print($"  ✗ {name}");
        }
    }

    private void CheckSceneLoading()
    {
        GD.Print("\n[CI-01] Scene Loading");

        var scenes = new[]
        {
            "res://scenes/main/game_root.tscn",
            "res://scenes/entities/player.tscn",
            "res://scenes/entities/enemy.tscn",
            "res://scenes/effects/loot_drop_visual.tscn",
        };

        foreach (var path in scenes)
        {
            bool exists = ResourceLoader.Exists(path);
            Assert($"Scene exists: {path}", exists);
            if (exists)
            {
                var scene = GD.Load<PackedScene>(path);
                Assert($"Scene loadable: {path}", scene != null);
            }
        }
    }

    private void CheckAutoloads()
    {
        GD.Print("\n[CI-02] Autoload Scripts");

        var autoloads = new[]
        {
            "res://scripts/Autoload/EventBus.cs",
            "res://scripts/Autoload/ConfigDB.cs",
            "res://scripts/Autoload/GameManager.cs",
            "res://scripts/Autoload/SaveManager.cs",
            "res://scripts/Autoload/DemoManager.cs",
            "res://scripts/Autoload/OfflineSystem.cs",
            "res://scripts/Autoload/DailyGoalSystem.cs",
            "res://scripts/Autoload/StageEventSystem.cs",
            "res://scripts/Autoload/MetaProgressionSystem.cs",
            "res://scripts/Autoload/LootCodexSystem.cs",
        };

        foreach (var path in autoloads)
            Assert($"Autoload exists: {path}", ResourceLoader.Exists(path));
    }

    private void CheckJsonData()
    {
        GD.Print("\n[CI-03] JSON Data Files");

        var jsonFiles = new[]
        {
            "res://data/chapters/chapter_defs.json",
            "res://data/enemies/enemy_defs.json",
            "res://data/equipment/equipment_bases.json",
            "res://data/equipment/affixes.json",
            "res://data/equipment/legendary_affixes.json",
            "res://data/equipment/cube_recipes.json",
            "res://data/equipment/gems.json",
            "res://data/sets/set_defs.json",
            "res://data/drops/drop_tables.json",
            "res://data/skills/core_skills.json",
            "res://data/progression/hero_levels.json",
            "res://data/progression/research_tree.json",
            "res://data/rift/rift_scaling.json",
            "res://data/rift/rift_keys.json",
            "res://data/backgrounds/parallax_scene_defs.json",
            "res://data/guide/guide_steps.json",
            "res://data/achievements/achievements.json",
            "res://data/achievements/titles.json",
        };

        foreach (var path in jsonFiles)
        {
            bool exists = FileAccess.FileExists(path);
            Assert($"JSON exists: {path}", exists);

            if (exists)
            {
                using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
                bool readable = file != null;
                Assert($"JSON readable: {path}", readable);

                if (readable)
                {
                    string text = file!.GetAsText();
                    bool validJson = !string.IsNullOrEmpty(text) && (text.TrimStart().StartsWith('{') || text.TrimStart().StartsWith('['));
                    Assert($"JSON valid: {path}", validJson);
                }
            }
        }
    }

    private void CheckPixelAssets()
    {
        GD.Print("\n[CI-04] Pixel Placeholder Assets");

        var keyAssets = new[]
        {
            "res://assets/generated/characters/hero_idle_v2.png",
            "res://assets/generated/characters/hero_attack_anim_01.png",
            "res://assets/generated/portraits/enemy_normal_placeholder.png",
            "res://assets/generated/bosses/boss_fuci_shanjun_v2.png",
            "res://assets/generated/afk_rpg_formal/icons/icon_gold.png",
            "res://assets/generated/afk_rpg_formal/ui/panel_bg.png",
            "res://assets/generated/afk_rpg_formal/backgrounds/ch1_layer_sky.png",
            "res://assets/generated/effects/slash_01.png",
            "res://assets/generated/characters/disciple_male_portrait.png",
            "res://assets/generated/afk_rpg_formal/icons/icon_scrap.png",
        };

        foreach (var path in keyAssets)
        {
            bool exists = ResourceLoader.Exists(path);
            Assert($"Asset exists: {path}", exists);
        }
    }

    private void CheckNoGdScriptResidue()
    {
        GD.Print("\n[CI-05] No GDScript Residue");

        var checkPaths = new[] { "scripts/", "tools/", "scenes/" };

        foreach (var dir in checkPaths)
        {
            string fullPath = $"res://{dir}";
            bool hasGd = false;

            if (DirAccess.DirExistsAbsolute(fullPath))
            {
                using var access = DirAccess.Open(fullPath);
                if (access != null)
                {
                    access.ListDirBegin();
                    string fileName;
                    while ((fileName = access.GetNext()) != string.Empty)
                    {
                        if (fileName.EndsWith(".gd"))
                        {
                            hasGd = true;
                            break;
                        }
                    }
                    access.ListDirEnd();
                }
            }

            Assert($"No .gd files in {dir}", !hasGd);
        }
    }
}
