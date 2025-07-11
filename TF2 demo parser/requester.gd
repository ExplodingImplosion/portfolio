extends HTTPRequest

const main := preload("res://main.gd")
const APIs := preload("res://apis.gd")

@onready var parent := get_parent() as main

var assets: PackedStringArray
@export var button: Button
var assets_downloaded: int
signal done

func cancel() -> void:
	cancel_request()
	reset()

func pause(on: bool) -> void:
	button.disabled = on

func is_done() -> bool:
	return !button.disabled

func downloaded() -> bool:
	return assets.size() == assets_downloaded

func reset() -> void:
	for connection in request_completed.get_connections():
		request_completed.disconnect(connection.callable as Callable)
	assets.clear()
	assets_downloaded = 0
	pause(false)
	done.emit()

func try_request(url: String, headers: PackedStringArray, method: HTTPClient.Method = HTTPClient.METHOD_GET, request_data := "") -> void:
	var err: Error = request(url,headers,method,request_data)
	oprint("Method %s requesting %s\nHeaders: %s\nRequest data: %s"%[method,url,headers,request_data])
	if err != OK:
		oprint("Got error %s."%error_string(err))
	else:
		oprint("Success.")

func _init() -> void:
	request_completed.connect(print_request_completion)

func oprint(string: String) -> void:
	parent.oprint(string)

var most_recent_result: int
var most_recent_response_code: int
var most_recent_body: PackedByteArray
var most_recent_body_string: String
var most_recent_headers: PackedStringArray

var json := JSON.new()
var json_err: Error

func print_request_completion(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	most_recent_result = result
	most_recent_response_code = response_code
	most_recent_headers = headers
	most_recent_body = body
	most_recent_body_string = body.get_string_from_utf8()
	json_err = json.parse(most_recent_body_string)
	if response_code == 422 or response_code == 400:
		oprint("Error 422 unprocessable:")
		oprint(most_recent_body_string)
	oprint("Converting body string to json returned "+error_string(json_err))
	oprint("Result: %s\nResponse code: %s\n\n"%
	[result,response_code])
	#debug_done()
	done.emit()

func print_body(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	oprint(most_recent_body_string)

func oprint_body_as_struct(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	parent.oprint_value(JSON.parse_string(most_recent_body_string))

#func try_request_shopify(url: String, extra_headers: PackedStringArray = [],method: HTTPClient.Method = HTTPClient.METHOD_GET, request_data: String = "") -> void:
	#assert(url.begins_with(Shopify.main_url),"'%s' is an invalid Shopify URL. Valid shopify URLs must begin with '%s'."%[url,Shopify.main_url])
	#var headers: PackedStringArray = [Shopify.get_token_header()]
	#headers.append_array(extra_headers)
	#oprint("Pinging %s"%url)
	#try_request(url,headers,method,request_data)

func await_func_on_request(method: Callable, url: String, flags: = CONNECT_ONE_SHOT, headers: PackedStringArray = [], http_method: HTTPClient.Method = HTTPClient.METHOD_GET) -> bool:
	done.connect(method,flags)
	try_request(url,headers,http_method)
	await done
	return true

func debug_done() -> void:
	var cons := done.get_connections()
	var binds: Array
	for connection in cons:
		binds.append((connection.callable as Callable).get_method())
		binds.append((connection.callable as Callable).get_bound_arguments())
	parent.output.oprint_value(binds)

# if you try to run this func back to back like this on the same frame, you run
# into badness:
# await run_func_for_all_pages(args...)
# await run_func_for_all_pages(different args...)
# DON'T DO IT! IT FUCKS UP THE SIGNALS... unless.
# This dumb fucking hack with the awaiting until physics frames exceed yadda yadda
# gives signals time to properly disconnect.
var last_frame_finished_running_func_for_all_pages: int
func run_func_for_all_pages(method: Callable,url: String,paginated_url: String,headers: PackedStringArray = [], http_method: HTTPClient.Method = HTTPClient.METHOD_GET) -> bool:
	while Engine.get_physics_frames() <= last_frame_finished_running_func_for_all_pages:
		await get_tree().physics_frame
	done.connect(method)
	var get_next_page_func := get_next_page.bind(paginated_url)
	done.connect(get_next_page_func,CONNECT_REFERENCE_COUNTED)
	#try_request_shopify(url,headers,http_method)
	await pages_done
	done.disconnect(method)
	done.disconnect(get_next_page_func)
	cancel_request()
	last_frame_finished_running_func_for_all_pages = Engine.get_physics_frames()
	return true

func got_valid_result() -> bool:
	return most_recent_result == 0

func got_valid_response_code() -> bool:
	return most_recent_response_code == 200

func got_valid_response() -> bool:
	return got_valid_result() and got_valid_response_code()

func got_valid_json() -> bool:
	return json_err == OK

func got_valid_json_response() -> bool:
	return got_valid_response_code() and got_valid_json()

signal pages_done
func get_next_page(next_url: String) -> void:
	oprint("Trying to get next page...")
	if !got_valid_response():
		oprint("Bad result or response code. Bailing.")
		return pages_done.emit()

	# Find the header indicating link to next page.
	var next_header: String
	for header in most_recent_headers:
		if header.contains('rel="next"'):
			next_header = header
			break
	# Make sure that the header was found.
	if next_header.is_empty():
		oprint("Couldn't find next header. Bailing.")
		
		return pages_done.emit()
	
	# Very dumb way of getting the page_info bit itself
	var header_substr := next_header.split("page_info=")
	if header_substr.size() != 2:
		oprint("Header substr was invalid size %s on first split. Bailing."%header_substr.size())
		return pages_done.emit()
	header_substr = header_substr[1].split(">; rel=\"next\"")
	# lmao
	if header_substr.size() != 2:
		oprint("Header substr was invalid size %s on second split. Bailing."%header_substr.size())
		return pages_done.emit()
	
	oprint("Next header page info from %s:\nIs %s"%[next_header,header_substr[0]])
	
	var next_page_func := get_next_page.bind(next_url)
	await await_func_on_request(next_page_func,next_url%header_substr[0],CONNECT_REFERENCE_COUNTED)
	done.disconnect(next_page_func)
