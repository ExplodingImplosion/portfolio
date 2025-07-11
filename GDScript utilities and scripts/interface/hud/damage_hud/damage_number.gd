extends Label

const LabelUtils = preload("res://utils/label_utils.gd")
const DamageNumber = preload("res://interface/hud/damage_hud/damage_number.gd")

var damage: float
@export var lifetime: float
@export var offset: Vector2
@export var snap: float
var time_left: float
enum RoundMode {UP,DOWN,NO_ROUND}
@export var round_mode: RoundMode = RoundMode.DOWN
@export var follow_node: Node3D
@export var x_direction: Curve
@export var y_direction: Curve
@export var sample_baked: bool = false

func _process(delta: float) -> void:
	time_left += delta
	if time_left >= lifetime:
		queue_free()
	reposition()
 
func reposition() -> void:
	if !follow_node or !is_instance_valid(follow_node): return
	var camera := Quack.root.get_camera_3d()
	if !camera: return
	
	var fraction: float = time_left / lifetime
	var node_pos := follow_node.get_global_transform_interpolated().origin
	var cam_pos := camera.get_global_transform_interpolated().origin
	# TODO: the goal of this was going to be to have the damage number move relative to the node's
	# relative position to the camera, in the sense that the numbers move less on the screen the farther away that the target node is. Not doing that for now because I've given up on the math
	# after an hour or 2
	#var angle :=
	
	position = camera.unproject_position(node_pos) + ( ( offset + Vector2(x_direction.sample_baked(fraction),y_direction.sample_baked(fraction)) if sample_baked else Vector2(x_direction.sample(fraction),y_direction.sample(fraction)) ) if (x_direction and y_direction) else offset )
	visible = !camera.is_position_behind(node_pos)

func _ready() -> void:
	damage = snappedf(damage,snap)
	text = str(damage)

func update_damage(new_damage: float) -> void:
	damage = snappedf(new_damage,snap)
	text = str(damage)

class DisplayProfile:
	
	var color: Color
	
	var shadowed: bool
	var shadow_color: Color
	var shadow_offset: Vector2
	
	var outlined: bool
	var outline_color: Color
	var outline_size: float
	
	var shadow_outlined: bool
	var shadow_outline_size: float
	
	func apply(label: Label) -> void:
		LabelUtils.set_font_color(label,color)
		if shadowed:
			LabelUtils.set_font_shadow_color(label,shadow_color)
			LabelUtils.set_font_shadow_offset(label,shadow_offset)
		if outlined:
			LabelUtils.set_font_outline_color(label,outline_color)
			LabelUtils.set_font_outline_size(label,outline_size)
		if  shadow_outlined:
			LabelUtils.set_font_shadow_outline_size(label,shadow_outline_size)
