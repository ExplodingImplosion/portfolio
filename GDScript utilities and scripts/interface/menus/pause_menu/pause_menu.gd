extends Control

const Menu = preload("res://interface/menus/main_menu.gd")

@onready var menu: Menu = $MainMenu as Menu

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_cancel"):
		if menu.visible:
			if menu.is_on_default_layer():
				deactivate()
		else:
			activate()

func activate() -> void:
	toggle_menu(true)
	Inputs.pause_gameplay_inputs()

func deactivate() -> void:
	menu.quitconfirm.hide()
	toggle_menu(false)
	Inputs.resume_gameplay_inputs()

func gotomainmenu() -> void:
	Console.console_commands_script.main_menu_cmd()

func _exit_tree() -> void:
	# hmm starting to think this resume / pause gameplay inputs thing might
	# notve been fully thought thru (including the counting up / down part)
	if menu.visible:
		Inputs.resume_gameplay_inputs()
		Inputs.show_cursor()

func _ready() -> void:
	toggle_menu(false)

func toggle_menu(on: bool) -> void:
	menu.visible = on
	menu.set_process_input(on)
