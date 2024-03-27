extends Node

## Setting path to access the number of desired users playing the game.
const NUM_USERS_SETTING = &"quack/gameplay/number_of_players"
const PHYSICS_FRAMERATE_SETTING = &"physics/common/physics_ticks_per_second"

## Dictionary of [Node]s that are currently removed from [member tree], but are not freed from
## memory. Keys are the nodes' instance ID's. Values are references to the nodes
## themselves.
var removed_nodes: Dictionary = {}
## Dictionary of [int]'s serving as node ID's for each [Node] in [member removed_nodes].
## Keys are [Nodes]s in [member removed_nodes] (calling [method Dictionary.values]
## is the same as calling [method Dictionary.keys] on [member removed_node_ids])
## Values are the nodes' multiplayer ID's.
var removed_node_ids: Dictionary = {}
## Calls that will be executed on the next frame during [method _process].
var next_frame_calls: Array[Callable]
## Calls that will be executed on the next physics frame during [method _physics_process].
var next_physics_frame_calls: Array[Callable]
## The number of desired users playing the game.
var num_users: int = 1

## The player's username. Hopefully will be depreciated soon.
var username: String

## Cached accessor for the game's root [Window]. Accessing this is functionally
## the same as [method get_root]. Updated by default before [method _ready] is
## called.
@onready var root: Viewport = get_root()
##Cached accessor for the game's [SceneTree]. Accessing this is functionally the
## same as [method Node.get_tree]. Updated by default before [method _ready] is called.
@onready var tree: SceneTree = get_tree()
## Cached accessor for the game's [PhysicsDirectSpaceState3D]. Accessing this
## is functionally the same as accessing [member root]'s [code]world_3d[/code]'s
## [code]direct_space_state[/code]. Declared before [method _ready] is called,
## but assigned at the end of the first time [method _physics_process] is called.
@onready var query: PhysicsDirectSpaceState3D# = root.world_3d.direct_space_state

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	TimeUtils.update_physics_times()
	execute_next_physics_frame_calls()
	if TimeUtils.is_startup():
		query = root.world_3d.direct_space_state

## Calls every [Callable] in [member next_physics_frame_calls] and then clears
## the array. Called every time [method _physics_process] is called.
func execute_next_physics_frame_calls() -> void:
	for callable in next_physics_frame_calls:
		callable.call()
	next_physics_frame_calls.clear()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	TimeUtils.update_process_times()
#	if current_time_thread != current_time:
#		print("main: threaded time %s != %s"%[current_time_thread, current_time])
	execute_next_frame_calls()

## Calls every [Callable] in [member next_frame_calls] and then clears the array.
## Called every time [method _process] is called.
func execute_next_frame_calls() -> void:
	for callable in next_frame_calls:
		callable.call()
	next_frame_calls.clear()

func _init() -> void:
#	stupid_shader_cache_workaround()
	# Passing self cuz 'Quack' as a thing isnt initialized yet is is insanely stupid
	assert(!Resources.resources.is_empty())
	Tickrate.initialize()
	Network.initialize()
	num_users = get_setting_safe(NUM_USERS_SETTING,1)
	assert_valid_number_of_users()
	# maybe put this at the end of _ready()?
	TimeUtils.begin_physics_tracking()

func stupid_shader_cache_workaround() -> void:
	var node := Node.new()
	add_child(node)
	for resource in Resources.resources:
		if resource is PackedScene:
			node.add_child(resource.instantiate())
		elif resource is Material:
			var mesh := MeshInstance3D.new()
			mesh.set_mesh(BoxMesh.new())
			mesh.mesh.surface_set_material(0,resource)
			node.add_child(mesh)
	for child in node.get_children():
		child.queue_free()
	node.queue_free()

## Spawns a node from [member Resources.resources] by [param idx], adds it as a
## child of [param parent], and returns the new [Node].
func spawn_node(idx: int, parent: Node) -> Node:
	var node: Node = Resources.resources[idx].instantiate()
	parent.add_child(node)
	return node

## Spawns a node from [member Resources.resources] by [param idx], adds it as a
## child of [param parent]. It's not that much faster than calling
## [method spawn_node]. lmao
func spawn_node_fast(idx: int, parent: Node) -> void:
	parent.add_child(Resources.resources[idx].instantiate())

func get_debug_transparent_material() -> StandardMaterial3D:
	return Resources.get_resource(Resources.DEBUGTRANSPARENTMATERIAL)

func _ready() -> void:
	setup_connections()
	setup_filepaths()
	WindowUtils.initialize_general_settings()
	Audio.initialize_settings()
	ConnectivityTester.test_internet_connection()
	on_scene_changed()
	multiplayer.set_server_relay_enabled(false)
	# might be able to get rid of this tbh, this is legacy and untested as
	# to whether getting rid of it causes any issues
	Tickrate.auto_assign_physics_delta.call_deferred()

const USER_DIRECTORY: String = "user://"
const SETTING_FILEPATH: String = "override.cfg"
func _exit_tree() -> void:
	var err := ProjectSettings.save_custom(SETTING_FILEPATH)
	if err != OK:
		printerr("Couldn't save settings. Got error %s."%error_string(err))

func setup_filepaths() -> void:
	@warning_ignore("static_called_on_instance")
	setup_directory(USER_DIRECTORY)
	# same as setup_directory(Replays.REPLAY_DIRECTORY)
	Replays.setup_filepath()

static func setup_directory(directory: String) -> void:
	if !DirAccess.dir_exists_absolute(directory):
		# maybe make_dir_recursive?
		DirAccess.make_dir_absolute(directory)

func setup_connections() -> void:
	root.size_changed.connect(on_window_resized)
	root.focus_entered.connect(on_window_focused)
	root.focus_exited.connect(on_window_unfocused)

enum {DEFAULT_WINDOW_SIZE_x = 1152,DEFAULT_WINDOW_SIZE_y = 648}
func on_window_resized() -> void:
	for child in root.get_children():
		if child is Control and child.is_in_group("Basic Scaling"):
			child.set_scale(Vector2(root.size.x/float(DEFAULT_WINDOW_SIZE_x),
									root.size.y/float(DEFAULT_WINDOW_SIZE_y)))

func on_window_unfocused() -> void:
	Engine.set_max_fps(WindowUtils.get_oof_fps_cap())

func on_window_focused() -> void:
	Engine.set_max_fps(WindowUtils.get_game_fps_cap() if is_3D_scene() else WindowUtils.get_menu_fps_cap())

func get_root_last_child() -> Node:
	return root.get_child(root.get_child_count() - 1)

func get_root() -> Window:
	return get_tree().get_root()

func refresh_root() -> void:
	root = get_root()

func refresh_tree() -> void:
	tree = get_tree()
#	refresh_root()

func get_mp() -> MultiplayerAPI:
	return tree.get_multiplayer()

func get_local_mp_id() -> int:
	# same as get_mp().get_unique_id()
	if multiplayer:
		return multiplayer.get_unique_id()
	else:
		return 1

func get_current_scene() -> Node:
	return tree.current_scene

func get_nodes_in_group(group: StringName) -> Array:
	return tree.get_nodes_in_group(group)

func get_current_camera() -> Camera3D:
	return root.get_camera_3d()

func change_scene(scene: String) -> void:
	var gaming: Error = tree.change_scene_to_file(scene)
	if gaming != OK:
		breakpoint
	on_scene_changed.call_deferred()

func change_scene_to_node(node: Node) -> void:
	tree.unload_current_scene()
	root.add_child(node)
	tree.set_current_scene(get_root_last_child())
	on_scene_changed.call_deferred()

func is_3D_scene() -> bool:
	return get_current_scene() is Node3D

func on_scene_changed() -> void:
#	tree.set_multiplayer_poll_enabled(!tree.current_scene is MultiplayerLevel)
	if is_3D_scene():
		WindowUtils.go_game_settings()
	else:
		WindowUtils.go_menu_settings()
	on_window_resized.call()

func quit() -> void:
#	Settings.save_settings()
	tree.quit()

static func get_datetime_string() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-")

static func array_getlast(array: Array):
	return array[array.size() - 1]

static func array_getlastidx(array: Array) -> int:
	return array.size() - 1

static func global_orientation(obj: Node3D) -> Vector3:
	# tbh normailizing this changes like basically nothing so maybe its not worth doing
	# example: changes (-0.318499, -0.088899, 0.943740) into (-0.318501, -0.088899, 0.943745)
	return obj.global_transform.basis.z.normalized()

static func get_window_title() -> String:
	return "Movement test (DEBUG)" if OS.is_debug_build() else "Movement test"

# could be static
func is_exported() -> bool:
	return !OS.has_feature("editor")

func change_window_title(title: String) -> void:
	root.set_title(title)

func reset_window_title() -> void:
	@warning_ignore("static_called_on_instance")
	change_window_title(get_window_title())

func append_to_window_title(title: String) -> void:
	@warning_ignore("static_called_on_instance")
	change_window_title(get_window_title() + title)

static func is_timer_running(timer: Timer) -> bool:
	# if a timer is inactive it also returns 0, so this works no matter what :)
	return false if timer.get_time_left() == 0.0 else true

# Depreciated because I learned about "is_instance_valid" lmao
#static func is_freed_instance(obj: Object) -> bool:
#	return weakref(obj).get_ref() == null

static func get_dict_from_array(array: Array) -> Dictionary:
	var dict: Dictionary = {}
	for idx in array.size():
		dict[idx] = array[idx]
	return dict

static func apply_array_to_dict(dict: Dictionary, array: Array) -> void:
	for idx in array.size():
		dict[idx] = array[idx]

static func types_are_same(var1: Variant, var2: Variant) -> bool:
	return typeof(var1) == typeof(var2)

func setup_subwindow_size(subwindow: Window, size: Vector2i) -> void:
	if root.size.x < size.x:
		size.x = root.size.x - 60
	if root.size.y < size.y:
		size.y = root.size.y - 60
	subwindow.set_size(size)
	if subwindow.position.x > root.size.x or subwindow.position.x < root.position.x:
		subwindow.position.x = root.size.x - subwindow.size.x - 20
	if subwindow.position.y > root.size.y or subwindow.position.y < root.position.y:
		subwindow.position.y = root.size.y - subwindow.size.y - 20

static func print_meta_list_for_node_and_children(node: Node) -> void:
	for child in node.get_children():
		print("--------------")
		print(child.get_name())
		print("--------------")
		print(child.get_meta_list())
		print("-------------------------------")
		print_meta_list_for_node_and_children(child)
		print("-------------------------------")

static func get_func_length(function: Callable) -> int:
	var time2: int
	var time: int = Time.get_ticks_usec()
	function.call()
	time2 = Time.get_ticks_usec()
	return time2 - time

static func get_filename_without_extension(path: String) -> String:
	return path.get_file().rstrip(path.get_extension())

static func disconnect_all_signals(obj: Object) -> void:
	for sig in obj.get_signal_list():
		disconnect_all_signal_connections(obj,sig.name)

static func disconnect_all_connections(sig: Signal) -> void:
	for connection in sig.get_connections():
		sig.disconnect(connection.callable)

static func disconnect_all_signal_connections(obj: Object, sig: String) -> void:
	var connections: Array[Dictionary] = obj.get_signal_connection_list(sig)
	for connection in connections:
		obj.disconnect(sig,connection.callable)

static func signal_disconnect_all_connections(sig: Signal) -> void:
	var connections: Array[Dictionary] = sig.get_connections()
	for connection in connections:
		sig.disconnect(connection.callable)

static func connect_signal_if_not_already(sig: Signal, callable: Callable) -> void:
	if !sig.is_connected(callable):
		sig.connect(callable)

static func disconnect_signal_if_connected(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

static func suspend_signal_connection(sig: Signal, callable: Callable, suspension_end_signal: Signal) -> void:
	assert(sig.is_connected(callable), "Signal %s must be connected to callable %s in order to suspend its connection."%[sig,callable])
	assert(callable.get_object() != null, "Callable %s must be connected to an object in order for signal to suspend its connection."%[callable])
	
	sig.disconnect(callable)
	
	suspension_end_signal.connect(sig.get_object().connect.bind(sig.get_name(),callable),CONNECT_ONE_SHOT)

func remove_node(node: Node) -> void:
	var instance_id: int = node.get_instance_id()
	node.get_parent().remove_child.call_deferred(node)
	removed_nodes[instance_id] = node
	removed_node_ids[node] = instance_id

func reinsert_node(node: Node, parent: Node) -> void:
	parent.add_child(node)
	var instance_id: int = removed_node_ids[node]
	erase_node_from_dicts(node,instance_id)

func erase_node_from_dicts(node: Node, instance_id: int) -> void:
	removed_nodes.erase(instance_id)
	removed_node_ids.erase(node)

func reinsert_node_by_id(instance_id: int, parent: Node) -> void:
	var node: Node = removed_nodes[instance_id]
	parent.add_child(node)
	erase_node_from_dicts(node,instance_id)

func is_removed_node_properly_set_up(node: Node) -> String:
	if !removed_node_ids.has(node):
		return "Removed node IDs does not contain an ID for node %s."%node
	if !removed_nodes.has(removed_node_ids[node]):
		return "Removed nodes does not contain node %s's ID of %s."%[node,removed_node_ids[node]]
	if removed_nodes[removed_node_ids[node]] != node:
		return "Removed nodes node %s matches node %s's ID key of %s."%[removed_nodes[removed_node_ids[node]],node,removed_node_ids[node]]
	return ""

func free_removed_node(node: Node) -> void:
	assert(is_removed_node_properly_set_up(node).is_empty(),is_removed_node_properly_set_up(node))
	node.free()
	erase_node_from_dicts(node,removed_node_ids[node])

func queue_free_removed_node(node: Node) -> void:
	node.queue_free()
	erase_node_from_dicts(node,removed_node_ids[node])

func connect_to_timer(timer_len: float, callable: Callable, flags: int = 0) -> int:
	return tree.create_timer(timer_len).timeout.connect(callable,flags)

func defer_to_next_frame(callable: Callable) -> void:
	next_frame_calls.append(callable)

func defer_to_next_physics_frame(callable: Callable) -> void:
	next_physics_frame_calls.append(callable)

func is_in_multiplayerlevel() -> bool:
	return get_current_scene() is MultiplayerLevel

func assert_valid_number_of_users() -> void:
	assert(num_users < 5 and num_users > 0,"%s is an invalid number of users. Number of users must be less than 5 or greater than 0."%[num_users])

func connect_callable_to_frame_starts(callable: Callable, flags: int = 0) -> void:
	tree.process_frame.connect(callable,flags)
	tree.physics_frame.connect(callable,flags)

func disconnect_callable_from_frame_starts(callable: Callable) -> void:
	tree.process_frame.disconnect(callable)
	tree.physics_frame.disconnect(callable)

func defer_if_out_of_time(callable: Callable, max_frame_frac: float = 0.95) -> void:
	if TimeUtils.get_frame_frac() >= max_frame_frac:
		defer_to_next_frame(callable)
	else:
		callable.call()

func connect_callable_to_frame_start_if_out_of_time(callable: Callable, max_time: float = 0.95) -> void:
	connect_callable_to_frame_starts(callable)
	# on frame start, disconnect callable from proc/phys
	connect_callable_to_frame_starts(disconnect_callable_from_frame_starts.bind(callable))
	# on frame start, disconnect disconnection callable from proc/phys
	connect_callable_to_frame_starts(disconnect_callable_from_frame_starts.bind(disconnect_callable_from_frame_starts))

func await_if_out_of_time(max_frame_frac: float = 0.95,sig: Signal = tree.process_frame) -> bool:
	if TimeUtils.get_frame_frac() >= max_frame_frac or Engine.is_in_physics_frame():
		await sig
	return true

func get_setting_safe(setting: String, default: Variant) -> Variant:
	if !ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting,default)
		Console.write("Setting %s didn't exist in file, applying and saving as %s."%[setting,default])
		return default
	return ProjectSettings.get_setting(setting)
