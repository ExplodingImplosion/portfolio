extends CenterContainer

const APIs := preload("res://apis.gd")
const Order := preload("res://order.gd")
const Requester := preload("requester.gd")
const Output := preload("res://output.gd")
const MainServer := preload("res://main_server.gd")
const ServerNode := preload("res://server_node.gd")
const Communicator := preload("res://Communicator.gd")
const DemosTFParser := preload("res://demostf_parser.gd")

@onready var tree: SceneTree = get_tree()
@onready var root: Window = get_tree().get_root()
@onready var requester := $"api_requester" as Requester
@onready var file_location_selector := $"file_location_selector" as FileDialog

var last_time_sent: int
const send_interval = 500010
const initial_sends = 40
var initial_sends_sent: int

var processor_count := OS.get_processor_count()
var active_tasks: Array[Task]

class Task:
	var id: int
	var demo_name: String
	
	func _init(_id: int, _demo_name: String) -> void:
		id = _id
		demo_name = _demo_name

func oprintv(variant: Variant) -> void:
	oprint(str(variant))

func bruh(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var json := JSON.new()
	var err := json.parse(body.get_string_from_utf8())
	if err == OK:
		requester.oprint_dictionary(json.get_data() as Dictionary)

func hash_dict() -> void:
	oprintv((JSON.parse_string(requester.most_recent_body_string) as Dictionary).hash())

func is_main_server() -> bool:
	return OS.get_unique_id() == MAIN_SERVER_ID

const EXISTING_DEMO_IDS_FILEPATH = "existing_demo_ids.lmao"
var existing_demo_ids_file: FileAccess
var communicator: Communicator
func _ready() -> void:
	tree.process_frame.connect(output.try_oprint_on_frame)
	root.set_disable_3d(true)
	root.size_changed.connect(resize_elements)
	if OS.get_unique_id() == MAIN_SERVER_ID:
		communicator = Communicator.new(
			Communicator.default_interval_usec,
			Communicator.default_deletion_threshold_usec,
			[],[], # Don't start with any servers to ping, since they'll be populated
		)
		MainServer.setup(communicator)
	else:
		communicator = Communicator.new(
			Communicator.default_interval_usec * 6,
			Communicator.default_deletion_threshold_usec,
			[Communicator.main_server_ip],
			[Communicator.main_server_port],
			)
		ServerNode.setup(communicator)
	
	open_files()
	
	execute_args()

func open_files() -> void:
	existing_demo_ids_file = FileAccess.open(EXISTING_DEMO_IDS_FILEPATH,get_open_mode(EXISTING_DEMO_IDS_FILEPATH))
	oprint("Existing demos database status: %s"%error_string(FileAccess.get_open_error()))
	converted = FileAccess.open(CONVERTED_FILEPATH,get_open_mode(CONVERTED_FILEPATH))
	oprint("Converted demos database status: %s"%error_string(FileAccess.get_open_error()))
	results = FileAccess.open(RESULTS_FILEPATH,get_open_mode(RESULTS_FILEPATH))
	oprint("Results database status: %s"%error_string(FileAccess.get_open_error()))
	if results.get_length() == 0:
		results.store_csv_line(this_header)
		results.flush()

const this_header = MatchData.new_csv_header_4

func execute_args() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if args.has("poll_demostf"):
		poll_demostf_api()
	if args.has("parse_local_demos"):
		start_parsing()
	if args.has("convert_to_csv_always"):
		start_converting()

var parsing: bool
func start_parsing() -> void:
	parsing = toggle_frame_connection(parsing,try_parse_demos)

func toggle_frame_connection(is_connected: bool, method: Callable) -> bool:
	if is_connected:
		tree.physics_frame.disconnect(method)
	else:
		tree.physics_frame.connect(method)
	return !method

var converting: bool
func start_converting() -> void:
	converting = toggle_frame_connection(converting,try_convert_to_data)

const pages = 999
func poll_demostf_api() -> void:
	for i in pages:
		requester.await_func_on_request(parse_demostf_api,"https://api.demos.tf/demos/?page=%s?type=6v6"%(i+1))
		await demos_parsed

static func get_open_mode(path: String) -> FileAccess.ModeFlags:
	return FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ

var local_demo_parsing_finished := true
func parse_local_demos() -> void:
	if !local_demo_parsing_finished:
		return
	local_demo_parsing_finished = false
	var parsed_demos := DirAccess.get_files_at("parsed")
	convert_to_basename(parsed_demos)
	var idx: int
	var demos := DirAccess.get_files_at("demos")
	for demo in demos:
		var basename := demo.get_basename()
		if !parsed_demos.has(basename):
			oprint("Parsing demo %s --> %s on CPU %s (%s)."%[demo,basename+".txt",idx,as_hex(1<<idx)])
			thread_task(parse_demo.bind(idx,"demos/%s"%demo,"parsed/%s"%(basename+".txt")))
			idx = wrapi(idx + 1,0,processor_count)
		else:
			oprintverb("Demo %s already parsed."%demo)
	local_demo_parsing_finished = true

var thread_ids: PackedInt64Array
func thread_task(task: Callable, high: bool = false) -> void:
	var id := WorkerThreadPool.add_task(task,high)
	thread_ids.append(id)
	oprint.call_deferred("Threading %s, %stask ID %s."%[task.get_method(),"high priority " if high else "",id])

var blocking_thread_ids: PackedInt64Array
func thread_blocking_task(task: Callable, high: bool = false) -> void:
	var id := WorkerThreadPool.add_task(task,high)
	blocking_thread_ids.append(id)
	#oprint.call_deferred("Threading %s which will block csv writing, %stask ID %s."%[task.get_method(),"high priority " if high else "",id])

func is_demo_local(id: int) -> bool:
	return lmaofile_has(existing_demo_ids_file,id)

static func lmaofile_has(file: FileAccess, id: int) -> bool:
	file.seek(0)
	while file.get_position() < file.get_length():
		if id == file.get_32():
			return true
	file.seek(0)
	return false

func is_demo_converted(id: int) -> bool:
	if !converted_cache.has(id):
		if lmaofile_has(converted,id):
			converted_cache[id] = id
			return true
		else:
			return false
	else:
		return true

func add_local_demo(id: int) -> void:
	store_id_32(existing_demo_ids_file,id,"Storing local demo")

func store_id_32(file: FileAccess, id: int, status_string: String) -> void:
	file.seek_end()
	oprint.call_deferred(status_string+" %s %s."%[id,("succeeded" if file.store_32(id) else "failed")])

func add_converted_demo(id: int) -> void:
	converted_cache[id] = id
	store_id_32(converted,id,"Marking demo as converted")

signal demos_parsed
func parse_demostf_api() -> void:
	var valid_demos: Array[Array]
	if requester.json.data == null:
		demos_parsed.emit()
		oprint("Skipping demo because json data is null.")
		return
	var json: Array[Dictionary] = Array(requester.json.data,TYPE_DICTIONARY,"",null)
	for demo in json:
		if DemosTFParser.is_valid_demo(demo):
			if !is_demo_local(demo.id as int):
				oprint("Demo %s is a valid demo!"%demo.name)
				valid_demos.append([demo.id,demo.url,demo.name])
			else:
				oprint("Demo %s already local"%(demo.id as int))
		else:
			oprint("%s is an invalid map"%demo.map)
	for i in valid_demos.size():
		var demo := valid_demos[i]
		oprint("Downloading demo %s / %s"%[i+1,valid_demos.size()])
		await download_demo(demo[0],demo[1],demo[2])
	var space_left: int = DirAccess.open(drive).get_space_left()
	oprint("%s remaining on HDD."%String.humanize_size(space_left))
	if space_left < twenty_gigs:
		for file in DirAccess.get_files_at("demos"):
			if file.get_extension() != "dem":
				continue
			var file_removal: Error = DirAccess.open("demos").remove(file)
			oprint("File removal of %s status: %s"%[file,error_string(file_removal)])
	valid_demos.clear()
	json.clear()
	demos_parsed.emit()

var drive := DirAccess.get_drive_name(DirAccess.open("").get_current_drive())

func download_demo(id: int, url: String, demo_name: String) -> bool:
	await requester.await_func_on_request(save_demo.bind("demos/%s"%demo_name,id),url)
	return true

func save_demo(path: String, id: int) -> void:
	thread_task(add_local_demo.bind(id),true)
	thread_task(save_file.bind(path,requester.most_recent_body),true)

func save_file(path: String, contents: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	oprint.call_deferred("Saving %s file to %s... error status: %s"%[String.humanize_size(contents.size()),path,error_string(FileAccess.get_open_error())])
	oprint.call_deferred("Saving demo %s."%("succeeded" if file.store_buffer(contents) else "failed"))

# These kinda over-abstract parse_demo but fuck you
const affinity_batch_path = "affinity.bat"
const get_hex = "%X"

static func as_hex(affinity: int) -> String:
	return get_hex%(affinity)

func parse_demo(affinity: int, demo_path: String, output_path: String) -> void:
	assert(affinity <= processor_count, "Affinity must be between 0 and %s!"%processor_count)
	var array := []
	var code := OS.execute(affinity_batch_path,[as_hex(1<<affinity),demo_path,output_path],array,true)
	if !is_instance_valid(self): return prints("code: %s"%(code if code != 1 else error_string(code)),(array[0] as String).replace("\\n","\n").replace("\\r",""))
	oprint.call_deferred("code: %s"%(code if code != 1 else error_string(code)))
	oprintv.call_deferred((array[0] as String).replace("\\n","\n").replace("\\r",""))

@onready var current_window_mode: Window.Mode = root.mode
func _physics_process(delta: float) -> void:
	# This is a dumb fucking hack to change the output's size appropriately if
	# someone changes the window's mode, because for some reason Godot doesn't
	# seem to have a good way to automatically detect when the window's
	# "fullscreen" mode (including maximizing / un-maximizing a window) changes.
	# So instead, this just checks if the window's fullscreen mode is different
	# every ~250ms. TODO remove this if there's ever a way to do it better!
	if Engine.get_physics_frames() % 5 == 0:
		var mode: Window.Mode = root.mode
		if mode != current_window_mode:
			resize_elements()
			current_window_mode = mode
	
	cleanup_threads()
	
	# Every minute or so
	#if Engine.get_physics_frames() % 1200 == 0:
		#if OS.get_memory_info().free < one_gig:
			#pass # time to panic! less than a gig left

const six_sec_phys_frames = 120

func cleanup_threads() -> void:
	if Engine.get_physics_frames() % six_sec_phys_frames == 0:
		for id in thread_ids:
				if WorkerThreadPool.is_task_completed(id):
					var err := WorkerThreadPool.wait_for_task_completion(id)
					oprintverb("Waiting for task %s completion returned %s."%[id,error_string(err)])
					thread_ids.remove_at(thread_ids.find(id))

func cleanup_blocking_threads() -> void:
	while !blocking_thread_ids.is_empty():
		for id in blocking_thread_ids:
			if WorkerThreadPool.is_task_completed(id):
				var err := WorkerThreadPool.wait_for_task_completion(id)
				oprintverb.call_deferred("Waiting for blocking task %s completion returned %s."%[id,error_string(err)])
				blocking_thread_ids.remove_at(blocking_thread_ids.find(id))

func try_parse_demos() -> void:
	if Engine.get_physics_frames() % six_sec_phys_frames == 3:
		parse_local_demos()

func thread_data_conversion() -> void:
	thread_task(convert_to_data,false)

func try_convert_to_data() -> void:
	if Engine.get_physics_frames() % six_sec_phys_frames == 5:
		thread_data_conversion()

const CONVERTED_FILEPATH = "converted.lmao"
const RESULTS_FILEPATH = "results_v12.csv"
var converted: FileAccess
var converted_cache: Dictionary[int,int]
var results: FileAccess
func convert_to_csv() -> void:
	results.seek_end()
	var pos: int = results.get_position()
	var hashes: PackedInt32Array
	var keys := data_map.keys()
	for string:String in keys:
		hashes.append((string as String).hash())
	var collision: bool
	for hash in hashes:
		if hashes.count(hash) > 1:
			collision = true
	if collision:
		oprint.call_deferred("OH FUCK! HASH COLLISION!")
	
	var id: int 
	var idx: int = -1
	var size := data_map.size()
	for data:MatchData in data_map.values():
		idx += 1
		oprint.call_deferred("%s / %s"%[idx,size])
		id = (keys[idx] as String).hash()
		if is_demo_converted(id):
			oprintverb.call_deferred("Match %s already converted."%keys[idx])
			continue
		if data == null:
			oprint.call_deferred("Match %s is null."%keys[idx])
			add_converted_demo(id)
			continue
		
		assert(id == data.filename.hash())
		assert(keys[idx] == data.filename)
		
		if !data.is_valid_data():
			oprint.call_deferred("Match %s is invalid data!\n%s"%[data.filename,data.get_validation_error_string()])
			oprint.call_deferred("Because of invalid data, marking this as converted.")
			add_converted_demo(id)
			continue
		
		add_converted_demo(id)
		oprint.call_deferred("Storing demo %s to csv."%id)
		#for line in data.to_csv_lines():
		#for line in data.to_csv_line_2():
		#for line in data.to_csv_lines_2():
		for line in data.to_csv_lines_4():
			results.store_csv_line(line)
		#results.store_csv_line(data.to_csv_line())
	
	if pos == results.get_position():
		for key:String in data_map.keys():
			data_map[key] = null
		data_conversions_finished = true
		return
	defer_csv_conversion_finish.call_deferred()

func get_func_time(method: Callable, include_stack: bool = false) -> Variant:
	var t1: int
	var t2: int
	var to_return: Variant
	t1 = Time.get_ticks_usec()
	to_return = method.call()
	t2 = Time.get_ticks_usec()
	oprint.call_deferred("Function %s took %sms"%[method.get_method(),(float(t2-t1)/1_000_000.) * 1_000.])
	if include_stack:
		for dict:Dictionary in get_stack():
			output.oprint_dictionary(dict)
	return to_return

func defer_csv_conversion_finish() -> void:
	results.flush()
	for key:String in data_map.keys():
		data_map[key] = null
	
	data_conversions_finished = true

const csv_header: PackedStringArray = [
	"filename",
	"id",
	"team",
	"other_on_last_count",
	"other_off_last_count",
	"points_count",
	"sac_count",
	"sniper_count",
	"spy_count",
	"other_med_deaths_on_last",
	"match_outcome"
	]

class MatchData:
	var filename: String
	var id: String
	var winner: String
	var pid_list: Array
	var strats: Array
	var player_info_list: Array[PlayerInfo]
	var header: MatchHeader
	var red_on_last_ticks: PackedInt32Array
	var red_off_last_ticks: PackedInt32Array
	var red_last_capped_ticks: PackedInt32Array
	var red_sac_ticks: PackedInt32Array
	var blue_on_last_ticks: PackedInt32Array
	var blue_off_last_ticks: PackedInt32Array
	var blue_last_capped_ticks: PackedInt32Array
	var blue_sac_ticks: PackedInt32Array
	var blue_med_on_last_death_ticks: PackedInt32Array
	var red_med_on_last_death_ticks: PackedInt32Array
	var red_sniper_tick_nums: PackedInt32Array
	var red_spy_tick_nums: PackedInt32Array
	var blue_sniper_tick_nums: PackedInt32Array
	var blue_spy_tick_nums: PackedInt32Array
	
	static func capped_last(on_last_start: int, last_capped_ticks: PackedInt32Array, off_last_ticks: PackedInt32Array) -> bool:
		for last_capped_tick in last_capped_ticks:
			# Skip ticks where last was capped before the tick when a team got on last
			if last_capped_tick < on_last_start:
				continue
			assert(last_capped_tick != on_last_start)
			for off_last_tick in off_last_ticks:
				assert(off_last_tick != on_last_start)
				assert(off_last_tick != last_capped_tick)
				# If a team got off last before the next tick when last was capped,
				# and a team got off last after they got pushed to last, then the attacking
				# team didn't cap last.
				if off_last_tick < last_capped_tick and off_last_tick > on_last_start:
					return false
			# Otherwise, they did.
			return true
		return find_tick_after(on_last_start,last_capped_ticks) != -1 # If it's -1, then last wasn't capped because time ran out or some shit
	
	static func find_tick_after(starting_tick: int, tick_list: PackedInt32Array) -> int:
		for tick in tick_list:
			if tick > starting_tick:
				return tick
		return -1
	
	static func find_in_range(starting_tick: int, ending_tick: int, list: PackedInt32Array) -> PackedInt32Array:
		var return_list: PackedInt32Array = []
		for tick in list:
			if tick > starting_tick and tick < ending_tick:
				return_list.append(tick)
		return return_list
	
	const new_csv_header: PackedStringArray = [
		"filename",
		"id",
		"team_sacing",
		"on_last_tick",
		"capped_last",
		"num_sacs",
		"num_successful_sacs"
	]
	
	const new_csv_header_2: PackedStringArray = [
		"filename",
		"id",
		"team",
		"other_on_last_count",
		"other_off_last_count",
		"points_count",
		"sac_count",
		"other_med_deaths_on_last",
		"match_outcome",
		"on_last_tick",
		"capped_last",
		"num_sacs",
		"num_successful_sacs"
	]
	
	const new_csv_header_3: PackedStringArray = [
		"filename",
		"id",
		"team",
		"other_on_last_count",
		"other_off_last_count",
		"points_count",
		"sac_count",
		"sniper_count",
		"spy_count",
		"other_med_deaths_on_last",
		"match_outcome",
		"on_last_tick",
		"capped_last",
		"num_sacs",
		"played_sniper",
		"sniper_ticks",
		"played_spy",
		"spy_ticks",
		"time_on_last",
		"num_successful_sacs"
	]
	
	const new_csv_header_4: PackedStringArray = [
		"filename",
		"id",
		"team",
		"other_on_last_count",
		"other_off_last_count",
		"points_count",
		"sac_count",
		"sniper_count",
		"spy_count",
		"other_med_deaths_on_last",
		"match_outcome",
		"on_last_tick",
		"capped_last",
		"num_sacs",
		"played_sniper",
		"sniper_ticks",
		"played_spy",
		"spy_ticks",
		"time_on_last",
		"med_deaths_this_last",
		"num_successful_sacs"
	]
	
	const eight_seconds = 528
	const le_verybignumber = 9223372036854775807
	const ten_seconds = 660
	
	static func get_sac_results(on_last_start: int, end_tick: int, sac_ticks: PackedInt32Array, med_death_ticks: PackedInt32Array) -> Vector2i:
		var sacs := find_in_range(on_last_start,end_tick,sac_ticks)
		var med_deaths := find_in_range(on_last_start,end_tick,med_death_ticks)
		var num_successful_sacs: int = 0
		for sac in sacs:
			for death in med_deaths:
				# death happened after sac start, and death didn't happen way later
				if death >= sac and death - sac < eight_seconds:
					num_successful_sacs += 1
					break # skip other med deaths
		return Vector2i(sacs.size(),num_successful_sacs)
	
	static func get_sac_results_2(on_last_start: int, end_tick: int, sac_ticks: PackedInt32Array, med_death_ticks: PackedInt32Array) -> Vector3i:
		var sacs := find_in_range(on_last_start,end_tick,sac_ticks)
		var med_deaths := find_in_range(on_last_start,end_tick,med_death_ticks)
		var num_successful_sacs: int = 0
		for sac in sacs:
			for death in med_deaths:
				# death happened after sac start, and death didn't happen way later
				if death >= sac and death - sac < eight_seconds:
					num_successful_sacs += 1
					break # skip other med deaths
		return Vector3i(sacs.size(),num_successful_sacs,med_deaths.size())
	
	func get_adv_csv(team: String, on_last_tick: int, succeeded: bool, num_sacs: int, num_succeeded_sacs: int) -> PackedStringArray:
		return [filename,id,team,on_last_tick,1 if succeeded else 0,num_sacs,num_succeeded_sacs]
	
	func asdf(team: String, on_last_ticks: PackedInt32Array, off_last_ticks: PackedInt32Array, last_capped_ticks: PackedInt32Array, sac_ticks: PackedInt32Array, med_death_ticks: PackedInt32Array) -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		for on_last_start in on_last_ticks:
			var next_last_capped_tick := find_tick_after(on_last_start,last_capped_ticks)
			if next_last_capped_tick == -1:
				var sacdata := get_sac_results(on_last_start,le_verybignumber,sac_ticks,med_death_ticks)
				array.append(get_adv_csv(team,on_last_start,false,sacdata.x,sacdata.y))
				continue
			
			# If the team capped last after having gotten the other team to last this time
			if capped_last(on_last_start,last_capped_ticks,off_last_ticks):
				var capped_tick := find_tick_after(on_last_start,last_capped_ticks)
				var sacdata := get_sac_results(on_last_start,capped_tick,sac_ticks,med_death_ticks)
				array.append(get_adv_csv(team,on_last_start,true,sacdata.x,sacdata.y))
			else:
				var off_last_tick := find_tick_after(on_last_start,off_last_ticks)
				var sacdata := get_sac_results(on_last_start,off_last_tick,sac_ticks,med_death_ticks)
				array.append(get_adv_csv(team,on_last_start,false,sacdata.x,sacdata.y))
		return array
	
	func asdf_2(team: String, on_last_ticks: PackedInt32Array, off_last_ticks: PackedInt32Array, last_capped_ticks: PackedInt32Array, sac_ticks: PackedInt32Array, med_death_ticks: PackedInt32Array) -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		for on_last_start in on_last_ticks:
			var next_last_capped_tick := find_tick_after(on_last_start,last_capped_ticks)
			if next_last_capped_tick == -1:
				var sacdata := get_sac_results(on_last_start,le_verybignumber,sac_ticks,med_death_ticks)
				array.append((get_adv_csv_red if team == "red" else get_adv_csv_blue).call(on_last_start,false,sacdata.x,sacdata.y))
				continue
			
			# If the team capped last after having gotten the other team to last this time
			if capped_last(on_last_start,last_capped_ticks,off_last_ticks):
				var capped_tick := find_tick_after(on_last_start,last_capped_ticks)
				var sacdata := get_sac_results(on_last_start,capped_tick,sac_ticks,med_death_ticks)
				array.append((get_adv_csv_red if team == "red" else get_adv_csv_blue).call(on_last_start,true,sacdata.x,sacdata.y))
			else:
				var off_last_tick := find_tick_after(on_last_start,off_last_ticks)
				var sacdata := get_sac_results(on_last_start,off_last_tick,sac_ticks,med_death_ticks)
				array.append((get_adv_csv_red if team == "red" else get_adv_csv_blue).call(on_last_start,false,sacdata.x,sacdata.y))
		return array
	
	func duration_ticks() -> int:
		return header.duration * 66
	
	func asdf_3(team: String, on_last_ticks: PackedInt32Array, off_last_ticks: PackedInt32Array, last_capped_ticks: PackedInt32Array, sac_ticks: PackedInt32Array, med_death_ticks: PackedInt32Array, sniper_tick_nums: PackedInt32Array, spy_tick_nums: PackedInt32Array) -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		var i: int = -1
		for on_last_start in on_last_ticks:
			i += 1
			var next_last_capped_tick := find_tick_after(on_last_start,last_capped_ticks)
			if next_last_capped_tick == -1:
				var sacdata := get_sac_results(on_last_start,le_verybignumber,sac_ticks,med_death_ticks)
				array.append(get_adv_csv_2(to_red_csv_line() if team == "red" else to_blue_csv_line(),on_last_start,false,sacdata.x,sacdata.y,sniper_tick_nums[i],spy_tick_nums[i],duration_ticks()-on_last_start))
				continue
			
			# If the team capped last after having gotten the other team to last this time
			if capped_last(on_last_start,last_capped_ticks,off_last_ticks):
				var capped_tick := find_tick_after(on_last_start,last_capped_ticks)
				var sacdata := get_sac_results(on_last_start,capped_tick,sac_ticks,med_death_ticks)
				array.append(get_adv_csv_2(to_red_csv_line() if team == "red" else to_blue_csv_line(),on_last_start,true,sacdata.x,sacdata.y,sniper_tick_nums[i],spy_tick_nums[i],capped_tick-on_last_start))
			else:
				var off_last_tick := find_tick_after(on_last_start,off_last_ticks)
				var sacdata := get_sac_results(on_last_start,off_last_tick,sac_ticks,med_death_ticks)
				array.append(get_adv_csv_2(to_red_csv_line() if team == "red" else to_blue_csv_line(),on_last_start,false,sacdata.x,sacdata.y,sniper_tick_nums[i],spy_tick_nums[i],off_last_tick-on_last_start))
		return array
	
	func asdf_4(team: String, on_last_ticks: PackedInt32Array, off_last_ticks: PackedInt32Array, last_capped_ticks: PackedInt32Array, sac_ticks: PackedInt32Array, med_death_ticks: PackedInt32Array, sniper_tick_nums: PackedInt32Array, spy_tick_nums: PackedInt32Array) -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		var i: int = -1
		for on_last_start in on_last_ticks:
			i += 1
			var next_last_capped_tick := find_tick_after(on_last_start,last_capped_ticks)
			if next_last_capped_tick == -1:
				var sacdata := get_sac_results_2(on_last_start,le_verybignumber,sac_ticks,med_death_ticks)
				array.append(get_adv_csv_3(to_red_csv_line() if team == "red" else to_blue_csv_line(),on_last_start,false,sacdata.x,sacdata.y,sniper_tick_nums[i],spy_tick_nums[i],duration_ticks()-on_last_start,sacdata.z))
				continue
			
			# If the team capped last after having gotten the other team to last this time
			if capped_last(on_last_start,last_capped_ticks,off_last_ticks):
				var capped_tick := find_tick_after(on_last_start,last_capped_ticks)
				var sacdata := get_sac_results_2(on_last_start,capped_tick,sac_ticks,med_death_ticks)
				array.append(get_adv_csv_3(to_red_csv_line() if team == "red" else to_blue_csv_line(),on_last_start,true,sacdata.x,sacdata.y,sniper_tick_nums[i],spy_tick_nums[i],capped_tick-on_last_start,sacdata.z))
			else:
				var off_last_tick := find_tick_after(on_last_start,off_last_ticks)
				var sacdata := get_sac_results_2(on_last_start,off_last_tick,sac_ticks,med_death_ticks)
				array.append(get_adv_csv_3(to_red_csv_line() if team == "red" else to_blue_csv_line(),on_last_start,false,sacdata.x,sacdata.y,sniper_tick_nums[i],spy_tick_nums[i],off_last_tick-on_last_start,sacdata.z))
		return array
	
	func get_adv_csv_2(line: PackedStringArray, on_last_tick: int, succeeded: bool, num_sacs: int, num_succeeded_sacs: int, sniper_tick_count: int, spy_tick_count: int,time_on_last: int) -> PackedStringArray:
		return line + PackedStringArray([on_last_tick,1 if succeeded else 0,num_sacs,sniper_tick_count > ten_seconds,sniper_tick_count,spy_tick_count > ten_seconds, spy_tick_count, time_on_last, num_succeeded_sacs,])
	
	func get_adv_csv_3(line: PackedStringArray, on_last_tick: int, succeeded: bool, num_sacs: int, num_succeeded_sacs: int, sniper_tick_count: int, spy_tick_count: int,time_on_last: int,med_deaths_this_last: int) -> PackedStringArray:
		return line + PackedStringArray([on_last_tick,1 if succeeded else 0,num_sacs,sniper_tick_count > ten_seconds,sniper_tick_count,spy_tick_count > ten_seconds, spy_tick_count, time_on_last, med_deaths_this_last, num_succeeded_sacs,])
	
	func get_adv_csv_red(on_last_tick: int, succeeded: bool, num_sacs: int, num_succeeded_sacs: int) -> PackedStringArray:
		return to_red_csv_line() + PackedStringArray([on_last_tick,1 if succeeded else 0,num_sacs,num_succeeded_sacs])
	
	func get_adv_csv_blue(on_last_tick: int, succeeded: bool, num_sacs: int, num_succeeded_sacs: int) -> PackedStringArray:
		return to_blue_csv_line() + PackedStringArray([on_last_tick,1 if succeeded else 0,num_sacs,num_succeeded_sacs])
	
	func to_csv_lines_2() -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		array.append_array(asdf_2("red",blue_on_last_ticks,blue_off_last_ticks,blue_last_capped_ticks,red_sac_ticks,blue_med_on_last_death_ticks))
		array.append_array(asdf_2("blue",red_on_last_ticks,red_off_last_ticks,red_last_capped_ticks,blue_sac_ticks,red_med_on_last_death_ticks))
		
		return array
	
	func to_csv_lines_3() -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		array.append_array(asdf_3("red",blue_on_last_ticks,blue_off_last_ticks,blue_last_capped_ticks,red_sac_ticks,blue_med_on_last_death_ticks,red_sniper_tick_nums,red_spy_tick_nums))
		array.append_array(asdf_3("blue",red_on_last_ticks,red_off_last_ticks,red_last_capped_ticks,blue_sac_ticks,red_med_on_last_death_ticks,blue_sniper_tick_nums,blue_spy_tick_nums))
		
		return array
	
	func to_csv_lines_4() -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		array.append_array(asdf_4("red",blue_on_last_ticks,blue_off_last_ticks,blue_last_capped_ticks,red_sac_ticks,blue_med_on_last_death_ticks,red_sniper_tick_nums,red_spy_tick_nums))
		array.append_array(asdf_4("blue",red_on_last_ticks,red_off_last_ticks,red_last_capped_ticks,blue_sac_ticks,red_med_on_last_death_ticks,blue_sniper_tick_nums,blue_spy_tick_nums))
		
		return array
	
	func to_csv_lines() -> Array[PackedStringArray]:
		var array: Array[PackedStringArray] = []
		array.append_array(asdf("red",blue_on_last_ticks,blue_off_last_ticks,blue_last_capped_ticks,red_sac_ticks,blue_med_on_last_death_ticks))
		array.append_array(asdf("blue",red_on_last_ticks,red_off_last_ticks,red_last_capped_ticks,blue_sac_ticks,red_med_on_last_death_ticks))
		
		return array
	
	func get_count(ticks: PackedInt32Array) -> int:
		var count: int = 0
		for num in ticks:
			if num > ten_seconds:
				count += 1
		return count
	
	func to_red_csv_line() -> PackedStringArray:
		return [
			filename,
			id,
			"red",
			str(blue_on_last_ticks.size()),
			str(blue_off_last_ticks.size()),
			str(blue_last_capped_ticks.size()), # This is how many points red got, which is how many times blue's last was capped
			str(red_sac_ticks.size()),
			str(get_count(red_sniper_tick_nums)),
			str(get_count(red_spy_tick_nums)),
			str(blue_med_on_last_death_ticks.size()),
			str("win" if red_last_capped_ticks.size() < blue_last_capped_ticks.size() else "lose" if red_last_capped_ticks.size() > blue_last_capped_ticks.size() else "tie")
			]
	
	func to_blue_csv_line() -> PackedStringArray:
		return [
			filename,
			id,
			"blue",
			str(red_on_last_ticks.size()),
			str(red_off_last_ticks.size()),
			str(red_last_capped_ticks.size()), # This is how many points blue got, which is how many times red's last was capped
			str(blue_sac_ticks.size()),
			str(get_count(blue_sniper_tick_nums)),
			str(get_count(blue_spy_tick_nums)),
			str(red_med_on_last_death_ticks.size()),
			str("win" if red_last_capped_ticks.size() > blue_last_capped_ticks.size() else "lose" if red_last_capped_ticks.size() < blue_last_capped_ticks.size() else "tie")
			]
	
	func to_csv_line() -> PackedStringArray:
		return [
			filename,
			id,
			str(red_on_last_ticks.size()),
			str(red_off_last_ticks.size()),
			str(blue_last_capped_ticks.size()), # This is how many points red got, which is how many times blue's last was capped
			str(red_sac_ticks.size()),
			str(blue_on_last_ticks.size()),
			str(blue_off_last_ticks.size()),
			str(red_last_capped_ticks.size()), # This is how many points blue got, which is how many times red's last was capped
			str(blue_sac_ticks.size()),
			str(red_med_on_last_death_ticks.size()),
			str(blue_med_on_last_death_ticks.size())
			]
	
	func to_csv_line_2() -> Array[PackedStringArray]:
		return [
			to_red_csv_line(),
			to_blue_csv_line()
		]
	
	func is_valid_data() -> bool:
		return DemosTFParser.is_valid_map(header.map) and was_someone_on_last() and !has_duplicate_ticks()
	
	func get_validation_error_string() -> String:
		var string: String
		
		if !DemosTFParser.is_valid_map(header.map):
			string += "%s is an invalid map."%header.map
		if !was_someone_on_last():
			string += "\nNo one was found on last."+get_potential_problem_list_as_string()
		if has_duplicate_ticks():
			string += "\nDuplicate tick was found."+get_potential_problem_list_as_string()
		
		return string
	
	func get_potential_problem_list_as_string() -> String:
		return "\nred on last: %s\nred off last: %s\nred sacs: %s\nblue on last: %s\nblue off last: %s\nblue sacs: %s\nred last capped: %s\nblue last capped: %s"%[red_on_last_ticks,red_off_last_ticks,red_sac_ticks,blue_on_last_ticks,blue_off_last_ticks,blue_sac_ticks,red_last_capped_ticks,blue_last_capped_ticks]
	
	func was_someone_on_last() -> bool:
		return !red_on_last_ticks.is_empty() or !blue_on_last_ticks.is_empty()
	
	static func has_duplicates(array: PackedInt32Array) -> bool:
		for i in array:
			if array.count(i) > 1:
				return true
		return false
	
	func has_duplicate_ticks() -> bool:
		return (MatchData.has_duplicates(red_on_last_ticks) or
	MatchData.has_duplicates(red_off_last_ticks) or
	MatchData.has_duplicates(red_last_capped_ticks) or
	MatchData.has_duplicates(red_sac_ticks) or
	MatchData.has_duplicates(blue_on_last_ticks) or
	MatchData.has_duplicates(blue_off_last_ticks) or
	MatchData.has_duplicates(blue_last_capped_ticks) or
	MatchData.has_duplicates(blue_sac_ticks))
	
	func _init(
		filename: String,
		id: String,
		winner: String,
		pid_list: Array,
		strats: Array,
		player_info_list: Array[PlayerInfo],
		header: MatchHeader,
		red_on_last_ticks: PackedInt32Array,
		red_off_last_ticks: PackedInt32Array,
		red_last_capped_ticks: PackedInt32Array,
		red_sac_ticks: PackedInt32Array,
		blue_on_last_ticks: PackedInt32Array,
		blue_off_last_ticks: PackedInt32Array,
		blue_last_capped_ticks: PackedInt32Array,
		blue_sac_ticks: PackedInt32Array,
		blue_med_on_last_death_ticks: PackedInt32Array,
		red_med_on_last_death_ticks: PackedInt32Array,
		red_sniper_tick_nums: PackedInt32Array,
		red_spy_tick_nums: PackedInt32Array,
		blue_sniper_tick_nums: PackedInt32Array,
		blue_spy_tick_nums: PackedInt32Array,
	) -> void:
		self.filename = filename
		self.id = id
		self.winner = winner
		self.pid_list = pid_list
		self.strats = strats
		self.player_info_list = player_info_list
		self.header = header
		self.red_on_last_ticks = red_on_last_ticks
		self.red_off_last_ticks = red_off_last_ticks
		self.red_last_capped_ticks = red_last_capped_ticks
		self.red_sac_ticks = red_sac_ticks
		self.blue_on_last_ticks = blue_on_last_ticks
		self.blue_off_last_ticks = blue_off_last_ticks
		self.blue_last_capped_ticks = blue_last_capped_ticks
		self.blue_sac_ticks = blue_sac_ticks
		self.blue_med_on_last_death_ticks = blue_med_on_last_death_ticks
		self.red_med_on_last_death_ticks = red_med_on_last_death_ticks
		self.red_sniper_tick_nums = red_sniper_tick_nums
		self.red_spy_tick_nums = red_spy_tick_nums
		self.blue_sniper_tick_nums = blue_sniper_tick_nums
		self.blue_spy_tick_nums = blue_spy_tick_nums
	
	static func get_sac_ticks(array: Array[Array]) -> PackedInt32Array:
		var sac_ticks: PackedInt32Array = []
		for each in array:
			sac_ticks.append(each[1])
		return sac_ticks
	
	static func from_json(fname: String, json: Dictionary) -> MatchData:
		var red_sacs: Array[Array] = Array(json.red.sac_ticks,TYPE_ARRAY,"",null)
		var blue_sacs: Array[Array] = Array(json.blue.sac_ticks,TYPE_ARRAY,"",null)
		return MatchData.new(
			fname,
			json.id as String,
			json.winner as String,
			json.player_id_list as Array,
			json.strats as Array,
			[], # Exclude playerinfo for now
			MatchHeader.from_json(json.header as Dictionary),
			PackedInt32Array(json.red.on_last_ticks as Array),
			PackedInt32Array(json.red.off_last_ticks as Array),
			PackedInt32Array(json.red.last_capped_ticks as Array),
			get_sac_ticks(red_sacs),
			PackedInt32Array(json.blue.on_last_ticks as Array),
			PackedInt32Array(json.blue.off_last_ticks as Array),
			PackedInt32Array(json.blue.last_capped_ticks as Array),
			get_sac_ticks(blue_sacs),
			PackedInt32Array(json.blue.med_deaths_on_last as Array),
			PackedInt32Array(json.red.med_deaths_on_last as Array),
			PackedInt32Array(json.red.sniper_ticks_per_last as Array),
			PackedInt32Array(json.red.spy_ticks_per_last as Array),
			PackedInt32Array(json.blue.sniper_ticks_per_last as Array),
			PackedInt32Array(json.blue.spy_ticks_per_last as Array),
		)

class PlayerInfo:
	pass

class MatchHeader:
	var version: float
	var protocol: float
	var server_name: String
	var nickname: String
	var map: String
	var game: String
	var duration: float
	var ticks: int
	var frames: int
	var signon: int
	
	func _init(
		version: float,
		protocol: float,
		server_name: String,
		nickname: String,
		map: String,
		game: String,
		duration: float,
		ticks: int,
		frames: int,
		signon: int,
	) -> void:
		self.version = version
		self.protocol = protocol
		self.server_name = server_name
		self.nickname = nickname
		self.map = map
		self.game = game
		self.duration = duration
		self.ticks = ticks
		self.frames = frames
		self.signon = signon
	
	static func from_json(json: Dictionary) -> MatchHeader:
		return MatchHeader.new(
			json.version,
			json.protocol,
			json.server,
			json.nick,
			json.map,
			json.game,
			json.duration,
			json.ticks as int,
			json.frames as int,
			json.signon as int
		)

var data_map: Dictionary[String,MatchData]
var data_conversions_finished := true
func convert_to_data() -> void:
	if !data_conversions_finished:
		return
	data_conversions_finished = false
	var converted_data: Array[String] = Array(data_map.keys(),TYPE_STRING,"",null)
	convert_to_basename_array(converted_data)
	var thread_queue: Array[Callable]
	for demo in DirAccess.get_files_at("parsed"):
		var basename := demo.get_basename()
		if !data_map.has(demo):
			oprint.call_deferred("Converting demo %s to data."%[demo])
			thread_queue.append(add_matchdata.bind("parsed/%s"%demo))
			data_map[demo] = null
		else:
			oprintverb("Demo %s already converted."%demo)
	for thread in thread_queue:
		thread_blocking_task(thread,true)
	var num: int = thread_queue.size()
	if num > 0:
		oprint.call_deferred("Threading add matchdata %s times, will block csv from writing."%num)
	cleanup_blocking_threads()
	convert_to_csv()

func add_matchdata(parsed_path: String) -> void:
	var file := FileAccess.open(parsed_path,FileAccess.READ)
	var text := file.get_as_text()
	var json_text := text.substr(text.find("{",0))
	var json := JSON.new()
	var json_err := json.parse(json_text)
	oprint.call_deferred("%s JSON conversion status: %s."%[parsed_path,error_string(json_err)])
	if json_err != OK:
		return
	var data: Variant = json.data
	if data is Dictionary:
		var fname := parsed_path.get_file()
		data_map[fname] = MatchData.from_json(fname,data as Dictionary)
	else:
		oprint.call_deferred("What the fuck?! JSON data for %s is OK but returned %s instead of a dictionary."%[
			parsed_path,type_string(typeof(data))
		])

static func convert_to_basename_array(array: Array[String]) -> void:
	for i in array.size():
		array[i] = array[i].get_basename()

static func convert_to_basename(array: PackedStringArray) -> void:
	for i in array.size():
		array[i] = array[i].get_basename()

const one_gig = 1_000_000_000
const twenty_gigs = 20_000_000_000

@onready var panel: Panel = $formatting/output_scroller_container/Panel as Panel
func resize_elements() -> void:
	var root_size := root.size
	scroller.custom_minimum_size.y = root_size.y
	panel.custom_minimum_size.y = root_size.y
	ensure_scroller_fits()
	# Somehow this is kinda buggy and the panel disappears sometimes... wtf?
	# TODO fix this lmao
	if scroller.custom_minimum_size.x < scroller_desired_position and (root_size.x - panel.custom_minimum_size.x) > scroller.custom_minimum_size.x:
		scroller.custom_minimum_size.x = scroller_desired_position
	output.custom_minimum_size = scroller.custom_minimum_size

func ensure_scroller_fits() -> void:
	var max_panel_pos := root.size.x - panel.custom_minimum_size.x
	if scroller.custom_minimum_size.x > max_panel_pos:
		scroller.custom_minimum_size.x = max_panel_pos

const MAIN_SERVER_ID = ""

@onready var output: Output = %output as Output
func oprint(string: String) -> void:
	output.oprint(string)

func oprintverb(string: String) -> void:
	output.oprintverb(string)

func on_file_location_selector_popup() -> void:
	file_location_selector.size = root.size / 2
	file_location_selector.position = root.size / 2 - file_location_selector.size / 2


var dragging_panel: bool
@onready var scroller := $formatting/output_scroller_container/output_scroller as ScrollContainer
## This is the 'desired' width for output text. If someone makes the window too small for the
## output's full width, the output is gonna shrink to fit that size, but this assumes that they
## still would prefer the output to be this wide, given there's enough room for it.
@onready var scroller_desired_position: float = scroller.custom_minimum_size.x
func on_panel_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging_panel = event.pressed
	else:
		if event is InputEventMouseMotion:
			if dragging_panel:
				# User drags panel (potentially off-window, too)...
				scroller.custom_minimum_size.x += +event.relative.x
				# Respect their wishes. They might want it to be bigger than the
				# window allows! So save it.
				scroller_desired_position = scroller.custom_minimum_size.x
				# Make sure that output + the panel fits in the window, though.
				ensure_scroller_fits()
				# Resize the scroller appropriately.
				output.custom_minimum_size = scroller.custom_minimum_size

@onready var api_requester_buttons: Array[Button] = [
]

func lock_buttons() -> void:
	for button in api_requester_buttons:
		button.disabled = true

func unlock_buttons() -> void:
	for button in api_requester_buttons:
		button.disabled = false

func await_button_unlock(method: Callable) -> void:
	lock_buttons()
	await method.call()
	unlock_buttons()

func clear_output() -> void:
	output.clear()


func reset_converted() -> void:
	oprint("%s reset!"%CONVERTED_FILEPATH)
	converted.close()
	converted = FileAccess.open(CONVERTED_FILEPATH,FileAccess.WRITE_READ)
	converted_cache.clear()


func reset_csv() -> void:
	oprint("%s reset!"%RESULTS_FILEPATH)
	reset_converted()
	results.close()
	results = FileAccess.open(RESULTS_FILEPATH,FileAccess.WRITE_READ)
	results.store_csv_line(this_header)
	results.flush()
