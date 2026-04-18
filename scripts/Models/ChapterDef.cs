namespace DesktopIdle.Models;

public class ChapterDef
{
    public string Id { get; set; } = "";
    public int Order { get; set; }
    public string Name { get; set; } = "";
    public int RecommendedPower { get; set; }
    public string[] NodeIds { get; set; } = [];
    public string BackgroundId { get; set; } = "";
    public string NextChapterId { get; set; } = "";
}
