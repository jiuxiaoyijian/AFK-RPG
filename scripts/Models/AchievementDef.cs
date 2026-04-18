namespace DesktopIdle.Models;

public enum AchievementCategory { Combat, Collection, Exploration, Rebirth, Milestone }

public class AchievementDef
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public AchievementCategory Category { get; set; }
    public string ConditionType { get; set; } = "";
    public long ConditionTarget { get; set; }
    public string RewardType { get; set; } = "";
    public string RewardValue { get; set; } = "";
    public bool Hidden { get; set; }
}

public class TitleDef
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string RequiredAchievementId { get; set; } = "";
}
