@tool
extends "res://interface/classes/settings_menu.gd"

const WindowUtils = Quack.WindowUtils
const Audio = Quack.Audio

@onready var scroller := $Container/Scroller as ScrollContainer

func _ready() -> void:
	super._ready()
	if !Engine.is_editor_hint():
		scroller.clip_contents = true

func change_game_framerate(value: float) -> void:
	WindowUtils.set_max_game_fps(value)

func change_game_fullscreen(index: int) -> void:
	if Quack.is_3D_scene():
		WindowUtils.set_window_mode(index)

func change_menu_fullscreen(index: int) -> void:
	if !Quack.is_3D_scene():
		WindowUtils.set_window_mode(index)

func change_vsync(index: int) -> void:
	WindowUtils.set_vsync(index)

func change_master_volume(value: float) -> void:
	Audio.set_volume(value)

# Requires restart
#func change_rendering_method(string: String) -> void:
	#pass # Replace with function body.

func use_gi_half_resolution(toggled_on: bool) -> void:
	RenderingServer.gi_set_use_half_resolution(toggled_on)

# Requires restart
#func force_vertex_shading(toggled_on: bool) -> void:
	#pass

# Requires restart
#func force_lambert(toggled_on: bool) -> void:
	#pass # Replace with function body.

func change_msaa(index: int) -> void:
	Quack.root.msaa_3d = index

func change_ssaa(index: int) -> void:
	Quack.root.screen_space_aa = index

func use_taa(toggled_on: bool) -> void:
	Quack.root.use_taa = toggled_on

func use_debanding(toggled_on: bool) -> void:
	Quack.root.use_debanding = toggled_on

func set_scaling_mode(index: int) -> void:
	Quack.root.scaling_3d_mode = index

func set_render_scale(value: float) -> void:
	WindowUtils.set_render_scale(value)

func set_fsr_sharpness(value: float) -> void:
	Quack.root.fsr_sharpness = value

func set_vrs(index: int) -> void:
	Quack.root.vrs_mode = index

func set_sens(value: float) -> void:
	Inputs.change_sens(value)

func set_console_transparency(value: float) -> void:
	if value == 1.:
		Console.set_transparent()
	else:
		Console.set_opacity(1.-value)
		if value == 0.:
			Console.transparent_bg = false

func set_low_processor_mode(toggled_on: bool) -> void:
	OS.low_processor_usage_mode = toggled_on

@onready var game_framerate_ticker := $Container/Scroller/Container/Video/SliderContainerContainer2/SliderContainer/GameFramerateTicker as SpinBox
func clamp_reasonable_framerate_value(value: float) -> void:
	if value < game_framerate_ticker.min_value and value != 0.:
		game_framerate_ticker.set_value(snappedi(clampf(value,0.,game_framerate_ticker.min_value),game_framerate_ticker.min_value))

func set_ssr_enabled(toggled_on: bool) -> void:
	var env := Quack.root.world_3d.environment
	if !env: return
	env.ssr_enabled = toggled_on

func set_ssao_enabled(toggled_on: bool) -> void:
	var env := Quack.root.world_3d.environment
	if !env: return
	env.ssao_enabled = toggled_on

func set_ssil_enabled(toggled_on: bool) -> void:
	var env := Quack.root.world_3d.environment
	if !env: return
	env.ssil_enabled = toggled_on

func set_glow_enabled(toggled_on: bool) -> void:
	var env := Quack.root.world_3d.environment
	if !env: return
	env.glow_enabled = toggled_on

func set_sdfgi_enabled(toggled_on: bool) -> void:
	var env := Quack.root.world_3d.environment
	if !env: return
	env.sdfgi_enabled = toggled_on

func set_sdfgi_use_occlusion(toggled_on: bool) -> void:
	var env := Quack.root.world_3d.environment
	if !env: return
	env.sdfgi_use_occlusion = toggled_on

# This is high key overkill perf-wise for individual settings changes but fuck it lmao
const POScript = preload("res://interface/perf_overlay/perf_overlay.gd")
func update_perf_overlay_visibility_settings() -> void:
	var perf_overlay := Console.console_commands_script.perf_overlay as POScript
	if perf_overlay:
		perf_overlay.apply_visibility_settings()

# for some reason if u dont have this as preloaded then even tho autocomplete works for performance_overlay_cmd its still considered untyped...?
const ccscript = preload("res://utils/console/console_commands.gd")
func toggle_perfoverlay(on: bool) -> void:
	if Engine.is_editor_hint(): return
	var perf_overlay := ccscript.perf_overlay as POScript
	if on:
		if !perf_overlay:
			ccscript.performance_overlay_cmd()
	else:
		if perf_overlay:
			ccscript.performance_overlay_cmd()

func set_perfoverlay_max_width(value: float) -> void:
	var perf_overlay := Console.console_commands_script.perf_overlay as POScript
	if perf_overlay:
		perf_overlay.max_width = value
		perf_overlay.assign_width_to_root_width()

func set_perfoverlay_font_size(value: float) -> void:
	var perf_overlay := Console.console_commands_script.perf_overlay as POScript
	if perf_overlay:
		perf_overlay.font_size = value
		perf_overlay.apply_visibility_settings()

func set_perfoverlay_color(color: Color) -> void:
	var perf_overlay := Console.console_commands_script.perf_overlay as POScript
	if perf_overlay:
		perf_overlay.color = color
		perf_overlay.apply_visibility_settings()
