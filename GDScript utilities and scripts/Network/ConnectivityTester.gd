class_name ConnectivityTester

const internet_connectivity_tester_urls: PackedStringArray = ["1.1.1.1","8.8.8.8","www.google.com","www.example.com"]

static func check_http_client_connection(http_client: HTTPClient, url_idx: int, attempt_num: int) -> void:
	var poll: int = http_client.poll()
	assert(poll == OK or poll == ERR_CANT_RESOLVE, "poll should work... got %s instead."%[poll])
	match get_http_client_connection_result_from_status(http_client.get_status()):
		HTTPCLIENTCONNECTIONSTATUS.CONNECTING:
			if attempt_num >= MAX_HTTP_CONNECTION_ATTEMPTS:
				if url_idx < internet_connectivity_tester_urls.size() - 1:
					try_connecting_to_host(http_client,url_idx+1,0)
			else:
				wait_for_connection(http_client,url_idx,attempt_num+1)
		HTTPCLIENTCONNECTIONSTATUS.CONNECTED:
			Network.is_connected_to_internet = true
			print("Connected to %s on attempt %s."%[internet_connectivity_tester_urls[url_idx],attempt_num])
			http_client.close()
		HTTPCLIENTCONNECTIONSTATUS.FAILED:
			if url_idx < internet_connectivity_tester_urls.size() - 1:
				try_connecting_to_host(http_client,url_idx+1,0)

enum HTTPCLIENTCONNECTIONSTATUS{CONNECTING,CONNECTED,FAILED}

static func get_http_client_connection_result_from_status(status: int) -> int:
	if status == HTTPClient.STATUS_CONNECTED:
		return HTTPCLIENTCONNECTIONSTATUS.CONNECTED
	elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE or status == HTTPClient.STATUS_CONNECTION_ERROR or status == HTTPClient.STATUS_DISCONNECTED:
		return HTTPCLIENTCONNECTIONSTATUS.FAILED
	else:
		return HTTPCLIENTCONNECTIONSTATUS.CONNECTING

const MAX_HTTP_CONNECTION_ATTEMPTS = 3

static func try_connecting_to_host(http_client: HTTPClient, url_idx: int, attempt_num: int) -> void:
	var error: int = http_client.connect_to_host(internet_connectivity_tester_urls[url_idx])
	assert(error == OK,"connect_to_host is supposed to work even if the connection doesn't. got %s instead."%[error])
	wait_for_connection(http_client,url_idx,attempt_num)

static func wait_for_connection(http_client: HTTPClient, url_idx: int, attempt_num: int) -> void:
	prints("HTTPClient attempting to connect to url %s, attempt number %s"%[internet_connectivity_tester_urls[url_idx],attempt_num])
	Quack.connect_to_timer(1.0,ConnectivityTester.check_http_client_connection.bind(http_client,url_idx,attempt_num))

static func test_internet_connection() -> void:
	assert(!internet_connectivity_tester_urls.is_empty(), "internet_connectivity_tester_urls is empty.")
	var http_client := HTTPClient.new()
	try_connecting_to_host(http_client,0,0)

static func test_sheila_connection() -> void:
	return
