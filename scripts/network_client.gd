class_name GemNet
extends RefCounted

var game: Node
var peer := WebSocketPeer.new()
var connected := false
var welcomed := false
var hello_sent := false
var elapsed := 0.0
var send_timer := 0.0
var id := 0
var admin := false
var token := ""
var remote_players: Array = []
var received: Dictionary = {}

func _init(owner_game: Node) -> void:
	game = owner_game
	peer.inbound_buffer_size = 4194304
	peer.outbound_buffer_size = 262144
	peer.max_queued_packets = 512

func connect_to(url: String, admin_token: String = "") -> Error:
	token = admin_token
	return peer.connect_to_url(url)

func send(message: Dictionary) -> void:
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peer.send_text(JSON.stringify(message))

func close() -> void:
	peer.close(1000, "Left expedition")
	token = ""
	connected = false

func poll(delta: float) -> void:
	elapsed += delta
	peer.poll()
	var state := peer.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED or (not connected and elapsed > 20):
		game.network_failed("Connection closed or timed out. Check the server address and that the server is running.")
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not hello_sent:
		send({"type": "hello", "version": 1, "name": game.player_name, "color": game.character_color, "token": token})
		token = ""
		hello_sent = true
	var budget := 32
	while peer.get_available_packet_count() > 0 and budget > 0:
		budget -= 1
		var packet := peer.get_packet()
		if packet.size() > 262144:
			game.network_failed("Server sent an oversized packet.")
			return
		var message = JSON.parse_string(packet.get_string_from_utf8())
		if message is Dictionary:
			handle(message)
	if not connected:
		return
	send_timer += delta
	if send_timer >= 0.05:
		send_timer = 0
		var active: bool = game.mode == "play" and not game.chat_open
		var direction := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var aim: Vector2 = game.mouse_world()
		send({"type": "input", "dx": direction if active else 0, "jump": active and (Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)), "down": active and (Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)), "mine": active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and game.can_use_mouse(), "x": aim.x, "y": aim.y, "slot": game.selected})

func handle(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"welcome":
			id = int(message.id)
			admin = bool(message.admin)
			game.universe_seed = int(message.seed)
			game.planet = int(message.get("planet", 0))
			game.world = GemWorld.new(game.universe_seed)
			game.worlds = {game.planet: game.world}
			game.generation = -1
			game.mode = "sync"
			game.player_name = str(message.name)
			game.character_color = int(message.color)
			welcomed = true
			connected = false
			received.clear()
			remote_players.clear()
		"chunk":
			if not welcomed:
				return
			var index := int(message.get("index", -1))
			if index < 0 or index >= 48 or not message.get("data") is String:
				return
			var chunk: GemChunk = game.world.chunks[index]
			var explored := chunk.data.duplicate()
			if not chunk.decode(Marshalls.base64_to_raw(message.data)):
				game.network_failed("Invalid world data from server.")
				return
			for offset in range(7, chunk.data.size(), 8):
				chunk.data[offset] |= explored[offset] & 128
			received[index] = true
			game.world.light_dirty = true
		"ready":
			if received.size() != 48:
				game.network_failed("Incomplete world snapshot.")
				return
			game.finish_generation()
			connected = true
			game.append_chat("Server", "Connected as %s%s. Enter to chat; /help for commands." % [game.player_name, " [ADMIN]" if admin else ""])
			send({"type": "ready"})
		"chat":
			game.append_chat(str(message.get("name", "Server")), str(message.get("text", "")))
		"error":
			game.append_chat("Server", str(message.get("text", "Request rejected.")))
		"snapshot":
			if not connected:
				return
			remote_players = message.get("players", [])
			var own: Dictionary = message.get("self", {})
			if own.is_empty():
				return
			var authoritative := Vector2(float(own.x), float(own.y))
			var distance: float = game.player.position.distance_to(authoritative)
			if distance > 0.65:
				game.player.position = authoritative
				game.player.velocity = Vector2(float(own.vx), float(own.vy))
			game.health = float(own.health)
			game.energy = float(own.energy)
			game.god_mode = bool(own.god)
			game.fly_mode = bool(own.fly)
			game.tier = int(own.tier)
			game.ship = bool(own.ship)
			game.core_active = bool(own.core)
			game.hook = Vector2(float(own.hx), float(own.hy))
			game.hook_length = float(own.rope)
			admin = bool(own.admin)
			if own.inventory is Array and own.inventory.size() == 16:
				var next_inventory := PackedInt32Array(own.inventory)
				var changed: bool = next_inventory != game.inventory
				game.inventory = next_inventory
				if changed and game.mode == "craft":
					game.show_crafting()
			for enemy in game.enemies:
				enemy.active = false
			var enemy_index := 0
			for enemy in message.get("enemies", []):
				if enemy_index >= game.enemies.size():
					break
				game.enemies[enemy_index].active = true
				game.enemies[enemy_index].body.position = Vector2(enemy.x, enemy.y)
				enemy_index += 1
			for drop in game.drops:
				drop.active = false
			var drop_index := 0
			for drop in message.get("drops", []):
				if drop_index >= game.drops.size():
					break
				game.drops[drop_index].active = true
				game.drops[drop_index].pos = Vector2(drop.x, drop.y)
				game.drops[drop_index].id = int(drop.id)
				drop_index += 1
