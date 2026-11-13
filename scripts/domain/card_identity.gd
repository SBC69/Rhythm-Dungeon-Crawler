# scripts/domain/card_identity.gd
class_name CardIdentity
extends RefCounted

static var _counter: int = 1000

static func generate_instance_id() -> String:
	_counter += 1
	return "inst_%d_%d" % [Time.get_ticks_msec(), _counter]

static func is_equipment_type(card_type: int) -> bool:
	# CardDatabase.CardType enum values:
	# WEAPON = 0, ARMOR = 1, POTION = 2, BUFF = 3, AMULET = 4
	return card_type == 0 or card_type == 1 or card_type == 4

static func create_instance(template: Dictionary) -> Dictionary:
	var inst := template.duplicate(true)
	if not inst.has("instance_id") or str(inst.get("instance_id", "")).is_empty():
		inst["instance_id"] = generate_instance_id()
	if not inst.has("revision"):
		inst["revision"] = 1
	
	var c_type: int = int(inst.get("type", 4))
	if is_equipment_type(c_type):
		inst["count"] = 1
		if not inst.has("upgrade_level"):
			inst["upgrade_level"] = 0
	else:
		inst["count"] = maxi(1, int(inst.get("count", 1)))
	
	return inst

static func can_merge(a: Dictionary, b: Dictionary) -> bool:
	var type_a: int = int(a.get("type", -1))
	var type_b: int = int(b.get("type", -1))
	if type_a != type_b:
		return false
	
	# Equipment never merges
	if is_equipment_type(type_a):
		return false
	
	# Must have matching definition ID
	if str(a.get("id", "")) != str(b.get("id", "")):
		return false
	
	# Must have matching rarity and sell_value
	if int(a.get("rarity", -1)) != int(b.get("rarity", -1)):
		return false
	if int(a.get("sell_value", 0)) != int(b.get("sell_value", 0)):
		return false
	
	# Compare gameplay effect attributes
	var effect_keys := ["heal", "power_buff", "dice_bonus", "extra_reroll", "power", "damage_reduction"]
	for k in effect_keys:
		if a.has(k) or b.has(k):
			if int(a.get(k, 0)) != int(b.get(k, 0)):
				return false
	
	return true

static func increment_revision(card: Dictionary) -> void:
	card["revision"] = int(card.get("revision", 0)) + 1
