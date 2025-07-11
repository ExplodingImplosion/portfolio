@tool
extends "res://interface/classes/menu.gd"
const IntEnumSettingOption = preload("res://interface/classes/int_enum_setting_option.gd")
const TextSettingOption = preload("res://interface/classes/text_setting_option.gd")
const ReadoutLabel = preload("res://interface/classes/readout_label.gd")
# If you wanted, ReadoutLabel could be here as a non-dependency with this:
#class ReadoutLabel extends Label:
	#func set_float_text(value: float) -> void:
		#set_text(str(value))
#
	#func set_int_text(value: float) -> void:
		#set_text(str(int(value)))

## Overrides the parent under which settings will be created, instead of the settings menu root node
@export var selected_node: Node
@export_group("Format Options")
## If filled, all settings created will be given this name.
@export var custom_name: String
## If overriden, all settings created will be given this theme.
@export var custom_theme: Theme
## What type of node will contain setting children when settings are created by
## section prefix.
@export var section_child_type: SectionChildType
## If not customized or an integer, range values will be given this step
@export var default_step: float = .001
## Overrides HSlider custom_minimum_size.x value if 0
@export_range(0.,9999.,0.01,"exp") var slider_min_size: float = 0.
@export var range_values_include_spin_boxes: RangeValueSetting

enum RangeValueSetting {
	## Range values will be HSliders only.
	ExcludeSpinBox,
	## Range values will be HSliders and SpinBoxes.
	IncludeSpinBox,
	## Range values will be SpinBoxes only.
	SpinBoxOnly,
}

enum SectionChildType {
	## Section children will be Control nodes.
	Generic,
	## Section children will be VBoxContainer nodes.
	VBox,
	## Section children will be HBoxContainer nodes.
	HBox,
	## Every odd section child will be a VBoxContainer node, and every even section
	## child will be an HBoxContainer node.
	Alternating,
	## Section children will be HFlowContainer nodes.
	Flow
}

func _init() -> void:
	if Engine.is_editor_hint():
		setup_project_settings()
	

func _ready() -> void:
	if !Engine.is_editor_hint():
		super._ready()
		for sig in get_incoming_connections():
			var callable := sig.callable as Callable
			if callable.get_method() == &"change_setting" and callable.get_object() == self:
				var args := callable.get_bound_arguments()
				var setting_path: String = args[0] as String
				var source: Object = (sig.signal as Signal).get_object()
				if source is Range:
					(source as Range).set_value_no_signal(
						ProjectSettings.get_setting(setting_path) as float
					)
				elif source is Button:
					if source is OptionButton:
						var setting: Variant = ProjectSettings.get_setting(setting_path)
						match typeof(setting):
							TYPE_INT:
								(source as OptionButton).selected = find_valid_enum_selection(source as OptionButton, setting as int)
							TYPE_STRING:
								(source as OptionButton).selected = find_valid_string_enum_selection(source as OptionButton, setting as String)
							_:
								Console.writerr("Couldn't select dropdown for setting %s's, invalid type %s."%[setting_path,type_string(typeof(setting))])
								(source as OptionButton).selected = -1
					else:
						(source as Button).set_pressed_no_signal(
							ProjectSettings.get_setting(setting_path) as bool
						)
				elif source is ColorPicker:
					(source as ColorPicker).color = ProjectSettings.get_setting(setting_path) as Color
	else:
		hook_up_int_option_buttons(self)

func hook_up_int_option_buttons(node: Node) -> void:
	if node is OptionButton:
		if not node is TextSettingOption:
			node.editor_state_changed.connect(figure_out_required_type.bind(node))
	for child in node.get_children():
		hook_up_int_option_buttons(child)

func are_item_ids_aligned(node: OptionButton) -> bool:
	for i in node.item_count:
		if node.get_item_id(i) != i:
			return false
	return true

func figure_out_required_type(node: OptionButton) -> void:
	var misaligned_item_ids: bool = !are_item_ids_aligned(node)
	if misaligned_item_ids:
		if node is IntEnumSettingOption:
			return
		else:
			var script: Variant = node.get_script()
			if script != null:
				printerr("Node %s has misaligned item indexes and IDs, but is using a script that doesn't inherit IntEnumSettingOption, so unexpected behavior might happen."%get_path_to(node))
			else:
				node.set_script(IntEnumSettingOption)
				for connection in node.item_selected.get_connections():
					var callable: Callable = connection.callable
					var flags: int = connection.flags
					node.item_selected.disconnect(callable)
					# WHY THE FUCK DOES CONNECTING WITH .connect WORK BUT A DIRECT
					# ACCESSOR FUCKING DOESNT!? FUCK YOUUUUUUUUUUUUUU FUCK YOU FUCK
					# YOU FUCK YOU I SPENT 30+ MINS TRYING TO HACK AROUND TO MAKE
					# THE DIRECT ACCESSOR WORK! I also lowkey forgot that you could
					# use the .connect func lmaoooo fuck me running bro
					var err := (node as IntEnumSettingOption).connect(&"enum_selected",callable,flags)
					prints("connecting %s:"%callable.get_method(),error_string(err))
					#(node as IntEnumSettingOption).enum_selected.connect(callable,flags)
	else:
		if node is IntEnumSettingOption:
			if node.get_script() != IntEnumSettingOption:
				return printerr("Node %s has aligned item indexes and IDs, but is using a script that inherits IntEnumSettingOption, so the script will not be detached."%get_path_to(node))
			else:
				# NOTE: For reasons described above, do NOT access enum_selected
				# directly, and use the node funcs
				for connection in (node as IntEnumSettingOption).get_signal_connection_list(&"enum_selected"):
					var callable: Callable = connection.callable
					var flags: int = connection.flags
					(node as IntEnumSettingOption).disconnect(&"enum_selected",callable)
					node.item_selected.connect(callable,flags)
				node.set_script(null)

## This allows for hidden enum values. For instance, if a fullscreen option
## should always be [code]WINDOW_MODE_FULLSCREEN_EXCLUSIVE[/code], you might
## want to exclude a [code]WINDOW_MODE_FULLSCREEN[/code] option. However, this
## means that there would be <5 options, even though the exclusive option is index
## 4. This makes sure that the proper enum ID is selected.
func find_valid_enum_selection(options: OptionButton, enum_idx: int) -> int:
	for i in options.item_count:
		if options.get_item_id(i) == enum_idx:
			return i
	return -1

func find_valid_string_enum_selection(options: OptionButton, string: String) -> int:
	for i in options.item_count:
		if options.get_item_text(i) == string:
			return i
	return -1

var project_settings: Dictionary[String,Dictionary]

func setup_project_settings() -> void:
	var plist := ProjectSettings.get_property_list()
	for p in plist:
		if p.name == "ProjectSettings" or p.name == "script" or p.usage & PROPERTY_USAGE_INTERNAL:
			continue
		project_settings[p.name] = p
@export_group("Create Settings")
@export var setting_to_create: String

@export_tool_button("Create single setting") var create_setting: Callable = func() -> void:
	if setting_to_create.is_empty():
		return printerr("Can't create setting, since no setting was supplied")
	elif not project_settings.has(setting_to_create):
		return printerr("Can't create setting %s, since no setting exists. Maybe try reloading project settings?"%setting_to_create)
	create_setting_lmao(setting_to_create)
@export var prefix_to_create: String
@export var include_titles: bool
@export var titles_include_colon: bool
@export_tool_button("Create settings by section") var create_settings_by_section: Callable = func() -> void:
	var has_selected_node: bool = true if selected_node else false
	var main_node: Node = selected_node if has_selected_node else self
	for setting:String in project_settings.keys():
		if setting.begins_with(prefix_to_create):
			var path: String
			for string in setting.rstrip("/").substr(0,setting.rfind("/")).split("/"):
				path += string.to_pascal_case()
				var nodepath := NodePath(path)
				if !main_node.has_node(nodepath):
					print("Creating node %s."%path)
					var new_node := get_section_child(path)
					new_node.name = string.to_pascal_case()
					add_node_to_scene(new_node)
					selected_node = new_node
					if include_titles:
						var label := Label.new()
						label.text = new_node.name+(":" if titles_include_colon else "")
						add_node_to_scene(label)
				else:
					selected_node = main_node.get_node(path)
				path += "/"
			selected_node = main_node.get_node(path)
			if !main_node.has_node(NodePath(setting.replacen("/","/_").to_pascal_case())):
				print("Creating setting %s."%setting.replacen("/","/_").to_pascal_case())
				create_setting_lmao(setting)
			else:
				print("Node %s already exists."%setting.replacen("/","/_").to_pascal_case())
		selected_node = main_node
	if !has_selected_node:
		selected_node = null

func get_section_child(path: String) -> Control:
	match section_child_type:
		SectionChildType.Generic:
			return Control.new()
		SectionChildType.VBox:
			return VBoxContainer.new()
		SectionChildType.HBox:
			return HBoxContainer.new()
		SectionChildType.Alternating:
			return VBoxContainer.new() if path.countn("/") % 2 == 0 else HBoxContainer.new()
		SectionChildType.Flow:
			return HFlowContainer.new()
		_:
			return Control.new()
	#return Control.new()

func create_setting_lmao(setting_name: String) -> void:
	var setting := project_settings[setting_name]
	print("Setting info:")
	for key in setting.keys():
		print("	",key,":	",setting[key])
	match setting.hint as int:
		PROPERTY_HINT_ENUM:
			create_enum_setting(setting.name,setting.type,setting.usage,setting.hint,setting.hint_string)
		PROPERTY_HINT_NONE:
			match setting.type as int:
				TYPE_BOOL:
					create_bool_setting(setting.name,setting.usage,setting.hint,setting.hint_string)
				TYPE_STRING:
					create_string_setting(setting.name,setting.usage,setting.hint,setting.hint_string)
				TYPE_INT:
					var spin_box_setting := range_values_include_spin_boxes
					range_values_include_spin_boxes = RangeValueSetting.SpinBoxOnly
					create_range_setting(setting.name,setting.usage,setting.hint,setting.hint_string,true)
					range_values_include_spin_boxes = spin_box_setting
				TYPE_FLOAT:
					var spin_box_setting := range_values_include_spin_boxes
					range_values_include_spin_boxes = RangeValueSetting.SpinBoxOnly
					create_range_setting(setting.name,setting.usage,setting.hint,setting.hint_string)
					range_values_include_spin_boxes = spin_box_setting
				_:
					printerr("Type %s is unimplemented for hint %s."%[type_string(setting.type as int),setting.hint as int])
		PROPERTY_HINT_RANGE:
			match setting.type as int:
				TYPE_FLOAT:
					create_range_setting(setting.name,setting.usage,setting.hint,setting.hint_string)
				TYPE_INT:
					create_range_setting(setting.name,setting.usage,setting.hint,setting.hint_string,true)
				_:
					printerr("Type %s is unimplemented for hint %s."%[type_string(setting.type as int),setting.hint as int])
		#PROPERTY_HINT_FILE:
			#pass
		_:
			printerr("Hint %s is unimplemented."%setting.hint)
@export_group("Reload Project Settings")
@export_tool_button("Reload ProjectSettings") var reload_project_settings := setup_project_settings

func create_string_setting(setting: String, usage: int, hint: int, hint_string: String) -> void:
	var line := LineEdit.new()
	set_node_name(line,setting)
	line.placeholder_text = ProjectSettings.get_setting(setting,"") as String
	line.text = line.placeholder_text
	

func create_range_setting(setting: String, usage: int, hint: int, hint_string: String, int_override: bool = false) -> void:
	var slider := HSlider.new()
	set_node_name(slider,setting)
	slider.step = default_step
	slider.custom_minimum_size.x = slider_min_size
	var params := hint_string.split(",")
	var values_assigned: bool = false
	var param: String
	var prefix: String
	var suffix: String
	for i in params.size():
		param = params[i]
		if param.is_valid_float() and not values_assigned:
			for y in 3:
				if i+y < params.size() - 1:
					if y == 0:
						slider.min_value = params[i+y].to_float()
					elif y == 1:
						slider.max_value = params[i+y].to_float()
					elif y == 2:
						slider.step = params[i+y].to_float()
				elif i + y < params.size():
					if y == 1:
						slider.max_value = params[i+y].to_float()
					elif y == 2:
						slider.step = params[i+y].to_float()
				else:
					continue
			values_assigned = true
		else:
			match param:
				"or_greater":
					slider.allow_greater = true
				"or_less":
					slider.allow_lesser = true
				"exp":
					slider.exp_edit = true
				_:
					if !param.is_valid_float():
						if param.begins_with("prefix:"):
							prefix = param.trim_prefix("prefix:")
						elif param.begins_with("suffix:"):
							suffix = param.trim_prefix("suffix:")
						else:
							printerr("Hint string parameter %s is unsupported."%param)
	if not values_assigned:
		slider.allow_greater = true
		slider.allow_lesser = true
		slider.exp_edit = true
	setup_signal_connection(slider.value_changed,setting)
	var other_node: Control
	slider.value = float(ProjectSettings.get_setting(setting,0.)) as float
	if range_values_include_spin_boxes:
		var spin_box := SpinBox.new()
		spin_box.name = slider.name + "Ticker"
		spin_box.set_value_no_signal.call_deferred(slider.value)
		spin_box.step = slider.step
		spin_box.rounded = slider.step == 1.
		spin_box.max_value = slider.max_value
		spin_box.min_value = slider.min_value
		spin_box.allow_greater = slider.allow_greater
		spin_box.allow_lesser = slider.allow_lesser
		spin_box.prefix = prefix
		spin_box.suffix = suffix
		slider.value_changed.connect(spin_box.set_value_no_signal,CONNECT_PERSIST)
		if range_values_include_spin_boxes == RangeValueSetting.IncludeSpinBox:
			spin_box.value_changed.connect(slider.set_value_no_signal,CONNECT_PERSIST)
		setup_signal_connection(spin_box.value_changed,setting)
		other_node = spin_box
	else:
		var label := ReadoutLabel.new()
		label.name = slider.name+"Readout"
		label.text = str(ProjectSettings.get_setting(setting,0))
		if slider.step == int(slider.step):
			slider.value_changed.connect(label.set_int_text,CONNECT_PERSIST)
		else:
			# If you do this, it literally works, but Godot still throws an error and yells at you:
			# ERROR: Error calling from signal 'value_changed' to callable: 'Label::set_text': Cannot convert argument 1 from float to String.
			#slider.value_changed.connect(label.set_text,CONNECT_PERSIST)
			slider.value_changed.connect(label.set_float_text,CONNECT_PERSIST)
		other_node = label
	
	apply_theme(other_node)
	if range_values_include_spin_boxes != RangeValueSetting.SpinBoxOnly:
		var hbox := LabelUtils.add_children_of_hbox(slider,other_node,)
		hbox.name = "SliderContainer"
		create_hbox_readout(hbox,setting)
		# Not typesafe, but it can't be typesafe otherwise exports are broken lmao
		# https://github.com/godotengine/godot/issues/91713
		var root: Node = Engine.get_singleton(&"EditorInterface").get_edited_scene_root()
		slider.set_owner(root)
		other_node.set_owner(root)
	else:
		create_hbox_readout(other_node,setting)
		slider.queue_free()

func create_bool_setting(setting: String, usage: int, hint: int, hint_string: String) -> void:
	var check := CheckBox.new()
	set_node_name(check,setting)
	check.text = get_setting_title(setting)
	check.button_pressed = ProjectSettings.get_setting(setting,false) as bool
	setup_signal_connection(check.toggled,setting)
	add_node_to_scene(check)

func set_node_name(node: Node, setting: String) -> void:
	node.name = get_setting_name(setting) if custom_name.is_empty() else custom_name

func get_setting_name(setting: String) -> String:
	return setting.split("/")[-1].to_pascal_case()

func get_setting_title(setting: String) -> String:
	return setting.split("/")[-1].capitalize()

func create_enum_setting(setting: String, type: int, usage: int, hint: int, hint_string: String) -> void:
	var dropdown: OptionButton = TextSettingOption.new() if type == TYPE_STRING else OptionButton.new()
	var options: PackedStringArray = hint_string.split(",")
	for option in options:
		dropdown.add_item(option)
	set_node_name(dropdown,setting)
	dropdown.selected = ProjectSettings.get_setting(setting,-1) as int
	dropdown.allow_reselect = true
	if type == TYPE_STRING:
		setup_signal_connection((dropdown as TextSettingOption).string_selected,setting)
	else:
		setup_signal_connection(dropdown.item_selected,setting)
	create_hbox_readout(dropdown,setting)

const LabelUtils = preload("res://utils/label_utils.gd")
func create_hbox_readout(item: Control, setting: String) -> void:
	var label := Label.new()
	apply_theme(label)
	label.name = item.name+"Label"
	label.text = get_setting_title(setting)
	var hbox := LabelUtils.add_children_of_hbox(label,item)
	hbox.name = item.name+"Container"
	add_node_to_scene(hbox)

func apply_theme(node: Control) -> void:
	if custom_theme:
		node.theme = custom_theme
	elif theme:
		node.theme = theme

func add_node_to_scene(node: Node) -> void:
	if node is Control:
		apply_theme(node as Control)
	#var nodes := EditorInterface.get_selection().get_selected_nodes()
	#if nodes.is_empty():
		#add_child(node)
	#else:
		#nodes[0].add_child(node)
	if selected_node and selected_node.owner == self:
		selected_node.add_child(node,true)
	else:
		add_child(node,true)
	# Not typesafe, but it can't be typesafe otherwise exports are broken lmao
	# https://github.com/godotengine/godot/issues/91713
	var root: Node = Engine.get_singleton(&"EditorInterface").get_edited_scene_root()
	node.set_owner(root)
	for child in node.get_children():
		child.set_owner(root)

func change_setting(value: Variant, setting: String) -> void:
	ProjectSettings.set_setting(setting,value)

func setup_signal_connection(sig: Signal, setting: String) -> void:
	sig.connect(change_setting.bind(setting),CONNECT_PERSIST)

@export_group("Customize Setting Metadata")
@export var setting_to_modify: String
@export var modify_as: ModifySettings
@export_tool_button("Modify Setting Metadata") var modify_setting: Callable = func() -> void:
	if setting_to_modify.is_empty():
		return printerr("Can't modify setting, since no setting was supplied")
	elif not project_settings.has(setting_to_modify):
		return printerr("Can't modify setting %s, since no setting exists. Maybe try reloading project settings?"%setting_to_modify)
	var setting: Dictionary = project_settings[setting_to_modify]
	match setting.type:
		TYPE_INT:
			if modify_as == ModifySettings.ModifyRange:
				modify_range(setting)
			else:
				modify_enum(setting)
		TYPE_FLOAT:
			if modify_as == ModifySettings.ModifyEnum:
				return printerr("Can't make a float into an enum. Change modify_as to Modify Range.")
			else:
				modify_range(setting)
		TYPE_STRING:
			if modify_as == ModifySettings.ModifyRange:
				return printerr("Can't make a string into a range. Change modify_as to ModifyEnum.")
			else:
				modify_enum(setting)
		_:
			return printerr("Setting %s has invalid type %s. Must be a float or an int."%[setting_to_modify,type_string(setting.type as int)])
	print("Modified setting %s metadata.\nHint is now: %s\nHint string is now: %s"%[setting_to_modify,setting.hint,setting.hint_string])
	ProjectSettings.add_property_info(setting)

@export_tool_button("Remove Setting Metadata") var remove_setting_metadata: Callable = func() -> void:
	if setting_to_modify.is_empty():
		return printerr("Can't modify setting, since no setting was supplied")
	elif not project_settings.has(setting_to_modify):
		return printerr("Can't modify setting %s, since no setting exists. Maybe try reloading project settings?"%setting_to_modify)
	var setting: Dictionary = project_settings[setting_to_modify]
	setting.erase("hint")
	setting.erase("hint_string")

@export_tool_button("Create 0-1 Range") var create_0_1_range: Callable = func() -> void:
	min_val = 0
	max_val = 1
	step = 0
	allow_greater = false
	allow_lesser = false
	exp_edit = false
	radians_as_degrees = false
	modify_setting.call()

func modify_range(setting: Dictionary) -> void:
	setting.hint = PROPERTY_HINT_RANGE
	var string := "%s,%s"%[min_val,max_val]
	if step == 0.:
		if setting.type == TYPE_INT:
			string += ",1"
	else:
		string += ",%s"%step
	if allow_greater: string += ",or_greater"
	if allow_lesser: string += ",or_less"
	if exp_edit: string += ",exp"
	if radians_as_degrees: string += ",radians_as_degrees"
	setting.hint_string = string

func modify_enum(setting: Dictionary) -> void:
	setting.hint = PROPERTY_HINT_ENUM
	setting.hint_string = enum_names

func modify_enum_suggestion(setting: Dictionary) -> void:
	setting.hint = PROPERTY_HINT_ENUM_SUGGESTION
	setting.hint_string = enum_names

enum ModifySettings {
	ModifyRange,
	ModifyEnum
}

@export_subgroup("Range Options")
@export var min_val: float
@export var max_val: float
@export var step: float
@export var allow_greater: bool
@export var allow_lesser: bool
@export var exp_edit: bool
@export var radians_as_degrees: bool
@export_subgroup("Enum Options")
@export var enum_names: String

@export_group("Fix old")
@export_tool_button("Fix int enums") var fix_int_enums: Callable = func() -> void:
	fix_int_enums_function_lmao(self)

# The tool button thing doesnt call itself cuz i dont wanna ctrl+shift+q after i didnt give the function a name. its an anonymous lambda lmaoooo
func fix_int_enums_function_lmao(node: Node) -> void:
	if node is OptionButton:
		if not node is TextSettingOption:
			figure_out_required_type(node)
	for child in node.get_children():
		fix_int_enums_function_lmao(child)
