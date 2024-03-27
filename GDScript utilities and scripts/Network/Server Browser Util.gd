class_name ServerBrowserUtil extends PacketPeerUDP

const DEFAULT_SEND_PORT = 42069
const DEFAULT_RECEIVE_PORT = 25566
const default_deletion_threshold_usec = 3000000
const default_interval_usec = 250000
const internet_target_ips: PackedStringArray = [""]
const local_broadcast_ip = '255.255.255.255'

signal server_updated
signal server_deleted

var broadcast_interval_usec: int
var deletion_threshold_usec: int

var num_targets: int
var target_ips: PackedStringArray
var target_ports: PackedInt32Array

var receive_port: int

var last_time_sent: int

var servers: Dictionary

class Target:
	var ip: String
	var port: int

func _init(interval_usec: int = default_interval_usec, this_deletion_threshold_usec: int = default_deletion_threshold_usec, destination_ips: PackedStringArray = [local_broadcast_ip], these_target_ports: PackedInt32Array = [DEFAULT_RECEIVE_PORT], this_receive_port: int = DEFAULT_RECEIVE_PORT) -> void:
	
	assert(!destination_ips.is_empty(), "Server browser util must have at least one IP")
	assert(these_target_ports.size() == destination_ips.size(),
	"Server browser util must have same number of IPs as ports, but has %s IPs and %s ports."%[
		destination_ips.size(),these_target_ports.size()
	])
	subtract_local_addresses(destination_ips,these_target_ports)
	set_broadcast_enabled(destination_ips.has(local_broadcast_ip))
	
	broadcast_interval_usec = interval_usec
	deletion_threshold_usec = this_deletion_threshold_usec
	
	num_targets = destination_ips.size()
	target_ips = destination_ips
	target_ports = these_target_ports
	
	receive_port = this_receive_port

static func subtract_local_addresses(addresses: PackedStringArray, ports: PackedInt32Array) -> void:
	var local_addresses := IP.get_local_addresses()
	for i in addresses.size():
		if local_addresses.has(addresses[i]):
			addresses.remove_at(i)
			ports.remove_at(i)

func is_valid_broadcast_interval(t: int) -> bool:
	return t >= last_time_sent + broadcast_interval_usec

func broadcast_on_interval(packet: PackedByteArray) -> void:
	var t := Time.get_ticks_usec()
	if is_valid_broadcast_interval(t):
		broadcast(packet)
		last_time_sent = t

func begin_broadcasting_as_client() -> void:
	begin_broadcasting(PackedByteArray([PacketType.CLIENT]))

func begin_broadcasting(packet: PackedByteArray) -> void:
	assert(packet[packet_type_offset] >= 0 and packet[packet_type_offset] < PacketType.PACKET_TYPE_MAX, "%s is an invalid packet type."%packet[packet_type_offset])
	Console.write("Beginning %s broadcast."%"client" if packet[packet_type_offset] == PacketType.CLIENT else "server")
	broadcast_func = broadcast_on_interval.bind(packet)
	broadcast_func.call()
	Quack.connect_callable_to_frame_starts(broadcast_func)

var broadcast_func: Callable

func stop_broadcasting() -> void:
	Console.write("Stopping broadcast.")
	Quack.disconnect_callable_from_frame_starts(broadcast_func)

func broadcast(bytes: PackedByteArray) -> void:
	var ip: String
	var port: int
	var err: Error
	for i in num_targets:
		ip = target_ips[i]
		port = target_ports[i]
		err = set_dest_address(ip,port)
		if err != OK:
			Console.writerr("Server browser dialogue couldn't set destination address to %s:%s, error %s."%[ip,port,err])
		else:
			Console.writeverb("Pinging %s:%s..."%[ip,port])
			put_packet(bytes)

func begin_listening() -> void:
	close()
	var err: Error = bind(receive_port)
	if err != OK:
		return Console.writerr("Server browser dialogue couldn't bind to port %s, error %s."%[receive_port,error_string(err)])
	Console.write("Now listening for servers on port %s..."%receive_port)
	Quack.connect_callable_to_frame_starts(process_packets)
	Quack.connect_callable_to_frame_starts(sweep_servers_for_deletion)

func stop_listening() -> void:
	close()
	Console.write("Stopped listening for servers.")
	Quack.disconnect_callable_from_frame_starts(process_packets)
	Quack.disconnect_callable_from_frame_starts(sweep_servers_for_deletion)
	Console.write("Cleared server list.")
	servers.clear()

func process_packets() -> void:
	var timestamp := Time.get_ticks_usec()
	while get_available_packet_count() > 0:
		process_packet(timestamp)

func sweep_servers_for_deletion() -> void:
	var time := Time.get_ticks_usec()
	var server: ServerInfo
	for id: int in servers.keys():
		server = servers[id]
		if time >= server.time_updated_usec + deletion_threshold_usec:
			Console.writeverb("Server %s timed out."%id)
			servers.erase(id)

func process_packet(timestamp: int) -> void:
	# TODO: maybe create some way to validate if the packet is coming from an
	# appropriate source
	var packet := get_packet()
	var packet_err: Error = get_packet_error()
	if packet_err != OK:
		return Console.writerr("Server browser util %s got a packet with error %s."%[get_instance_id(),error_string(packet_err)])
	
	var packet_ip := get_packet_ip()
	var packet_port := get_packet_port()
	
	Console.writeverb("Server browser dialogue got packet from %s:%s."%[packet_ip,packet_port])
	
	if !is_valid_server_packet(packet):
		return Console.writerrverb("Invalid packet, discarding...")
	
	var info: ServerInfo = ServerInfo.decode(0,packet,timestamp,packet_ip,packet_port)
	if servers.has(info.id):
		Console.writeverb("Server %s updated."%info.id)
		(servers[info.id] as ServerInfo).time_updated_usec = timestamp
	else:
		Console.writeverb("Server %s discovered."%info.id)
		servers[info.id] = info

# idk what you'd use this for
class Packet:
	var bytes: PackedByteArray
	var error: Error
	var ip: String
	var port: int
	func _init(peer: PacketPeerUDP) -> void:
		bytes = peer.get_packet()
		error = peer.get_packet_error()
		ip = peer.get_packet_ip()
		port = peer.get_packet_port()

static func is_valid_server_packet(packet: PackedByteArray) -> bool:
	return !packet.is_empty() and packet[packet_type_offset] < PacketType.SERVER_TYPE_MAX

enum PacketType {SELFSERVER, REMOTESERVER, SERVER_TYPE_MAX, CLIENT = SERVER_TYPE_MAX, PACKET_TYPE_MAX}
const packet_type_offset = 0
const port_offset = 1
const ip_size_offset = port_offset + 2
const ip_offset = ip_size_offset + 2

static func create_selfserver_packet(port: int) -> PackedByteArray:
	var packet: PackedByteArray = [PacketType.SELFSERVER]
	packet.resize(ip_size_offset)
	packet.encode_u16(port_offset,port)
	return packet

class ServerInfo:
	var ip: String
	var port: int
	var time_updated_usec: int
	var id: int
	var ip_bytes: PackedByteArray
	var as_bytes: PackedByteArray
	
	func _init(server_ip: String, server_port: int, time_detected_usec: int) -> void:
		ip = server_ip
		port = server_port
		time_updated_usec = time_detected_usec
		id = ServerInfo.get_id(server_ip,server_port)
		ip_bytes = server_ip.to_ascii_buffer()
	
	func encode_info(offset: int, array: PackedByteArray) -> void:
		ByteUtils.encode_array(array,get_as_bytes(),offset)
	
	func get_as_bytes() -> PackedByteArray:
		if as_bytes.is_empty():
			# this will automatically initialize the first byte as a 0, which is the same as PacketType.SERVER
			as_bytes.resize(ip_offset)
			as_bytes.encode_u16(port_offset,port)
			as_bytes.encode_u16(ip_size_offset,ip_bytes.size())
			as_bytes.append_array(ip_bytes)
		return as_bytes
	
	static func decode(offset: int, serialized: PackedByteArray,time_detected: int, packet_ip: String, packet_port: int) -> ServerInfo:
		assert(serialized[offset] == PacketType.SELFSERVER or serialized[offset] == PacketType.REMOTESERVER, "Packet is supposed to be of type server (%s or %s) but is instead %s."%[
			PacketType.SELFSERVER,PacketType.REMOTESERVER,serialized[offset]
		])
		if serialized[offset] == PacketType.SELFSERVER:
			return ServerInfo.new(packet_ip,serialized.decode_u16(offset+port_offset),time_detected)
		else:
			return ServerInfo.new( #offset + ip offset start slice, offset + decoded ip size end slice
				serialized.slice(offset+ip_offset,serialized.decode_u16(offset+ip_size_offset)).get_string_from_ascii(),
				serialized.decode_u16(offset+port_offset),
				time_detected
			)
	
	static func get_id(ip: String, port: int) -> int:
		return ip.hash() + port # might not be optimal
