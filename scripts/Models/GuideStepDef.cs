namespace DesktopIdle.Models;

public enum GuideType { Mandatory, SoftTip }

public class GuideStepDef
{
    public string Id { get; set; } = "";
    public GuideType Type { get; set; }
    public int Order { get; set; }
    public string TriggerCondition { get; set; } = "";
    public string HighlightTarget { get; set; } = "";
    public string CompletionCondition { get; set; } = "";
    public string Message { get; set; } = "";
    public double TimeoutSeconds { get; set; }
}
