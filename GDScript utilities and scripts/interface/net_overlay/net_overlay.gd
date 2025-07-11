extends CanvasLayer

const Serializer = preload("res://gameplay/serializer.gd")
const Network = Serializer.Network
const LabelUtils = preload("res://utils/label_utils.gd")

@onready var container: HFlowContainer = $Container as HFlowContainer

func _init() -> void:
	Serializer.component_tracker.component_added.connect(track_serializer,CONNECT_DEFERRED)
	Serializer.component_tracker.component_removed.connect(untrack_serializer)

func _ready() -> void:
	Quack.defer_to_next_frame(track_serializers_on_startup.call_deferred)

func track_serializers_on_startup() -> void:
	for serializer in Serializer.component_list.values():
		track_serializer(serializer as Serializer)

func _exit_tree() -> void:
	Serializer.component_tracker.component_added.disconnect(track_serializer)
	Serializer.component_tracker.component_removed.disconnect(untrack_serializer)

var serializer_map: Dictionary[Serializer,SerializerReadout]

class SerializerReadout extends HBoxContainer:
	var serializer: Serializer
	var node_name := Label.new()
	var node_uid := Label.new()
	var node_size := Label.new()
	
	func _init(component: Serializer) -> void:
		serializer = component
		setup_label(node_name,serializer.owner.name)
		setup_label(node_uid,str(component.uid))
		setup_label(node_size,"size: %s"%var_to_bytes(component.serialized).size())
	
	func setup_label(label: Label, text: String) -> void:
		label.text = text
		LabelUtils.set_font(label,preload("res://interface/fonts/montserrat-extrabold.ttf"))
		LabelUtils.set_font_shadow_color(label,Color.BLACK)
		LabelUtils.set_font_size(label,18)
		add_child(label)

func track_serializer(serializer: Serializer) -> void:
	var readout := SerializerReadout.new(serializer)
	container.add_child(readout)
	serializer_map[serializer] = readout

func untrack_serializer(serializer: Serializer) -> void:
	if !serializer_map.has(serializer):
		return Quack.defer_to_next_frame(untrack_serializer.bind(serializer))
	serializer_map[serializer].queue_free()
	serializer_map.erase(serializer)
