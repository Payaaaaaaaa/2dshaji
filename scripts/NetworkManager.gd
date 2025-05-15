extends Node

class_name NetworkManager

# 信号定义
signal connection_succeeded
signal connection_failed
signal player_list_changed
signal server_disconnected

# 网络配置
const DEFAULT_PORT = 10567
const MAX_PLAYERS = 5  # 1杀手 + 4幸存者
const MIN_PLAYERS = 2  # 至少需要1杀手+1幸存者

# 网络状态
var is_server: bool = false
var server_info = {
	"name": "默认房间",
	"max_players": MAX_PLAYERS
}

# 玩家管理
var player_info = {}  # {id: {name, role, ready, ...}}
var my_info = {
	"name": "玩家",
	"role": "幸存者",  # "幸存者" 或 "杀手"
	"ready": false,
	"connected": true
}

# 心跳检测
var heartbeat_timer: Timer
const HEARTBEAT_INTERVAL = 1.0
const DISCONNECT_TIMEOUT = 5.0
var player_last_heartbeat = {}

func _ready():
	# 初始化心跳计时器
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	heartbeat_timer.autostart = false
	heartbeat_timer.timeout.connect(_on_heartbeat_timer_timeout)
	add_child(heartbeat_timer)
	
	# 监听网络信号
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# 创建服务器
func create_server(port: int = DEFAULT_PORT) -> bool:
	print("尝试创建服务器...")
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	
	if error != OK:
		print("创建服务器失败: ", error)
		return false
	
	# 设置服务器参数
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	
	# 设置服务器信息
	var server_id = multiplayer.get_unique_id()
	my_info.role = "杀手"  # 房主默认为杀手
	player_info[server_id] = my_info.duplicate()
	
	# 启动心跳检测
	heartbeat_timer.start()
	
	print("服务器创建成功，ID: ", server_id)
	return true

# 加入服务器
func join_server(address: String, port: int = DEFAULT_PORT) -> bool:
	print("尝试连接服务器:", address, ":", port)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	
	if error != OK:
		print("连接服务器失败: ", error)
		connection_failed.emit()
		return false
	
	# 设置客户端参数
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	my_info.role = "幸存者"  # 加入者默认为幸存者
	
	print("正在连接服务器...")
	return true

# 断开连接
func disconnect_from_server():
	print("断开连接...")
	
	if heartbeat_timer.is_inside_tree() and heartbeat_timer.is_autostart_enabled():
		heartbeat_timer.stop()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	
	player_info.clear()
	player_last_heartbeat.clear()
	is_server = false
	
	server_disconnected.emit()

# 心跳计时器超时
func _on_heartbeat_timer_timeout():
	if is_server:
		# 服务器检查各客户端心跳
		var current_time = Time.get_ticks_msec()
		var disconnected_players = []
		
		for id in player_info.keys():
			if id != 1:  # 不检查服务器自己
				if id in player_last_heartbeat:
					var last_beat = player_last_heartbeat[id]
					if current_time - last_beat > DISCONNECT_TIMEOUT * 1000:
						print("玩家 ", id, " 心跳超时，断开连接")
						disconnected_players.append(id)
				else:
					# 初始化玩家心跳时间
					player_last_heartbeat[id] = current_time
		
		# 处理断开连接的玩家
		for id in disconnected_players:
			_handle_player_disconnect(id)
			
		# 发送心跳请求
		rpc("client_heartbeat_request")
	else:
		# 客户端向服务器发送心跳
		rpc_id(1, "server_receive_heartbeat", multiplayer.get_unique_id())

# 客户端接收心跳请求并回应
@rpc("authority", "call_remote", "unreliable")
func client_heartbeat_request():
	rpc_id(1, "server_receive_heartbeat", multiplayer.get_unique_id())

# 服务器接收心跳响应
@rpc("any_peer", "call_local", "unreliable")
func server_receive_heartbeat(client_id: int):
	if is_server and client_id == multiplayer.get_remote_sender_id():
		player_last_heartbeat[client_id] = Time.get_ticks_msec()

# 处理玩家断开连接
func _handle_player_disconnect(id: int):
	if player_info.has(id):
		# 标记玩家断线，但不立即删除，给予重连机会
		player_info[id].connected = false
		player_list_changed.emit()
		
		# 广播玩家状态更新
		if is_server:
			rpc("sync_player_list", player_info)
			
			# 如果在游戏中，可以考虑AI接管或其他处理
			if Global.current_state == Global.GameState.GAME:
				if player_info[id].role == "幸存者":
					# 幸存者掉线处理
					pass
				elif player_info[id].role == "杀手":
					# 杀手掉线处理
					pass

# 更新玩家准备状态
func set_player_ready(is_ready: bool):
	my_info.ready = is_ready
	var my_id = multiplayer.get_unique_id()
	
	if my_id in player_info:
		player_info[my_id].ready = is_ready
	
	if is_server:
		# 服务器直接更新
		update_player_info(my_id, my_info)
	else:
		# 客户端通知服务器
		rpc_id(1, "update_player_info", my_id, my_info)

# 更新玩家信息
@rpc("any_peer", "call_local", "reliable")
func update_player_info(id: int, info: Dictionary):
	if !is_server and multiplayer.get_remote_sender_id() != 1:
		# 只接受服务器发来的更新
		return
		
	player_info[id] = info.duplicate()
	player_list_changed.emit()
	
	if is_server:
		# 服务器将更新广播给所有客户端
		rpc("sync_player_list", player_info)

# 同步玩家列表
@rpc("authority", "call_remote", "reliable")
func sync_player_list(players: Dictionary):
	player_info = players.duplicate()
	player_list_changed.emit()
	print("玩家列表已更新，当前玩家:", player_info.size())

# 设置玩家角色
func set_player_role(id: int, role: String):
	if !is_server:
		return
	
	if id in player_info:
		player_info[id].role = role
		rpc("sync_player_list", player_info)

# 检查是否可以开始游戏
func can_start_game() -> bool:
	if !is_server:
		return false
	
	# 计算已准备的幸存者人数
	var ready_survivors = 0
	var has_killer = false
	
	for id in player_info:
		if player_info[id].role == "杀手":
			has_killer = true
		elif player_info[id].role == "幸存者" and player_info[id].ready:
			ready_survivors += 1
	
	return has_killer and ready_survivors >= 1  # 至少需要1个已准备的幸存者

# 开始游戏
func start_game():
	if !is_server or !can_start_game():
		return false
	
	print("开始游戏...")
	rpc("on_game_start")
	Global.change_state(Global.GameState.GAME)
	return true

# 通知所有客户端游戏开始
@rpc("authority", "call_remote", "reliable")
func on_game_start():
	print("收到游戏开始通知!")
	Global.change_state(Global.GameState.GAME)

# 网络事件处理函数
func _on_peer_connected(id: int):
	print("玩家连接：", id)
	
	if is_server:
		# 服务器初始化新玩家的心跳时间
		player_last_heartbeat[id] = Time.get_ticks_msec()

func _on_peer_disconnected(id: int):
	print("玩家断开连接：", id)
	
	# 彻底移除断开连接的玩家
	if player_info.has(id):
		player_info.erase(id)
	
	if player_last_heartbeat.has(id):
		player_last_heartbeat.erase(id)
	
	player_list_changed.emit()
	
	if is_server:
		rpc("sync_player_list", player_info)

func _on_connected_to_server():
	print("已连接到服务器")
	connection_succeeded.emit()
	
	var my_id = multiplayer.get_unique_id()
	
	# 将自己的信息发送给服务器
	rpc_id(1, "update_player_info", my_id, my_info)

func _on_connection_failed():
	print("连接服务器失败")
	connection_failed.emit()
	
	multiplayer.multiplayer_peer = null
	is_server = false

func _on_server_disconnected():
	print("服务器已断开连接")
	disconnect_from_server()

# 获取在线幸存者数量
func get_online_survivors_count() -> int:
	var count = 0
	for id in player_info:
		if player_info[id].role == "幸存者" and player_info[id].connected:
			count += 1
	return count

# 获取杀手ID（如果有）
func get_killer_id() -> int:
	for id in player_info:
		if player_info[id].role == "杀手":
			return id
	return -1

# 检查指定ID是否为杀手
func is_killer(id: int) -> bool:
	return id in player_info and player_info[id].role == "杀手"

# 检查指定ID是否为幸存者
func is_survivor(id: int) -> bool:
	return id in player_info and player_info[id].role == "幸存者" 