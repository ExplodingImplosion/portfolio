extends "res://interface/classes/menu.gd"

@onready var quitconfirm := $QuitConfirm as ConfirmationDialog
@onready var quicksettings : = $QuickSettings as Control

func play() -> void:
	Console.console_commands_script.play_cmd("dev")

func gotosettings() -> void:
	_go_to_layer(quicksettings)

func quit() -> void:
	quitconfirm.popup_centered()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_cancel"):
		match current_layer:
			default_layer:
				if quitconfirm.visible:
					quit()
				else:
					quitconfirm.hide()
			_:
				go_to_default_layer()
