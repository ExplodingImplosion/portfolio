@tool
extends EditorScript

const paths: PackedStringArray = [
	"res://network/multiplayer/property.gd",
	"res://network/multiplayer/networked_node.gd",
	"res://gameplay/serializer.gd",
	"res://network/multiplayer/quack_multiplayer.gd",
	#"res://utils/stream_peer_bit_buffer.gd"
]

const banned_filenames_lmao: Dictionary[String,Variant] = {
	"Network": null,
	"ServerBrowser": null,
	"WindowUtils": null,
	"Splitscreen": null,
	"SplitscreenViewport": null,
	#"MultiplayerLevel": null,
	"ConsoleCommands": null,
	#"MultiplayerSession": null,
	#"Team": null,
	"Sesh": null,
	#"Client": null,
	#"Player": null,
	"LagFaker": null,
	"Quack": null,
	"Fuckup": null,
	"Replay": null,
	"NetDebug": null,
	"PlayerCharacter": null,
	"Net": null,
	"ConnectivityTester": null,
	"StreamPeerBitBuffer": null,
}

func _run() -> void:
	var exclusions: Dictionary[GDScript,Variant] = {}
	var script: GDScript
	for path in paths:
		script = load(path) as GDScript
		if not exclusions.has(script):
			parse_script(script, path.get_file().get_basename(),exclusions)

func parse_script(script: GDScript, filename: String, exclusions: Dictionary[GDScript,Variant] = {}) -> void:
	exclusions[script] = null
	var snake_case_filename := filename.to_snake_case()
	var pascal_case_filename := filename.to_pascal_case()
	var cpp_path := "res://cpp_gen/"+snake_case_filename+".cpp"
	var h_path := "res://cpp_gen/"+snake_case_filename+".h"
	var cpp_file := FileAccess.open(cpp_path,FileAccess.WRITE)
	var h_file := FileAccess.open(h_path,FileAccess.WRITE)
	var cpp_src := ""
	var cpp_header := "#include %s.h"%snake_case_filename
	var cpp_bind_methods := ""
	var h_src: String = "class %s: public %s {\n%s\npublic:\n[props][methods]};"%[
		pascal_case_filename,
		script.get_instance_base_type(),
		get_gdclass_declaration(pascal_case_filename,script.get_instance_base_type())
	]
	var h_header := ""
	var h_footer := ""
	var h_props := ""
	var h_methods := ""
	var generic_cpp_function_body := get_cpp_function_body()
	for method in script.get_script_method_list():
		#prints(filename,method.name)
		#if method.default_args.size() > 0:
			#prints(filename,method,"has default args",method.default_args)
		var args: Array[Argument] = Argument.get_args(method.args)
		var cpp_declaration := get_cpp_function_declaration(pascal_case_filename,flags_to_string(method.flags) + Argument.get_return_type(method.return),method.name,args)
		var h_declaration := get_cpp_function_declaration("",flags_to_string(method.flags,true) + Argument.get_return_type(method.return),method.name,args)
		cpp_src += cpp_declaration+generic_cpp_function_body+"\n"
		h_methods += h_declaration+";\n"
		var arg_names: PackedStringArray; arg_names.resize(args.size())
		for i in args.size(): arg_names[i] = args[i].name
		cpp_bind_methods += get_method_bind_declaration(pascal_case_filename,method.name,arg_names, method.flags & METHOD_FLAG_STATIC)+"\n"
		#print(declaration+"\n")
	for property in script.get_script_property_list():
		# This tends to be the script itself
		if property.type == TYPE_NIL:
			print("Skipping property %s in script %s (usage %s)"%[property.name,filename,property.usage])
			continue
		# This is the point where i regret naming it this
		var arg := Argument.new(property)
		h_props += str(arg,";\n")
		h_methods += get_property_getter("",arg)+";\n"+get_property_setter("",arg)+";\n"
		cpp_src += get_property_getter(pascal_case_filename,arg)+generic_cpp_function_body+"\n"+get_property_setter(pascal_case_filename,arg)+generic_cpp_function_body+"\n"
		cpp_bind_methods += get_property_bind_declaration(pascal_case_filename,arg) + "\n"
	var constant: Variant
	var cmap := script.get_script_constant_map()
	for cname in cmap:
		constant = script[cname]
		if constant is GDScript:
			h_header += "#include %s.h\n"%(cname as String).to_snake_case()
			if not exclusions.has(constant) and not banned_filenames_lmao.has(cname):
				prints(filename,"is loading",cname)
				parse_script(constant,cname,exclusions)
		elif constant is Dictionary:
			var casted := constant as Dictionary
			var valid_enum: bool = true
			for key in casted.keys():
				if not key is String:
					valid_enum = false; break
				if not casted[key] is int:
					valid_enum = false; break
			if valid_enum:
				h_props += get_enum_declaration(casted,cname)+"\n"
				cpp_bind_methods += get_enum_bind_declaration(casted)+"\n"
				h_footer += get_enum_variant_cast_declaration(pascal_case_filename,cname)+"\n"
		else:
			h_props += get_const_declaration(
				# Forgive me for my sins against readability
				Argument.get_return_type(
					{
						"type": typeof(constant),
						"class_name": "" if not constant is Object else constant.get_class()
					}
				),
				cname,
				str(constant)
			)+"\n"
	for sig in script.get_script_signal_list():
		cpp_bind_methods += get_cpp_signal_declaration(sig.name,Argument.get_args(sig.args))+"\n"
	
	h_src = h_header + "\n" + h_src.replacen("[props]",h_props).replacen("[methods]",h_methods) + "\n" + h_footer
	cpp_src = cpp_header + "\n" + cpp_src + ("%s{\n[methods]}"%get_cpp_function_declaration("","void","%s::_bind_methods"%pascal_case_filename,[])).replacen("[methods]",cpp_bind_methods)
	
	cpp_file.store_string(cpp_src)
	h_file.store_string(h_src)
	
	cpp_file.flush()
	cpp_file.close()
	
	h_file.flush()
	h_file.close()

func get_const_declaration(type: String, name: String, value: String) -> String:
	return "const %s %s = %s;"%[type,name,value]

func get_method_bind_declaration(classname: String, method_name: String, args: PackedStringArray, is_static: bool) -> String:
	for i in args.size():
		args[i] = '"%s"'%args[i]
	if is_static:
		return 'ClassDB::bind_static_method("%s", D_METHOD("%s"%s), &%s::%s);'%[
			classname, method_name,", " + ", ".join(args) if not args.is_empty() else "",classname,method_name
		]
	else:
		return 'ClassDB::bind_method(D_METHOD("%s"%s), &%s::%s);'%[
			method_name,", " + ", ".join(args) if not args.is_empty() else "",classname,method_name
		]

func get_property_bind_declaration(classname: String, property: Argument) -> String:
	return '%s\n%s\nADD_PROPERTY(%s, "set_%s," "get_%s"); // unfinished and u should prolly change this'%[
		get_method_bind_declaration(classname,"set_%s"%property.name,["value"],false),
		get_method_bind_declaration(classname,"get_%s"%property.name,[],false),
		property.get_property_info(property.hint),
		property.name,
		property.name
	]

func get_property_getter(class_type: String, property: Argument) -> String:
	return get_cpp_function_declaration(class_type,property.type,"get_%s"%property.name,[],true)

func get_property_setter(class_type: String, property: Argument) -> String:
	return get_cpp_function_declaration(class_type,property.type,"set_%s"%property.name,[property],true)

func get_enum_variant_cast_declaration(classname: String, enum_name: String) -> String:
	return "VARIANT_ENUM_CAST(%s::%s);"%[classname,enum_name]

func get_enum_bind_declaration(enumeration: Dictionary, num_indents: int = 0, indent_string := "\t") -> String:
	var string := ""
	var indents := indent_string.repeat(num_indents)
	for name in enumeration.keys():
		string += indents+"BIND_ENUM_CONSTANT(%s);\n"%name
	return string

func get_enum_declaration(enumeration: Dictionary, enum_name: String) -> String:
	var string := "enum %s {\n[enum]};"%enum_name
	var body := ""
	for key in enumeration.keys():
		body += "%s = %s,\n"%[key,enumeration[key]]
	return string.replacen("[enum]",body)

func get_gdclass_declaration(type: String, base_type: String) -> String:
	return "GDCLASS(%s, %s);"%[type,base_type]

func flags_to_string(flags: MethodFlags, header := false) -> String:
	var string := ""
	if flags & METHOD_FLAG_CONST:
		string += "const "
	if flags & METHOD_FLAG_STATIC and header:
		string += "static "
	if flags & METHOD_FLAG_VIRTUAL:
		string += "virtual "
	return string

# This has been mangled over time lmfao
func get_cpp_function_declaration(class_type: String, type: String, func_name: String, args: Array[Argument], p_override := false) -> String:
	var args_strings: PackedStringArray; args_strings.resize(args.size());
	# this was originally just filling args strings but is now incredibly unholy
	for i in args.size(): args[i].name = "p_"+args[i].name if p_override else args[i].name; args_strings[i] = str(args[i]); args[i].name = args[i].name.substr(2) if p_override else args[i].name
	var args_string := ", ".join(args_strings)
	return "%s %s%s(%s)"%[
		type,"%s::"%class_type if not class_type.is_empty() else "",func_name,args_string
	]

func get_cpp_signal_declaration(name: String, args: Array[Argument]) -> String:
	var args_p_info: PackedStringArray; args_p_info.resize(args.size())
	for i in args.size():
		args_p_info[i] = args[i].get_property_info()
	return 'ADD_SIGNAL(MethodInfo("%s", %s));'%[
		name,", ".join(args_p_info)
	]

func get_cpp_function_body(indent_count: int = 0, indent_string := "\t") -> String:
	var min_indent := indent_string.repeat(indent_count)
	var next_indent := indent_string.repeat(indent_count + 1)
	return " {\n%s\n%s}"%[next_indent,min_indent]

class Argument:
	
	static func get_args(array: Array[Dictionary]) -> Array[Argument]:
		var args: Array[Argument]; args.resize(array.size())
		for i in args.size(): args[i] = Argument.new(array[i] as Dictionary)
		return args
	
	var name: String; var type: String; var type_int: Variant.Type
	# For complex property info
	var hint: PropertyHint; var hint_string: String; var usage: PropertyUsageFlags;
	func _init(dict: Dictionary) -> void:
		name = dict.name as String; type = Argument.get_return_type(dict); type_int = dict.type
		# For complex property info
		hint = dict.hint; hint_string = dict.hint_string; usage = dict.usage
	
	func _to_string() -> String:
		return "%s %s"%[type,name]
	
	func get_property_info(complex: bool = false) -> String:
		return 'PropertyInfo(Variant::%s, "%s"%s)'%[
			type.to_snake_case().to_upper() if type_int != TYPE_OBJECT else "OBJECT",name,
			', %s, "%s", %s'%[hint,hint_string,usage] if complex else ""
		]

	static func get_return_type(dict: Dictionary) -> String:
		match dict.type:
			TYPE_NIL:
				return "void"
			TYPE_OBJECT:
				return (dict.class_name as String).get_file().to_pascal_case()
			TYPE_INT:
				return "int"
			TYPE_FLOAT:
				return "float"
			TYPE_BOOL:
				return "bool"
			TYPE_STRING:
				return "String"
			TYPE_VECTOR2:
				return "Vector2"
			TYPE_VECTOR2I:
				return "Vector2i"
			TYPE_RECT2:
				return "Rect2"
			TYPE_RECT2I:
				return "Rect2i"
			TYPE_VECTOR3:
				return "Vector3"
			TYPE_VECTOR3I:
				return "Vector3i"
			TYPE_TRANSFORM2D:
				return "Transform2d"
			TYPE_VECTOR4:
				return "Vector4"
			TYPE_VECTOR4I:
				return "Vector4i"
			TYPE_PLANE:
				return "Plane"
			TYPE_QUATERNION:
				return "Quaternion"
			TYPE_BASIS:
				return "Basis"
			TYPE_TRANSFORM3D:
				return "Transform3d"
			TYPE_PROJECTION:
				return "Projection"
			TYPE_COLOR:
				return "Color"
			TYPE_STRING_NAME:
				return "StringName"
			TYPE_NODE_PATH:
				return "NodePath"
			TYPE_RID:
				return "Rid"
			TYPE_CALLABLE:
				return "Callable"
			TYPE_SIGNAL:
				return "Signal"
			TYPE_DICTIONARY:
				return "Dictionary"
			TYPE_ARRAY:
				return "Array"
			TYPE_PACKED_BYTE_ARRAY:
				return "PackedByteArray"
			TYPE_PACKED_INT32_ARRAY:
				return "PackedInt32Array"
			TYPE_PACKED_INT64_ARRAY:
				return "PackedInt64Array"
			TYPE_PACKED_FLOAT32_ARRAY:
				return "PackedFloat32Array"
			TYPE_PACKED_FLOAT64_ARRAY:
				return "PackedFloat64Array"
			TYPE_PACKED_STRING_ARRAY:
				return "PackedStringArray"
			TYPE_PACKED_VECTOR2_ARRAY:
				return "PackedVector2Array"
			TYPE_PACKED_VECTOR3_ARRAY:
				return "PackedVector3Array"
			TYPE_PACKED_COLOR_ARRAY:
				return "PackedColorArray"
			TYPE_PACKED_VECTOR4_ARRAY:
				return "PackedVector4Array"
			TYPE_MAX:
				return "What the fuck"
			_:
				return "What the fuuuuck lmao"
