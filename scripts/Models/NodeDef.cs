namespace DesktopIdle.Models;

public class NodeDef
{
    public string Id { get; set; } = "";
    public string ChapterId { get; set; } = "";
    public string Name { get; set; } = "";
    /// <summary>"normal", "elite", or "boss"</summary>
    public string NodeType { get; set; } = "normal";
    public string EnemyPoolId { get; set; } = "";
    public int WaveCount { get; set; }
    public int TimeLimit { get; set; }
    public string NextNodeId { get; set; } = "";

    public bool IsElite => NodeType == "elite";
    public bool IsBoss => NodeType == "boss";
}
