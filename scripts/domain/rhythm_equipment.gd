class_name RhythmEquipment
extends RefCounted

# Slots match CardIdentity: weapon 0, armor 1, amulet 4.
# Values are fractions, rolled once and stored on the individual item.
const PROPERTIES: Dictionary = {
	"precision": {"name": "Steady Grip", "min_rarity": 0, "slots": [0, 4], "values": [0.01, 0.02, 0.03, 0.04], "text": "+%s%% hit timing window"},
	"foresight": {"name": "Foresight", "min_rarity": 0, "slots": [1, 4], "values": [0.02, 0.03, 0.04, 0.05], "text": "Notes appear %s%% earlier"},
	"tempo": {"name": "Steady Pulse", "min_rarity": 1, "slots": [0, 4], "values": [0.0, 0.01, 0.015, 0.02], "text": "Battle tempo reduced by %s%%"},
	"opening": {"name": "Composure", "min_rarity": 1, "slots": [0, 1], "values": [0.0, 0.02, 0.03, 0.04], "text": "+%s%% timing window on the first 3 notes"},
	"recovery": {"name": "Second Wind", "min_rarity": 2, "slots": [1, 4], "values": [0.0, 0.0, 0.03, 0.04], "text": "+%s%% timing window on the note after a miss"},
	"restraint": {"name": "Self-Control", "min_rarity": 2, "slots": [0, 1], "values": [0.0, 0.0, 0.10, 0.15], "text": "Stray press penalty reduced by %s%%"},
}
const CAPS: Dictionary = {"precision": 0.06, "foresight": 0.10, "tempo": 0.03, "opening": 0.06, "recovery": 0.06, "restraint": 0.20}
const MAX_WINDOW_BONUS: float = 0.10

static func property_count(rarity: int) -> int:
	return 2 if rarity >= 2 else 1

static func roll_for(card: Dictionary, rng: RandomNumberGenerator = null) -> void:
	var type := int(card.get("type", -1))
	if not CardIdentity.is_equipment_type(type) or card.has("rhythm_affixes"):
		return
	var rarity := clampi(int(card.get("rarity", 0)), 0, 3)
	var pool: Array[String] = []
	for id in PROPERTIES:
		var rule: Dictionary = PROPERTIES[id]
		if rarity >= int(rule.min_rarity) and type in rule.slots:
			pool.append(id)
	var affixes: Array[Dictionary] = []
	for _i in range(mini(property_count(rarity), pool.size())):
		var index := rng.randi_range(0, pool.size() - 1) if rng != null else randi_range(0, pool.size() - 1)
		var id := pool[index]
		pool.remove_at(index)
		affixes.append({"id": id, "value": float(PROPERTIES[id].values[rarity])})
	card["rhythm_affixes"] = affixes

static func affixes_for(card: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var type := int(card.get("type", -1))
	var raw = card.get("rhythm_affixes", [])
	if not CardIdentity.is_equipment_type(type) or not raw is Array:
		return result
	var rarity := clampi(int(card.get("rarity", 0)), 0, 3)
	var seen: Array[String] = []
	for entry in raw:
		if not entry is Dictionary:
			continue
		var id := str(entry.get("id", ""))
		if not PROPERTIES.has(id) or id in seen:
			continue
		var rule: Dictionary = PROPERTIES[id]
		var value = entry.get("value", 0.0)
		if rarity < int(rule.min_rarity) or not type in rule.slots or not (value is float or value is int):
			continue
		if not is_finite(float(value)) or float(value) <= 0.0:
			continue
		result.append({"id": id, "value": minf(float(value), float(rule.values[rarity]))})
		seen.append(id)
		if result.size() >= property_count(rarity):
			break
	return result

static func bonuses_for(equipment: Array) -> Dictionary:
	var result: Dictionary = {}
	for id in CAPS:
		result[id] = 0.0
	for card in equipment:
		if not card is Dictionary:
			continue
		for affix in affixes_for(card):
			result[affix.id] = minf(float(CAPS[affix.id]), float(result[affix.id]) + float(affix.value))
	return result

static func describe(card: Dictionary) -> String:
	var lines: PackedStringArray = []
	for affix in affixes_for(card):
		var rule: Dictionary = PROPERTIES[affix.id]
		lines.append("%s: %s" % [TranslationServer.translate(rule.name), TranslationServer.translate(rule.text) % percent(float(affix.value))])
	return "\n".join(lines)

static func summary(equipment: Array) -> String:
	var bonuses := bonuses_for(equipment)
	var lines: PackedStringArray = []
	for id in PROPERTIES:
		if float(bonuses[id]) > 0.0:
			lines.append(TranslationServer.translate(PROPERTIES[id].text) % percent(float(bonuses[id])))
	if lines.is_empty():
		return TranslationServer.translate("No rhythm combat properties")
	return TranslationServer.translate("Equipped item properties:\n") + "\n".join(lines) + TranslationServer.translate("\nAdditional timing window bonus is capped at 10%.")

static func compact_description(card: Dictionary) -> String:
	var lines: PackedStringArray = []
	for affix in affixes_for(card):
		lines.append("%s %s%s%%" % [TranslationServer.translate(PROPERTIES[affix.id].name), "−" if affix.id in ["tempo", "restraint"] else "+", percent(float(affix.value))])
	return "\n".join(lines)

static func percent(value: float) -> String:
	return ("%.1f" % (value * 100.0)).trim_suffix(".0")
