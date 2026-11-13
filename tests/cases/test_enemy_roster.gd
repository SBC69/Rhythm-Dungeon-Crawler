class_name TestEnemyRoster
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-ENEMY-ROSTER"] = {"fn": Callable(TestEnemyRoster, "test_roster"), "expected_failure": false, "desc": "Eleven weighted enemy archetypes, correct sprites, scaling, legacy snapshots, and boss separation"}
	registry["T-ENEMY-DOORS"] = {"fn": Callable(TestEnemyRoster, "test_doors_and_view"), "expected_failure": false, "desc": "New enemies actually appear behind random doors and render correctly in old/new encounters"}

static func test_roster(fix: GameFixture) -> void:
	var cfg := BalanceConfig.new()
	fix.assert_true(cfg.load_from_file(), "Expanded enemy config validates")
	var entries: Array = cfg.config_data.enemies.archetypes
	fix.assert_eq(entries.size(), 11, "Eleven ordinary enemy species")
	var total_weight := 0
	var ids: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var context := {"mode": "timed", "dungeon_index": 1, "floor_number": 3, "room_number": 6}
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		total_weight += int(entry.weight)
		fix.assert_false(str(entry.id) in ids, "Each weighted entry has a unique enemy ID")
		ids.append(str(entry.id))
		var forced: Dictionary = cfg.config_data.duplicate(true)
		for i in range(entries.size()):
			forced.enemies.archetypes[i].weight = 1 if i == index else 0
		for kind in ["regular", "elite"]:
			var monster := EncounterFactory.create_encounter(kind, context, rng, forced)
			fix.assert_eq(monster.id, entry.id, "Every species is reachable through the real weighted picker")
			fix.assert_false(monster.is_boss, "Random species do not masquerade as floor bosses")
			fix.assert_eq(monster.is_elite, kind == "elite", "Elite status belongs to the encounter kind")
			fix.assert_eq(monster.power, EncounterFactory.enemy_power(kind, 2, 6, int(entry.power_offset), forced), "Every new species uses the existing scaling formula")
			fix.assert_eq(monster.attack, maxi(1, int(monster.power) + int(entry.get("attack_offset", 0))), "Enemy attack uses its species profile")
			fix.assert_eq(monster.defense, maxi(1, int(monster.power) + int(entry.get("defense_offset", 0))), "Enemy defense uses its own species profile")
			fix.assert_true(ResourceLoader.exists(monster.sprite), "Enemy sprite is imported")
			var round_state := RhythmRound.new(10, 10, monster)
			fix.assert_true(RhythmRound.PATTERNS.has(round_state.settings.pattern_id), "Every new species has a playable rhythm")
		var image := Image.load_from_file(str(EncounterFactory.MONSTER_TEMPLATES[entry.id].sprite))
		fix.assert_false(image.is_empty(), "Enemy PNG can be decoded")
		if str(entry.id) != "skeleton":
			fix.assert_eq(image.get_pixel(0, 0).a, 0.0, "New sprite has a transparent background")
	fix.assert_eq(total_weight, 100, "Normal enemy weights sum to 100")
	var observed: Dictionary = {}
	for _i in range(1000):
		var monster := EncounterFactory.create_encounter("regular", context, rng, cfg.config_data)
		observed[monster.id] = int(observed.get(monster.id, 0)) + 1
	fix.assert_eq(observed.size(), 11, "Seeded random encounters include all requested species")
	fix.assert_true(int(observed.get("dungeon_slime", 0)) > int(observed.get("bound_djinn", 0)), "Rare djinn appears less frequently than slime")
	var legacy: Dictionary = cfg.config_data.duplicate(true)
	legacy.enemies.archetypes = [{"suffix": "01", "power_offset": -1, "weight": 45}, {"suffix": "02", "power_offset": 0, "weight": 35}, {"suffix": "03", "power_offset": 1, "weight": 20}]
	for _i in range(30):
		var monster := EncounterFactory.create_encounter("regular", context, rng, legacy)
		fix.assert_true(monster.id in ["skeleton", "shadow_ghoul", "crypt_knight"], "Old saved balance snapshots keep their original enemy pool")
	var boss := EncounterFactory.create_encounter("boss", {"floor_number": 2, "room_number": 10}, rng, cfg.config_data)
	fix.assert_eq(boss.id, "boss_archon", "Archdemon remains an independent floor boss")
	fix.assert_true(boss.is_boss, "Floor boss retains boss status")
	fix.assert_eq(boss.attack, int(boss.power) + 2, "Generated boss has its separate attack bonus")
	fix.assert_eq(boss.defense, int(boss.power) + 2, "Generated boss has its separate defense bonus")
	fix.assert_eq(boss.sprite, "res://assets/sprites/monsters/boss_archon-pixel.png", "Archdemon boss uses its new sprite")
	await fix.teardown()

static func test_doors_and_view(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var cfg: Dictionary = gm.floor_routes.balance_snapshot
	var context: Dictionary = gm.floor_routes.context
	var observed: Dictionary = {}
	for seed_value in range(128):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var routes := FloorRoutes.create(context, cfg, rng)
		fix.assert_eq(routes.get_current_choices().size(), 3, "New roster retains three ordinary door choices")
		for choice in routes.get_current_choices():
			if choice.kind in ["regular", "elite"]:
				observed[str(choice.data.id)] = true
	fix.assert_eq(observed.size(), 11, "All eleven species appear in actual generated door choices")
	main.router.show_combat({"id": "shadow_ghoul", "power": 7, "sprite": "res://assets/sprites/monsters/skeleton.png", "tint": [0.7, 0.9, 0.6, 1.0]})
	for id in EncounterFactory.MONSTER_TEMPLATES:
		var data: Dictionary = EncounterFactory.MONSTER_TEMPLATES[id].duplicate(true)
		data.power = gm.get_total_player_power() + 3
		# Saved encounters from the old build can still point to the shared skeleton.
		data.sprite = "res://assets/sprites/monsters/skeleton.png"
		main.monster_view.setup_monster(data)
		fix.assert_eq(main.monster_view.monster_texture.texture.resource_path, EncounterFactory.sprite_for(data), "Rendering resolves the current species sprite even for old encounters")
		fix.assert_eq(main.monster_view.monster_texture.modulate, Color.WHITE, "Artwork is not darkened by obsolete placeholder tints")
		var round_state := RhythmRound.new(10, 10, data)
		if RhythmRound.ENEMY_STYLES.has(id):
			fix.assert_eq(round_state.settings.pattern_name, RhythmRound.ENEMY_STYLES[id].name, "Ordinary species shows its own rhythm name")
	await fix.teardown()
