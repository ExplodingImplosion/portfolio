extends HBoxContainer

const HealthComponent = preload("res://gameplay/health_component.gd")

@export var player: Node
@export var snap: float
@onready var snap_to_int: bool = snap == 0.
var health_component: HealthComponent
var has_health: bool

@onready var health_label: Label = $HealthLabel as Label
@onready var max_health_label: Label = $MaxHealthLabel as Label
@onready var slash_label: Label = $SlashLabel as Label

func _ready() -> void:
	if player:
		set_current_player.call_deferred(player)

func _physics_process(delta: float) -> void:
	if has_health:
		if player and is_instance_valid(player):
			assert(health_component and is_instance_valid(health_component), "lmao")
			update_labels(health_component)

func set_current_player(current_player: Node) -> void:
	player = current_player
	has_health = HealthComponent.component_list.has(player)
	if has_health:
		health_component = HealthComponent.component_list[player]
		update_labels(health_component)
	else:
		health_label.set_text("")
		slash_label.set_text("--")
		max_health_label.set_text("")

func update_labels(health_component: HealthComponent) -> void:
	health_label.set_text(str(int(health_component.health) if snap_to_int else snappedf(health_component.health,snap)))
	slash_label.set_text("/")
	#max_health_label.set_text(str(health_component.max_health))
