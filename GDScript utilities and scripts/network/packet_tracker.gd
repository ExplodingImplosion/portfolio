var history: Array[PackedByteArray]
var history_offset: int = -1

var packet_map: Dictionary
var packet_signature_map: Dictionary

func _init(tracker_size: int) -> void:
	history.resize(tracker_size)

func maps_erase_by_packet(packet: PackedByteArray) -> void:
	packet_map.erase(packet_signature_map[packet])
	packet_signature_map.erase(packet)

func maps_erase_by_signature(signature: int) -> void:
	packet_signature_map.erase(packet_map[signature])
	packet_map.erase(signature)

func maps_add_packet(packet: PackedByteArray, signature: int) -> void:
	packet_map[signature] = packet
	packet_signature_map[packet] = signature

func add_to_history_by_signature(packet: PackedByteArray, _signature: int) -> void:
	increment_history_offset()
	var replaced_packet: PackedByteArray = history[history_offset]
	if !replaced_packet.is_empty() and packet_signature_map.has(replaced_packet):
		maps_erase_by_packet(replaced_packet)
	history[history_offset] = packet

func add_to_history(packet: PackedByteArray) -> void:
	increment_history_offset()
	history[history_offset] = packet

func get_history_offset_incremented() -> int:
	return wrapi(history_offset + 1, 0, history.size())

func increment_history_offset() -> void:
	history_offset = get_history_offset_incremented()

func get_previous_packet(frames_behind: int) -> PackedByteArray:
	assert(frames_behind >= 0, "frames_behind must be a positive number, but is %s."%[frames_behind])
	# maybe change this to some kind of wrapi
	return history[history_offset - frames_behind]

func get_most_recent_packet() -> PackedByteArray:
	return history[history_offset]

func size() -> int:
	return history.size()
