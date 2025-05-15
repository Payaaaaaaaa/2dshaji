extends Node2D

# 游戏场景的主要脚本
# 负责初始化游戏环境、角色生成和场景管理

# 节点引用
@onready var multiplayer_manager = $MultiplayerManager
@onready var game_logic = $GameLogic
@onready var players_node = $Players
@onready var objects_node = $Objects
@onready var hud = $HUD
@onready var game_map = $GameMap
@onready var game_result_ui = $GameResultUI

# UI整合组件
var ui_integration: UIGameIntegration
var qte_integration: QTEIntegration

# 调试工具
var debug_controller = null

# 场景状态
var game_initialized := false
var round_started := false

func _ready():
	print("游戏场景加载完成")
	
	# 确保有必要的节点
	if not multiplayer_manager:
		multiplayer_manager = MultiplayerManager.new()
		add_child(multiplayer_manager)
	
	if not players_node:
		players_node = Node2D.new()
		players_node.name = "Players"
		add_child(players_node)
	
	if not objects_node:
		objects_node = Node2D.new()
		objects_node.name = "Objects"
		add_child(objects_node)
	
	# 设置节点引用
	if multiplayer_manager:
		multiplayer_manager.players_node = players_node
		multiplayer_manager.objects_node = objects_node
	
	# 设置场景引用
	if game_logic:
		game_logic.players_node = players_node
		game_logic.objects_node = objects_node
	
	# 初始化调试控制器(仅在开发环境)
	_initialize_debug_tools()
	
	# 如果是服务器，等待一帧然后初始化游戏
	if Global.network_manager.is_server:
		call_deferred("initialize_game")
	
	# 初始化UI整合系统
	_initialize_ui_integration()
	
	# 连接信号
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# 初始化调试工具
func _initialize_debug_tools():
	# 仅在开发版本或调试模式下启用调试工具
	var is_dev_build = OS.is_debug_build() or OS.has_feature("editor")
	
	if is_dev_build:
		print("初始化调试工具...")
		# 加载并创建调试控制器
		var DebugController = load("res://scripts/UI/DebugController.gd")
		if DebugController:
			debug_controller = DebugController.new()
			add_child(debug_controller)

# 初始化UI整合系统
func _initialize_ui_integration():
	# 创建UI整合系统
	ui_integration = UIGameIntegration.new(self)
	add_child(ui_integration)
	
	# 创建QTE整合系统
	if hud and hud.get_node_or_null("SkillCheckUI"):
		var skill_check_ui = hud.get_node("SkillCheckUI")
		qte_integration = QTEIntegration.new(skill_check_ui)
		add_child(qte_integration)
		
		# 设置QTE回调
		if qte_integration:
			qte_integration.set_callbacks(
				func(): _on_qte_success(),
				func(): _on_qte_fail(),
				func(success): _on_qte_complete(success)
			)
	
	# 连接游戏结束信号
	if game_result_ui:
		game_result_ui.continue_pressed.connect(_on_game_result_continue)

# 初始化游戏
func initialize_game():
	print("初始化游戏...")
	await get_tree().process_frame
	
	# 更新HUD
	update_hud()
	
	if Global.network_manager.is_server:
		# 生成地图
		if game_map:
			print("生成程序化地图...")
			var map_seed = randi()  # 创建随机种子
			var map_theme = -1  # 随机主题
			var generated_seed = game_map.generate_map(map_seed, map_theme)
			print("地图生成完成，使用种子:", generated_seed)
			
			# 等待地图生成完成
			await game_map.map_ready
	else:
		# 客户端等待地图数据
		if game_map:
			print("客户端等待地图数据...")
			await game_map.map_seed_received
			print("客户端收到地图数据")
	
	# 在地图生成完成后初始化游戏内容
	if multiplayer_manager:
		# 服务器初始化游戏内容
		multiplayer_manager.initialize_game()
		
		# 当地图和玩家都准备好后，更新UI集成
		await multiplayer_manager.game_content_initialized
		_update_ui_integration()
		
		game_initialized = true
	else:
		push_error("无法初始化游戏: MultiplayerManager不存在")

# 更新HUD
func update_hud():
	if not hud:
		return
	
	# 如果是幸存者，显示幸存者HUD
	if Global.network_manager.is_survivor(multiplayer.get_unique_id()):
		hud.set_survivor_mode()
	else:
		# 如果是杀手，显示杀手HUD
		hud.set_killer_mode()
	
	# 更新任务进度
	hud.update_generator_count(Global.generators_completed, Global.GENERATORS_REQUIRED)

# 更新UI整合系统
func _update_ui_integration():
	if ui_integration:
		# 等待玩家生成完成
		await get_tree().process_frame
		
		# 获取玩家控制的角色
		var local_player_id = multiplayer.get_unique_id()
		for player in players_node.get_children():
			if player is Character and player.player_id == local_player_id:
				# 更新QTE集成
				if qte_integration:
					qte_integration.set_current_player(player)

# 开始回合
func start_round():
	if not game_initialized or round_started:
		return
	
	round_started = true
	rpc("on_round_started")
	
	# 开始回合计时
	if Global.network_manager.is_server:
		game_logic.start_round_timer()

# 通知所有客户端回合开始
@rpc("authority", "call_remote", "reliable")
func on_round_started():
	round_started = true
	
	# 通知HUD更新
	if hud:
		hud.on_round_started()
	
	# 播放开始音效
	play_round_start_sound()

# 播放回合开始音效
func play_round_start_sound():
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = load("res://assets/audio/sfx_round_start.wav")
	audio_player.volume_db = -10
	add_child(audio_player)
	audio_player.play()
	
	# 音效播放完毕后移除节点
	audio_player.finished.connect(func(): audio_player.queue_free())

# 结束游戏回合
func end_round(killer_won: bool):
	if not round_started:
		return
	
	round_started = false
	
	# 收集游戏统计数据
	var player_stats = _collect_player_stats()
	
	# 构建结果数据
	var result_data = {
		"killer_won": killer_won,
		"player_stats": player_stats
	}
	
	# 通知所有客户端
	rpc("on_round_ended", killer_won, result_data)
	
	# 3秒后显示结果界面
	await get_tree().create_timer(3.0).timeout
	
	# 显示结果界面
	if game_result_ui:
		game_result_ui.show_results(result_data)

# 收集玩家统计数据
func _collect_player_stats() -> Dictionary:
	var stats = {
		"killer": {},
		"survivors": []
	}
	
	# 遍历所有玩家
	for player_id in Global.network_manager.player_info:
		var player_info = Global.network_manager.player_info[player_id]
		var character = _find_player_by_id(player_id)
		
		if Global.network_manager.is_killer(player_id):
			# 杀手数据
			stats["killer"] = {
				"name": player_info.get("name", "杀手"),
				"hook_count": Global.hook_count,
				"hit_count": Global.hit_count,
				"kill_count": Global.kill_count
			}
		else:
			# 幸存者数据
			var survivor_data = {
				"name": player_info.get("name", "幸存者"),
				"generator_count": 0,
				"rescue_count": 0,
				"escaped": false
			}
			
			# 如果角色实例存在，获取详细数据
			if character and character is Survivor:
				survivor_data["generator_count"] = character.generators_repaired
				survivor_data["rescue_count"] = character.survivors_rescued
				survivor_data["escaped"] = character.has_escaped
			
			stats["survivors"].append(survivor_data)
	
	return stats

# 查找玩家角色
func _find_player_by_id(player_id: int) -> Character:
	if not players_node:
		return null
	
	for player in players_node.get_children():
		if player is Character and player.player_id == player_id:
			return player
	
	return null

# 通知所有客户端回合结束
@rpc("authority", "call_remote", "reliable")
func on_round_ended(killer_won: bool, result_data: Dictionary):
	round_started = false
	
	# 通知HUD显示结果
	if hud:
		hud.show_round_result(killer_won)
	
	# 播放结束音效
	play_round_end_sound(killer_won)
	
	# 等待3秒后显示结果界面
	await get_tree().create_timer(3.0).timeout
	
	# 显示结果界面
	if game_result_ui:
		game_result_ui.show_results(result_data)

# 播放回合结束音效
func play_round_end_sound(killer_won: bool):
	var audio_player = AudioStreamPlayer.new()
	
	if killer_won:
		audio_player.stream = load("res://assets/audio/music_killer_win.ogg")
	else:
		audio_player.stream = load("res://assets/audio/music_survivor_win.ogg")
	
	audio_player.volume_db = -5
	add_child(audio_player)
	audio_player.play()

# 处理玩家断线
func _on_peer_disconnected(id: int):
	print("玩家断开连接:", id)
	
	# 如果游戏已经开始
	if round_started and Global.network_manager.is_server:
		# 检查是否是杀手断线
		if Global.network_manager.is_killer(id):
			print("杀手断线，幸存者获胜")
			end_round(false)
		else:
			# 更新幸存者计数
			var alive = 0
			var escaped = Global.survivor_escaped
			
			for player_id in Global.network_manager.player_info:
				if Global.network_manager.is_survivor(player_id) and player_id != id:
					alive += 1
			
			Global.update_survivor_count(alive, escaped)
			
			# 检查游戏是否应该结束
			if alive == 0:
				print("所有幸存者断线或死亡，杀手获胜")
				end_round(true)

# 接收游戏内事件
func on_game_event(event_name: String, data: Dictionary = {}):
	# 处理各种游戏事件
	match event_name:
		"generator_completed":
			# 发电机修理完成
			if Global.network_manager.is_server:
				Global.generator_completed()
				
				# 更新HUD
				rpc("update_generator_hud", Global.generators_completed)
				
				# 检查是否所有发电机都修好
				if Global.generators_completed >= Global.GENERATORS_REQUIRED:
					# 通电出口门
					power_exit_gates()
		
		"survivor_escaped":
			# 幸存者逃脱
			if Global.network_manager.is_server and data.has("player_id"):
				var player_id = data["player_id"]
				
				# 更新幸存者状态
				Global.survivor_escaped += 1
				var alive = Global.survivors_alive - 1
				Global.update_survivor_count(alive, Global.survivor_escaped)
		
		"survivor_died":
			# 幸存者死亡
			if Global.network_manager.is_server and data.has("player_id"):
				var player_id = data["player_id"]
				
				# 更新幸存者状态
				Global.survivors_alive -= 1
				Global.update_survivor_count(Global.survivors_alive, Global.survivor_escaped)

# 更新发电机HUD
@rpc("authority", "call_remote", "reliable")
func update_generator_hud(count: int):
	if hud:
		hud.update_generator_count(count, Global.GENERATORS_REQUIRED)

# 通电所有出口门
func power_exit_gates():
	if not Global.network_manager.is_server:
		return
	
	# 查找所有出口门并通电
	for child in objects_node.get_children():
		if child is ExitGate:
			child.set_powered(true)
	
	# 通知所有玩家
	rpc("on_exit_gates_powered")

# 通知所有出口门通电
@rpc("authority", "call_remote", "reliable")
func on_exit_gates_powered():
	print("所有出口门已通电!")
	
	# 更新HUD提示
	if hud:
		hud.show_exit_gate_powered()
	
	# 播放通电音效
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = load("res://assets/audio/sfx_exitgate_powered.wav")
	add_child(audio_player)
	audio_player.play()
	
	# 音效播放完毕后移除节点
	audio_player.finished.connect(func(): audio_player.queue_free())

# QTE回调函数
func _on_qte_success():
	# QTE成功的处理
	# 通常由QTEIntegration处理通知服务器
	pass

func _on_qte_fail():
	# QTE失败的处理
	# 通常由QTEIntegration处理通知服务器
	pass

func _on_qte_complete(success: bool):
	# QTE完成后的处理
	pass

# 结算界面继续按钮回调
func _on_game_result_continue():
	# 返回大厅
	Global.change_state(Global.GameState.LOBBY) 