extends Node2D

const TILE = 24.0
const INK = Color("e6eee9")
const MUTED = Color("8eaaa9")
const MINT = Color("7be4c6")
const GOLD = Color("efc487")
const SLOTS = [0, -1, 1, 8, 9, 10, 12, 13, 11]
const SLOT_NAMES = ["Pickaxe", "Blade", "Earth", "Torch", "Bench", "Belt", "Power", "Wire", "Drill"]
const PLANET_NAMES = ["VERDANT HOLLOW", "RUST MOON", "GLASS TIDE", "EMBER VEIL", "PALE ORBIT", "THE QUIET EDGE"]
const RECIPES = [
	["Torches × 6", 8, 6, {1: 3}, 0, "Earth 3"],
	["Workbench", 9, 1, {1: 12, 2: 5}, 0, "Earth 12 · Stone 5"],
	["Copper pickaxe", -2, 1, {3: 8, 2: 5}, 9, "Copper 8 · Stone 5"],
	["Crystal pickaxe", -3, 1, {5: 10, 6: 3}, 9, "Iron 10 · Crystal 3"],
	["Conveyors × 4", 10, 4, {3: 2, 2: 4}, 9, "Copper 2 · Stone 4"],
	["Generator", 12, 1, {3: 6, 5: 3}, 9, "Copper 6 · Iron 3"],
	["Wires × 8", 13, 8, {3: 2}, 9, "Copper 2"],
	["Automatic drill", 11, 1, {5: 6, 3: 4}, 9, "Iron 6 · Copper 4"],
	["Survey spacecraft", -4, 1, {5: 15, 6: 8, 3: 20}, 9, "Iron 15 · Crystal 8 · Copper 20"]
]
var world: GemWorld
var worlds: Dictionary = {}
var player := GemMotion.new()
var inventory := PackedInt32Array()
var save_store := GemSaveStore.new()
var net: GemNet
var server_actor := false
var player_name := "Explorer"
var character_color := 0
var god_mode := false
var fly_mode := false
var energy := 100.0
var chat_open := false
var chat_lines := PackedStringArray()
var chat_panel: PanelContainer
var chat_log: RichTextLabel
var chat_entry: LineEdit
var show_fps := false
var server_url := "ws://127.0.0.1:8077"
var settings := ConfigFile.new()
var universe_seed := 7319
var planet := 0
var tier := 1
var ship := false
var core_active := false
var health := 100.0
var selected := 0
var camera := Vector2.ZERO
var time := 0.0
var tick := 0
var generation := -1
var mode := "title"
var notice := ""
var notice_time := 0.0
var mine_cooldown := 0.0
var attack_time := 0.0
var invulnerable := 0.0
var damage_cells: Dictionary = {}
var hook := Vector2(-1, -1)
var hook_length := 0.0
var drops: Array = []
var enemies: Array = []
var particles: Array = []
var ui := Control.new()
var panel: PanelContainer
var seed_input: LineEdit
var touch_axis := 0.0
var touch_jump := false
var touch_mine := false
var last_reveal := Vector2i(-1, -1)
var autosave := 0.0
var light_values := PackedByteArray()
var light_queue := PackedInt32Array()
var light_origin := Vector2i.ZERO
const LIGHT_W = 80
const LIGHT_H = 50

func _ready() -> void:
	inventory.resize(16)
	light_values.resize(LIGHT_W * LIGHT_H)
	light_queue.resize(LIGHT_W * LIGHT_H * 16)
	for i in 64:
		drops.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "id": 1})
	for i in 20:
		var body := GemMotion.new()
		body.half = Vector2(0.44, 0.36)
		enemies.append({"active": false, "body": body, "hp": 3, "timer": 0.0})
	if server_actor:
		return
	if settings.load("user://settings.cfg") == OK:
		player_name = str(settings.get_value("player", "name", "Explorer"))
		character_color = clampi(int(settings.get_value("player", "color", 0)), 0, 4)
		show_fps = bool(settings.get_value("display", "fps", false))
		server_url = str(settings.get_value("network", "url", server_url))
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	create_chat()
	show_title()

func style(bg: Color, border: Color = Color("31464d")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box

func clear_panel() -> void:
	if is_instance_valid(panel):
		panel.hide()
		panel.queue_free()
		panel = null

func make_panel(width: float = 460) -> VBoxContainer:
	clear_panel()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(Color("10232d")))
	panel.position = Vector2((get_viewport_rect().size.x - width) / 2, 110)
	panel.custom_minimum_size.x = width
	ui.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column

func label_to(column: VBoxContainer, text: String, size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	column.add_child(label)
	return label

func button_to(column: VBoxContainer, text: String, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.add_theme_stylebox_override("normal", style(Color("1b3740")))
	button.add_theme_stylebox_override("hover", style(Color("29534f"), MINT))
	button.pressed.connect(action)
	column.add_child(button)
	return button

func show_title() -> void:
	if net != null:
		net.close()
		net = null
	close_chat()
	mode = "title"
	var column := make_panel(360)
	panel.position.y = 220
	label_to(column, "YOUR NEXT ADVENTURE", 16, Color("a5cbdf"))
	menu_button(column, "PLAY", show_character, Color("53b548"))
	menu_button(column, "MULTIPLAYER", show_multiplayer, Color("388bc0"))
	menu_button(column, "OPTIONS", show_options, Color("388bc0"))
	menu_button(column, "QUIT", show_quit, Color("cc4b45"))

func menu_button(column: VBoxContainer, text: String, action: Callable, color: Color) -> Button:
	var button := button_to(column, text, action)
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 24)
	var box := style(color, color.lightened(0.15))
	box.border_width_bottom = 6
	box.border_color = color.darkened(0.3)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", style(color.darkened(0.12)))
	return button

func show_character() -> void:
	mode = "character"
	var column := make_panel(430)
	panel.position.y = 290
	label_to(column, "SELECT CHARACTER", 23)
	var colors := HBoxContainer.new()
	column.add_child(colors)
	for i in GemArt.SUITS.size():
		var button := Button.new()
		button.text = "%s %s" % ["*" if i == character_color else "", ["Blue", "Violet", "Red", "Green", "Gold"][i]]
		button.add_theme_stylebox_override("normal", style(GemArt.SUITS[i].darkened(0.35)))
		button.pressed.connect(func(): character_color = i; show_character())
		colors.add_child(button)
	var name_input := LineEdit.new()
	name_input.text = player_name
	name_input.max_length = 16
	name_input.placeholder_text = "Player name"
	name_input.text_changed.connect(func(value): player_name = value)
	column.add_child(name_input)
	seed_input = LineEdit.new()
	seed_input.text = str(universe_seed)
	seed_input.placeholder_text = "World seed (number or word)"
	column.add_child(seed_input)
	button_to(column, "NEW WORLD", func():
		universe_seed = int(seed_input.text) if seed_input.text.is_valid_int() else int(seed_input.text.hash())
		player_name = clean_name(player_name)
		save_settings()
		worlds.clear()
		for drop in drops:
			drop.active = false
		inventory.fill(0)
		inventory[1] = 24
		inventory[8] = 12
		god_mode = false
		fly_mode = false
		tier = 1
		ship = false
		core_active = false
		travel(0))
	button_to(column, "CONTINUE SAVED WORLD", load_game, not save_store.latest_metadata().is_empty())
	button_to(column, "BACK", show_title)

func show_multiplayer() -> void:
	mode = "lobby"
	var column := make_panel(470)
	panel.position.y = 230
	label_to(column, "MULTIPLAYER LOBBY", 25)
	label_to(column, "Up to 8 explorers in a shared world", 15, MUTED)
	var name_input := LineEdit.new()
	name_input.text = player_name
	name_input.max_length = 16
	name_input.placeholder_text = "Player name"
	column.add_child(name_input)
	var address := LineEdit.new()
	address.text = server_url
	address.placeholder_text = "wss://your-server.example"
	column.add_child(address)
	var password := LineEdit.new()
	password.secret = true
	password.placeholder_text = "Admin token (optional; never saved)"
	column.add_child(password)
	button_to(column, "Suit: " + ["Blue", "Violet", "Red", "Green", "Gold"][character_color], func():
		character_color = (character_color + 1) % 5
		player_name = name_input.text
		server_url = address.text
		show_multiplayer())
	menu_button(column, "JOIN GAME", func():
		player_name = clean_name(name_input.text)
		server_url = address.text.strip_edges()
		if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
			tell("Enter a ws:// or wss:// server address.")
			return
		var token := password.text
		password.clear()
		save_settings()
		clear_panel()
		mode = "connecting"
		net = GemNet.new(self)
		if net.connect_to(server_url, token) != OK:
			network_failed("Could not connect to that server address."), Color("53b548"))
	button_to(column, "BACK", show_title)

func network_failed(message: String) -> void:
	if net != null:
		net.close()
		net = null
	show_multiplayer()
	tell(message)

func show_options() -> void:
	var return_to_game := mode in ["play", "pause", "craft"]
	mode = "options"
	var column := make_panel(430)
	panel.position.y = 235
	label_to(column, "OPTIONS", 28)
	var fps := CheckButton.new()
	fps.text = "Show frame rate"
	fps.button_pressed = show_fps
	fps.toggled.connect(func(value): show_fps = value; save_settings())
	column.add_child(fps)
	button_to(column, "TOGGLE FULLSCREEN", func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	label_to(column, "A / D  Move       Space  Jump       Q  Grapple\nLeft mouse  Tool     Right mouse  Build\n1-9  Hotbar     C  Craft     M  Star chart\nEnter  Chat / commands     Esc  Back\nFlying: W / S or Up / Down", 16, MUTED)
	button_to(column, "BACK", show_pause if return_to_game else show_title)

func show_quit() -> void:
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	mode = "quit"
	var column := make_panel(420)
	panel.position.y = 260
	label_to(column, "SEE YOU AMONG THE STARS", 22)
	label_to(column, "You can close this browser tab to quit.", 16, MUTED)
	button_to(column, "BACK TO MENU", show_title)

static func clean_name(value: String) -> String:
	var result := ""
	for character in value.left(16):
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			result += character
	return "Explorer" if result.is_empty() else result

func save_settings() -> void:
	settings.set_value("player", "name", player_name)
	settings.set_value("player", "color", character_color)
	settings.set_value("display", "fps", show_fps)
	settings.set_value("network", "url", server_url)
	settings.save("user://settings.cfg")

func create_chat() -> void:
	chat_panel = PanelContainer.new()
	chat_panel.custom_minimum_size = Vector2(375, 140)
	var box := style(Color(0.035, 0.09, 0.14, 0.55), Color(0.2, 0.45, 0.58, 0.25))
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	chat_panel.add_theme_stylebox_override("panel", box)
	chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(chat_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_panel.add_child(column)
	chat_log = RichTextLabel.new()
	chat_log.custom_minimum_size = Vector2(355, 110)
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(chat_log)
	chat_entry = LineEdit.new()
	chat_entry.max_length = 240
	chat_entry.placeholder_text = "Message or /help ..."
	chat_entry.text_submitted.connect(submit_chat)
	column.add_child(chat_entry)
	chat_entry.hide()
	append_chat("Chat", "Press Enter to chat. /help lists commands.")

func append_chat(sender: String, message: String) -> void:
	var text := message.replace("\n", " ").replace("\r", " ").replace("\t", " ").left(480)
	chat_lines.append(sender.left(24) + ": " + text)
	while chat_lines.size() > 60:
		chat_lines.remove_at(0)
	if is_instance_valid(chat_log):
		chat_log.text = "\n".join(chat_lines)

func open_chat() -> void:
	if not is_instance_valid(chat_entry):
		return
	chat_open = true
	chat_entry.show()
	chat_entry.grab_focus()

func close_chat() -> void:
	chat_open = false
	if is_instance_valid(chat_entry):
		chat_entry.clear()
		chat_entry.hide()
		chat_entry.release_focus()

func submit_chat(value: String) -> void:
	var text := value.strip_edges()
	close_chat()
	if text.is_empty():
		return
	if net != null:
		net.send({"type": "chat", "text": text})
	elif text.begins_with("/"):
		append_chat("Admin", GemCommands.execute(text, self, {1: self}, true))
	else:
		append_chat(player_name, text)

func can_use_mouse() -> bool:
	if mode != "play" or chat_open:
		return false
	var cursor := get_global_mouse_position()
	return cursor.y < get_viewport_rect().size.y - 70 and (not is_instance_valid(chat_panel) or not chat_panel.get_global_rect().has_point(cursor))

func advance_motion(direction: float, jumping: bool, down: bool, delta: float) -> void:
	if fly_mode:
		player.velocity = Vector2(direction, float(down) - float(jumping)).limit_length(1) * 14
		player.position += player.velocity * delta
		player.position.x = clampf(player.position.x, 1, GemWorld.WIDTH - 2)
		player.position.y = clampf(player.position.y, 1, GemWorld.HEIGHT - 2)
		return
	player.step(world, direction, jumping and not was_jumping, jumping, delta)
	was_jumping = jumping
	if hook.x >= 0:
		energy = maxf(0, energy - delta * 8)
		var rope := hook - player.position
		if rope.length() > hook_length:
			player.velocity += rope.normalized() * 65 * delta
			var radial := -rope.normalized()
			if player.velocity.dot(radial) > 0:
				player.velocity -= radial * player.velocity.dot(radial)
		if energy <= 0:
			hook = Vector2(-1, -1)
	else:
		energy = minf(100, energy + delta * 18)

func travel(destination: int) -> void:
	if net != null:
		net.send({"type": "travel", "planet": destination})
		return
	clear_panel()
	planet = destination
	hook = Vector2(-1, -1)
	damage_cells.clear()
	for drop in drops:
		if drop.active:
			inventory[drop.id] += 1
		drop.active = false
	for enemy in enemies:
		enemy.active = false
	if worlds.has(planet):
		world = worlds[planet]
		finish_generation()
	else:
		world = GemWorld.new((universe_seed + planet * 104729) & 0x7fffffff)
		worlds[planet] = world
		generation = 0
		mode = "loading"

func finish_generation() -> void:
	generation = -1
	player.position = world.spawn
	player.velocity = Vector2.ZERO
	health = 100
	camera = player.position * TILE + Vector2(0, -90)
	mode = "play"
	last_reveal = Vector2i(-1, -1)
	world.light_dirty = true
	tell("Explore the forest. Copper and the Core wait below. Enter opens chat; /help lists commands.")

func tell(message: String) -> void:
	notice = message
	notice_time = 5

func _process(delta: float) -> void:
	if net != null:
		net.poll(delta)
	time += delta
	notice_time = maxf(0, notice_time - delta)
	if generation >= 0:
		world.generate_chunk(generation)
		generation += 1
		if generation == world.chunks.size():
			# Starter crystals make the iron-layer tool upgrade reachable.
			for x in range(126, 130):
				world.set_tile(x, 80, GemWorld.CRYSTAL)
			finish_generation()
	if save_store.saving:
		save_store.tick()
		if not save_store.saving:
			tell("Expedition saved." if save_store.error.is_empty() else save_store.error)
	if mode == "play" and not save_store.saving:
		camera = camera.lerp(player.position * TILE + Vector2(0, -90), 1.0 - exp(-delta * 9))
	if is_instance_valid(chat_panel):
		chat_panel.visible = mode in ["play", "pause", "craft", "orbit"]
		chat_panel.position = Vector2(14, get_viewport_rect().size.y - 230)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if mode != "play" or save_store.saving:
		return
	tick += 1
	mine_cooldown = maxf(0, mine_cooldown - delta)
	attack_time = maxf(0, attack_time - delta)
	invulnerable = maxf(0, invulnerable - delta)
	var direction := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var jumping := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or touch_jump
	if chat_open:
		direction = 0
		jumping = false
	advance_motion(clampf(direction + touch_axis, -1, 1), jumping, not chat_open and (Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)), delta)
	if net == null and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or touch_mine) and mine_cooldown <= 0 and can_use_mouse():
		use_tool()
	var cell := Vector2i(player.position.floor())
	if cell != last_reveal:
		world.reveal(player.position)
		last_reveal = cell
		world.light_dirty = true
	if tick % 6 == 0 and world.light_dirty:
		update_lighting()
	if net != null:
		return
	if tick % 3 == 0:
		world.fluid_tick(cell)
	if tick % 120 == 0:
		spawn_enemy()
		process_machines()
		grow_glowcap()
	for target in damage_cells.keys():
		if time - float(damage_cells[target]) > 3:
			world.set_field(target.x, target.y, 4, GemWorld.HP[world.get_field(target.x, target.y)])
			damage_cells.erase(target)
	update_entities(delta)
	health = minf(100, health + delta * 0.35)
	if health <= 0 or player.position.y > GemWorld.HEIGHT:
		player.position = world.spawn
		player.velocity = Vector2.ZERO
		health = 100
		hook = Vector2(-1, -1)
		tell("Rescued by the Core. Your inventory is safe.")
	autosave += delta
	if autosave > 90:
		autosave = 0
		save_game()

var was_jumping := false

func _unhandled_input(event: InputEvent) -> void:
	if save_store.saving:
		return
	if chat_open:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			close_chat()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_ENTER and mode == "play":
			open_chat()
			return
		if key == KEY_ESCAPE and mode in ["play", "pause", "craft", "orbit"]:
			if mode == "play":
				show_pause()
			else:
				clear_panel()
				mode = "play"
			return
		if mode != "play" or save_store.saving:
			return
		if key >= KEY_1 and key <= KEY_9:
			selected = key - KEY_1
		elif key == KEY_C:
			show_crafting()
		elif key == KEY_Q:
			if net != null:
				net.send({"type": "hook", "x": mouse_world().x, "y": mouse_world().y})
				return
			if hook.x >= 0:
				hook = Vector2(-1, -1)
			else:
				var target := world.raycast(player.position, mouse_world(), 12)
				if world.solid(target.x, target.y):
					hook = Vector2(target) + Vector2.ONE * 0.5
					hook_length = maxf(2, player.position.distance_to(hook) * 0.7)
		elif key == KEY_E:
			if net != null:
				net.send({"type": "core"})
				return
			if player.position.distance_to(Vector2(135, 33)) < 5:
				if inventory[6] >= 5 and not core_active:
					inventory[6] -= 5
					core_active = true
					tell("The Core is awake. The stars are waiting.")
				else:
					tell("The Core is awake." if core_active else "The Core needs 5 crystals.")
		elif key == KEY_M:
			show_orbit()
	if mode == "play" and event is InputEventMouseButton and event.pressed and not save_store.saving:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if can_use_mouse():
				if net != null:
					net.send({"type": "place", "x": mouse_world().x, "y": mouse_world().y, "slot": selected})
				else:
					place_tile()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected = (selected + 8) % 9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected = (selected + 1) % 9
		elif event.button_index == MOUSE_BUTTON_LEFT and event.position.y > get_viewport_rect().size.y - 62:
			var start := (get_viewport_rect().size.x - 450) / 2
			if event.position.x >= start and event.position.x < start + 450:
				selected = clampi(int((event.position.x - start) / 50), 0, 8)

func mouse_world() -> Vector2:
	return (get_global_mouse_position() - get_viewport_rect().size * 0.5 + camera) / TILE

func use_tool(target_position: Vector2 = Vector2.INF) -> void:
	mine_cooldown = 0.17
	if selected == 1:
		attack_time = 0.2
		for enemy in enemies:
			if enemy.active and (enemy.body as GemMotion).position.distance_to(player.position) < 2.8 and world.raycast(player.position, enemy.body.position) == Vector2i(enemy.body.position.floor()):
				enemy.hp -= tier
				enemy.body.velocity = (enemy.body.position - player.position).normalized() * 9 + Vector2(0, -5)
				if enemy.hp <= 0:
					enemy.active = false
					spawn_drop(enemy.body.position, GemWorld.CRYSTAL)
		return
	if selected > 1:
		place_tile(target_position)
		return
	var cell := world.raycast(player.position, mouse_world() if target_position == Vector2.INF else target_position)
	if not world.inside(cell.x, cell.y):
		return
	var id := world.get_field(cell.x, cell.y)
	if id == GemWorld.AIR:
		return
	if GemWorld.HARDNESS[id] > tier:
		tell("Needs a stronger pickaxe." if id != GemWorld.CORE else "The Core cannot be mined. Press E nearby.")
		return
	var hp := world.get_field(cell.x, cell.y, 4) - 22 * tier
	damage_cells[cell] = time
	if hp <= 0:
		# Reserve the drop first; a full pool must never delete an item.
		if not spawn_drop(Vector2(cell) + Vector2.ONE * 0.5, id):
			return
		world.set_tile(cell.x, cell.y, 0)
		damage_cells.erase(cell)
	else:
		world.set_field(cell.x, cell.y, 4, hp)

func place_tile(target_position: Vector2 = Vector2.INF) -> void:
	var id: int = SLOTS[selected] if selected > 1 else GemWorld.DIRT
	var cell := Vector2i((mouse_world() if target_position == Vector2.INF else target_position).floor())
	if player.position.distance_to(Vector2(cell) + Vector2.ONE * 0.5) > 5 or not world.inside(cell.x, cell.y):
		return
	if inventory[id] <= 0:
		tell("No %s left. Press C to craft." % GemWorld.NAMES[id].to_lower())
		return
	if world.get_field(cell.x, cell.y) != 0 or world.get_field(cell.x, cell.y, 5) != 0:
		return
	var hit := world.raycast(player.position, Vector2(cell) + Vector2.ONE * 0.5)
	if hit != cell:
		return
	var bounds := Rect2(player.position - player.half, player.half * 2)
	if bounds.intersects(Rect2(Vector2(cell), Vector2.ONE)):
		return
	for enemy in enemies:
		if enemy.active:
			var body: GemMotion = enemy.body
			if Rect2(body.position - body.half, body.half * 2).intersects(Rect2(Vector2(cell), Vector2.ONE)):
				return
	var supported := false
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if world.get_field(cell.x + d.x, cell.y + d.y) > 0:
			supported = true
	if not supported:
		tell("Build against an existing block.")
		return
	world.set_tile(cell.x, cell.y, id)
	inventory[id] -= 1

func spawn_drop(pos: Vector2, id: int) -> bool:
	for drop in drops:
		if not drop.active:
			drop.active = true
			drop.pos = pos
			drop.vel = Vector2(0.8, -3)
			drop.id = id
			return true
	return false

func update_entities(delta: float) -> void:
	for drop in drops:
		if not drop.active:
			continue
		var pos: Vector2 = drop.pos
		if pos.distance_to(player.position) < 3:
			drop.pos = pos.move_toward(player.position, 12 * delta)
			if drop.pos.distance_to(player.position) < 0.55:
				inventory[drop.id] += 1
				drop.active = false
		else:
			drop.vel.y = minf(12, drop.vel.y + 22 * delta)
			var target: Vector2 = pos + drop.vel * delta
			if world.solid(floori(target.x), floori(target.y + 0.15)):
				drop.vel = Vector2.ZERO
				if world.get_field(floori(pos.x), floori(pos.y + 0.3)) == GemWorld.BELT:
					drop.pos.x += 2 * delta
			else:
				drop.pos = target
	for enemy in enemies:
		if not enemy.active:
			continue
		var body: GemMotion = enemy.body
		if body.position.distance_to(player.position) > 45:
			enemy.active = false
			continue
		enemy.timer -= delta
		if body.grounded and enemy.timer <= 0:
			body.velocity = Vector2(signf(player.position.x - body.position.x) * 3, -7)
			enemy.timer = 1.4
		body.velocity.y = minf(20, body.velocity.y + 28 * delta)
		body.move(world, delta)
		if body.position.distance_to(player.position) < 1 and invulnerable <= 0 and not god_mode:
			health -= 12
			invulnerable = 1
			player.velocity = Vector2(signf(player.position.x - body.position.x) * 10, -7)

func spawn_enemy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed + tick
	for enemy in enemies:
		if enemy.active:
			continue
		for attempt in 12:
			var x := floori(player.position.x) + rng.randi_range(25, 34) * (-1 if rng.randf() < 0.5 else 1)
			var y := floori(player.position.y) + rng.randi_range(-8, 9)
			if world.inside(x, y) and not world.solid(x, y) and world.solid(x, y + 1):
				enemy.active = true
				enemy.hp = 3 + planet
				enemy.body.position = Vector2(x + 0.5, y + 0.5)
				enemy.body.velocity = Vector2.ZERO
				enemy.timer = 0.8
				return
		return

func grow_glowcap() -> void:
	var x := floori(player.position.x) + (tick * 17 % 43) - 21
	var y := floori(player.position.y) + (tick * 13 % 19) - 9
	if world.get_field(x, y) == 0 and world.solid(x, y + 1) and y > 36:
		world.set_tile(x, y, GemWorld.FLOWER)

func process_machines() -> void:
	# Local bounded graph traversal: generators energize connected wire/drill cells.
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	var center := Vector2i(player.position.floor())
	for y in range(center.y - 18, center.y + 19):
		for x in range(center.x - 28, center.x + 29):
			if world.get_field(x, y) == GemWorld.GENERATOR:
				queue.append(Vector2i(x, y))
	while not queue.is_empty() and visited.size() < 2048:
		var cell: Vector2i = queue.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		var id := world.get_field(cell.x, cell.y)
		if id == GemWorld.DRILL:
			var target := cell + Vector2i.DOWN
			var tile := world.get_field(target.x, target.y)
			if tile > 0 and GemWorld.HARDNESS[tile] <= 3 and spawn_drop(Vector2(cell) + Vector2(0.5, -0.3), tile):
				world.set_tile(target.x, target.y, 0)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + d
			if not visited.has(next) and world.get_field(next.x, next.y) in [GemWorld.WIRE, GemWorld.DRILL, GemWorld.GENERATOR]:
				queue.append(next)

func near_bench() -> bool:
	var p := Vector2i(player.position.floor())
	for y in range(p.y - 6, p.y + 7):
		for x in range(p.x - 6, p.x + 7):
			if world.get_field(x, y) == GemWorld.BENCH:
				return true
	return false

func can_craft(recipe: Array) -> bool:
	if recipe[4] == GemWorld.BENCH and not near_bench():
		return false
	if recipe[1] == -2 and tier >= 2 or recipe[1] == -3 and tier >= 3 or recipe[1] == -4 and ship:
		return false
	for id in recipe[3]:
		if inventory[id] < recipe[3][id]:
			return false
	return true

func craft(index: int) -> void:
	if net != null:
		net.send({"type": "craft", "recipe": index})
		return
	if index < 0 or index >= RECIPES.size():
		return
	var recipe: Array = RECIPES[index]
	if not can_craft(recipe):
		return
	for id in recipe[3]:
		inventory[id] -= recipe[3][id]
	if recipe[1] == -2:
		tier = 2
	elif recipe[1] == -3:
		tier = 3
	elif recipe[1] == -4:
		ship = true
	else:
		inventory[recipe[1]] += recipe[2]
	show_crafting()

func show_crafting() -> void:
	if server_actor:
		return
	mode = "craft"
	var column := make_panel(560)
	panel.position.y = 32
	label_to(column, "FIELD WORKSHOP", 25, MINT)
	label_to(column, "Workbench in range" if near_bench() else "Place a workbench nearby to unlock advanced recipes", 14, MUTED)
	for i in RECIPES.size():
		var recipe: Array = RECIPES[i]
		button_to(column, "%s    /    %s" % [recipe[0], recipe[5]], craft.bind(i), can_craft(recipe))
	button_to(column, "Back to expedition   [ Esc ]", resume)

func resume() -> void:
	clear_panel()
	mode = "play"

func show_pause() -> void:
	mode = "pause"
	var column := make_panel()
	label_to(column, "EXPEDITION PAUSED", 26, MINT)
	label_to(column, "Seed %s · %s" % [universe_seed, PLANET_NAMES[planet]], 14, MUTED)
	button_to(column, "Resume", resume)
	button_to(column, "Save expedition", save_game)
	button_to(column, "Crafting", show_crafting)
	button_to(column, "Star chart", show_orbit)
	button_to(column, "Return to title", show_title)
	label_to(column, "Left click: use tool · Right click: place\nQ: grapple / release · E: awaken Core\nM: star chart · C: craft · 1–9: select tool", 15, MUTED)

func show_orbit() -> void:
	mode = "orbit"
	var column := make_panel(500)
	label_to(column, "THE LOCAL CONSTELLATION", 24, MINT)
	label_to(column, "Spacecraft ready" if ship else "Craft a survey spacecraft to travel between planets", 14, MUTED)
	for i in PLANET_NAMES.size():
		button_to(column, "%02d   %s%s" % [i + 1, PLANET_NAMES[i], "   • YOU ARE HERE" if i == planet else ""], travel.bind(i), ship and i != planet)
	button_to(column, "Return   [ Esc ]", resume)

func save_game() -> void:
	if net != null:
		tell("Multiplayer worlds are managed by the server; local saves are separate.")
		return
	if world == null or generation >= 0:
		return
	# Magnetize all outstanding loot before checkpointing, preserving mined items.
	for drop in drops:
		if drop.active:
			inventory[drop.id] += 1
			drop.active = false
	var state := {"seed": universe_seed, "planet": planet, "tier": tier, "ship": ship, "core": core_active, "health": health, "x": player.position.x, "y": player.position.y, "inventory": Array(inventory)}
	if not save_store.begin(worlds, state):
		tell(save_store.error)
	else:
		resume()

func load_game() -> void:
	var state := save_store.restore()
	if state.is_empty():
		tell(save_store.error)
		return
	worlds = state.worlds
	universe_seed = int(state.seed)
	tier = int(state.tier)
	ship = state.ship
	core_active = state.core
	inventory = PackedInt32Array(state.inventory)
	travel(int(state.planet))
	player.position = Vector2(state.x, state.y)
	health = state.health
	camera = player.position * TILE
	tell("Welcome back, explorer.")

func update_lighting() -> void:
	light_values.fill(0)
	light_origin = Vector2i(player.position.floor()) - Vector2i(LIGHT_W / 2, LIGHT_H / 2)
	var tail := 0
	for y in LIGHT_H:
		for x in LIGHT_W:
			var wx := light_origin.x + x
			var wy := light_origin.y + y
			var id := world.get_field(wx, wy)
			var value := 0
			if wy < 23 and id == 0:
				value = 15
			elif id in [GemWorld.TORCH, GemWorld.CORE, GemWorld.GENERATOR]:
				value = 15
			elif id in [GemWorld.CRYSTAL, GemWorld.FLOWER]:
				value = 7
			if x == LIGHT_W / 2 and y == LIGHT_H / 2:
				value = 15
			if value > 0:
				var index := y * LIGHT_W + x
				light_values[index] = value
				light_queue[tail] = index
				tail += 1
	var head := 0
	while head < tail:
		var index := light_queue[head]
		head += 1
		var x := index % LIGHT_W
		var y := index / LIGHT_W
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or nx >= LIGHT_W or ny < 0 or ny >= LIGHT_H:
				continue
			var next := ny * LIGHT_W + nx
			var loss := 5 if world.solid(light_origin.x + nx, light_origin.y + ny) else 1
			var value := int(light_values[index]) - loss
			if value > light_values[next] and tail < light_queue.size():
				light_values[next] = value
				light_queue[tail] = next
				tail += 1
	world.light_dirty = false

func brightness(x: int, y: int) -> float:
	if y <= world.surface_height(x) + 1:
		return 1.0
	if world.get_field(x, y, 7) & 128 == 0:
		return 0.0
	var local := Vector2i(x, y) - light_origin
	if local.x < 0 or local.y < 0 or local.x >= LIGHT_W or local.y >= LIGHT_H:
		return 0.12
	return maxf(0.14, light_values[local.y * LIGHT_W + local.x] / 15.0)

func screen(pos: Vector2) -> Vector2:
	return pos * TILE - camera + get_viewport_rect().size * 0.5

func text_at(pos: Vector2, text: String, size: int = 16, color: Color = INK) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	var size := get_viewport_rect().size
	var in_world := mode in ["play", "pause", "craft", "orbit"] and world != null
	if in_world:
		draw_world()
		draw_hud()
		if mode != "play":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.1, 0.78))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b213d"))
		for i in 90:
			var point := Vector2(fposmod(i * 137.7, size.x), fposmod(i * 89.3, size.y))
			draw_rect(Rect2(point, Vector2.ONE * (2 if i % 5 else 3)), Color(0.65, 0.83, 0.94, 0.3 + 0.18 * sin(time + i)))
		GemArt.planet(self, Vector2(size.x * 0.14, 120), 48, Color("58a891"), true)
		GemArt.planet(self, Vector2(size.x * 0.86, 103), 62, Color("e7a54d"), false)
		GemArt.planet(self, Vector2(65, size.y - 36), 126, Color("278998"), false)
		GemArt.planet(self, Vector2(size.x - 112, size.y - 117), 44, Color("9956a9"), false)
		var title := "GEM FINDER"
		var title_width := ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		text_at(Vector2((size.x - title_width) / 2 + 3, 102), title, 48, Color("18384f"))
		text_at(Vector2((size.x - title_width) / 2, 97), title, 48, Color("edf2d3"))
		text_at(Vector2(size.x / 2 - 163, 129), "BUILD. EXPLORE. BRING YOUR FRIENDS.", 16, Color("94bbce"))
		if mode == "character":
			for i in 5:
				var pos := Vector2(size.x / 2 + (i - 2) * 82, 224)
				if i == character_color:
					draw_rect(Rect2(pos - Vector2(33, 52), Vector2(66, 102)), Color("78c86b"), false, 2)
				GemArt.astronaut(self, pos, GemArt.SUITS[i], 0, 1, 2)
		if mode in ["loading", "connecting", "sync"]:
			var progress: float = generation / 48.0 if mode == "loading" else (net.received.size() / 48.0 if net != null else 0)
			var message := "GENERATING WORLD" if mode == "loading" else "CONNECTING TO EXPEDITION"
			text_at(Vector2(size.x / 2 - 180, 302), message, 25)
			draw_rect(Rect2(size.x / 2 - 180, 330, 360, 10), Color("233f59"))
			draw_rect(Rect2(size.x / 2 - 180, 330, 360 * progress, 10), Color("71c95c"))
			text_at(Vector2(size.x / 2 - 90, 377), "Please wait...  Esc to cancel", 14, MUTED)
	if save_store.saving:
		text_at(Vector2(20, 104), "Saving world...", 16, GOLD)
	if notice_time > 0:
		var text := notice.left(110)
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30
		var rect := Rect2((size.x - width) / 2, 112 if in_world else size.y - 55, width, 32)
		draw_rect(rect, Color(0.025, 0.08, 0.15, 0.9))
		text_at(rect.position + Vector2(15, 22), text, 15, GOLD)

func draw_background() -> void:
	var size := get_viewport_rect().size
	var daylight := clampf((35 - player.position.y) / 12, 0, 1)
	var sky := Color("101c2d").lerp(Color("65c1e9"), daylight)
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	if daylight > 0:
		for i in 7:
			var x := fposmod(i * 281 - camera.x * 0.15 + time * 2, size.x + 260) - 130
			var y := 85 + i % 3 * 40
			for segment in 5:
				draw_rect(Rect2(x + segment * 26, y - (2 - absi(2 - segment)) * 14, 31, 20 + (2 - absi(2 - segment)) * 14), Color(0.88, 0.98, 1, daylight * 0.9))
		for layer in 2:
			for i in 17:
				var x := fposmod(i * 123 - camera.x * (0.25 + layer * 0.15), size.x + 180) - 90
				GemArt.tree(self, Vector2(x, screen(Vector2(128, 22)).y + 25 + layer * 12), 100 + (i * 37 % 100) + layer * 40, Color(0.65, 0.9, 0.79, daylight * 0.9) if layer == 0 else Color(0.8, 1, 0.87, daylight))
	else:
		for i in 14:
			var x := fposmod(i * 153 - camera.x * 0.3, size.x + 160) - 80
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 70, 0), Vector2(x + 45, 150 + i % 4 * 45)]), Color("192d36"))
	# World-aligned trees do not obstruct collision or mining.
	var left := floori((camera.x - size.x / 2) / TILE) - 6
	var right := ceili((camera.x + size.x / 2) / TILE) + 6
	for x in range(left, right):
		if posmod(x, 11) == 0 and (x < 108 or x > 150):
			GemArt.tree(self, screen(Vector2(x + 0.5, world.surface_height(x))), 130 + posmod(x * 7, 70), Color.WHITE)
	GemArt.ship(self, screen(Vector2(140, 22)))

func draw_world() -> void:
	draw_background()
	var size := get_viewport_rect().size
	var top := Vector2i(((camera - size * 0.5) / TILE).floor()) - Vector2i.ONE
	var count := Vector2i((size / TILE).ceil()) + Vector2i(3, 3)
	for y in range(top.y, top.y + count.y):
		for x in range(top.x, top.x + count.x):
			var pos := screen(Vector2(x, y))
			var rect := Rect2(pos, Vector2.ONE * TILE)
			var light := brightness(x, y)
			if light == 0:
				draw_rect(rect, Color("101823"))
				continue
			var id := world.get_field(x, y)
			if world.get_field(x, y, 2) > 0:
				var base := Color("35432d") if y < 58 else (Color("50312c") if y < 106 else Color("24454c"))
				draw_rect(rect, base * Color(light, light, light))
			if id > 0:
				draw_tile(id, pos, light, x * 13 + y * 7)
				if id == GemWorld.DIRT and y < 29 and world.get_field(x, y - 1) == 0:
					draw_rect(Rect2(pos, Vector2(TILE, 5)), Color("6bb942"))
					draw_rect(Rect2(pos, Vector2(TILE, 2)), Color("a6dd56"))
					for i in 3:
						draw_rect(Rect2(pos + Vector2(i * 8 + 1, 4), Vector2(4, 4 + posmod(x + i, 4))), Color("48883a"))
					if posmod(x, 4) == 0:
						draw_line(pos + Vector2(9, 0), pos + Vector2(9, -9), Color("4a853e"), 2)
						draw_rect(Rect2(pos + Vector2(6, -12), Vector2(7, 6)), Color("e4c650") if posmod(x, 3) else Color("e1a9ba"))
				var hp := world.get_field(x, y, 4)
				if hp < GemWorld.HP[id] and hp > 0:
					draw_line(pos + Vector2(4, 19), pos + Vector2(20, 19), Color("17212b"), 3)
					draw_line(pos + Vector2(4, 19), pos + Vector2(4 + 16.0 * hp / GemWorld.HP[id], 19), GOLD, 2)
			var volume := world.get_field(x, y, 5) >> 4
			if volume > 0:
				draw_rect(Rect2(pos + Vector2(0, TILE * (1 - volume / 15.0)), Vector2(TILE, TILE * volume / 15.0)), Color(0.12, 0.5, 0.78, 0.65 * light))
	for drop in drops:
		if drop.active:
			var pos: Vector2 = drop.pos
			if brightness(floori(pos.x), floori(pos.y)) > 0:
				draw_rect(Rect2(screen(pos) - Vector2(4, 4), Vector2(8, 8)), GemWorld.COLORS[drop.id])
	for enemy in enemies:
		if enemy.active:
			var pos: Vector2 = enemy.body.position
			if brightness(floori(pos.x), floori(pos.y)) > 0.2:
				var p := screen(pos)
				draw_rect(Rect2(p - Vector2(11, 6), Vector2(22, 14)), Color("75ae4f"))
				draw_rect(Rect2(p - Vector2(8, 9), Vector2(16, 8)), Color("9aca62"))
				draw_rect(Rect2(p + Vector2(-5, -3), Vector2(3, 3)), Color("273832"))
				draw_rect(Rect2(p + Vector2(4, -3), Vector2(3, 3)), Color("273832"))
	if net != null:
		for remote in net.remote_players:
			if int(remote.id) == net.id:
				continue
			var pos := screen(Vector2(remote.x, remote.y))
			GemArt.astronaut(self, pos, GemArt.SUITS[clampi(int(remote.color), 0, 4)], time * 9 if absf(remote.vx) > 0.5 else 0, -1 if remote.vx < 0 else 1)
			text_at(pos + Vector2(-25, -31), str(remote.name), 13)
	var p := screen(player.position)
	if hook.x >= 0:
		draw_line(p, screen(hook), GOLD, 1.5)
		draw_circle(screen(hook), 3, GOLD)
	if invulnerable <= 0 or tick % 8 < 4:
		var facing := -1.0 if mouse_world().x < player.position.x else 1.0
		GemArt.astronaut(self, p, GemArt.SUITS[character_color], time * 12 if absf(player.velocity.x) > 0.5 else 0, facing)
		var aim := (mouse_world() - player.position).normalized()
		draw_line(p + aim * 7, p + aim * 24, Color("625e4c"), 4)
		draw_line(p + aim * 24 - aim.orthogonal() * 8, p + aim * 24 + aim.orthogonal() * 8, Color("bac9b8"), 4)
	text_at(p + Vector2(-24, -32), player_name, 13)
	if attack_time > 0:
		draw_arc(p, 48, -1.3, 1.3, 18, Color(0.7, 1, 0.9, attack_time * 4), 4)
	var target := world.raycast(player.position, mouse_world()) if selected == 0 else Vector2i(mouse_world().floor())
	if player.position.distance_to(Vector2(target) + Vector2.ONE * 0.5) <= 5.1 and can_use_mouse():
		draw_rect(Rect2(screen(Vector2(target)), Vector2.ONE * TILE), Color("f5eebb"), false, 1)

func draw_tile(id: int, pos: Vector2, light: float, variant: int) -> void:
	var tint := Color(light, light, light)
	var color: Color = GemWorld.COLORS[id] * tint
	if id == GemWorld.TORCH:
		draw_rect(Rect2(pos + Vector2(10, 9), Vector2(4, 15)), Color("93603f") * tint)
		draw_rect(Rect2(pos + Vector2(8, 5), Vector2(8, 9)), Color("e7903e") * tint)
		draw_rect(Rect2(pos + Vector2(10, 3), Vector2(4, 8)), Color("ffeaa0") * tint)
	elif id == GemWorld.WIRE:
		draw_line(pos + Vector2(0, 12), pos + Vector2(24, 12), color, 2)
		draw_line(pos + Vector2(12, 0), pos + Vector2(12, 24), color, 2)
	elif id == GemWorld.FLOWER:
		draw_line(pos + Vector2(12, 23), pos + Vector2(12, 13), color, 2)
		draw_rect(Rect2(pos + Vector2(5, 9), Vector2(14, 6)), color)
	elif id == GemWorld.CORE:
		draw_rect(Rect2(pos + Vector2(2, 0), Vector2(20, 24)), Color("294b56") * tint)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(12, 2), pos + Vector2(20, 12), pos + Vector2(12, 22), pos + Vector2(4, 12)]), color)
	elif id >= GemWorld.BENCH:
		draw_rect(Rect2(pos + Vector2(1, 4), Vector2(22, 20)), color.darkened(0.35))
		draw_rect(Rect2(pos + Vector2(2, 4), Vector2(20, 5)), color)
		if id == GemWorld.BELT:
			for i in 3:
				draw_rect(Rect2(pos + Vector2(3 + i * 8, 16), Vector2(5, 5)), color)
		elif id == GemWorld.GENERATOR:
			draw_rect(Rect2(pos + Vector2(8, 10), Vector2(8, 9)), MINT * tint)
		elif id == GemWorld.DRILL:
			draw_colored_polygon(PackedVector2Array([pos + Vector2(5, 10), pos + Vector2(19, 10), pos + Vector2(12, 24)]), GOLD * tint)
	else:
		if id == GemWorld.DIRT:
			color = Color("855737") * tint
		draw_rect(Rect2(pos, Vector2.ONE * TILE), color.darkened(float(posmod(variant, 5)) * 0.025))
		for i in 4:
			var center := pos + Vector2(2 + posmod(variant + i * 7, 18), 3 + posmod(variant * 3 + i * 5, 17))
			var ore_tile := id in [GemWorld.COPPER, GemWorld.IRON, GemWorld.CRYSTAL]
			draw_rect(Rect2(center, Vector2(3 + i % 2, 3)), color.lightened(0.22 * light) if ore_tile else color.darkened(0.18))
		draw_line(pos, pos + Vector2(24, 0), color.darkened(0.12), 1)

func draw_hud() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(14, 14, 226, 67), Color(0.025, 0.08, 0.13, 0.55))
	text_at(Vector2(23, 34), "+", 22, Color("e56557"))
	draw_rect(Rect2(47, 21, 174, 14), Color("59392f"))
	draw_rect(Rect2(49, 23, 170 * health / 100, 10), Color("e75b4e"))
	text_at(Vector2(23, 61), "+", 22, Color("6dc2e1"))
	draw_rect(Rect2(47, 48, 174, 12), Color("264e6c"))
	draw_rect(Rect2(49, 50, 170 * energy / 100, 8), Color("4babcf"))
	text_at(Vector2(252, 30), "HP %s / 100" % int(health), 12)
	text_at(Vector2(252, 54), "GOD ON" if god_mode else "FLY ON" if fly_mode else "Tier %s" % tier, 12, GOLD)
	text_at(Vector2(size.x - 238, 28), PLANET_NAMES[planet], 14)
	text_at(Vector2(size.x - 238, 48), "%s   x %.1f  y %.1f" % ["ONLINE" if net != null else "SOLO", player.position.x, player.position.y], 12, MUTED)
	if net != null and net.admin:
		text_at(Vector2(size.x - 238, 67), "ADMIN", 12, GOLD)
	var start := (size.x - 450) / 2
	draw_rect(Rect2(start - 5, size.y - 66, 460, 58), Color("102133"))
	draw_rect(Rect2(start - 5, size.y - 66, 460, 58), Color("527795"), false, 2)
	for i in 9:
		var rect := Rect2(start + i * 50, size.y - 61, 46, 47)
		draw_rect(rect, Color("47637b") if i == selected else Color("21384a"))
		draw_rect(rect, Color("e8ce72") if i == selected else Color("628199"), false, 2 if i == selected else 1)
		text_at(rect.position + Vector2(3, 11), str(i + 1), 10, Color("c8d8df"))
		if i > 1:
			draw_tile(SLOTS[i], rect.position + Vector2(10, 10), 1, i)
			text_at(rect.position + Vector2(27, 41), str(inventory[SLOTS[i]]), 11)
		else:
			draw_line(rect.position + Vector2(14, 35), rect.position + Vector2(32, 15), GOLD, 3)
			draw_line(rect.position + Vector2(20, 14), rect.position + Vector2(38, 21), Color("cbd8cb"), 4)
	text_at(Vector2(start, size.y - 76), SLOT_NAMES[selected] + "  |  C Craft   M Map   Enter Chat", 13, Color("e4e9cc"))
	text_at(Vector2(14, size.y - 33), "Stone %s  Copper %s  Iron %s  Crystal %s" % [inventory[2], inventory[3], inventory[5], inventory[6]], 12, GOLD)
	if show_fps:
		text_at(Vector2(size.x - 85, size.y - 26), "%s FPS" % int(Engine.get_frames_per_second()), 12, MUTED)
