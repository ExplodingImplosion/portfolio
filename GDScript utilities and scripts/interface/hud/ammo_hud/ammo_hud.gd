extends HBoxContainer

const AmmoComponent = preload("res://gameplay/item/shared/ammo_component.gd")
const Weapon = AmmoComponent.Weapon

var is_ammo_weapon: bool
@export var weapon: Weapon
var ammo_component: AmmoComponent

@onready var ammo_label: Label = $AmmoLabel as Label
@onready var mag_label: Label = $MagLabel as Label
@onready var slash_label: Label = $SlashLabel as Label
@onready var reserve_label: Label = $ReserveLabel as Label

func _ready() -> void:
	if weapon:
		set_current_weapon.call_deferred(weapon)

func _physics_process(delta: float) -> void:
	if is_ammo_weapon:
		if weapon and is_instance_valid(weapon):
			assert(ammo_component and is_instance_valid(ammo_component), "lmao")
			update_labels(ammo_component)

func set_current_weapon(current_weapon: Weapon) -> void:
	weapon = current_weapon
	is_ammo_weapon = AmmoComponent.component_list.has(weapon)
	if is_ammo_weapon:
		ammo_component = AmmoComponent.component_list[weapon]
		update_labels(ammo_component)
	else:
		ammo_label.set_text("")
		slash_label.set_text("--")
		mag_label.set_text("")

func update_labels(ammo_component: AmmoComponent) -> void:
	ammo_label.set_text(str(ammo_component.ammo))
	slash_label.set_text("/")
	mag_label.set_text(str(ammo_component.mag_size))
	#reserve_label.set_text("")
