extends Node

# Card types
enum CardType {
	WEAPON,
	ARMOR,
	POTION,
	BUFF,
	AMULET
}

# Card rarities
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

# Card definition dictionary
var _base_cards: Dictionary = {
	"rusty_sword": {
		"id": "rusty_sword",
		"name": "Rusty Sword",
		"type": CardType.WEAPON,
		"rarity": Rarity.COMMON,
		"power": 2,
		"description": "+2 permanent hero power",
		"icon": "res://assets/sprites/cards/sword.png"
	},
	"iron_blade": {
		"id": "iron_blade",
		"name": "Iron Blade",
		"type": CardType.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"power": 4,
		"description": "+4 permanent hero power",
		"icon": "res://assets/sprites/cards/sword.png"
	},
	"radiant_broadsword": {
		"id": "radiant_broadsword",
		"name": "Radiant Broadsword",
		"type": CardType.WEAPON,
		"rarity": Rarity.RARE,
		"power": 7,
		"description": "+7 permanent hero power",
		"icon": "res://assets/sprites/cards/sword.png"
	},
	"leather_armor": {
		"id": "leather_armor",
		"name": "Leather Armor",
		"type": CardType.ARMOR,
		"rarity": Rarity.COMMON,
		"power": 2,
		"damage_reduction": 1,
		"description": "+2 power, -1 damage on failure",
		"icon": "res://assets/sprites/cards/shield.png"
	},
	"spiked_shield": {
		"id": "spiked_shield",
		"name": "Spiked Shield",
		"type": CardType.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"power": 4,
		"damage_reduction": 2,
		"description": "+4 power, -2 damage on failure",
		"icon": "res://assets/sprites/cards/shield.png"
	},
	"royal_plate": {
		"id": "royal_plate",
		"name": "Royal Plate",
		"type": CardType.ARMOR,
		"rarity": Rarity.RARE,
		"power": 7,
		"damage_reduction": 4,
		"description": "+7 power, -4 damage on failure",
		"icon": "res://assets/sprites/cards/shield.png"
	},
	"minor_health_potion": {
		"id": "minor_health_potion",
		"name": "Minor Health Potion",
		"type": CardType.POTION,
		"rarity": Rarity.COMMON,
		"heal": 15,
		"description": "Restores +15 HP (consumable)",
		"icon": "res://assets/sprites/cards/potion.png"
	},
	"greater_health_potion": {
		"id": "greater_health_potion",
		"name": "Greater Health Potion",
		"type": CardType.POTION,
		"rarity": Rarity.UNCOMMON,
		"heal": 35,
		"description": "Restores +35 HP (consumable)",
		"icon": "res://assets/sprites/cards/potion.png"
	},
	"scroll_of_might": {
		"id": "scroll_of_might",
		"name": "Scroll of Might",
		"type": CardType.BUFF,
		"rarity": Rarity.COMMON,
		"power_buff": 3,
		"description": "+3 power for this battle",
		"icon": "res://assets/sprites/cards/scroll.png"
	},
	"scroll_of_arcane_power": {
		"id": "scroll_of_arcane_power",
		"name": "Arcane Scroll",
		"type": CardType.BUFF,
		"rarity": Rarity.UNCOMMON,
		"power_buff": 6,
		"description": "+6 power for this battle",
		"icon": "res://assets/sprites/cards/scroll.png"
	},
	"lucky_dice_amulet": {
		"id": "lucky_dice_amulet",
		"name": "Lucky Dice Amulet",
		"type": CardType.AMULET,
		"rarity": Rarity.COMMON,
		"dice_bonus": 2,
		"description": "+2 to escape and saving rolls",
		"icon": "res://assets/sprites/cards/dice.png"
	},
	"golden_ring_reroll": {
		"id": "golden_ring_reroll",
		"name": "Ring of Fortune",
		"type": CardType.AMULET,
		"rarity": Rarity.UNCOMMON,
		"extra_reroll": 1,
		"description": "+1 extra free reroll",
		"icon": "res://assets/sprites/cards/ring.png"
	}
}

var _alchemy_cards: Dictionary = {
	"herbal_health_potion": {
		"id": "herbal_health_potion",
		"name": "Herbal Health Potion",
		"type": CardType.POTION,
		"rarity": Rarity.COMMON,
		"heal": 25,
		"sell_value": 15,
		"description": "Restores +25 HP (consumable)",
		"icon": "res://assets/sprites/cards/potion.png",
		"alchemist_stage": 1
	},
	"scroll_of_resolve": {
		"id": "scroll_of_resolve",
		"name": "Scroll of Resolve",
		"type": CardType.BUFF,
		"rarity": Rarity.COMMON,
		"power_buff": 4,
		"sell_value": 15,
		"description": "+4 power for this battle",
		"icon": "res://assets/sprites/cards/scroll.png",
		"alchemist_stage": 1
	},
	"restoration_health_potion": {
		"id": "restoration_health_potion",
		"name": "Restoration Potion",
		"type": CardType.POTION,
		"rarity": Rarity.RARE,
		"heal": 50,
		"sell_value": 60,
		"description": "Restores +50 HP (consumable)",
		"icon": "res://assets/sprites/cards/potion.png",
		"alchemist_stage": 2
	},
	"scroll_of_valor": {
		"id": "scroll_of_valor",
		"name": "Scroll of Valor",
		"type": CardType.BUFF,
		"rarity": Rarity.RARE,
		"power_buff": 9,
		"sell_value": 60,
		"description": "+9 power for this battle",
		"icon": "res://assets/sprites/cards/scroll.png",
		"alchemist_stage": 2
	},
	"vital_health_potion": {
		"id": "vital_health_potion",
		"name": "Vital Health Potion",
		"type": CardType.POTION,
		"rarity": Rarity.LEGENDARY,
		"heal": 75,
		"sell_value": 120,
		"description": "Restores +75 HP (consumable)",
		"icon": "res://assets/sprites/cards/potion.png",
		"alchemist_stage": 3
	},
	"scroll_of_dominion": {
		"id": "scroll_of_dominion",
		"name": "Scroll of Dominion",
		"type": CardType.BUFF,
		"rarity": Rarity.LEGENDARY,
		"power_buff": 12,
		"sell_value": 120,
		"description": "+12 power for this battle",
		"icon": "res://assets/sprites/cards/scroll.png",
		"alchemist_stage": 3
	}
}

var _snapshotted_run_generation: int = -1
var _snapshotted_alchemist_stage: int = -1
var _snapshotted_pool: Dictionary = {}

var cards: Dictionary:
	get:
		var gm = null
		var main_loop = Engine.get_main_loop()
		if main_loop != null and main_loop is SceneTree and main_loop.root != null:
			gm = main_loop.root.get_node_or_null("GameManager")

		var cur_gen = 0
		var alch_stage = 0
		if gm != null:
			cur_gen = int(gm.run_generation)
			if not gm.player_profile.is_empty():
				alch_stage = int(gm.player_profile.get("village_object_stages", {}).get("alchemist", 0))

		if cur_gen != _snapshotted_run_generation or _snapshotted_pool.is_empty() or alch_stage < _snapshotted_alchemist_stage:
			_snapshotted_run_generation = cur_gen
			_snapshotted_alchemist_stage = alch_stage
			var result = _base_cards.duplicate(true)
			if alch_stage >= 1:
				result["herbal_health_potion"] = _alchemy_cards["herbal_health_potion"]
				result["scroll_of_resolve"] = _alchemy_cards["scroll_of_resolve"]
			if alch_stage >= 2:
				result["restoration_health_potion"] = _alchemy_cards["restoration_health_potion"]
				result["scroll_of_valor"] = _alchemy_cards["scroll_of_valor"]
			if alch_stage >= 3:
				result["vital_health_potion"] = _alchemy_cards["vital_health_potion"]
				result["scroll_of_dominion"] = _alchemy_cards["scroll_of_dominion"]
			_snapshotted_pool = result

		return _snapshotted_pool
	set(value):
		_base_cards = value
		_snapshotted_pool.clear()
		_snapshotted_alchemist_stage = -1

func get_card_data(card_id: String) -> Dictionary:
	var target_id = card_id
	if target_id == "health_potion":
		target_id = "minor_health_potion"
	var all_cards: Dictionary = {}
	if _base_cards.has(target_id):
		all_cards = _base_cards
	elif _alchemy_cards.has(target_id):
		all_cards = _alchemy_cards
	else:
		for k in _base_cards.keys():
			if target_id in k:
				target_id = k
				all_cards = _base_cards
				break
		if all_cards.is_empty():
			for k in _alchemy_cards.keys():
				if target_id in k:
					target_id = k
					all_cards = _alchemy_cards
					break
	if all_cards.has(target_id):
		var card = all_cards[target_id].duplicate(true)
		if not card.has("sell_value"):
			match card.get("rarity", Rarity.COMMON):
				Rarity.COMMON:
					card["sell_value"] = 15
				Rarity.UNCOMMON:
					card["sell_value"] = 30
				Rarity.RARE:
					card["sell_value"] = 60
				Rarity.LEGENDARY:
					card["sell_value"] = 120
		card["count"] = 1
		RhythmEquipment.roll_for(card)
		card["description"] = CardPresenter.get_description(card)
		return CardIdentity.create_instance(card)
	return {}

func get_card_for_floor(floor_number: int, card_id: String) -> Dictionary:
	var target_id = card_id
	if target_id == "health_potion":
		target_id = "minor_health_potion"
	if not cards.has(target_id):
		# Fallback search by substring
		for k in cards.keys():
			if target_id in k:
				target_id = k
				break
	var card = get_card_data(target_id)
	if card.is_empty():
		return {}
	if floor_number > 1:
		if card.has("power"):
			card["power"] = int(card.get("power", 0)) + (floor_number - 1)
		if card.has("heal"):
			card["heal"] = int(card.get("heal", 0)) + (floor_number - 1) * 5
		if card.has("power_buff"):
			card["power_buff"] = int(card.get("power_buff", 0)) + (floor_number - 1)
	card["description"] = CardPresenter.get_description(card)
	return card

func get_random_starter_deck() -> Array[Dictionary]:
	var starter: Array[Dictionary] = []
	# 1 starter weapon (auto-equipped)
	starter.append(get_card_data("rusty_sword"))
	# 1 starter armor (auto-equipped)
	starter.append(get_card_data("leather_armor"))
	# 2 potions
	starter.append(get_card_data("minor_health_potion"))
	starter.append(get_card_data("minor_health_potion"))
	# 2 scrolls of might (+3 power each)
	starter.append(get_card_data("scroll_of_might"))
	starter.append(get_card_data("scroll_of_might"))
	# 1 amulet of luck
	starter.append(get_card_data("lucky_dice_amulet"))
	return starter

func get_random_loot_cards(floor_number: int, count: int = 3) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []
	var pool = cards.keys()
	pool.shuffle()
	for i in range(mini(count, pool.size())):
		var card_id = pool[i]
		var card = get_card_for_floor(floor_number, card_id)
		loot.append(card)
	return loot
