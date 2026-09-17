extends SceneTree

var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error("FAILED: " + description)
		quit(1)
		assert(condition, description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var chunk := GemChunk.new()
	for i in chunk.data.size():
		chunk.data[i] = (i * 37 + i / 13) % 256
	var copy := GemChunk.new()
	check(copy.decode(chunk.encode()), "RLE accepts valid data")
	check(copy.data == chunk.data, "RLE preserves all eight fields")
	check(not copy.decode(PackedByteArray([0, 0, 0])), "RLE rejects truncation")
	check(not copy.decode(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])), "RLE rejects zero runs")
	var world := GemWorld.new(77)
	var other := GemWorld.new(77)
	for i in world.chunks.size():
		world.generate_chunk(i)
		other.generate_chunk(i)
		check(world.chunks[i].data == other.chunks[i].data, "Deterministic chunk %s" % i)
	var body := GemMotion.new()
	body.position = world.spawn
	check(not body.overlaps(world, body.position), "Spawn has player clearance")
	for i in 120:
		body.step(world, 0, false, false, 1.0 / 60)
	check(body.grounded and absf(body.position.y - 21.15) < 0.01, "Player lands on surface landing pad")
	body.position = Vector2(128, 30)
	body.velocity = Vector2(0, 200)
	body.move(world, 0.1)
	check(body.position.y <= 34.151 and not body.overlaps(world, body.position), "Swept collision prevents tunneling")
	world.set_field(128, 30, 5, 241)
	world.set_field(128, 31, 5, 161)
	world.transfer(128, 30, 128, 31, 15)
	check(world.get_field(128, 30, 5) >> 4 == 10, "Fluid source retains overflow")
	check(world.get_field(128, 31, 5) >> 4 == 15, "Fluid destination capacity respected")
	world.set_field(129, 30, 5, 82)
	world.transfer(128, 30, 129, 30, 15)
	check(world.get_field(129, 30, 5) == 82, "Fluid types do not overwrite")
	var initial_volume := 0
	for active_chunk in world.chunks:
		for offset in range(5, active_chunk.data.size(), 8):
			initial_volume += active_chunk.data[offset] >> 4
	for i in 18:
		world.fluid_tick(Vector2i(128, 31))
	var final_volume := 0
	for active_chunk in world.chunks:
		for offset in range(5, active_chunk.data.size(), 8):
			final_volume += active_chunk.data[offset] >> 4
	check(initial_volume == final_volume, "Scheduled fluid updates conserve total volume across chunk boundaries")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.worlds = {0: world}
	game.world = world
	game.finish_generation()
	game.set_physics_process(false)
	game.set_process(false)
	game.player.position = Vector2(128.5, 34.15)
	world.set_tile(128, 35, GemWorld.STONE)
	for i in 3:
		game.use_tool(Vector2(128.5, 35.5))
	check(world.get_field(128, 35) == 0, "Mining destroys a reachable block after sufficient damage")
	for i in 30:
		game.update_entities(1.0 / 60)
	check(game.inventory[2] == 1, "Mined item reaches inventory exactly once")
	world.set_tile(130, 34, GemWorld.CLAY)
	game.use_tool(Vector2(130.5, 34.5))
	check(world.get_field(130, 34, 4) == GemWorld.HP[GemWorld.CLAY], "Weak pick cannot damage clay")
	world.set_tile(130, 34, GemWorld.STONE)
	world.set_field(130, 34, 4, 1)
	for drop in game.drops:
		drop.active = true
	game.use_tool(Vector2(130.5, 34.5))
	check(world.get_field(130, 34) == GemWorld.STONE, "Full drop pool preserves the source block")
	for drop in game.drops:
		drop.active = false
	world.set_tile(130, 34, 0)
	game.inventory[1] = 8
	game.selected = 2
	game.place_tile(Vector2(128.5, 34.5))
	check(world.get_field(128, 34) == 0 and game.inventory[1] == 8, "Placement rejects player overlap without consuming inventory")
	game.place_tile(Vector2(140.5, 34.5))
	check(world.get_field(140, 34) == 0 and game.inventory[1] == 8, "Placement rejects out-of-reach targets")
	game.place_tile(Vector2(130.5, 34.5))
	check(world.get_field(130, 34) == GemWorld.DIRT and game.inventory[1] == 7, "Valid placement commits one item")
	game.place_tile(Vector2(130.5, 34.5))
	check(game.inventory[1] == 7, "Occupied placement cannot consume another item")
	world.set_tile(130, 34, 0)
	game.selected = 0
	game.tier = 3
	game.player.position = Vector2(0.5, 30.5)
	world.set_tile(0, 30, 0)
	game.use_tool(Vector2(-2, 30.5))
	var active_drops := 0
	for drop in game.drops:
		active_drops += int(drop.active)
	check(active_drops == 0, "Out-of-world mining cannot create infinite items")
	game.tier = 1
	game.player.position = Vector2(128.5, 34.15)
	world.set_tile(128, 35, GemWorld.STONE)
	game.inventory[3] = 8
	game.inventory[2] = 5
	check(not game.can_craft(game.RECIPES[2]), "Advanced crafting requires station")
	world.set_tile(130, 34, GemWorld.BENCH)
	check(game.can_craft(game.RECIPES[2]), "Nearby station enables recipe")
	game.craft(2)
	check(game.tier == 2 and game.inventory[3] == 0, "Craft commits inputs and upgrade")
	game.craft(2)
	check(game.inventory[3] == 0, "Repeated unavailable craft cannot consume negative inventory")
	game.inventory[5] = 10
	game.inventory[6] = 3
	check(GemWorld.HARDNESS[GemWorld.CRYSTAL] <= game.tier, "Crystal ingredient is obtainable before crystal pickaxe")
	check(game.can_craft(game.RECIPES[3]), "Tier three progression is reachable")
	var enemy: Dictionary = game.enemies[0]
	enemy.active = true
	enemy.hp = 3
	enemy.body.position = Vector2(130.5, 34)
	world.set_tile(130, 34, 0)
	world.set_tile(129, 34, GemWorld.STONE)
	game.selected = 1
	game.use_tool()
	check(enemy.hp == 3, "Melee cannot hit through a solid wall")
	world.set_tile(129, 34, 0)
	game.use_tool()
	check(enemy.hp == 1, "Melee applies tool-scaled damage in reach")
	game.use_tool()
	check(not enemy.active, "Defeated enemy returns to pool")
	for drop in game.drops:
		drop.active = false
	enemy.active = true
	enemy.hp = 3
	enemy.body.position = game.player.position
	enemy.body.velocity = Vector2.ZERO
	game.update_entities(1.0 / 60)
	var hit_health: float = game.health
	game.update_entities(1.0 / 60)
	check(hit_health == 88 and game.health == hit_health, "Contact damage respects invulnerability window")
	enemy.active = false
	game.health = 100
	game.selected = 0
	game.player.velocity = Vector2.ZERO
	world.set_tile(123, 33, 0)
	world.set_tile(124, 33, GemWorld.WIRE)
	world.set_tile(125, 33, GemWorld.DRILL)
	world.set_tile(125, 34, GemWorld.STONE)
	game.process_machines()
	check(world.get_field(125, 34) == GemWorld.STONE, "Unpowered drill does not mine")
	world.set_tile(123, 33, GemWorld.GENERATOR)
	game.process_machines()
	check(world.get_field(125, 34) == 0, "Connected generator powers wire-linked drill")
	for drop in game.drops:
		drop.active = false
	world.set_tile(123, 33, 0)
	world.set_tile(124, 33, 0)
	world.set_tile(125, 33, 0)
	world.set_tile(125, 35, GemWorld.BELT)
	game.spawn_drop(Vector2(125.4, 34.87), GemWorld.COPPER)
	game.drops[0].vel = Vector2.ZERO
	game.update_entities(1.0 / 60)
	check(game.drops[0].pos.x > 125.4, "Conveyor transports a resting item")
	game.drops[0].active = false
	world.set_tile(130, 34, GemWorld.BENCH)
	game.update_lighting()
	var maximum := 0
	for value in game.light_values:
		maximum = maxi(maximum, value)
	check(maximum == 15, "Lighting remains in nibble range")
	game.save_store.root = "res://tests/save-fixture"
	game.save_game()
	while game.save_store.saving:
		game.save_store.tick()
	check(game.save_store.error.is_empty(), "Incremental checkpoint completes")
	var loaded: Dictionary = game.save_store.restore()
	check(not loaded.is_empty() and int(loaded.tier) == 2, "Save restores progression")
	check((loaded.worlds[0] as GemWorld).chunks[11].data == world.chunks[11].data, "Save restores chunk bytes")
	var old_stone: int = loaded.inventory[2]
	var old_slot: int = loaded.slot
	game.inventory[2] = 99
	game.save_game()
	while game.save_store.saving:
		game.save_store.tick()
	check(game.save_store.slot != old_slot, "Checkpoints alternate slots")
	var corrupt_slot: int = game.save_store.slot
	var broken := FileAccess.open("res://tests/save-fixture/%s_0_0.bin" % corrupt_slot, FileAccess.WRITE)
	broken.store_8(0)
	broken.close()
	var recovered: Dictionary = game.save_store.restore()
	check(not recovered.is_empty() and int(recovered.slot) == old_slot and int(recovered.inventory[2]) == old_stone, "Corrupt latest checkpoint falls back to previous intact checkpoint")
	game.save_game()
	check(game.save_store.slot == corrupt_slot, "Next write preserves the recovered good slot")
	while game.save_store.saving:
		game.save_store.tick()
	check(not game.save_store.restore().is_empty(), "Saving works after backup recovery")
	game.resume()
	for i in 600:
		game._process(1.0 / 60)
		game._physics_process(1.0 / 60)
	check(not game.player.overlaps(world, game.player.position), "Ten seconds of integrated simulation leave player outside solid tiles")
	check(game.health > 0, "Integrated simulation preserves a valid player")
	world.set_tile(125, 34, GemWorld.TORCH)
	game.worlds[1] = other
	game.spawn_drop(game.player.position, GemWorld.COPPER)
	var copper_before: int = game.inventory[3]
	game.travel(1)
	check(game.inventory[3] == copper_before + 1, "Planet travel preserves outstanding mined loot")
	game.travel(0)
	check(game.world.get_field(125, 34) == GemWorld.TORCH, "Planet revisits preserve terrain changes")
	game.queue_free()
	await process_frame
	print("PASS: %s checks" % checks)
	quit(0)
