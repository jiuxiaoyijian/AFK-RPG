class_name DamageResolver
extends RefCounted


static func build_damage(base_attack: float, multiplier: float, bonus_percent: float = 0.0) -> float:
	return maxf(1.0, base_attack * multiplier * (1.0 + bonus_percent))


static func apply_defense(raw_damage: float, defense: float) -> float:
	var mitigation: float = defense / (defense + 50.0)
	return maxf(1.0, raw_damage * (1.0 - mitigation))
