extends RefCounted


static func get_equipped_set_counts(equipped_items: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for item_variant in equipped_items.values():
		if not item_variant is Dictionary:
			continue
		var item: Dictionary = item_variant
		var set_id: String = String(item.get("set_id", ""))
		if set_id.is_empty():
			set_id = String(item.get("hua_ring_set_id", ""))
			if set_id.is_empty():
				continue
			counts[set_id] = int(counts.get(set_id, 0)) + 2
			continue
		counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts


static func build_set_summary(equipped_items: Dictionary) -> Dictionary:
	var counts: Dictionary = get_equipped_set_counts(equipped_items)
	var active_sets: Array = []
	var total_bonuses: Dictionary = {}
	for set_id_variant in counts.keys():
		var set_id: String = String(set_id_variant)
		var piece_count: int = int(counts.get(set_id_variant, 0))
		var set_data: Dictionary = ConfigDB.get_set(set_id)
		if set_data.is_empty():
			continue
		var active_bonuses: Array = []
		var next_bonus_pieces: int = 0
		for bonus_variant in set_data.get("bonuses", []):
			var bonus: Dictionary = bonus_variant
			var required_pieces: int = int(bonus.get("pieces", 0))
			if piece_count >= required_pieces:
				active_bonuses.append(bonus)
				_add_bonus_to_totals(total_bonuses, bonus)
			elif next_bonus_pieces == 0 or required_pieces < next_bonus_pieces:
				next_bonus_pieces = required_pieces
		active_sets.append({
			"set_id": set_id,
			"name": String(set_data.get("name", set_id)),
			"theme": String(set_data.get("theme", "")),
			"piece_count": piece_count,
			"piece_slots": set_data.get("piece_slots", []).duplicate(true),
			"active_bonuses": active_bonuses,
			"next_bonus_pieces": next_bonus_pieces,
		})
	active_sets.sort_custom(_sort_active_sets)
	return {
		"counts": counts,
		"active_sets": active_sets,
		"total_bonuses": total_bonuses,
		"primary_active_set": active_sets[0] if not active_sets.is_empty() else {},
	}


static func _add_bonus_to_totals(totals: Dictionary, bonus: Dictionary) -> void:
	var stat_key: String = String(bonus.get("stat_key", ""))
	if stat_key.is_empty():
		return
	totals[stat_key] = float(totals.get(stat_key, 0.0)) + float(bonus.get("value", 0.0))


static func _sort_active_sets(a: Dictionary, b: Dictionary) -> bool:
	var a_piece_count: int = int(a.get("piece_count", 0))
	var b_piece_count: int = int(b.get("piece_count", 0))
	if a_piece_count != b_piece_count:
		return a_piece_count > b_piece_count
	var a_bonus_count: int = a.get("active_bonuses", []).size()
	var b_bonus_count: int = b.get("active_bonuses", []).size()
	if a_bonus_count != b_bonus_count:
		return a_bonus_count > b_bonus_count
	return String(a.get("set_id", "")) < String(b.get("set_id", ""))
