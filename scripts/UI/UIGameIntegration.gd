extends Node
class_name UIGameIntegration

# 节点引用
var game_scene: Node
var game_hud: GameHUD
var game_logic: Node
var network_manager: Node

# 状态追踪
var player_role: String
var generators_completed: int = 0
var generators_required: int = 5
var survivors_alive: int = 0
var survivors_total: int = 0
var current_player: Character

# 信号
signal hud_ready

func _init(game: Node):
	game_scene = game
	
	# 获取引用
	game_hud = game.get_node_or_null("HUD")
	game_logic = game.get_node_or_null("GameLogic")
	network_manager = Global.network_manager
	
	# 配置初始状态
	if network_manager:
		player_role = "killer" if network_manager.is_killer(multiplayer.get_unique_id()) else "survivor"
		
	generators_required = Global.GENERATORS_REQUIRED
	generators_completed = Global.generators_completed

	_setup_signals()
	_initialize_hud()

# 设置信号连接
func _setup_signals():
	# 游戏逻辑信号
	if game_logic:
		if game_logic.has_signal("generator_completed"):
			game_logic.generator_completed.connect(_on_generator_completed)
		if game_logic.has_signal("survivor_died"):
			game_logic.survivor_died.connect(_on_survivor_died)
		if game_logic.has_signal("survivor_escaped"):
			game_logic.survivor_escaped.connect(_on_survivor_escaped)
		if game_logic.has_signal("all_generators_completed"):
			game_logic.all_generators_completed.connect(_on_all_generators_completed)
		if game_logic.has_signal("exit_gate_powered"):
			game_logic.exit_gate_powered.connect(_on_exit_gate_powered)
		if game_logic.has_signal("game_ended"):
			game_logic.game_ended.connect(_on_game_ended)
	
	# 全局信号
	if Global.has_signal("game_event"):
		Global.game_event.connect(_on_game_event)
		
	# 获取玩家角色引用
	var player_id = multiplayer.get_unique_id()
	current_player = _find_player_by_id(player_id)
	
	# 监听玩家状态变化
	if current_player:
		if current_player.has_signal("health_changed"):
			current_player.health_changed.connect(_on_player_health_changed)
		if current_player.has_signal("state_changed"):
			current_player.state_changed.connect(_on_player_state_changed)
		if current_player.has_signal("interaction_started"):
			current_player.interaction_started.connect(_on_interaction_started)
		if current_player.has_signal("interaction_completed"):
			current_player.interaction_completed.connect(_on_interaction_completed)
		if current_player.has_signal("interaction_canceled"):
			current_player.interaction_canceled.connect(_on_interaction_canceled)
		if current_player.has_signal("item_obtained"):
			current_player.item_obtained.connect(_on_item_obtained)
		if current_player.has_signal("item_used"):
			current_player.item_used.connect(_on_item_used)

# 初始化HUD
func _initialize_hud():
	if not game_hud:
		return
		
	# 设置HUD模式
	if player_role == "killer":
		game_hud.set_killer_mode()
	else:
		game_hud.set_survivor_mode()
	
	# 设置当前玩家
	if current_player:
		game_hud.set_player(current_player)
	
	# 更新发电机计数
	game_hud.update_generators_count(generators_completed, generators_required)
	
	# 更新幸存者计数
	_update_survivor_count()
	
	# 发出HUD准备好的信号
	hud_ready.emit()

# 更新幸存者计数
func _update_survivor_count():
	if not game_hud:
		return
	
	survivors_alive = 0
	survivors_total = 0
	
	# 计算当前存活的幸存者
	for player_id in network_manager.player_info:
		if network_manager.is_survivor(player_id):
			survivors_total += 1
			var player = _find_player_by_id(player_id)
			if player and player.is_alive():
				survivors_alive += 1
	
	game_hud.update_survivors_count(survivors_alive, survivors_total)

# 查找玩家角色
func _find_player_by_id(player_id: int) -> Character:
	if not game_scene:
		return null
	
	var players_node = game_scene.get_node_or_null("Players")
	if not players_node:
		return null
	
	for player in players_node.get_children():
		if player is Character and player.player_id == player_id:
			return player
	
	return null

# 触发技能检测
func trigger_skill_check(player_id: int, difficulty: float = 0.5, zone_size: float = 0.1):
	if multiplayer.get_unique_id() != player_id:
		return
	
	if game_hud:
		game_hud.trigger_skill_check(difficulty, zone_size)

# 显示交互提示
func show_interaction_prompt(interactable: Interactable):
	if not game_hud:
		return
	
	game_hud.show_interaction_prompt(interactable)

# 隐藏交互提示
func hide_interaction_prompt():
	if not game_hud:
		return
	
	game_hud.hide_interaction_prompt()

# 更新交互进度
func update_interaction_progress(progress: float):
	if not game_hud:
		return
	
	game_hud.update_interaction_progress(progress)

# 显示通知
func show_notification(text: String, duration: float = 3.0):
	if not game_hud:
		return
	
	game_hud.show_notification(text, duration)

# 更新玩家状态
func update_player_status():
	if not game_hud or not current_player:
		return
	
	game_hud.update_player_status()

# ---- 信号处理函数 ----

func _on_game_event(event_name: String, data: Dictionary):
	match event_name:
		"generator_completed":
			generators_completed += 1
			if game_hud:
				game_hud.update_generators_count(generators_completed, generators_required)
				game_hud.show_notification("发电机已修好! %d/%d" % [generators_completed, generators_required])
		
		"survivor_hooked":
			if player_role == "killer":
				show_notification("幸存者已被挂上钩子!")
			else:
				show_notification("队友被挂上钩子了!")
		
		"survivor_rescued":
			if player_role == "killer":
				show_notification("幸存者被救下了!")
			else:
				show_notification("队友被救下了!")
		
		"survivor_died":
			_update_survivor_count()
			if player_role == "killer":
				show_notification("幸存者已死亡!")
			else:
				show_notification("队友死亡了!")
		
		"exit_gates_powered":
			show_notification("所有发电机已修好，出口门已通电!", 5.0)
		
		"survivor_escaped":
			if player_role == "killer":
				show_notification("幸存者已逃脱!")
			else:
				show_notification("队友已成功逃脱!")
		
		"game_ended":
			var killer_won = data.get("killer_won", false)
			if player_role == "killer":
				show_notification(killer_won ? "胜利!" : "失败...", 10.0)
			else:
				show_notification(killer_won ? "失败..." : "胜利!", 10.0)

func _on_generator_completed():
	# 处理发电机完成事件
	generators_completed += 1
	if game_hud:
		game_hud.update_generators_count(generators_completed, generators_required)
		game_hud.show_notification("发电机已修好! %d/%d" % [generators_completed, generators_required])

func _on_survivor_died(player_id: int):
	_update_survivor_count()

func _on_survivor_escaped(player_id: int):
	_update_survivor_count()

func _on_all_generators_completed():
	if game_hud:
		game_hud.show_notification("所有发电机已修好，出口门已通电!", 5.0)

func _on_exit_gate_powered():
	if game_hud:
		game_hud.show_notification("出口门已通电!", 5.0)

func _on_game_ended(killer_won: bool):
	var message: String
	
	if player_role == "killer":
		message = killer_won ? "胜利!" : "失败..."
	else:
		message = killer_won ? "失败..." : "胜利!"
	
	if game_hud:
		game_hud.show_notification(message, 10.0)

# 玩家状态变化处理
func _on_player_health_changed(new_health_state: int):
	update_player_status()

func _on_player_state_changed(new_state: int):
	update_player_status()

func _on_interaction_started(interactable: Interactable):
	if game_hud:
		game_hud.on_interaction_started(interactable)

func _on_interaction_completed(interactable: Interactable):
	if game_hud:
		game_hud.on_interaction_completed(interactable)

func _on_interaction_canceled():
	if game_hud:
		game_hud.on_interaction_canceled()

func _on_item_obtained(item_name: String, uses: int):
	if game_hud:
		game_hud.update_item_display(item_name, uses)

func _on_item_used(uses_left: int):
	if current_player and current_player.has_method("get_item_name"):
		var item_name = current_player.get_item_name()
		if game_hud:
			game_hud.update_item_display(item_name, uses_left) 