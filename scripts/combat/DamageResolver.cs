using Godot;

namespace DesktopIdle.Combat;

/// <summary>
/// Static damage calculator implementing the 7-bucket multiplicative formula.
/// Single source of truth for all damage calculations.
/// </summary>
public static class DamageResolver
{
    public struct DamageParams
    {
        public double WeaponDamage;
        public double PrimaryStat;
        public double CritRate;
        public double CritDamage;
        public double SkillDamagePercent;
        public double ElementalDamagePercent;
        public double SetBonusPercent;
        public double LegendaryEffectPercent;
        public double EliteDamagePercent;
    }

    public struct DamageResult
    {
        public double FinalDamage;
        public bool IsCritical;
    }

    public static DamageResult Calculate(DamageParams p)
    {
        bool isCrit = IsCriticalHit(p.CritRate);

        double result = p.WeaponDamage;
        result *= 1.0 + p.PrimaryStat / 100.0;
        if (isCrit)
            result *= 1.0 + p.CritDamage;
        result *= 1.0 + p.SkillDamagePercent;
        result *= 1.0 + p.ElementalDamagePercent;
        result *= 1.0 + p.SetBonusPercent;
        result *= 1.0 + p.LegendaryEffectPercent;
        result *= 1.0 + p.EliteDamagePercent;

        return new DamageResult
        {
            FinalDamage = Mathf.Max(1.0f, (float)result),
            IsCritical = isCrit,
        };
    }

    public static double BuildDamage(double baseAttack, double multiplier, double bonusPercent = 0)
        => Mathf.Max(1.0f, (float)(baseAttack * multiplier * (1.0 + bonusPercent)));

    public static double ApplyDefense(double rawDamage, double defense)
    {
        double mitigation = defense / (defense + 50.0);
        return Mathf.Max(1.0f, (float)(rawDamage * (1.0 - mitigation)));
    }

    public static bool IsCriticalHit(double critRate)
        => GD.Randf() < Mathf.Clamp((float)critRate, 0f, 1f);

    public static double GetExpectedCritMultiplier(double critRate, double critDamage)
        => 1.0 + Mathf.Clamp((float)critRate, 0f, 1f) * critDamage;
}
