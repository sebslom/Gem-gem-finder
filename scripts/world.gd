class_name GemWorld
extends RefCounted

const WIDTH = 256
const HEIGHT = 192
const COLS = WIDTH / 32
const ROWS = HEIGHT / 32
const AIR = 0
const DIRT = 1
const STONE = 2
const COPPER = 3
const CLAY = 4
const IRON = 5
const CRYSTAL = 6
const BARRIER = 7
const TORCH = 8
const BENCH = 9
const BELT = 10
const DRILL = 11
const GENERATOR = 12
const WIRE = 13
const CORE = 14
const FLOWER = 15
const COLORS = [Color("0c1420"), Color("70513f"), Color("4c5868"), Color("c48655"), Color("95514c"), Color("82959e"), Color("46c8c5"), Color("302d4e"), Color("ffc779"), Color("aa7950"), Color("707c90"), Color("deae60"), Color("64d4b4"), Color("c6a45c"), Color("62ecde"), Color("bc9de5")]
const NAMES = ["Air", "Earth", "Stone", "Copper", "Clay", "Iron", "Crystal", "Obsidian", "Torch", "Workbench", "Conveyor", "Drill", "Generator", "Wire", "The Core", "Glowcap"]
const HP = [0, 40, 65, 60, 70, 85, 100, 160, 10, 40, 50, 70, 70, 10, 255, 5]
const HARDNESS = [0, 1, 1, 1, 2, 2, 2, 3, 1, 1, 1, 2, 2, 1, 99, 1]
var chunks: Array[GemChunk] = []
var world_seed := 0
var spawn := Vector2(128.5, 20.0)
var macro := FastNoiseLite.new()
var micro := FastNoiseLite.new()
var ore := FastNoiseLite.new()
var light_dirty := true
var fluid_cursor := 0

func _init(seed_value: int = 7319) -> void:
	world_seed = seed_value
	macro.seed = seed_value
	macro.frequency = 0.045
	micro.seed = seed_value ^ 991
	micro.frequency = 0.12
	ore.seed = seed_value ^ 8377
	ore.frequency = 0.23
	for i in COLS * ROWS:
		chunks.append(GemChunk.new())

func inside(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

func chunk_at(x: int, y: int) -> GemChunk:
	return chunks[(y >> 5) * COLS + (x >> 5)]

func offset(x: int, y: int) -> int:
	return ((y & 31) * 32 + (x & 31)) * 8

func get_field(x: int, y: int, field: int = 0) -> int:
	if not inside(x, y):
		return BARRIER if field == 0 else 0
	return chunk_at(x, y).data[offset(x, y) + field]

func set_field(x: int, y: int, field: int, value: int) -> void:
	if inside(x, y):
		var chunk := chunk_at(x, y)
		chunk.data[offset(x, y) + field] = value
		chunk.dirty = true

func set_tile(x: int, y: int, id: int) -> void:
	set_field(x, y, 0, id)
	set_field(x, y, 4, HP[id])
	light_dirty = true

func solid(x: int, y: int) -> bool:
	var id := get_field(x, y)
	return id > 0 and id not in [TORCH, WIRE, FLOWER]

func surface_height(x: int) -> int:
	return 22 if x >= 108 and x <= 150 else 24 + int(macro.get_noise_1d(float(x)) * 5)

func terrain(x: int, y: int) -> bool:
	var surface := surface_height(x)
	return y >= surface and (y < surface + 3 or macro.get_noise_2d(x, y) > -0.20 or micro.get_noise_2d(x, y) > 0.29)

func generate_chunk(index: int) -> void:
	var cx := (index % COLS) * 32
	var cy := (index / COLS) * 32
	for ly in 32:
		for lx in 32:
			var x := cx + lx
			var y := cy + ly
			var id := AIR
			var neighbors := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if terrain(x + dx, y + dy):
						neighbors += 1
			if neighbors >= 5:
				id = DIRT if y < 57 else (CLAY if y < 103 else STONE)
				var value := ore.get_noise_2d(x, y)
				if value > 0.33:
					id = COPPER if y < 57 else (IRON if y < 103 else CRYSTAL)
				elif y < 57 and value < -0.35:
					id = STONE
			if y in [58, 59, 105, 106]:
				id = CLAY if y < 60 else BARRIER
			if x < 2 or x >= WIDTH - 2 or y >= HEIGHT - 2:
				id = BARRIER
			if x >= 108 and x <= 150 and y < 22:
				id = AIR
			if x >= 108 and x <= 150 and y == 22:
				id = DIRT
			# A guaranteed usable landing chamber and approach tunnels.
			if x >= 113 and x <= 144 and y >= 26 and y <= 34:
				id = AIR
			if x >= 110 and x <= 147 and y == 35:
				id = STONE
			if x == 135 and y in [32, 33, 34]:
				id = CORE
			if y == 34 and x in [116, 141]:
				id = TORCH
			if y == 35 and x in [118, 119, 120, 122, 123, 124]:
				id = COPPER
			set_tile(x, y, id)
			set_field(x, y, 2, 1 if y >= surface_height(x) else 0)
			if id == AIR and y > 114 and y < 148:
				set_field(x, y, 5, 241)

func fluid_tick(center: Vector2i) -> void:
	# One local chunk per tick, alternating horizontal preference. Transfers are
	# capacity-limited; incompatible types never overwrite one another.
	var cx := clampi((center.x >> 5) + fluid_cursor % 3 - 1, 0, COLS - 1)
	var cy := clampi((center.y >> 5) + (fluid_cursor / 3) % 3 - 1, 0, ROWS - 1)
	fluid_cursor += 1
	for y in range(cy * 32 + 31, cy * 32 - 1, -1):
		for x in range(cx * 32, cx * 32 + 32):
			if get_field(x, y, 5) >> 4 == 0:
				continue
			transfer(x, y, x, y + 1, 15)
			var side := 1 if fluid_cursor % 2 == 0 else -1
			for dx in [side, -side]:
				var difference := (get_field(x, y, 5) >> 4) - (get_field(x + dx, y, 5) >> 4)
				if difference > 1:
					transfer(x, y, x + dx, y, difference / 2)

func transfer(x: int, y: int, tx: int, ty: int, limit: int) -> void:
	if not inside(tx, ty) or solid(tx, ty):
		return
	var source := get_field(x, y, 5)
	var dest := get_field(tx, ty, 5)
	if (dest >> 4) > 0 and (dest & 15) != (source & 15):
		return
	var amount := mini(limit, mini(source >> 4, 15 - (dest >> 4)))
	if amount <= 0:
		return
	var remaining := (source >> 4) - amount
	set_field(x, y, 5, (remaining << 4) | (source & 15) if remaining else 0)
	set_field(tx, ty, 5, (((dest >> 4) + amount) << 4) | (source & 15))

func raycast(start: Vector2, target: Vector2, reach: float = 5.0) -> Vector2i:
	var end := start + (target - start).limit_length(reach)
	var distance := start.distance_to(end)
	var steps := maxi(1, ceili(distance * 12))
	for i in range(1, steps + 1):
		var cell := Vector2i((start.lerp(end, float(i) / steps)).floor())
		if get_field(cell.x, cell.y) != AIR:
			return cell
	return Vector2i(end.floor())

func reveal(center: Vector2) -> void:
	for i in 100:
		var direction := Vector2.from_angle(TAU * i / 100.0)
		for step in range(1, 27):
			var cell := Vector2i((center + direction * step * 0.5).floor())
			set_field(cell.x, cell.y, 7, get_field(cell.x, cell.y, 7) | 128)
			if solid(cell.x, cell.y):
				break
