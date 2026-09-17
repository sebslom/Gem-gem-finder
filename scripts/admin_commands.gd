class_name GemCommands
extends RefCounted

const HELP = "/help, /players, /items | Admin: /spawn item [amount] [player], /god [on|off] [player], /fly [on|off] [player], /tp x y [player], /tp destination [player]"

static func find_player(name: String, actor, roster: Dictionary):
	if name.is_empty():
		return actor
	for id in roster:
		var candidate = roster[id]
		if str(id) == name or candidate.player_name.to_lower() == name.to_lower():
			return candidate
	return null

static func execute(line: String, actor, roster: Dictionary, authorized: bool) -> String:
	var args := line.strip_edges().split(" ", false)
	if args.is_empty():
		return HELP
	var command := args[0].to_lower()
	if command == "/help":
		return HELP
	if command == "/players":
		var names := PackedStringArray()
		for id in roster:
			names.append("%s (#%s)" % [roster[id].player_name, id])
		return "Online: " + ", ".join(names)
	if command == "/items":
		return "earth, stone, copper, clay, iron, crystal, obsidian, torch, workbench, conveyor, drill, generator, wire, glowcap, copper_pickaxe, crystal_pickaxe, spacecraft"
	if command not in ["/spawn", "/god", "/godmode", "/fly", "/tp", "/teleport"]:
		return "Unknown command. /help lists available commands."
	if not authorized:
		return "Admin permission required. Authenticate in the multiplayer lobby."
	if command == "/spawn":
		if args.size() < 2 or args.size() > 4:
			return "Usage: /spawn item [amount:1-9999] [player]"
		if args.size() >= 3 and not args[2].is_valid_int():
			return "Amount must be a whole number from 1 to 9999."
		var amount := int(args[2]) if args.size() >= 3 else 1
		if amount < 1 or amount > 9999:
			return "Amount must be from 1 to 9999."
		var target = find_player(args[3] if args.size() == 4 else "", actor, roster)
		if target == null:
			return "Player not found. Use /players."
		var item := args[1].to_lower()
		if item == "copper_pickaxe":
			target.tier = maxi(target.tier, 2)
		elif item == "crystal_pickaxe":
			target.tier = 3
		elif item == "spacecraft":
			target.ship = true
		else:
			var id := -1
			for i in range(1, GemWorld.NAMES.size()):
				if item == GemWorld.NAMES[i].to_lower().replace(" ", "_") or item == str(i):
					id = i
			if id < 1 or id == GemWorld.CORE:
				return "Unknown or protected item. Use /items."
			if target.inventory[id] > 2147483647 - amount:
				return "Inventory limit reached."
			target.inventory[id] += amount
		return "Gave %s x%s to %s." % [item, amount, target.player_name]
	if command in ["/god", "/godmode", "/fly"]:
		if args.size() > 3 or (args.size() >= 2 and args[1] not in ["on", "off"]):
			return "Usage: %s [on|off] [player]" % command
		var target = find_player(args[2] if args.size() == 3 else "", actor, roster)
		if target == null:
			return "Player not found."
		var flying := command == "/fly"
		var current: bool = target.fly_mode if flying else target.god_mode
		var enabled := not current if args.size() == 1 else args[1] == "on"
		if flying:
			if not enabled and target.player.overlaps(target.world, target.player.position):
				return "Move into open space before turning flight off."
			target.fly_mode = enabled
			target.player.velocity = Vector2.ZERO
			target.hook = Vector2(-1, -1)
		else:
			target.god_mode = enabled
			if enabled:
				target.health = 100
		return "%s: %s %s." % [target.player_name, "Flight" if flying else "God mode", "ON" if enabled else "OFF"]
	if args.size() < 2 or args.size() > 4:
		return "Usage: /tp x y [player] OR /tp destination [player]"
	var destination := Vector2.ZERO
	var target = actor
	if args[1].is_valid_float():
		if args.size() < 3 or not args[2].is_valid_float():
			return "Both X and Y must be numbers (tile coordinates)."
		destination = Vector2(float(args[1]), float(args[2]))
		target = find_player(args[3] if args.size() == 4 else "", actor, roster)
	else:
		if args.size() > 3:
			return "Usage: /tp destination [player]"
		var other = find_player(args[1], actor, roster)
		if other == null:
			return "Destination player not found."
		destination = other.player.position
		target = find_player(args[2] if args.size() == 3 else "", actor, roster)
	if target == null:
		return "Player not found."
	if not destination.is_finite() or destination.x < 1 or destination.x > GemWorld.WIDTH - 2 or destination.y < 1 or destination.y > GemWorld.HEIGHT - 2:
		return "Coordinates outside world bounds (x:1-254, y:1-190)."
	if not target.fly_mode and target.player.overlaps(target.world, destination):
		return "Destination blocked by terrain. Choose open space or enable /fly."
	if target.planet != actor.planet:
		return "Teleport requires players on the same planet."
	target.player.position = destination
	target.player.velocity = Vector2.ZERO
	target.hook = Vector2(-1, -1)
	target.camera = destination * target.TILE + Vector2(0, -90)
	target.world.light_dirty = true
	return "Teleported %s to %.2f, %.2f." % [target.player_name, destination.x, destination.y]
