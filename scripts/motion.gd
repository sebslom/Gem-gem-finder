class_name GemMotion
extends RefCounted

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var half := Vector2(0.32, 0.85)
var grounded := false
var coyote := 0.0
var jump_buffer := 0.0

func overlaps(world: GemWorld, pos: Vector2) -> bool:
	for y in range(floori(pos.y - half.y + 0.001), floori(pos.y + half.y - 0.001) + 1):
		for x in range(floori(pos.x - half.x + 0.001), floori(pos.x + half.x - 0.001) + 1):
			if world.solid(x, y):
				return true
	return false

func step(world: GemWorld, direction: float, jump: bool, held: bool, delta: float) -> void:
	coyote = 0.1 if grounded else maxf(0, coyote - delta)
	jump_buffer = 0.12 if jump else maxf(0, jump_buffer - delta)
	var cell := Vector2i(position.floor())
	var swimming := world.get_field(cell.x, cell.y, 5) >> 4 > 7
	var speed := 4.5 if swimming else 9.0
	velocity.x = move_toward(velocity.x, direction * speed, (44.0 if direction != 0 else 38.0) * delta)
	velocity.y = minf(velocity.y + (12.0 if swimming else 38.0) * delta, 8.0 if swimming else 24.0)
	if jump_buffer > 0 and (coyote > 0 or swimming):
		velocity.y = -8.0 if swimming else -13.0
		jump_buffer = 0
		coyote = 0
		grounded = false
	if not held and velocity.y < -4.5:
		velocity.y = -4.5
	move(world, delta)

func move(world: GemWorld, delta: float) -> void:
	# Substep the full swept distance: fast falls cannot tunnel through a tile.
	var steps := maxi(1, ceili(velocity.length() * delta / 0.24))
	var part := delta / steps
	grounded = false
	for i in steps:
		var target := position + Vector2(0, velocity.y * part)
		if overlaps(world, target):
			if velocity.y > 0:
				grounded = true
				position.y = floorf(target.y + half.y) - half.y
			elif velocity.y < 0:
				position.y = floorf(target.y - half.y) + 1 + half.y
			velocity.y = 0
		else:
			position = target
		target = position + Vector2(velocity.x * part, 0)
		if overlaps(world, target):
			if grounded and not overlaps(world, target - Vector2(0, 0.5)):
				position = target - Vector2(0, 0.5)
			else:
				velocity.x = 0
		else:
			position = target
