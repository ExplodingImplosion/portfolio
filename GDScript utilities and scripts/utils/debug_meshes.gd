static func add_debug_boxmesh(transform: Transform3D, time: float = 3., custom_extents := Vector3(.05,.05,.05)) -> void:
	var bm := BoxMesh.new()
	bm.size = custom_extents
	spawn_debug_mesh(bm,transform,time)

static var raycast_debug_mesh: StandardMaterial3D = (func() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.set_shading_mode(BaseMaterial3D.SHADING_MODE_UNSHADED)
	mat.set_flag(BaseMaterial3D.FLAG_DISABLE_FOG,true)
	mat.set_cull_mode(BaseMaterial3D.CULL_DISABLED)
	mat.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
	mat.set_albedo(Color.GREEN)
	return mat).call() as StandardMaterial3D

static var raycast_colliding_debug_mesh: StandardMaterial3D = (func() -> StandardMaterial3D:
	var mat := raycast_debug_mesh.duplicate()
	mat.set_albedo(Color.RED)
	return mat).call() as StandardMaterial3D

static func spawn_debug_raycast_mesh(raycast: RayCast3D, time: float = 3.) -> MeshInstance3D: # time: float = Quack.Settings.get_setting_safe("quack/debug/collision_shape_default_time",3.) as float
	var mesh := ArrayMesh.new()
	var verts: PackedVector3Array = [Vector3.ZERO,raycast.target_position]
	var array: Array
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,array)
	mesh.surface_set_material(0,raycast_colliding_debug_mesh if raycast.is_colliding() else raycast_debug_mesh)
	return spawn_debug_mesh(mesh,raycast.global_transform,time)

static func draw_line(start: Vector3, end: Vector3, lifetime: float, color := Color.PURPLE) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var mat := StandardMaterial3D.new()
	mat.set_shading_mode(BaseMaterial3D.SHADING_MODE_UNSHADED)
	mat.set_flag(BaseMaterial3D.FLAG_DISABLE_FOG,true)
	mat.set_cull_mode(BaseMaterial3D.CULL_DISABLED)
	mat.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
	mat.set_albedo(color)
	var verts: PackedVector3Array = [start,end]
	var array: Array
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,array)
	mesh.surface_set_material(0,mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	Quack.get_current_scene().add_child(node)
	node.add_to_group(&"Debug Collision Shapes")
	Quack.tree.create_timer(lifetime,true,true,false).timeout.connect(node.queue_free,CONNECT_ONE_SHOT)
	return node

static func spawn_debug_mesh(mesh: Mesh, transform: Transform3D, time: float = 3.) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.ready.connect(node.set_global_transform.bind(transform))
	Quack.get_current_scene().add_child(node)
	node.add_to_group(&"Debug Collision Shapes")
	# BUG: for some fucking reason this last arg in create_timer, which supposedly
	# ignores timescale makes this timer take way fucking longer. FIXME! It should
	# ignore timescale, but for now I'm setting it so that it doesn't.
	Quack.tree.create_timer(time,true,true,false).timeout.connect(node.queue_free,CONNECT_ONE_SHOT)
	return node

static func can_add_debug_mesh() -> bool:
	return Quack.Settings.get_setting_safe("quack/debug/show_collisions",false)

static func can_add_debug_ray() -> bool:
	return Quack.Settings.get_setting_safe("quack/debug/show_rays",false)

const DEFAULT_DEBUG_COLLISION_COLOR = Color("0099b36b")
const DEFAULT_DEBUG_COLLISION_VERTEX_COLOR = Color(0.0, 0.6, 0.698, 0.0235)

static func spawn_colldier_debug_mesh(collider: CollisionShape3D, time: float = Quack.Settings.get_setting_safe("quack/debug/collision_shape_default_time",3.) as float) -> MeshInstance3D:
	 # Scenetreetimers in physics frames are bugged and assume that it's the
	# default tickrate or whatever. this might cause issues if the game ever
	# launches with a non 60hz physics framerate.
	var mesh := collider.shape.get_debug_mesh()
	return spawn_debug_mesh(mesh,collider.global_transform,time)# / (60. / Engine.physics_ticks_per_second))

static func spawn_recolored_debug_mesh(mesh: Mesh, color: Color, transform: Transform3D, time: float) -> MeshInstance3D:
	mesh = mesh.duplicate()
	var mdt := MeshDataTool.new()
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) == Mesh.PrimitiveType.PRIMITIVE_TRIANGLES:
			@warning_ignore("confusable_local_declaration")
			var err := mdt.create_from_surface(mesh,surface)
			if err != OK:
				Console.push_err("Editing surface %s of mesh %s with color %s returned error %s upon creating from surface."%[
					surface,mesh,color,error_string(err)
				])
				continue
			#await Quack.await_physics_frame(mdt.create_from_surface.bind(mesh,surface))
			mesh.surface_remove(surface)
		else:
			pass
			# TODO actually apply color
	#var task := WorkerThreadPool.add_group_task(mdt.set_vetex_color.bind(color),mdt.get_vertex_count(),-1,true,)
	for vertex in mdt.get_vertex_count():
		mdt.set_vertex_color(vertex,color)
	var err := mdt.commit_to_surface(mesh)
	if err != OK:
		Console.push_err("Editing mesh %s with color %s returned error %s upon committing to surface."%[
			mesh,color,error_string(err)
		])
	return spawn_debug_mesh(mesh,transform,time)

static func spawn_recolored_colldier_debug_mesh(collider: CollisionShape3D, color: Color = DEFAULT_DEBUG_COLLISION_VERTEX_COLOR, time: float = Quack.Settings.get_setting_safe("quack/debug/collision_shape_default_time",3.) as float) -> MeshInstance3D:
	return spawn_recolored_debug_mesh(collider.shape.get_debug_mesh(),color,collider.global_transform,time)

static func spawn_debug_mesh_child(collider: CollisionShape3D, interp: bool = false) -> void:
	Stupid4pt5Mesh.new(collider,interp)

class Stupid4pt5Mesh extends MeshInstance3D:
	var parent_collider: CollisionShape3D
	func _init(collider: CollisionShape3D, interp := false) -> void:
		mesh = collider.shape.get_debug_mesh()
		parent_collider = collider
		if interp:
			physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		else:
			physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			top_level = true
		process_mode = Node.PROCESS_MODE_PAUSABLE
		collider.add_child(self)
	
	func _physics_process(_delta: float) -> void:
		if top_level:
			update_transform.call_deferred()
	
	func update_transform() -> void:
		global_transform = parent_collider.global_transform

static var impact_mesh: ArrayMesh = (func() -> ArrayMesh:
	var sphere := SphereShape3D.new()
	sphere.radius = .05
	return sphere.get_debug_mesh()).call() as ArrayMesh
