extends Node

signal mouse_moved(relative)
signal pause_pressed

var gameplay_inputs_paused: bool = false
var gameplay_input_blockers: int = 0
func pause_gameplay_inputs() -> void:
	gameplay_input_blockers += 1
	gameplay_inputs_paused = true
	Inputs.show_cursor()

func resume_gameplay_inputs() -> void:
	gameplay_input_blockers -= 1
	gameplay_inputs_paused = gameplay_input_blockers > 0
	assert(gameplay_input_blockers >= 0, "Somethings gone wrong if this went negative")
	if not gameplay_inputs_paused:
		if Inputs.is_mouse_connected_to_object():
			Inputs.capture_cursor()

const MAX_NUM_PLAYERS = 3
var num_players_registered: int
func _ready() -> void:
	register_all_actions()
	register_splitscreen_actions()

func register_splitscreen_actions() -> void:
	var unregistered_actions: Array[StringName]
	var player_idx: int
	for i in 4:
		# originally this func looped backwards so that, basically, if it turned
		# out that player 4 had all their actions registered, then players 2 and
		# 3 probably already had their actions registered, too. But tbh, since
		# actions might be renamed, added or removed, and because this func only
		# runs occasionally, most often on startup, I'm just gonna check every
		# player anyway.
		player_idx = MAX_NUM_PLAYERS-i
		var idx_string := StringName(str(player_idx))
		unregistered_actions = get_unregistered_actions(idx_string)
		if !unregistered_actions.is_empty():
			for action in unregistered_actions:
				if OS.is_debug_build():
					Console.writeverb(action)
				register_splitscreen_action(action,idx_string)

func register_splitscreen_action(action: StringName, idx_str: StringName) -> void:
	InputMap.add_action(action)
	if is_just_pressed_action(action):
		add_splitscreen_action_to_map(action,idx_str,just_pressed_button_actions_map)
	elif !is_analog_action(action):
		add_splitscreen_action_to_map(action,idx_str,button_actions_map)

static func add_splitscreen_action_to_map(action: StringName, idx_str: StringName, map: Dictionary) -> void:
	map[action] = map[action.trim_suffix(idx_str)]

func is_mouse_connected_to_object() -> bool:
	return false if mouse_moved.get_connections().is_empty() else true

static func show_cursor() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

static func capture_cursor() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

static func is_mouse_captured() -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

static func showhide_cursor_on_ui_cancel() -> void:
	if Input.is_action_just_pressed(&"ui_cancel"):
		showhide_cursor()

static func showhide_cursor() -> void:
	@warning_ignore("standalone_ternary")
	capture_cursor() if is_mouse_visible() else show_cursor()

static func is_mouse_visible() -> bool:
#	return true if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE else false
	match Input.get_mouse_mode():
		Input.MOUSE_MODE_VISIBLE:
			return true
		Input.MOUSE_MODE_CONFINED:
			return true
		_:
			return false

@warning_ignore("static_called_on_instance")
@onready var sens: float = getsens() * .01
@onready var scope_factor: float = get_scope_factor()
var scoped: bool
var scope_scale: float = 1.

const SENS_SETTING = "quack/controls/mouse/sensitivity"
const SCOPE_FACTOR_SETTING = "quack/controls/mouse/scope_sensitivity_scale_factor"

static func getsens() -> float:
	return ProjectSettings.get_setting_safe(SENS_SETTING,5.)

static func get_scope_factor() -> float:
	return ProjectSettings.get_setting_safe(SCOPE_FACTOR_SETTING,1.)

func get_scope_relative_sens() -> float:
	return sens if not scoped else sens * scope_scale * scope_factor

func change_sens(newsens: float) -> void:
	ProjectSettings.set_setting(SENS_SETTING, newsens)
	sens = newsens * 0.01

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if !gameplay_inputs_paused:
			mouse_moved.emit((event as InputEventMouseMotion).relative*get_scope_relative_sens())
	elif Input.is_action_just_pressed(&"ui_cancel"):
		pause_pressed.emit()

enum {UP, DOWN}

static func action_pressed_as_bitflag(action: StringName, this_int: int) -> int:
	return this_int if Input.is_action_pressed(action) else UP

static func action_just_pressed_as_bitflag(action: StringName, this_int: int) -> int:
	return this_int if Input.is_action_just_pressed(action) else UP

var button_actions: Array[StringName]
var button_actions_map = {}
var just_pressed_button_actions: Array[StringName]
var just_pressed_button_actions_map = {}

func is_gameplay_action_pressed(action: StringName, exact_match := false) -> bool:
	return Input.is_action_pressed(action,exact_match) and !gameplay_inputs_paused

func is_gameplay_action_just_pressed(action: StringName, exact_match := false) -> bool:
	return Input.is_action_just_pressed(action,exact_match) and !gameplay_inputs_paused

func is_gameplay_action_just_released(action: StringName, exact_match := false) -> bool:
	return Input.is_action_just_released(action,exact_match) and !gameplay_inputs_paused

func get_keyboard_updowns(player_idx: int) -> int:
	var suffix := StringName(str(player_idx)) if player_idx > 0 else &""
	if gameplay_inputs_paused: return 0
	var updowns: int = 0
	var num_button_actions: int = button_actions.size()
	for action in num_button_actions:
		updowns |= action_pressed_as_bitflag(button_actions[action] + suffix, 1<<action)
	for action in just_pressed_button_actions.size():
		updowns |= action_just_pressed_as_bitflag(just_pressed_button_actions[action] + suffix, 1<<(action+num_button_actions))
	return updowns

func get_button_pressed(button: StringName) -> int:
	return 1<<button_actions_map[button]
func get_button_just_pressed(button: StringName) -> int:
	return 1<<(button_actions.size()+just_pressed_button_actions_map[button])

const left = &"analog_left"
const right = &"analog_right"
const forward = &"analog_forward"
const back = &"analog_back"

func get_movement_from_keyboard(player_idx: int) -> Vector2:
	var suffix := StringName(str(player_idx)) if player_idx > 0 else &""
	if gameplay_inputs_paused: return Vector2.ZERO
	return Input.get_vector(left+suffix,right+suffix,forward+suffix,back+suffix) * (1.0 - 0.5 * int(Input.is_action_pressed(&"walk")))

const analog_prefix = "analog"
const ui_prefix = "ui_"
const just_pressed_prefix = "just_pressed_"

## Returns if a string begins with "analog_"
static func is_analog_action(action: StringName) -> bool:
	return action.begins_with(analog_prefix)

## Returns if a string begins with "just_pressed_"
static func is_just_pressed_action(action: StringName) -> bool:
	return action.begins_with(just_pressed_prefix)

static func is_ui_action(action: StringName) -> bool:
	return action.begins_with(ui_prefix)

## Returns if a string is an acceptable game-related button input [param action] by
## determining if the button is prefixed with a ui-related, analog-related, or
## player_move-related string. If [param action] meets the criteria of [method is_ui_action],
## [method is_analog_action], or [method is_player_move_action], the function
## returns false.
static func is_game_button_action(action: StringName) -> bool:
	return not (is_ui_action(action) or is_analog_action(action) or Console.command_string_map.has(action))

## Called once when the game starts up. Registers all game-related
## button actions in [member action_events]/[member action_bitfields] and
## [member just_pressed_action_events]/[member just_pressed_action_bitfields] by
## parsing through [method InputMap.get_actions], and adding each action if it
## [method is_game_button_action].
func register_all_actions() -> void:
	for action in InputMap.get_actions():
		# Listen, this is Godot's fault. Not mine. But if we wanna get rid of this
		# warning, we can jus replace it with get_script().is_game_button_action(action)
		if get_script().is_game_button_action(action):
			if get_script().is_just_pressed_action(action):
				just_pressed_button_actions.append(action)
				just_pressed_button_actions_map[action] = just_pressed_button_actions.size() - 1
			else:
				button_actions.append(action)
				button_actions_map[action] = button_actions.size() - 1

func get_unregistered_actions(idx_str: StringName) -> Array[StringName]:
	var unregistered_actions: Array[StringName]
	add_unregistered_actions(idx_str,unregistered_actions,button_actions)
	add_unregistered_actions(idx_str,unregistered_actions,just_pressed_button_actions)
	# lmao
	unregistered_actions.append(left+idx_str)
	unregistered_actions.append(right+idx_str)
	unregistered_actions.append(forward+idx_str)
	unregistered_actions.append(back+idx_str)
	unregistered_actions.append(&"analog_move_mod"+idx_str)
	return unregistered_actions

func add_unregistered_actions(idx: StringName, add_to: Array[StringName], add_from: Array[StringName]) -> void:
	for action in add_from:
		action += idx
		if !InputMap.has_action(action):
			add_to.append(action)

func register_actions_for_splitscreen_player(idx: int) -> void:
	var idx_str := StringName(str(idx))
	for action in get_unregistered_actions(idx_str):
		register_splitscreen_action(action,idx_str)

func get_button_action_idx(action: StringName) -> int:
	return (button_actions_map[action] as int)

func get_just_pressed_button_action_idx(action: StringName) -> int:
	return (just_pressed_button_actions_map[action] as int)

func register_key_for_action(key: String, action: StringName) -> void:
	var event := InputEventKey.new()
	var keycode := OS.find_keycode_from_string(key)
	if keycode == KEY_NONE:
		return Console.writerr("Invalid key %s."%key)
	event.set_physical_keycode(keycode)
	if InputMap.action_has_event(action,event):
		Console.writerr("Action %s is already bound to button %s."%[action,key])
	else:
		InputMap.action_add_event(action,event)
		save_input_action(action)

func save_input_action(action: StringName) -> void:
	var setting_path: String = get_action_setting_path(action)
	var events := InputMap.action_get_events(action)
	var setting: Dictionary = ProjectSettings.get_setting(setting_path,{"deadzone": 0.5, "events": events})
	if setting.events != events:
		setting.events = events
	ProjectSettings.set_setting(setting_path,setting)

func get_action_setting_path(action: StringName) -> String:
	return "input/"+action

# a lotta these could be static lmao
func remove_action(key: String, action: StringName) -> void:
	var event := get_key_event(key)
	if InputMap.action_has_event(action,event):
		remove_action_event(action,event)
	else:
		Console.writerr("Action %s is not bound to button %s."%[action,key])

func remove_action_event(action: StringName, event: InputEvent) -> void:
	assert(InputMap.action_has_event(action,event), "Action %s must have event %s in order to remove it."%[action,event]) # could be InputMap.event_is_action(event,action)
	InputMap.action_erase_event(action,event)
	save_input_action(action)
	if Console.command_string_map.has(String(action)):
		if InputMap.action_get_events(action).is_empty():
			InputMap.erase_action(action)
			ProjectSettings.clear(get_action_setting_path(action))
			Console.shortcuts.erase(action)

func remove_key_from_all_actions(key: String) -> void:
	var event := get_key_event(key)
	var action_unbinded: bool
	for action in InputMap.get_actions():
		if InputMap.event_is_action(event,action):
			Console.write("Unbinding key %s from action %s."%[key,action])
			remove_action_event(action,event)
			action_unbinded = true
	if !action_unbinded:
		Console.writerr("Key %s not bound to any actions."%key)

func get_key_event(key: String) -> InputEventKey:
	var event := InputEventKey.new()
	event.set_physical_keycode(OS.find_keycode_from_string(key))
	return event

var players: Array[Player]

const INPUT_BUFFER_SIZE = 120
const MOUSE_MOVEMENT_OWNER_PLAYER_IDX = "quack/gameplay/mouse_movement_owner_player_idx"
class Player:
	var id: int
	var screen: int
	var team
	var owns_mouse_movement: bool
	var username: String
	
	var input_buffer: Array[PlayerInputs]
	
	func _init(id: int, screen: int, username: String) -> void:
		self.screen = screen
		self.id = id + screen
		owns_mouse_movement = (screen == ProjectSettings.get_setting_safe(MOUSE_MOVEMENT_OWNER_PLAYER_IDX,0) as int)
		
		input_buffer.resize(Quack.Network.input_buffer_size)
		input_buffer[0] = PlayerInputs.new(0,Vector2.ZERO)

var input_signature: int
class PlayerInputs:
	
	var updowns: int
	var aim_angle: Vector2
	
	func _init(updowns: int, aim_angle: Vector2) -> void:
		pass
