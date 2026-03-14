extends Object
const Profiler = preload("res://utils/profiler.gd")

static var profilers: Dictionary[StringName,Profiler]

static func profile(callable: Callable, override: String = "") -> Variant:
	var method := callable.get_method() + override
	if profilers.has(method):
		return profilers[method].profile_function(callable)
	else:
		return Profiler.new(method).profile_function(callable)

var method: StringName
var times: PackedInt64Array
var idx: int = 0

func profile_function(callable: Callable) -> Variant:
	var t1: int; var t2: int
	t1 = Time.get_ticks_usec()
	var value: Variant = callable.call()
	t2 = Time.get_ticks_usec()
	add_time(t2-t1)
	return value

func reset() -> void:
	times.fill(0)
	idx = 0

func add_time(time: int) -> void:
	if idx >= times.size():
		times.append(time)
	else:
		times[idx] = time
		idx += 1

func get_func_time() -> int:
	var total_time: int = 0
	for i in idx:
		total_time += times[i]
	return total_time

func _to_string() -> String:
	var time := Quack.TimeUtils.usec_to_seconds(get_func_time()) * 1000.
	var avg := time / idx if idx else 0.
	return "'%s' profile: %sms average over %s calls for %sms total this %s."%[
		method,avg,idx,time,"%s frame"%("physics" if Engine.is_in_physics_frame() else "process")
	]

func get_times() -> PackedInt64Array:
	return times.slice(0,idx)

func _init(method: StringName, min_size := 100) -> void:
	self.method = method
	times.resize(min_size)
	Quack.connect_callable_to_frame_starts(reset)
	Profiler.profilers[method] = self

func free() -> void:
	profilers.erase(method)
