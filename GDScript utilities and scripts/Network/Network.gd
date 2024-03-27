class_name Network

const net_prefix: String = "net_"
const net_updated_this_frame: String = "net_updated_this_frame"
enum {DISCONNECTED = -1, HOST, SERVER}
const localhost = 'localhost'
const loopback = '127.0.0.1'
enum {DEFAULT_PORT = 25565}

const sheila: String = "73.234.173.172"

const COMMAND_FRAME_RATE_SETTING_PATH = &"quack/network/maximum_command_frame_rate"
const PREFERRED_BUFFER_SIZE_SETTING_PATH = &"quack/network/preferred_buffer_size"
const MAX_RECEIVE_BANDWIDTH_SETTING_PATH = &"quack/network/max_receive_bandwidth"
const MAX_SEND_BANDWIDTH_SETTING_PATH = &"quack/network/max_send_bandwidth"

static var peer: ENetMultiplayerPeer
static var is_connected_to_internet: bool
static var connected_to_sheila: bool

static var input_buffer_size: int
static var worldstate_buffer_size: int
static var packet_buffer_size: int

static var server_browser_util: ServerBrowserUtil = ServerBrowserUtil.new()

## Used in [method update_net_receive_time] to calculate the
## [member delta_time_net_receive] by updating to [method Time.get_ticks_usec],
## and subtracting [member last_time_net_receive] from this value.
static var current_time_net_receive: int = 0
## The last time, in usec, that a multiplayer packet was received.
static var last_time_net_receive: int = 0
## The difference, in usec, between the last time a multiplayer packet was
## received, and the most recent time a multiplayer packet was received.
static var delta_time_net_receive: int = 0
## Used to calculate the estimated times when a client should expect to receive
## multiplayer packets. Updated to [method Time.get_ticks_usec] when
## [method receive_server_info] is called.
static var net_receive_start_time: int = 0

## Updates [member current_time_net_receive], [member last_time_net_receive]
## and calculates [member delta_time_net_receive] by subtracting the former two.
## Called every time the game receives a multiplayer packet.
static func update_net_receive_time() -> void:
	current_time_net_receive = Time.get_ticks_usec()
	delta_time_net_receive = current_time_net_receive - last_time_net_receive
	last_time_net_receive = current_time_net_receive

static func begin_net_receive_tracking() -> void:
	net_receive_start_time = Time.get_ticks_usec()
	last_time_net_receive = net_receive_start_time

static func initialize() -> void:
	@warning_ignore("assert_always_true")
	assert(Events.EVENTMAX < 257, "Number of events must fit into a single u8, but EVENTMAX is currently %s, which implies there are 256 or more events."%[Events.EVENTMAX])
	@warning_ignore("assert_always_true")
	assert(NetworkPacket.PACKET_TYPE_MAX < 257, "Number of packet types must fit into a single u8, but PACKET_TYPE_MAX is currently %s, which implies there are 256 or more packet types."%[NetworkPacket.PACKET_TYPE_MAX])
	QuackMultiplayer.register_all_scripts()
	server_browser_util.begin_broadcasting_as_client.call_deferred()
	server_browser_util.begin_listening.call_deferred()

static func get_mp() -> MultiplayerAPI:
	return Quack.get_mp()

static func get_local_mp_id() -> int:
	return Quack.get_local_mp_id()

## Signature offset in a given serialized format of something. The offset of
## a signature is always going to be the first byte, regardless of the size
## of the signature, or the remainder of whatever is serialized.
const SIGNATURE = 0

static func create_server(map_filepath: String, max_players: int, max_spectators: int, max_clients: int, tickrate: int,
_snapshot_tickrate: int, port: int) -> void:
	assert(tickrate > 9,"Servers shouldn't run at a tickrate lower than 10. %s is too small."%[tickrate])# and snapshot_tickrate > 0)
	assert(max_players+max_spectators <= max_clients,"%s is not enough maximum clients allowed to connect to a server. Servers must accomodate enough clients to accomodate up to maximum players (%s) + maximum spectators (%s)."%[max_clients,max_players,max_spectators])
	if Engine.get_physics_ticks_per_second() != tickrate:
		Tickrate.set_physics_simulation_rate(tickrate)
	reset_if_connected()
	setup_new_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	var err: Error = peer.create_server(port,max_clients)
	if err != OK:
		Console.write("Failed to create server on port %s. Error %s."%[port,error_string(err)])
		return reset()
	else:
		Console.write("Created server on port %s\nMax players: %s\nMax spectators: %s\nMax clients: %s\nTickrate: %s\nMap: %s"%
	[port,max_players,max_spectators,max_clients,tickrate,map_filepath])
	setup_server_connections()
	assign_multiplayer_peer(peer)
	Quack.change_scene(map_filepath)
	GameState.max_players = max_players
	GameState.max_spectators = max_spectators
	GameState.max_clients = max_clients
	#server_browser_util.stop_listening() # maybe don't, so that ppl can look for other games
	server_browser_util.stop_broadcasting()
	server_browser_util.begin_broadcasting(
		ServerBrowserUtil.create_selfserver_packet(port)
	)

static func create_dedicated_server(map_filepath: String, max_players: int, max_spectators: int,
tickrate: int, snapshot_tickrate: int, port: int) -> void:
	Console.write("Attempting to host dedicated server on "+map_filepath)
	create_server(
		map_filepath,
		max_players,
		max_spectators,
		max_players+max_spectators,
		tickrate,
		snapshot_tickrate,
		port
	)
	WindowUtils.append_to_window_title(" (SERVER)")

static func host(map_filepath: String, max_players: int, max_spectators: int, tickrate: int,
snapshot_tickrate: int, port: int) -> void:
	Console.write("Attempting to host game on "+map_filepath)
	create_server(
		map_filepath,
		max_players,
		max_spectators,
		max_players+max_spectators,
		tickrate,
		snapshot_tickrate,
		port
	)
	WindowUtils.append_to_window_title(" (HOST)")

static func setup_new_peer(mode: int = SERVER) -> void:
	assert(mode == SERVER or mode == MultiplayerPeer.TARGET_PEER_BROADCAST,"Targeting mode %s is incorrect. Target mode either needs to be set to target the server, %s, or set to broadcast, %s."%[mode,SERVER,MultiplayerPeer.TARGET_PEER_BROADCAST])
	var new_peer := ENetMultiplayerPeer.new()
	new_peer.set_target_peer(mode)
	new_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	peer = new_peer

static func assign_multiplayer_peer(new_peer: MultiplayerPeer) -> void:
	get_mp().set_multiplayer_peer(new_peer)

static func reset() -> void:
	Console.write("Resetting peer")
	if peer:
		peer.close()
	peer = null
	if Engine.get_physics_ticks_per_second() != 60 or Tickrate.target_physics_rate != 60:
		Tickrate.set_physics_simulation_rate(60)
	assign_multiplayer_peer(OfflineMultiplayerPeer.new())
	@warning_ignore("static_called_on_instance")
	Quack.disconnect_all_signals(Quack.multiplayer)
	# disconnect peer connections
	# disconnect tick funcs
	# reset vars
	# emit network ended signal
	# save history
	# this is hacky and dumb as fuck
	Quack.change_scene("res://Interface/Menus/Main Menu/Main Menu.tscn")
	WindowUtils.reset_window_title()
	ConnectivityTester.test_internet_connection()

static func multiplayer_connected() -> bool:
	return peer != null

static func reset_if_connected() -> void:
	if multiplayer_connected():
		reset()

static func get_sender_id() -> int:
	return get_mp().get_remote_sender_id()

static func connect_to_server(ip: String = localhost, port: int = DEFAULT_PORT) -> void:
	Console.write("Attempting to connect to server %s on port %s"%[ip,port])
	reset_if_connected()
	setup_new_peer()
	if NetDebug.lag_faker_active():
		NetDebug.lag_faker.connect_to_server(ip,port)
		NetDebug.lag_faker.connect_enet_peer(peer)
	else:
		peer.create_client(ip,port)
	assign_multiplayer_peer(peer)
	setup_client_connecting_connections()

static func setup_client_connecting_connections() -> void:
	var multiplayer: MultiplayerAPI = get_mp()
	multiplayer.connected_to_server.connect(Network.on_connection_succeeded)
	multiplayer.connection_failed.connect(Network.on_connection_failed)

static func setup_server_connections() -> void:
	@warning_ignore("shadowed_variable_base_class")
	var multiplayer: MultiplayerAPI = get_mp()
	multiplayer.peer_connected.connect(Network.on_peer_connected)
	multiplayer.peer_disconnected.connect(Network.on_peer_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(ClientPacket.receive_client_packet)

static func setup_client_connections() -> void:
	var multiplayer: MultiplayerAPI = get_mp()
	multiplayer.server_disconnected.connect(Network.on_server_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(ServerPacket.receive_server_packet)

static func is_server() -> bool:
	return get_local_mp_id() == SERVER

static func get_hostname_win() -> String:
	return IP.resolve_hostname(OS.get_environment("COMPUTERNAME"),IP.TYPE_IPV4)

static func get_hostname_unix() -> String:
	return IP.resolve_hostname(OS.get_environment("HOSTNAME"),IP.TYPE_IPV4)

static func get_hostname_desktop() -> String:
	if OS.has_environment("windows"):
		return get_hostname_win() 
	elif OS.has_environment("x11") or OS.has_environment("OSX"):
		return get_hostname_unix()
	else:
		return "Not Desktop"

static func get_loopback_hostname() -> String:
	return IP.resolve_hostname(loopback)

static func get_localhost_hostname() -> String:
	return IP.resolve_hostname(localhost)

static func on_peer_disconnected(peer_id: int) -> void:
	Console.write("Peer %s disconnected."%[peer_id])
	GameState.remove_client(peer_id)

# Client connection funcs
static func on_connection_succeeded() -> void:
	Console.write("Connection succeeded!")
	@warning_ignore("static_called_on_instance")
	Quack.disconnect_all_signals(get_mp())
	Network.setup_client_connections()

static func on_connection_failed() -> void:
	Console.write("Connection failed.")
	reset()

# Client funcs
static func on_server_disconnected() -> void:
	Console.write("Server disconnected.")
	reset()

static func on_peer_connected(peer_id: int) -> void:
	Console.write("Peer %s connected."%[peer_id])
	if GameState.can_accept_new_client():
		send_packet_to_peer(peer_id,GameState.get_server_info(),MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	else:
		Console.write("Peer %s denied. No room for new client. (%s/%s clients, %s/%s players, %s/%s spectators.)"%
		[peer_id,GameState.num_clients,GameState.max_clients,
		GameState.num_players,GameState.max_players,
		GameState.num_spectators,GameState.max_spectators])
		
		# forcibly disconnect peer because it doesn't emit peer_disconnected
		# which would call on_peer_disconnected and would try to remove a
		# nonexistent client.
		peer.disconnect_peer(peer_id,true)

static func send_packet_to_peer(peer_id: int, packet: PackedByteArray, transfer_mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE) -> void:
	assert(transfer_mode <= MultiplayerPeer.TRANSFER_MODE_RELIABLE and transfer_mode >= MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, "transfer_mode must be a number between %s and %s, but was passed as %s."%[MultiplayerPeer.TRANSFER_MODE_RELIABLE,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,transfer_mode])
	(Quack.multiplayer as SceneMultiplayer).send_bytes(packet,peer_id,transfer_mode)
	# maybe at some point turn this func (which returns an error) into something
	# that checks for and prints errors

static func get_max_command_frame_rate() -> int:
	return Quack.get_setting_safe(COMMAND_FRAME_RATE_SETTING_PATH,0)

static func get_preferred_buffer_size() -> int:
	return Quack.get_setting_safe(PREFERRED_BUFFER_SIZE_SETTING_PATH,0)

static func get_max_send_bandwidth() -> int:
	return Quack.get_setting_safe(MAX_SEND_BANDWIDTH_SETTING_PATH,0)

static func get_max_receive_bandwidth() -> int:
	return Quack.get_setting_safe(MAX_RECEIVE_BANDWIDTH_SETTING_PATH,0)
