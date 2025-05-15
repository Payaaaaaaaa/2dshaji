extends Node

# 游戏状态枚举
enum GameState {
	MAIN_MENU,
	LOBBY,
	GAME,
	END_SCREEN
}

# 当前游戏状态
var current_state: int = GameState.MAIN_MENU

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
var GENERATORS_REQUIRED: int = 5  # 需要完成修理的发电机数量

# 游戏进度变量
var generators_completed: int = 0  # 已修好的发电机数量
var survivors_alive: int = 0
var survivor_escaped: int = 0

# 当前随机种子(用于地图生成)
var current_seed: int = 0

# 场景路径
const MAIN_MENU_SCENE = "res://scenes/ui/MainMenu.tscn"
const LOBBY_SCENE = "res://scenes/ui/Lobby.tscn"
const GAME_SCENE = "res://scenes/Game.tscn"
const END_SCREEN_SCENE = "res://scenes/ui/EndScreen.tscn"

# 网络管理器引用
var network_manager = null
var audio_manager = null
var game_balance_manager = null

# 信号
signal game_state_changed(old_state, new_state)

func _ready():
	# 设置随机数种子
	randomize()
	
	# 初始化网络管理器
	network_manager = NetworkManager.new()
	add_child(network_manager)
	
	# 初始化音频管理器
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	
	# 初始化平衡管理器
	game_balance_manager = GameBalanceManager.new()
	add_child(game_balance_manager)
	
	# 连接网络管理器信号
	network_manager.connection_succeeded.connect(_on_connection_succeeded)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.server_disconnected.connect(_on_server_disconnected)

# 修改游戏状态
func change_state(new_state: int):
	var old_state = current_state
	current_state = new_state
	
	# 发出信号通知状态改变
	game_state_changed.emit(old_state, new_state)
	
	match new_state:
		GameState.MAIN_MENU:
			pass
		GameState.LOBBY:
			if old_state == GameState.MAIN_MENU:
				get_tree().change_scene_to_file(LOBBY_SCENE)
		GameState.GAME:
			# 初始化游戏变量
			generators_completed = 0
			survivors_alive = 0
			survivor_escaped = 0
			
			# 生成随机种子用于地图生成
			if network_manager.is_server:
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

# 创建服务器
func create_server(port: int = 10567) -> bool:
	if network_manager.create_server(port):
		change_state(GameState.LOBBY)
		return true
	return false

# 加入服务器
func join_server(address: String, port: int = 10567) -> bool:
	return network_manager.join_server(address, port)

# 断开连接
func disconnect_from_server():
	network_manager.disconnect_from_server()
	change_state(GameState.MAIN_MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# 开始游戏(仅主机可调用)
func start_game():
	if network_manager.is_server:
		network_manager.start_game()

# 网络连接成功
func _on_connection_succeeded():
	change_state(GameState.LOBBY)

# 网络连接失败
func _on_connection_failed():
	print("连接失败，返回主菜单")
	change_state(GameState.MAIN_MENU)

# 服务器断开连接
func _on_server_disconnected():
	disconnect_from_server()

# 发电机完成计数
func generator_completed():
	if !network_manager.is_server:
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
	if !network_manager.is_server:
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

# 更新幸存者状态
func update_survivor_count(alive: int, escaped: int):
	if !network_manager.is_server:
		return
		
	survivors_alive = alive
	survivor_escaped = escaped
	
	# 同步到所有客户端
	rpc("sync_survivor_status", survivors_alive, survivor_escaped)
	
	# 检查游戏结束条件
	check_game_end()

# 同步幸存者状态
@rpc("authority", "call_remote", "reliable")
func sync_survivor_status(alive: int, escaped: int):
	survivors_alive = alive
	survivor_escaped = escaped

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

# 加载游戏设置
func load_settings():
	# 加载平衡设置
	if game_balance_manager:
		game_balance_manager.load_balance_settings()

# 保存游戏设置
func save_settings():
	# 保存平衡设置
	if game_balance_manager:
		game_balance_manager.save_balance_settings() 