namespace DesktopIdle.Models;

public class SkillDef
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    /// <summary>"core", "active", or "passive"</summary>
    public string SkillType { get; set; } = "core";
    public string Description { get; set; } = "";
    public int UnlockLevel { get; set; } = 1;
    public int MaxLevel { get; set; } = 20;
    public double Cooldown { get; set; }
    public int EnergyCost { get; set; }
    public double BaseMultiplier { get; set; } = 1.0;
    public string IconId { get; set; } = "";
}
