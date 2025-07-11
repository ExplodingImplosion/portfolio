const WindowUtils = Quack.WindowUtils
const BBCode = Console.BBCode
const Network = Quack.Network
const NetDebug = Network.NetDebug
const ByteUtils = Quack.ByteUtils
const Tickrate = Quack.Tickrate
const TimeUtils = Quack.TimeUtils
const QuackMultiplayer = Network.QuackMultiplayer
const ServerBrowser = Network.ServerBrowser

const quit_aliases: PackedStringArray = ["exit","stop"]
static func quit_cmd() -> void:
	# lmao hac, otherwise tries to set window settings etc
	Quack.root.focus_entered.disconnect(Quack.on_window_focused)
	Quack.tree.quit()

static func max_fps_cmd(fps: int) -> void:
	WindowUtils.set_max_fps(fps)

const in_game_help_string = " while in-game (while 3D scenes are active)."
const menu_help_string = " while in menus (while a 3D scene isn't active)."
const nofocus_help_string = " while out of focus (when the game's window is minimized, clicked off of, etc)."

const max_fps_help_string = "Sets the maximum FPS that the game can run at%s"

const max_game_fps_help = max_fps_help_string%in_game_help_string
static func max_game_fps_cmd(fps: int) -> void:
	WindowUtils.set_max_game_fps(fps)

const max_menu_fps_help = max_fps_help_string%menu_help_string
static func max_menu_fps_cmd(fps: int) -> void:
	WindowUtils.set_max_menu_fps(fps)

const max_fps_nofocus_help = max_fps_help_string%nofocus_help_string
const max_fps_nofocus_aliases: PackedStringArray = ["max_fps_out_of_focus","max_no_focus_fps","max_fps_no_focus","max_fps_minimized","max_minimized_fps"]
static func max_fps_nofocus_cmd(fps: int) -> void:
	WindowUtils.set_max_out_of_focus_fps(fps)

const res_help_string = "Sets the resolution of the game%s"

const res_game_help = res_help_string%in_game_help_string
static func res_game_cmd(resx: int, resy: int) -> void:
	WindowUtils.set_game_res(Vector2i(resx,resy))

const res_help = res_help_string%" immediately. Saves as a game setting if in-game, otherwise saves as a menu setting."
static func res_cmd(resx: int, resy: int) -> void:
	WindowUtils.set_res(Vector2i(resx,resy))

const res_menu_help = res_help_string%menu_help_string
static func res_menu_cmd(resx: int, resy: int) -> void:
	WindowUtils.set_game_res(Vector2i(resx,resy))

const set_vsync_aliases: PackedStringArray = ["vsync"]
static func set_vsync_cmd(mode: int) -> void:
	WindowUtils.set_vsync(clampi(mode,DisplayServer.VSYNC_DISABLED,DisplayServer.VSYNC_MAILBOX))

static func get_vsync_cmd() -> void:
	Console.write("Vsync is %s."%("on" if WindowUtils.is_root_vsync_enabled() else "off"))

const change_scene_help = "Changes the current scene to a given filepath."
static func change_scene_cmd(scene_path: String) -> void:
	Quack.tree.change_scene_to_file(scene_path)
	Quack.defer_to_next_frame(Quack.on_scene_changed)

const potato_help = "Quick and dirty way to help the game run on lower end machines. Sets the game's 3D render scale to 0.2 and max FPS to 60."
static func potato_cmd() -> void:
	render_scale_cmd(0.2)
	max_fps_cmd(60)

static func setup_perf_overlay() -> CanvasLayer:
	if ProjectSettings.get_setting_safe("quack/performance_overlay/enabled",false) == false:
		return
	
	# Can't do this because Quack isn't initialized yet lmao so im hacking
	# this to defer it and this func never actually returns anything lmao
	#var overlay := perf_menu.instantiate() as CanvasLayer
	#Quack.root.add_child(overlay)
	#return overlay
	performance_overlay_cmd.call_deferred()
	return

const perf_menu: PackedScene = preload("res://interface/perf_overlay/perf_overlay.tscn")
static var perf_overlay: CanvasLayer = setup_perf_overlay()
const performance_overlay_aliases: PackedStringArray = ["perf_overlay"]
static func performance_overlay_cmd() -> void:
	if perf_overlay == null:
		perf_overlay = perf_menu.instantiate()
		Quack.root.add_child(perf_overlay)
	else:
		perf_overlay.queue_free()
		perf_overlay = null

const net_menu: PackedScene = preload("res://interface/net_overlay/net_overlay.tscn")
static var net_overlay: CanvasLayer
const net_overlay_aliases: PackedStringArray = ["network_overlay"]
static func net_overlay_cmd() -> void:
	if net_overlay == null:
		net_overlay = net_menu.instantiate()
		Quack.root.add_child(net_overlay)
	else:
		net_overlay.queue_free()
		net_overlay = null

static func toggle_fullscreen_cmd() -> void:
	WindowUtils.toggle_fullscreen()

static func set_fullscreen_cmd(toggle: bool) -> void:
	WindowUtils.set_fullscreen(toggle)

static func fullscreen_cmd() -> void:
	WindowUtils.go_fullscreen()

static func windowed_cmd() -> void:
	WindowUtils.go_windowed()

# maybe only make this work if its a debug build
const change_setting_help = "Changes the supplied setting path to the supplied new value. Only works if the new value is the same type as the previous value. Does NOT update setting variables used by scripts. (i.e. For most custom settings, a restart is required before changes take effect)."
const change_setting_aliases: PackedStringArray = ["set_setting"]
const change_setting_debug_only = true
static func change_setting_cmd(setting: String, newvalue: Variant) -> void:
	if !ProjectSettings.has_setting(setting):
		return Console.writerr("Setting %s does not exist."%setting)
	var value: Variant = ProjectSettings.get_setting(setting)
	var value_type := typeof(value)
	var newvalue_type := typeof(newvalue)
	if value_type != newvalue_type:
		return Console.writerr("Setting %s's value %s's type %s is not the same as supplied argument %s's type of %s."%[setting,value,type_string(value_type),newvalue,type_string(newvalue_type)])
	ProjectSettings.set_setting(setting,newvalue)
	Console.write("Changed setting %s to %s."%[setting,newvalue])

const get_setting_help = "Prints the current value of the supplied setting path."
const get_setting_aliases: PackedStringArray = ["print_setting"]
static func get_setting_cmd(setting: String) -> void:
	if ProjectSettings.has_setting(setting):
		return Console.write("%s: %s"%[setting,ProjectSettings.get_setting(setting,null)])
	else:
		return Console.writerr("Setting %s does not exist."%setting)

const get_all_settings_advanced_aliases: PackedStringArray = ["get_settings_advanced","get_settings_a"]
static func get_all_settings_advanced_cmd() -> void:
	var properties := ProjectSettings.get_property_list()
	for property in properties:
		if property.name == "ProjectSettings" or property.name == "script":
			continue
		Console.write_in_color(property.name as String,Color.YELLOW)
		for key in property.keys():
			if key != "name":
				if (property[key] is String or property[key] is StringName) and property[key] == "":
					continue
				Console.write(BBCode.set_color(Console.indent_string+str(key)+": ",Color.CYAN)+BBCode.set_color(
					type_string(property[key]) if key == "type" else ByteUtils.to_binary_string(property[key],false,29) if key == "usage" or key == "hint" else str(property[key]),Color.GREEN))
				await Console.await_if_out_of_time()
		Console.write(
			BBCode.set_color(Console.indent_string+"value: ",Color.CYAN)+
			BBCode.set_color(str(ProjectSettings.get_setting(property.name)),Color.LIGHT_SALMON)
			)
		await Console.await_if_out_of_time()

const get_all_settings_aliases: PackedStringArray = ["get_settings"]
static func get_all_settings_cmd() -> void:
	var properties := ProjectSettings.get_property_list()
	for property in properties:
		if property.name == "ProjectSettings" or property.name == "script":
			continue
		write_setting(property.name)
		await Console.await_if_out_of_time()

static func write_setting(setting: String) -> void:
	Console.write(BBCode.set_color(setting as String + ": ",Color.YELLOW)+BBCode.set_color(str(ProjectSettings.get_setting(setting)),Color.LIGHT_SALMON))

const get_settings_section_aliases: PackedStringArray = ["check_settings","get_settings_s"]
static func get_settings_section_cmd(section: String) -> void:
	var properties := ProjectSettings.get_property_list()
	for property in properties:
		if (property.name as String).begins_with(section):
			write_setting(property.name as String)
			await Console.await_if_out_of_time()

const time_scale_aliases: PackedStringArray = ["set_time_scale","change_time_scale"]
const time_scale_auth_only = true
static func time_scale_cmd(amnt: float) -> void:
	Engine.set_time_scale(amnt)

static func reset_time_scale_cmd() -> void:
	time_scale_cmd(1)

const set_max_text_rendering_duration_before_deferrment_help = "Sets the amount of time, in the unit of the fraction of time duration between the last frame completed and when the game wants to finish the next frame by with the game's target FPS, for which how long specific lists can be rendered for in one frame without being deferred."
const set_max_text_rendering_duration_before_deferrment_aliases: PackedStringArray = ["max_text_render_time","max_text_render_frac"]
static func set_max_text_rendering_duration_before_deferrment_cmd(fraction: float) -> void:
	Console.text_max_frame_duration_before_deferrment = fraction
	ProjectSettings.set_setting(Console.CONSOLE_TEXT_MAX_FRAME_DURATION_BEFORE_DEFERRMENT_SETTING_PATH,fraction)

const mem_help_string = "Prints the current and peak static memory usages to the console, in %s"

const print_mem_help = mem_help_string%"bytes."
static func print_mem_cmd() -> void:
	Console.write("Current memory usage: %s Bytes\nPeak memory usage: %s Bytes"%[OS.get_static_memory_usage(),OS.get_static_memory_peak_usage()])

const print_mem_gb_help = mem_help_string%"gigabytes."
static func print_mem_gb_cmd() -> void:
	var static_mem: int = OS.get_static_memory_usage()
	var peak_static_mem: int = OS.get_static_memory_peak_usage()
	var static_mem_gb: float = ByteUtils.bytes_to_gigabytes(static_mem)
	var peak_static_mem_gb: float = ByteUtils.bytes_to_gigabytes(peak_static_mem)
	Console.write("Current memory usage: %s Gigabytes\nPeak memory usage: %s Gigabytes"%[static_mem_gb,peak_static_mem_gb])

const print_mem_mb_help = mem_help_string%"megabytes."
static func print_mem_mb_cmd() -> void:
	var static_mem: int = OS.get_static_memory_usage()
	var peak_static_mem: int = OS.get_static_memory_peak_usage()
	var static_mem_mb: float = ByteUtils.bytes_to_megabytes(static_mem)
	var peak_static_mem_mb: float = ByteUtils.bytes_to_megabytes(peak_static_mem)
	Console.write("Current memory usage: %s Megabytes\nPeak memory usage: %s Megabytes"%[static_mem_mb,peak_static_mem_mb])

const print_mem_verbose_help = mem_help_string%"bytes, megabytes, and gigabytes. Also prints the following:
	- The total amount of usable physical memory on the device, in bytes or -1 if unknown.
	- The amount of free physical memory, that can be immediately allocated without disk access or other costly operation, in bytes or -1 if unknown.
	- The amount of available memory, that can be allocated without extending the swap file(s), in bytes or -1 if unknown.
	- The size of the current thread stack, in bytes or -1 if unknown."
const print_mem_verbose_aliases: PackedStringArray = ["print_mem_verb","print_mem_v"]
static func print_mem_verbose_cmd() -> void:
	print_mem_cmd()
	Console.writeln()
	print_mem_mb_cmd()
	Console.writeln()
	print_mem_gb_cmd()
	Console.writeln()
	var meminfo: Dictionary = OS.get_memory_info()
	var value: int
	for key in meminfo:
		value = meminfo[key] as int
		Console.write("%s: %s Bytes (%s MB) (%s GB)"%[key,value,ByteUtils.bytes_to_megabytes(value),ByteUtils.bytes_to_gigabytes(value)])

static func inst2dict2array(node: Node) -> Array:
	return inst_to_dict(node).values()

const kill_aliases: PackedStringArray = ["kill_me"]
static func kill_cmd() -> void:
	pass

static func reset_player_health() -> void:
	pass

const heal_me_aliases: PackedStringArray = ["heal_player"]
static func heal_me_cmd(amount: int) -> void:
	var player := get_player()
	if player:
		if HealthComponent.component_list.has(player):
			Console.write("Healing player %s for %s."%[player.name,amount])
			HealthComponent.component_list[player].heal(amount)
		else:
			Console.writerr("Player %s doesn't have a health component."%player.name)
	else:
		Console.writerr("No player to heal.")

const hurt_me_aliases: PackedStringArray = ["hurt_player"]
static func hurt_me_cmd(amount: int) -> void:
	var player := get_player()
	if player:
		if HealthComponent.component_list.has(player):
			Console.write("Damaging player %s for %s."%[player.name,amount])
			HealthComponent.component_list[player].damage(amount)
		else:
			Console.writerr("Player %s doesn't have a health component."%player.name)
	else:
		Console.writerr("No player to damage.")

const HealthComponent = preload("res://gameplay/health_component.gd")
const change_health_by_aliases: PackedStringArray = ["change_health"]
static func change_health_by_cmd(amount: int) -> void:
	var player := get_player()
	if player:
		if HealthComponent.component_list.has(player):
			Console.write("Changing player %s health by %s."%[player.name,amount])
			HealthComponent.component_list[player].change_health(amount)
		else:
			Console.writerr("Player %s doesn't have a health component."%player.name)
	else:
		Console.writerr("No player to change health of.")

static func set_health_cmd(health: int) -> void:
	var player := get_player()
	if player:
		if HealthComponent.component_list.has(player):
			Console.write("Setting player health to %s."%[player.name,health])
			HealthComponent.component_list[player].set_health(health)
		else:
			Console.writerr("Player %s doesn't have a health component."%player.name)
	else:
		Console.writerr("No player to set health of.")

static func respawn_cmd() -> void:
	Console.write("Respawning player (by restarting the scene lmao)")
	restart_scene_cmd()

const render_scale_help = "Sets the game's 3D render scale as a factor of 1."
const render_scale_aliases: PackedStringArray = ["set_render_scale","set_renderscale"]
static func render_scale_cmd(scale: float) -> void:
	WindowUtils.set_render_scale(scale)

const Audio = preload("res://utils/audio.gd")
const set_volume_help = "Sets the game's master volume as a factor of 1."
const set_volume_aliases: PackedStringArray = ["volume","master_volume","set_master_volume"]
static func set_volume_cmd(scale: float) -> void:
	Audio.set_volume(scale)
	#Audio.change_master_volume(scale)

const upnp_test_aliases: PackedStringArray = ["test_upnp"]
const upnp_test_debug_only = true
static func upnp_test_cmd() -> void:
	var upnp_thread := Thread.new()
	upnp_thread.start(upnp_test)
	Console.write("Starting UPnP test...")

static func upnp_test() -> void:
	var upnp := UPNP.new()
	upnp.discover()
	var _devices: Array[UPNPDevice] = []
	var _gateway: UPNPDevice = upnp.get_gateway()
	Console.write("UPnP device detected.") if upnp.get_device_count() > 0 else Console.write("No UPnP device detected.")

static func helpstringhack() -> String:
	return help_string
static var help_string = "
Enter commands by typing a command name. If a command accepts arguments, type arguments using spaces to separate them.\n\nTo show a list of all comands, use the command " + BBCode.set_color("show_commands",Color.CYAN)+".

For information about a specific command, use the command "+BBCode.set_color("help_command",Color.CYAN)+" with the command you'd like information about as its argument.

For information about all commands, use the command "+BBCode.set_color("help_advanced",Color.CYAN)+".

"
const help_help = "( ͡° ͜ʖ ͡°)"
static func help_cmd() -> void:
	Console.write(help_string)

const show_commands_aliases: PackedStringArray = ["show_all_commands","get_commands","commands", "show_c","print_commands","print_c","show_all_c","print_all_c"]
static func show_commands_cmd() -> void:
	Console.write("All commands:")
	for command in Console.commands:
		Console.write(Console.indent_string+command.get_command_name())
		await Console.await_if_out_of_time()
	Console.write("\nInput help [command] for more details about a specific command. Input help_advanced for more details about all commands.")

const help_comand_help = "Prints advanced help information about the supplied console command."
const help_command_aliases: PackedStringArray = ["help_cmd","help_c"]
static func help_command_cmd(command_string: String) -> void:
	
	var command: Console.CommandInfo = Console.command_string_map.get(command_string)
	if command == null:
		return Console.write("Command %s does not exist."%[command_string])
	
	# Write command
	Console.write(BBCode.set_color("Command: "+command.get_command_name(),Color.YELLOW))
	
	# Write help string, if it exists.
	if !command.help_string.is_empty():
		Console.write(BBCode.set_color(command.help_string,Color.PINK))
	
	if command.auth_only:
		Console.write(BBCode.set_color("Host only",Color.INDIAN_RED))
	
	# Write command arguments
	if command.has_args():
		Console.write(BBCode.set_color("Arguments:",Color.CHOCOLATE))
		for arg in command.args_info:
			Console.write("%s%s (%s)"%[Console.indent_string,arg[0],arg[1]])
	else:
		Console.write(BBCode.set_color("No arguments.",Color.GREEN*0.9))
	
	# Write aliases
	if command.get_aliases().is_empty():
		Console.write(BBCode.set_color("No aliases.",Color.CYAN))
	else:
		Console.write(BBCode.set_color("Aliases:",Color.CYAN))
		for alias in command.get_aliases():
			Console.write(Console.indent_string+BBCode.set_color(alias,Color.CYAN * 0.7))

const help_advanced_help = "Prints advanced help information about all console commands. Equivalent of executing 'help_command' on every console command."
const help_advanced_aliases: PackedStringArray = ["show_commands_advanced","show_aliases","show_commands_and_aliases"]
static func help_advanced_cmd() -> void:
	var command: Console.CommandInfo
	var num_commands: int = Console.commands.size()
	Console.writeln()
	for i in num_commands:
		command = Console.commands[i]
		help_command_cmd(command.get_command_name())
		# write 2 newlines until last command
		if i < num_commands - 1:
			Console.writeln()
		await Console.await_if_out_of_time()

static func doesntwork() -> void:
	Console.writerr("doesnt work lmao")

const run_code_test_help = "Debug-only command that executes the supplied function in the Code Tests.gd file, if it exists. If 'all' is supplied as an argument, executes all functions in Code Tests.gd"
const run_code_test_aliases: PackedStringArray = ["code_test","test_code","test_function","test_func","function_test","func_test"]
const run_code_test_debug_only = true
static func run_code_test_cmd(test: String) -> void:
	if !Quack.is_exported():
		var tests: GDScript = load("res://dev/code_tests.gd")
		var methods: Array[Dictionary] = tests.get_script_method_list()
		if test == all:
			for method in methods:
				if method.args.is_empty():
					Console.write("Running code test %s..."%method.name)
					tests.call(method.name)
			return
		var method_idx: int = -1
		for i in methods.size():
			if methods[i].name == test:
				method_idx = i
		if method_idx == -1:
			return Console.writerr("Test %s does not exist."%[test])
		if !methods[method_idx].args.is_empty():
			return Console.writerr("This function accepts arguments, which aren't supported for being called from the console.")
		tests.call(test)

const get_code_tests_help = "Debug-only command that prints every available code test function in Code Tests.gd."
const get_code_tests_debug_only = true
static func get_code_tests_cmd() -> void:
	if !Quack.is_exported():
		var tests: GDScript = load("res://Dev/Code Tests.gd")
		var methods: Array[Dictionary] = tests.get_script_method_list()
		for method in methods:
			if method.args.is_empty():
				Console.write(method.name as String)
				await Console.await_if_out_of_time()

const run_all_code_tests_help = "Executes the command 'run_code_test' with the argument 'all' supplied."
const all = "all"
const run_all_code_tests_debug_only = true
static func run_all_code_tests_cmd() -> void:
	run_code_test_cmd(all)

const MAIN_MENU_SETTING_PATH = "application/run/main_scene"
static var MAIN_MENU_FILEPATH: String = ProjectSettings.get_setting(MAIN_MENU_SETTING_PATH)
static func main_menu_cmd() -> void:
	assert(!MAIN_MENU_FILEPATH.is_empty(), "nvm i gotta change how i implement MAIN_MENU_FILEPATH cuz its empty rn")
	if Quack.tree.current_scene.scene_file_path == MAIN_MENU_FILEPATH:
		return Console.write("Already at main menu.")
	Console.write("Returning to main menu.")
	if Network.multiplayer_connected():
		disconnect_cmd()
	else:
		change_scene_cmd(MAIN_MENU_FILEPATH)

const clear_console_help = "Clears all text from the game's embedded console. Does not clear the game's log or console window, and does not clear the console's input history."
const clear_console_aliases: PackedStringArray = ["clear"]
static func clear_console_cmd() -> void:
	Console.readout.clear()

const reset_window_help = "Sets the game's main window to windowed mode, resets its size to default, and centers it on the device's main screen."
static func reset_window_cmd() -> void:
	var root: Window = Quack.root
	if root.get_mode() != Window.MODE_WINDOWED:
		root.set_mode(Window.MODE_WINDOWED)
	root.size = root.content_scale_size
	var primary_screen: int = DisplayServer.get_primary_screen()
	root.set_current_screen(primary_screen)
	root.position = DisplayServer.screen_get_size(primary_screen)/2 - root.size/2
	root.size_changed.emit() # maybe call deferred if it's also ever deferred in window utils

static func is_scene_file(file: String) -> bool:
	return file.trim_suffix(".remap").get_extension() == "tscn"

const LEVEL_DIRECTORY = "res://gameplay/level/levels"
static var playable_levels := get_playable_levels()
static func get_playable_levels() -> PackedStringArray:
	var levels := PackedStringArray([])
	# Probably won't pick up on anything but I guess it's a good fallback
	for file in DirAccess.get_files_at(LEVEL_DIRECTORY):
		file = file.trim_suffix(".remap")
		if file.get_extension() == "tscn":
			levels.append(file)
	
	for folder in DirAccess.get_directories_at(LEVEL_DIRECTORY):
		for file in DirAccess.get_files_at(LEVEL_DIRECTORY+"/"+folder):
			file = file.trim_suffix(".remap")
			if file.get_extension() == "tscn":
				levels.append(folder+"/"+file)
	return levels

static func level_exists(level_name: String) -> int:
	for i in playable_levels.size():
		var level := playable_levels[i]
		if (level.get_file().get_basename().get_basename() if Quack.is_exported() else level.get_file().get_basename()).to_lower() == level_name.to_lower():
			return i
	return -1

const get_playable_levels_aliases: PackedStringArray = ["get_levels","print_levels","print_playable_levels","levels","playable_levels"]
static func get_playable_levels_cmd() -> void:
	for level in playable_levels:
		Console.write(level)

static func reload_levels_cmd() -> void:
	playable_levels = get_playable_levels()

const play_defer_launch_arg = true
static func play_cmd(levelname: String) -> void:
	play_custom_cmd(levelname,Engine.physics_ticks_per_second)

const LEVEL_DIRECTORY_PLUS = "res://gameplay/level/levels/%s"
const play_custom_defer_launch_arg = true
static func play_custom_cmd(level_name: String,tickrate: int) -> void:
	Console.push_warn("Normally would check if resources are ready here")
	#if !Resources.resources_ready:
		#return Console.writerr("Can't start a game yet! Resources haven't been fully loaded.")
	var level_idx := level_exists(level_name)
	if level_idx == -1:
		return Console.writerr("Level %s does not exist!"%level_name)
	if Engine.get_physics_ticks_per_second() != tickrate:
		Engine.set_physics_ticks_per_second(tickrate)
	Network.reset_if_connected()
	Quack.change_scene(LEVEL_DIRECTORY_PLUS%playable_levels[level_idx])

const host_defer_launch_arg = true
static func host_cmd(level_name: String) -> void:
	host_custom_cmd(level_name,Engine.physics_ticks_per_second)
const reset_window_soft_help = "Sets the game's main window to windowed mode, resets its size to default, and centers it on its current screen."
static func reset_window_soft_cmd() -> void:
	var root: Window = Quack.root
	if root.get_mode() != Window.MODE_WINDOWED:
		root.set_mode(Window.MODE_WINDOWED)
	root.size = root.content_scale_size
	root.position = DisplayServer.screen_get_size(root.get_current_screen())/2 - root.size/2

const host_custom_defer_launch_arg = true
static func host_custom_cmd(level_name: String, tickrate: int) -> void:
	var level_idx := level_exists(level_name)
	if level_idx == -1:
		return Console.writerr("Level %s does not exist!"%level_name)
	Network.host(LEVEL_DIRECTORY_PLUS%playable_levels[level_idx],20,4,tickrate,-1,Network.DEFAULT_PORT)
const sensitive_info_warning_string = "WARNING: CAREFUL BEFORE USING THIS COMMAND WHILE SCREEN IS VISIBLE! SENSITIVE INFORMATION CAN BE EXPOSED!"

const get_ip_help = "Prints the device's IPV4 address. %s"%sensitive_info_warning_string
static func get_ip_cmd() -> void:
	Console.write("Local IPv4: " + Network.get_hostname_desktop())

const get_all_ip_help = "Prints every local address of the device. %s"%sensitive_info_warning_string
static func get_all_ip_cmd() -> void:
	var local_addys: PackedStringArray = IP.get_local_addresses()
	Console.write("List of all local addresses:")
	for addy in local_addys:
		Console.write(addy)

const get_all_interfaces_help = "Prints every network adapter of the device. %s"%sensitive_info_warning_string
const get_all_interfaces_aliases: PackedStringArray = ["get_interfaces"]
static func get_all_interfaces_cmd() -> void:
	var interfaces: Array[Dictionary] = IP.get_local_interfaces()
	Console.write("List of all internet interfaces:")
	write_array_of_dicts(interfaces,Console.text_max_frame_duration_before_deferrment)

const connect_help = "Tries to connect a game session to the supplied IP address using the game's default gameplay port."
static func connect_cmd(ip: String) -> void:
	Network.connect_to_server(ip,Network.DEFAULT_PORT)

const connect_with_port_help = "Tries to connect to a game session with the supplied IP address and port."
static func connect_with_port_cmd(ip: String, port: int) -> void:
	Network.connect_to_server(ip,port)

const disconnect_help = "Disconnects from the current game session, if any exists. Also can be used to shut down game session while hosting, or to return to main menu from other scenes, including singleplayer levels."
static func disconnect_cmd() -> void:
	Console.write("Disconnecting from server.")
	Network.reset()

const go_first_person_aliases: PackedStringArray = ["go_fp"]
static func go_first_person_cmd() -> void:
	doesntwork()
static func get_func_length(nodepath: String, function: String) -> void:
	@warning_ignore("static_called_on_instance")
	Console.write(str(Quack.get_func_length(Callable(Quack.root.get_node(NodePath(nodepath)),function))))

const pingtest_all_help = "Executes pingtest command on all available peers."
func pingtest_all_cmd() -> void:
	if Network.is_server():
		Console.write("Pinging all peers...")
		Console.receive_pingtest.rpc()
		Console.ping_start_time = Time.get_ticks_usec()

const pingtest_help = "Pings the supplied peer's console and calculates their latency, in microseconds"
static func pingtest_cmd(peer: int) -> void:
	if peer == Network.SERVER or Network.is_server():
		Console.write("Pinging peer %s"%[peer])
		Console.receive_pingtest.rpc_id(peer)
		Console.ping_start_time = Time.get_ticks_usec()

const sens_help = "Sets the player's 3D camera mouse sensitivity, in [INSERT CORRECT UNIT OF MEASUREMENT HERE]"
const sens_aliases: PackedStringArray = ["sensitivity","change_sensitivity","set_sensitivity","change_sens","set_sens"]
static func sens_cmd(sens: float) -> void:
	Inputs.change_sens(sens)

const net_info_string = "Auth frame signature: %s
Input signature: %s
Used input signature: %s
Received input signature: %s
Frame delay: %s
Server input delay: %s
Network input delay: %s
Total input delay: %s"

const cant_get_net_info_err_msg = "Can't get net info if not connected to a multiplayer game."

const get_net_info_help = "Prints information about the local client's game session information. Including:
	Their current known authoritative frame signature
	Their current input signature
	Their most recently used input signature
	Their current known authoritative received input signature
	Their current known input delay on the server's end, in physics frames.
	Their current known input delay caused by network latency, in physics frames.
	Their current known total input delay, in physics frames."
static func get_net_info_cmd(client: int) -> void:
	doesntwork()
	#if Network.multiplayer_connected():
		#if client < 1:
			#Console.write("Client ID: %s."%GameState.local_client.id)
		#client = GameState.local_client.id if client < 1 else client
		#if !GameState.clients.has(client):
			#return Console.write("Invalid client %s."%client)
		#Console.write(net_info_string%Array(get_client_info(client)))
	#else:
		#Console.write(cant_get_net_info_err_msg)

static func get_client_info(id: int) -> PackedInt64Array:
	doesntwork()
	return []
	#var client := GameState.clients[id] as Client
	#return [
				#client.last_acknowledged_frame,client.input_signature,
				#client.last_used_input_signature,client.last_received_input_signature,
				#client.frame_delay,client.get_server_input_delay(),
				#client.get_network_input_delay(),client.get_total_input_delay()
			#]

const get_net_info_ms_help = "Prints information about the local client's game session, in milliseconds."
static func get_net_info_ms_cmd(client: int) -> void:
	doesntwork()
	#if Network.multiplayer_connected():
		#if client < 1:
			#Console.write("Client ID: %s."%GameState.local_client.id)
		#client = GameState.local_client.id if client < 1 else client
		#if !GameState.clients.has(client):
			#return Console.write("Invalid client %s."%client)
		#var client_info: Array = get_client_info(client)
		#for i in range(4,8):
			#client_info[i] = "%sms"%TimeUtils.frames_to_ms_f(client_info[i])
		#Console.write(net_info_string%client_info)
	#else:
		#Console.write(cant_get_net_info_err_msg)

const get_net_info_verbose_help = "Prints information about the local client's game session, in physics frames AND in milliseconds."
const get_net_info_verbose_aliases: PackedStringArray = ["get_net_info_v","get_net_info_verb","net_info_verb","net_info_v","net_info_verbose"]
static func get_net_info_verbose_cmd(client: int) -> void:
	doesntwork()
	#if Network.multiplayer_connected():
		#if client < 1:
			#Console.write("Client ID: %s."%GameState.local_client.id)
		#client = GameState.local_client.id if client < 1 else client
		#if !GameState.clients.has(client):
			#return Console.write("Invalid client %s."%client)
		#var client_info: Array = get_client_info(client)
		#for i in range(4,8):
			#var frames: int = client_info[i] as int
			#client_info[i] = "%s frames, %sms"%[frames,TimeUtils.frames_to_ms_f(frames)]
		#Console.write(net_info_string%client_info)
	#else:
		#Console.write(cant_get_net_info_err_msg)

const change_tickrate_aliases: PackedStringArray = ["set_tickrate","tickrate","change_physics_simulation_rate"]
const change_tickrate_auth_only = true
static func change_tickrate_cmd(rate: int) -> void:
	Tickrate.set_physics_simulation_rate(rate)

static func connect_debug_cmd(ip: String) -> void:
	if !NetDebug.lag_faker_active():
		NetDebug.start_lag_faker(ip)
	connect_cmd(ip)

const start_net_debugger_aliases: PackedStringArray = ["start_lag_faker"]
static func start_net_debugger_cmd() -> void:
	if Network.multiplayer_connected():
		return Console.writerr("Cannot start debugger while connected to multiplayer.")
	NetDebug.start_lag_faker()

static func store_packets_cmd() -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	lag_faker.store_packets = !lag_faker.store_packets

static func print_in_packets_cmd() -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	Console.write("In packets:")
	for packet in lag_faker.in_queue.history:
		Console.write(packet._to_string())
		await Console.await_if_out_of_time()

static func print_in_packets_on_receive_cmd() -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	Console.write("Toggling printing of in packets when received...")
	lag_faker.print_in_queue = !lag_faker.print_in_queue

static func print_out_packets_on_send_cmd() -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	Console.write("Toggling printing of out packets when sent...")
	lag_faker.print_out_queue = !lag_faker.print_out_queue

static func print_out_packets_cmd() -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	Console.write("Out packets:")
	for packet in lag_faker.out_queue.history:
		Console.write(packet._to_string())
		await Console.await_if_out_of_time()

static func try_get_lag_faker() -> NetDebug.LagFaker:
	if !NetDebug.get_lag_faker():
		start_net_debugger_cmd()
		return NetDebug.get_lag_faker()
	else:
		return NetDebug.get_lag_faker()

const stop_net_debugger_aliases: PackedStringArray = ["stop_lag_faker"]
static func stop_net_debugger_cmd() -> void:
	if Network.multiplayer_connected():
		return Console.writerr("Cannot end debugger while connected to multiplayer.")
	NetDebug.stop_lag_faker()

static func fake_lag_cmd(amount: float) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.set_min_latency(TimeUtils.msecf_to_usec(amount))

static func fake_jitter_cmd(amount: float) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.set_jitter(TimeUtils.msecf_to_usec(amount))
	lag_faker.set_jitter_variance(1.)

static func fake_loss_cmd(frequency: int) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.set_loss(frequency)

static func fake_lag_client_cmd(amount: float) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.client_params.fake_min_latency_usec = TimeUtils.msecf_to_usec(amount)

static func fake_lag_server_cmd(amount: float) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.server_params.fake_min_latency_usec = TimeUtils.msecf_to_usec(amount)

static func fake_jitter_client_cmd(amount: float) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.client_params.fake_jitter_usec = TimeUtils.msecf_to_usec(amount)

static func fake_jitter_server_cmd(amount: float) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.server_params.fake_jitter_usec = TimeUtils.msecf_to_usec(amount)

const packet_loss_curve_path = "res://Utilities/Packet Loss Sin Curve.tres"

static func use_packet_loss_curve_cmd() -> void:
	var lag_faker := NetDebug.get_lag_faker()
	if !lag_faker: return
	lag_faker.set_loss_curve(packet_loss_curve_path)

static func use_packet_jitter_curve_cmd() -> void:
	var lag_faker := NetDebug.get_lag_faker()
	if !lag_faker: return
	lag_faker.set_jitter_curve(packet_loss_curve_path)

static func fake_loss_client_cmd(frequency: int) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.client_params.fake_loss = frequency

static func fake_loss_server_cmd(frequency: int) -> void:
	var lag_faker := try_get_lag_faker()
	if !lag_faker: return
	
	lag_faker.server_params.fake_loss = frequency

static func write_script_properties(object: Object,exceptions: PackedStringArray = [],prefix: String = "") -> void:
	for property in object.get_property_list():
		if QuackMultiplayer.is_script_variable(property) and !exceptions.has(property.name):
			Console.write(prefix+property.name+": "+str(object[property.name]))

const reload_console_commands_aliases: PackedStringArray = ["reload_console","refresh_commands","refresh_console"]
const reload_console_commands_debug_only = true
static func reload_console_commands_cmd() -> void:
	Console.reload_commands()
const get_all_classes_info_debug_only = true
static func get_all_classes_info_cmd() -> void:
	var global_class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	await Console.await_if_out_of_time()
	for c in global_class_list:
		Console.write(String(c.class))
		write_script_info(load(c.path))

const get_class_info_debug_only = true
static func get_class_info_cmd(name: String) -> void:
	var global_class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	await Console.await_if_out_of_time()
	var script: Script
	for c in global_class_list:
		if c.class == name:
			script = load(c.path)
			break
		await Console.await_if_out_of_time()
	if !script:
		return Console.write("%s not here lmao"%[name])
	
	write_script_info(script)

static func write_script_info(script: Script) -> void:
	var constant_map: Dictionary = script.get_script_constant_map()
	await Console.await_if_out_of_time()
	Console.write("Constants:")
	for constant in constant_map:
		Console.write(Console.indent_string+"%s: %s"%[constant,str(constant_map[constant])])
		await Console.await_if_out_of_time()
	Console.writelns(2)
	
	Console.write("Properties:")
	await write_array_of_dicts(script.get_script_property_list())
	
	Console.write("Methods:")
	await write_array_of_dicts(script.get_script_method_list())
	
	Console.write("Signals:")
	await write_array_of_dicts(script.get_script_signal_list())

static func write_array_of_dicts(array: Array[Dictionary],await_frac: float = 0.1) -> bool:
	for dict in array:
		await write_dict_stringkeyonly(dict,await_frac)
		Console.writeln()
	return true

static func write_dict_stringkeyonly(dict: Dictionary,await_frac: float = 0.1) -> bool:
	await Quack.await_if_out_of_time(await_frac)
	for key in dict:
		Console.write(Console.indent_string+"%s: %s"%[key,str(dict[key])])
		await Quack.await_if_out_of_time(await_frac)
	return true

const get_classes_debug_only = true
static func get_classes_cmd() -> void:
	var global_class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	await Console.await_if_out_of_time()
	for c in global_class_list:
		for property in c:
			Console.write("%s: %s"%[property,c[property]])
			await Console.await_if_out_of_time()
		Console.writeln()

const get_server_list_aliases: PackedStringArray = ["get_servers"]
static func get_server_list_cmd() -> void:
	var servers: Dictionary = Network.server_browser.servers
	var server: ServerBrowser.ServerInfo
	for id: int in servers.keys():
		server = servers[id]
		Console.write(BBCode.set_color("\t%s:%s"%[server.ip,server.port],Color.YELLOW))

const connect_local_help = "Connects to local server on local server list (viewable with get_server_list) at the supplied index, if valid."
static func connect_local_cmd(idx: int) -> void:
	var servers: Dictionary = Network.server_browser.servers
	if servers.is_empty():
		return Console.write("No available servers on local network.")
	idx = clampi(idx,1,servers.size())
	var server: ServerBrowser.ServerInfo = servers[servers.keys()[idx-1]]
	connect_with_port_cmd(server.ip,server.port)


const bind_help = "Binds the supplied button to the supplied action, if it exists, OR binds the supplied button to a supplied console command in place of an action. For instance, a regular action bind can be created as follows: 'bind B ui_back' will execute the action 'ui_back' whenever the B key is pressed. A command bind can be created as follows: 'bind Q quit' will execute the command 'quit' whenever the Q key is pressed."
static func bind_cmd(button: String, action: String) -> void:
	var actn := StringName(action)
	if InputMap.has_action(actn):
		Console.write("Binding %s to action %s."%[button,action])
		Inputs.register_key_for_action(button,action)
	elif Console.command_string_map.has(action):
		Console.write("Binding %s to command %s."%[button,action])
		if !InputMap.has_action(actn):
			Console.write("Adding command shortcut action %s."%action)
			Console.add_shortcut(actn)
		Inputs.register_key_for_action(button,action)
	else:
		Console.writerr("Action %s does not exist."%action)

const get_actions_help = "Prints every action in the game, including custom command actions."
static func get_actions_cmd() -> void:
	Console.write("All actions:")
	for action in InputMap.get_actions():
		Console.writevar(action)
		await Console.await_if_out_of_time()
	Console.writeln()

const get_binds_help = "Prints all of the binds of the supplied action, or executes the command 'get_all_binds' if no action is supplied."
static func get_binds_cmd(action: String) -> void:
	if action.is_empty():
		return get_all_binds_cmd()
	var actn := StringName(action)
	if InputMap.has_action(actn):
		Console.write(BBCode.set_color("Events bound to action %s:"%action,Color.PLUM))
		for event in InputMap.action_get_events(actn):
			Console.write(BBCode.set_color(str(event),Color.CYAN))
			await Console.await_if_out_of_time()
		Console.writeln()
	else:
		Console.writerr("Action %s does not exist."%action)

const get_all_binds_help = "Prints all of the binds of every action."
const get_all_binds_aliases: PackedStringArray = ["all_binds"]
static func get_all_binds_cmd() -> void:
	Console.write("Binds for all actions:")
	for action in InputMap.get_actions():
		Console.write_in_color(action,Color.YELLOW)
		Console.write("Events bound to action %s:"%action)
		for event in InputMap.action_get_events(action):
			Console.write_in_color(Console.indent_string+str(event),Color.CYAN*0.7)
			await Console.await_if_out_of_time()
		Console.writeln()

const get_bound_keys_help = "Prints all physical keycodes bound to actions, and every action that a key is bound to."
const get_bound_keys_aliases: PackedStringArray = ["get_all_bound_keys","bound_keys","get_key_binds","get_keybinds"]
static func get_bound_keys_cmd() -> void:
	Console.write("All bound keys:")
	var key_map: Dictionary[Key,PackedStringArray]
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				if event.physical_keycode == KEY_NONE:
					continue
				if key_map.has(event.physical_keycode):
					key_map[event.physical_keycode].append(action)
				else:
					key_map[event.physical_keycode] = PackedStringArray([action])
	for key in key_map.keys():
		Console.write_in_color("Actions bound to key %s:"%OS.get_keycode_string(key),Color.CYAN)
		for action in key_map[key]:
			Console.write_in_color(Console.indent_string+action,Color.YELLOW*.7)
			await Console.await_if_out_of_time()
		Console.writeln()

const unbind_help = "Unbinds the supplied buton from the supplied action. If no action is supplied, calls unbind_button on the supplied button."
static func unbind_cmd(button: String, action: String) -> void:
	if action.is_empty():
		return unbind_button_cmd(button)
	if InputMap.has_action(action):
		Console.write("Unbinding %s from action %s"%[button,action])
		Inputs.remove_action(button,StringName(action))
	else:
		Console.writerr("Action %s does not exist."%action)

const unbind_button_help = "Unbinds the supplied button from all actions."
static func unbind_button_cmd(button: String) -> void:
	Inputs.remove_key_from_all_actions(button)

static func get_args_cmd() -> void:
	Console.writevar(OS.get_cmdline_args())

static func get_user_args_cmd() -> void:
	Console.writevar(OS.get_cmdline_user_args())

static func get_all_args_cmd() -> void:
	var args := OS.get_cmdline_args()
	args.append(" ++ ")
	args.append_array(OS.get_cmdline_user_args())
	Console.writevar(args)

const restart_help = "Restarts the game."
static func restart_cmd() -> void:
	OS.set_restart_on_exit(true,OS.get_cmdline_args() + dasharray + OS.get_cmdline_user_args())
	quit_cmd()

const restartv_help = "Restarts the game with the --verbose launch option."
static func restartv_cmd() -> void:
	OS.set_restart_on_exit(true,OS.get_cmdline_args()+PackedStringArray(["--verbose"])+dasharray+OS.get_cmdline_user_args())
	quit_cmd()

const dasharray: PackedStringArray = ["--"]

const copy_help = "Copies the console's output to the user's clipboard."
static func copy_cmd() -> void:
	DisplayServer.clipboard_set(Console.get_text())
	Console.write("Console text copied to clipboard.")

const save_settings_help = "Saves settings to user data folder."
const save_settings_aliases: PackedStringArray = ["save"]
static func save_settings_cmd() -> void:
	var err: Error = ProjectSettings.save_custom(Quack.legaming_patch_app_hack)
	if err != OK:
		Console.writerr("Failed to save settings. Got error %s."%error_string(err))
	else:
		Console.write("Saved settings in %s."%BBCode.set_color((Quack.SETTING_FILEPATH),Color.YELLOW))
		# Prev, currently doesnt save to user data
		#Console.write("Saved settings at %s."%BBCode.set_color((OS.get_user_data_dir()+"/"+Quack.SETTING_FILEPATH),Color.YELLOW))

const quitsave_aliases: PackedStringArray = ["quits", "qs"]
static func quitsave_cmd() -> void:
	save_settings_cmd()
	quit_cmd()
	
const save_editor_debug_only = true
static func save_editor_cmd() -> void:
	if !Quack.is_exported():
		var err: Error = ProjectSettings.save()
		if err != OK:
			Console.writerr("Failed to save settings. Got error %s."%error_string(err))
		else:
			Console.write("Saved settings to %s."%BBCode.set_color("project.godot",Color.YELLOW))

static func windowpos_cmd(x: int, y: int) -> void:
	Quack.root.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	Quack.root.position = Vector2i(x,y)

const breakpoint_debug_only = true
static func breakpoint_cmd() -> void:
	breakpoint

static func freecam_cmd() -> void:
	doesntwork()
	#if !GameState.auth_worldstate:
		#return Console.write("Can't run a freecam when a game isn't running.")
	#var current_camera := Quack.get_current_camera()
	#if current_camera is FreeCam:
		#current_camera.queue_free()
	#else:
		#if current_camera:
			#var euler := current_camera.global_transform.basis.get_euler()
			#Quack.tree.current_scene.add_child(FreeCam.new(current_camera.global_transform.origin,Vector2(euler.x,euler.y)))
		#else:
			#Quack.tree.current_scene.add_child(FreeCam.new())

static func register_splitscreen_actions_cmd(player_idx: int) -> void:
	var idx: int = clampi(player_idx-1,1,3)
	Console.write("Adding splitscreen actions for player %s."%(idx+1))
	Inputs.register_actions_for_splitscreen_player(idx)

const accumulate_inputs_aliases: PackedStringArray = ["accumulate_input","use_accumulated_inputs","use_accumulated_input"]
static func accumulate_inputs_cmd(onoff: bool) -> void:
	Input.set_use_accumulated_input(onoff)

const restart_scene_auth_only = true
static func restart_scene_cmd() -> void:
	var path := Quack.tree.current_scene.scene_file_path
	if path.is_empty():
		return Console.writerr("Can't restart scene when current scene does not come from a packed scene file.")
	Console.write("Restarting scene %s..."%path)
	Quack.change_scene(path)

const rocket_launcher_scene = preload("res://gameplay/item/rocket_launcher/rocket_launcher.tscn")
const Weapon = preload("res://gameplay/item/shared/weapon.gd")
const PlayerCharacter = preload("res://gameplay/player/player_character.gd")
const OwnerID = preload("res://gameplay/owner_id.gd")
const InventoryComponent = preload("res://gameplay/player/inventory_component.gd")
const give_rocket_launcher_aliases: PackedStringArray = ["give_rl"]
const give_rocket_launcher_auth_only = true
static func give_rocket_launcher_cmd() -> void:
	try_give_player_item(rocket_launcher_scene)

const double_barrel_rl_scene = preload("res://gameplay/item/double_barrel_rl/double_barrel_rl.tscn")
const give_double_barrel_rocket_launcher_aliases: PackedStringArray = ["give_db","give_double_barrel_rl","give_db_rl","give_double_barrel"]
const give_double_barrel_rocket_launcher_auth_only = true
static func give_double_barrel_rocket_launcher_cmd() -> void:
	try_give_player_item(double_barrel_rl_scene)

const quad_rl_scene = preload("res://gameplay/item/quad_barrel_rl/quad_barrel_rl.tscn")
const give_quad_barrel_rocket_launcher_aliases: PackedStringArray = ["give_quad_barrel_rl","give_quad_rocket","give_quad_rocket_launcher","give_quad_rl","give_4_rl"]
const give_quad_barrel_rocket_launcher_auth_only = true
static func give_quad_barrel_rocket_launcher_cmd() -> void:
	try_give_player_item(quad_rl_scene)

const m16_scene = preload("res://gameplay/item/m16/m16.tscn")
const give_m16_auth_only = true
static func give_m16_cmd() -> void:
	try_give_player_item(m16_scene)

const quickscope_scene = preload("res://gameplay/item/quickscope_sniper/quickscope_sniper.tscn")
const give_quickscope_inator_aliases: PackedStringArray = ["give_quickscope","give_quickscoper","give_quickscope_gun","give_quickscope_sniper"]
const give_quickscope_inator_auth_only = true
static func give_quickscope_inator_cmd() -> void:
	try_give_player_item(quickscope_scene)

const knife_scene = preload("res://gameplay/item/knife/knife.tscn")
const give_knife_auth_only = true
static func give_knife_cmd() -> void:
	try_give_player_item(knife_scene)

const shotgun_scene = preload("res://gameplay/item/pump_shotgun/pump_shotgun.tscn")
const give_shotgun_auth_only = true
static func give_shotgun_cmd() -> void:
	try_give_player_item(shotgun_scene)

static func get_player() -> Node:
	if !Quack.tree.has_group(&"Player"):
		Console.writerr("No player to give item to.")
		return null
	return Quack.tree.get_first_node_in_group(&"Player")

const AmmoComponent = preload("res://gameplay/item/shared/ammo_component.gd")
static func give_player_item(player: PlayerCharacter, item: Weapon) -> void:
	if !InventoryComponent.component_list.has(player): return Console.writerr("Can't give %s to %s because they don't have an inventory component."%[item.name,player.name])
	Quack.get_current_scene().add_child(item)
	Console.write("Equipping %s..."%item.name)
	var ic := InventoryComponent.component_list[player]
	ic.weapon_removed.connect(free_node,CONNECT_REFERENCE_COUNTED)
	AmmoComponent.try_fill_mag(item)
	ic.add_weapon(item)
	item.reset_physics_interpolation.call_deferred()

static func free_node(node: Node) -> void:
	node.queue_free()

static func try_give_player_item(scene: PackedScene) -> void:
	var player := get_player()
	if player == null: return
	var item: Weapon = scene.instantiate() as Weapon
	if player is PlayerCharacter:
		give_player_item(player as PlayerCharacter,item)

const spoon_scene = preload("res://gameplay/item/spoon/spoon.tscn")
const give_spoon_auth_only = true
static func give_spoon_cmd() -> void:
	try_give_player_item(spoon_scene)

const spiker_scene = preload("res://gameplay/item/spiker/spiker.tscn")
const give_spiker_auth_only = true
static func give_spiker_cmd() -> void:
	try_give_player_item(spiker_scene)

const smg_scene = preload("res://gameplay/item/smg/smg.tscn")
const give_smg_auth_only = true
static func give_smg_cmd() -> void:
	try_give_player_item(smg_scene)

const GodotMovePlayer = preload("res://gameplay/player/godot_move_player.tscn")
const spawn_dummy_auth_only = true
static func spawn_dummy_cmd() -> void:
	if !Quack.tree.has_group(&"Player"): return Console.writerr("No player to spawn dummy above.")
	var player := Quack.tree.get_first_node_in_group(&"Player")
	if not player is Node3D: return Console.writerr("Player isn't a Node3D lmao")
	var pos: Vector3 = (player as Node3D).global_position+Vector3(0,10,0)
	Console.write("Spawning dummy at %s."%pos)
	var dummy: PlayerCharacter = GodotMovePlayer.instantiate() as PlayerCharacter
	QuackMultiplayer.set_node_position_on_ready(dummy,pos)
	dummy.ready.connect(dummy.force_update_transform)
	dummy.reset_physics_interpolation.call_deferred()
	Quack.get_current_scene().add_child(dummy)

static var infinite_ammo: bool
const infinite_ammo_help = "Gives every gun infinite ammo"
const infinite_ammo_auth_only = true
static func infinite_ammo_cmd(on: bool) -> void:
	infinite_ammo = on

static func alias_cmd(new_alias: String, command: String) -> void:
	if !Console.command_string_map.has(command):
		return Console.writerr("Can't add an alias for nonexistent command %s."%command)
	if Console.command_string_map.has(new_alias):
		return Console.writerr("Can't create %s as an alias since it already exists as a command alias for %s."%[new_alias,Console.command_string_map[new_alias].get_command_name()])
	var command_info := Console.command_string_map[command]
	Console.command_string_map[new_alias] = command_info
	command_info.aliases.append(new_alias)

const dump_environment_aliases: PackedStringArray = ["dump_env"]
const dump_environment_debug_only = true
static func dump_environment_cmd() -> void:
	var env := Quack.root.world_3d.environment
	if env:
		for property in env.get_property_list():
			if property.usage & PROPERTY_USAGE_EDITOR or property.usage < PROPERTY_USAGE_EDITOR or property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				property.type = type_string(property.type)
				if property.class_name == &"":
					property.erase("class_name")
				property.hint = " " + ByteUtils.to_binary_string(property.hint,false,29)
				property.usage = ByteUtils.to_binary_string(property.usage,false,29)
				await write_dict_stringkeyonly(property,1)
				Console.writelns(1)
	else:
		return Console.writerr("No environment to dump.")
	#if Quack.root.world_3d # alternative way of doing this

const dmg_num_scene = preload("res://interface/hud/damage_hud/damage_number.tscn")
const DamageNumber = preload("res://interface/hud/damage_hud/damage_number.gd")
const test_dmg_num_debug_only = true
static func test_dmg_num_cmd(dmg: float) -> void:
	var dmg_num: DamageNumber = dmg_num_scene.instantiate() as DamageNumber
	var scene := Quack.get_current_scene()
	var child := scene.get_children()[-1]
	if child is Node3D:
		dmg_num.follow_node = child
	dmg_num.lifetime = 1.
	dmg_num.damage = dmg
	Quack.root.add_child(dmg_num)
	dmg_num.reposition()
	dmg_num.reset_physics_interpolation()

const get_sensitivity_aliases: PackedStringArray = ["get_sens"]
static func get_sensitivity_cmd() -> void:
	Console.write("Sensitivity: %s"%Inputs.getsens())

#static func checkrl_cmd() -> void:
	#var state := rocket_launcher_scene.get_state()
	#for i in state.get_node_count():
		#Console.write(state.get_node_type(i))

static var step_by_step_physics: bool = false
static var stepping_manually: bool = false
const do_step_by_step_physics_debug_only = true
static var was_interpolating: bool
static func do_step_by_step_physics_cmd(on:bool) -> void:
	if stepping_manually:
		return Console.writerr("Can't toggle step by step while stepping manually")
	elif step_by_step_physics == on:
		return
	step_by_step_physics = on
	Quack.tree.paused = on
	if on:
		was_interpolating = Quack.tree.physics_interpolation
	if !manual_step_interp:
		if on:
			Quack.tree.physics_interpolation = false
		else:
			Quack.tree.physics_interpolation = was_interpolating
	elif not on:
		Quack.tree.physics_interpolation = was_interpolating

static var manual_step_interp: bool = true
const interp_during_manual_step_debug_only = true
static func interp_during_manual_step_cmd(on: bool) -> void:
	manual_step_interp = on

const step_physics_debug_only = true
static func step_physics_cmd() -> void:
	if step_by_step_physics:
		stepping_manually = true
		await Quack.tree.physics_frame
		Quack.tree.paused = false
		await Quack.tree.physics_frame
		Quack.tree.paused = true
		stepping_manually = false

const sens_convert_string_base = "Set your sens to ~%s to get the same sens as %s in "

const csgo_yaw = .022
const ow_yaw = .0066
const convert_csgo_sens_aliases: PackedStringArray = ["convert_cs_sens","convert_cs2_sens"]
static func convert_csgo_sens_cmd(sens: float) -> void:
	convert_sens(sens,csgo_yaw,"CS:GO")

const convert_ow_sens_aliases: PackedStringArray = ["convert_overwatch_sens"]
static func convert_ow_sens_cmd(sens: float) -> void:
	convert_sens(sens,ow_yaw,"Overwatch")

static func convert_tf2_sens_cmd(sens: float) -> void:
	convert_sens(sens,csgo_yaw,"TF2")

static func convert_sens(sens: float, yaw: float, string: String) -> void:
	Console.write((sens_convert_string_base+string+".")%[BBCode.set_color(str(100.*(yaw*sens)),Color.GREEN),sens])

const NoclipComponent = preload("res://gameplay/player/noclip_component.gd")
static func noclip_cmd() -> void:
	var player := get_player()
	if player and player is PlayerCharacter:
		toggle_noclip(player as PlayerCharacter)

static func toggle_noclip(player: PlayerCharacter) -> void:
	if NoclipComponent.component_list.has(player):
		NoclipComponent.component_list[player].queue_free()
		toggle_component_modes(player,Node.PROCESS_MODE_INHERIT)
	else:
		player.add_child(NoclipComponent.new())
		toggle_component_modes(player,Node.PROCESS_MODE_DISABLED)

const GodotMoveComponent = preload("res://gameplay/player/godot_move_component.gd")
const CrouchComponent = preload("res://gameplay/player/crouch_component.gd")
static func toggle_component_modes(player: PlayerCharacter, process_mode: Node.ProcessMode) -> void:
	# This would be more "flexible" but would slow tf down if theres hella players
	#for node in Quack.get_nodes_in_group(&"player_movement"):
		#if node.get_parent() == player:
			#node.set_process_mode(process_mode)
	if GodotMoveComponent.component_list.has(player):
		GodotMoveComponent.component_list[player].set_process_mode(process_mode)
	if CrouchComponent.component_list.has(player):
		CrouchComponent.component_list[player].set_process_mode(process_mode)
