extends Node

# 游戏状态枚举
enum GameState {
	MENU,       # 主菜单
	LOBBY,      # 房间/大厅
	GAME,       # 游戏中
	END_SCREEN  # 结算界面
}

# 当前游戏状态
var current_state: int = GameState.MENU

# 网络相关变量
var is_server: bool = false
var player_info = {}  # 玩家信息字典 {id: {name, role, ready}}
var my_info = {
	"name": "玩家",
	"role": "幸存者", # "幸存者" 或 "杀手"
	"ready": false
}

# 游戏相关常量
const MAX_SURVIVORS = 4
const GENERATORS_REQUIRED = 5

# 游戏进度变量
var generators_completed: int = 0
var survivors_alive: int = 0
var survivor_escaped: int = 0

# 当前随机种子(用于地图生成)
var current_seed: int = 0

# 场景路径
const MAIN_MENU_SCENE = "res://scenes/ui/MainMenu.tscn"
const LOBBY_SCENE = "res://scenes/ui/Lobby.tscn"
const GAME_SCENE = "res://scenes/Game.tscn"
const END_SCREEN_SCENE = "res://scenes/ui/EndScreen.tscn"

func _ready():
	# 设置随机数种子
	randomize()
	
	# 监听网络信号
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# 创建服务器/房间
func create_server(port: int = 10567) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_SURVIVORS)
	
	if error != OK:
		print("创建服务器失败: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	
	# 设置服务器信息
	var server_id = multiplayer.get_unique_id()
	my_info.role = "杀手"  # 房主默认为杀手
	player_info[server_id] = my_info.duplicate()
	
	print("服务器创建成功，ID: ", server_id)
	change_state(GameState.LOBBY)
	return true

# 加入服务器/房间
func join_server(address: String, port: int = 10567) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	
	if error != OK:
		print("连接服务器失败: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	my_info.role = "幸存者"  # 加入者默认为幸存者
	
	print("正在连接服务器...")
	return true

# 断开连接
func disconnect_from_server():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		
	player_info.clear()
	is_server = false
	change_state(GameState.MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# 修改游戏状态
func change_state(new_state: int):
	var old_state = current_state
	current_state = new_state
	
	match new_state:
		GameState.MENU:
			pass
		GameState.LOBBY:
			if old_state == GameState.MENU:
				get_tree().change_scene_to_file(LOBBY_SCENE)
		GameState.GAME:
			# 初始化游戏变量
			generators_completed = 0
			survivors_alive = 0
			survivor_escaped = 0
			
			# 生成随机种子用于地图生成
			if is_server:
				current_seed = randi()
				# 通知所有客户端使用相同种子
				rpc("set_game_seed", current_seed)
				
			get_tree().change_scene_to_file(GAME_SCENE)
		GameState.END_SCREEN:
			get_tree().change_scene_to_file(END_SCREEN_SCENE)

# 设置游戏种子(用于一致的随机地图生成)
@rpc("authority", "call_remote", "reliable")
func set_game_seed(seed_value: int):
	current_seed = seed_value
	print("收到地图种子：", current_seed)

# 开始游戏(仅主机可调用)
func start_game():
	if is_server:
		rpc("on_game_start")
		change_state(GameState.GAME)

# 通知所有客户端游戏开始
@rpc("authority", "call_remote", "reliable")
func on_game_start():
	print("游戏开始!")
	change_state(GameState.GAME)

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
	
	if is_server:
		# 服务器将更新广播给所有客户端
		rpc("sync_player_list", player_info)

# 同步玩家列表
@rpc("authority", "call_remote", "reliable")
func sync_player_list(players: Dictionary):
	player_info = players.duplicate()
	print("玩家列表已更新，当前玩家:", player_info.size())

# 发电机完成计数
func generator_completed():
	if !is_server:
		return
		
	generators_completed += 1
	rpc("sync_generator_count", generators_completed)
	
	# 检查是否所有发电机都修好
	if generators_completed >= GENERATORS_REQUIRED:
		rpc("on_all_generators_completed")

# 同步发电机计数
@rpc("authority", "call_remote", "reliable")
func sync_generator_count(count: int):
	generators_completed = count
	print("发电机进度：", generators_completed, "/", GENERATORS_REQUIRED)

# 所有发电机修好后调用
@rpc("authority", "call_remote", "reliable")
func on_all_generators_completed():
	print("所有发电机已修好，出口门已通电!")
	# 这里可以添加出口门通电的逻辑

# 检查游戏结束条件
func check_game_end():
	if !is_server:
		return
		
	# 如果所有幸存者逃脱或死亡，游戏结束
	if survivor_escaped + (MAX_SURVIVORS - survivors_alive) >= MAX_SURVIVORS:
		var killer_won = survivor_escaped == 0
		rpc("end_game", killer_won)

# 结束游戏
@rpc("authority", "call_remote", "reliable")
func end_game(killer_won: bool):
	print("游戏结束，杀手获胜: ", killer_won)
	change_state(GameState.END_SCREEN)

# 网络事件处理函数
func _on_peer_connected(id: int):
	print("玩家连接：", id)

func _on_peer_disconnected(id: int):
	print("玩家断开连接：", id)
	
	# 移除断开连接的玩家
	if player_info.has(id):
		player_info.erase(id)
		
		if is_server:
			rpc("sync_player_list", player_info)

func _on_connected_to_server():
	print("已连接到服务器")
	var my_id = multiplayer.get_unique_id()
	player_info[my_id] = my_info.duplicate()
	
	# 将自己的信息发送给服务器
	rpc_id(1, "update_player_info", my_id, my_info)
	change_state(GameState.LOBBY)

func _on_connection_failed():
	print("连接服务器失败")
	multiplayer.multiplayer_peer = null
	is_server = false

func _on_server_disconnected():
	print("服务器已断开连接")
	disconnect_from_server() 