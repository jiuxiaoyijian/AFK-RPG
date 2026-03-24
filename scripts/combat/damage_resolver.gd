class_name DamageResolver
extends RefCounted


static func calculate_damage(params: Dictionary) -> float:
	var base: float = params.get("weapon_damage", 1.0)
	var primary_stat: float = params.get("primary_stat", 0.0)
	var crit_rate: float = params.get("crit_rate", 0.0)
	var crit_damage: float = params.get("crit_damage", 0.0)
	var skill_dmg: float = params.get("skill_damage_percent", 0.0)
	var elemental: float = params.get("elemental_damage_percent", 0.0)
	var set_bonus: float = params.get("set_bonus_percent", 0.0)
	var legendary: float = params.get("legendary_effect_percent", 0.0)
	var elite: float = params.get("elite_damage_percent", 0.0)
	var is_crit: bool = is_critical_hit(crit_rate)

	var result: float = base
	result *= (1.0 + primary_stat / 100.0)
	if is_crit:
		result *= (1.0 + crit_damage)
	result *= (1.0 + skill_dmg)
	result *= (1.0 + elemental)
	result *= (1.0 + set_bonus)
	result *= (1.0 + legendary)
	result *= (1.0 + elite)
	return maxf(1.0, result)


static func build_damage(base_attack: float, multiplier: float, bonus_percent: float = 0.0) -> float:
	return maxf(1.0, base_attack * multiplier * (1.0 + bonus_percent))


static func apply_defense(raw_damage: float, defense: float) -> float:
	var mitigation: float = defense / (defense + 50.0)
	return maxf(1.0, raw_damage * (1.0 - mitigation))


static func is_critical_hit(crit_rate: float) -> bool:
	return randf() < clampf(crit_rate, 0.0, 1.0)


static func get_expected_crit_multiplier(crit_rate: float, crit_damage: float) -> float:
	return 1.0 + clampf(crit_rate, 0.0, 1.0) * crit_damage
