class_name GemSaveStore
extends RefCounted

var root := "user://expedition"
var tasks: Array = []
var metadata: Dictionary = {}
var slot := 0
var error := ""
var saving := false
var last_loaded_slot := -1

func begin(worlds: Dictionary, state: Dictionary) -> bool:
	if saving:
		return false
	error = ""
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		error = "Browser storage is unavailable."
		return false
	var previous := latest_metadata()
	slot = 1 - (last_loaded_slot if last_loaded_slot >= 0 else int(previous.get("slot", 1)))
	metadata = state.duplicate(true)
	metadata["schema"] = 1
	metadata["slot"] = slot
	metadata["revision"] = int(previous.get("revision", 0)) + 1
	metadata["planets"] = []
	# The game pauses during a snapshot so tiles and inventory are consistent.
	for planet in worlds:
		var world: GemWorld = worlds[planet]
		metadata["planets"].append({"id": planet, "seed": world.world_seed})
		for i in world.chunks.size():
			tasks.append([planet, i, world.chunks[i]])
	saving = true
	return true

func tick() -> void:
	if not saving:
		return
	if not tasks.is_empty():
		var task: Array = tasks.pop_back()
		var file := FileAccess.open("%s/%s_%s_%s.bin" % [root, slot, task[0], task[1]], FileAccess.WRITE)
		if file == null:
			fail("Could not write world data; previous save retained.")
			return
		file.store_buffer((task[2] as GemChunk).encode())
		if file.get_error() != OK:
			fail("Storage write failed; previous save retained.")
		return
	var file := FileAccess.open("%s/slot%s.json" % [root, slot], FileAccess.WRITE)
	if file == null:
		fail("Could not commit save.")
		return
	file.store_string(JSON.stringify(metadata))
	if file.get_error() != OK:
		fail("Could not commit save.")
		return
	file.close()
	last_loaded_slot = slot
	saving = false

func fail(message: String) -> void:
	error = message
	saving = false
	tasks.clear()

func latest_metadata() -> Dictionary:
	var candidates := metadata_candidates()
	return {} if candidates.is_empty() else candidates[0]

func metadata_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for i in 2:
		var path := "%s/slot%s.json" % [root, i]
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and valid_metadata(parsed) and int(parsed.slot) == i:
			candidates.append(parsed)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.revision) > int(b.revision))
	return candidates

func valid_metadata(state: Dictionary) -> bool:
	if state.get("schema") != 1:
		return false
	for key in ["slot", "revision", "seed", "planet", "tier", "health", "x", "y"]:
		if not state.get(key) is float and not state.get(key) is int:
			return false
	if int(state.slot) not in [0, 1] or int(state.tier) not in [1, 2, 3] or not state.get("ship") is bool or not state.get("core") is bool:
		return false
	if not is_finite(float(state.x)) or not is_finite(float(state.y)) or float(state.x) < 0 or float(state.x) >= GemWorld.WIDTH or float(state.y) < 0 or float(state.y) >= GemWorld.HEIGHT:
		return false
	if not state.get("inventory") is Array or state.inventory.size() != 16:
		return false
	for quantity in state.inventory:
		if (not quantity is int and not quantity is float) or float(quantity) < 0 or float(quantity) > 2147483647 or not is_finite(float(quantity)):
			return false
	if not state.get("planets") is Array or state.planets.is_empty() or state.planets.size() > 6:
		return false
	var ids: Array[int] = []
	for entry in state.planets:
		if not entry is Dictionary:
			return false
		if (not entry.get("id") is int and not entry.get("id") is float) or (not entry.get("seed") is int and not entry.get("seed") is float):
			return false
		var id := int(entry.id)
		if id < 0 or id >= 6 or id in ids:
			return false
		ids.append(id)
	return int(state.planet) in ids and float(state.health) > 0 and float(state.health) <= 100

func restore() -> Dictionary:
	error = ""
	for candidate in metadata_candidates():
		var restored := restore_candidate(candidate)
		if not restored.is_empty():
			last_loaded_slot = int(restored.slot)
			return restored
	error = "No complete checkpoint found."
	return {}

func restore_candidate(state: Dictionary) -> Dictionary:
	var restored: Dictionary = {}
	for entry in state.get("planets", []):
		var world := GemWorld.new(int(entry.seed))
		for i in world.chunks.size():
			var path := "%s/%s_%s_%s.bin" % [root, int(state.slot), int(entry.id), i]
			if not FileAccess.file_exists(path) or not world.chunks[i].decode(FileAccess.get_file_as_bytes(path)):
					return {}
		restored[int(entry.id)] = world
	state["worlds"] = restored
	return state
