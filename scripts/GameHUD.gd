extends CanvasLayer
class_name MainGameHUD

# UI组件引用
@onready var survivor_hud = $SurvivorHUD
@onready var killer_hud = $KillerHUD
@onready var interaction_prompt = $InteractionPrompt
@onready var qte = $QTE

# 状态标签
@onready var game_state_label = $GameInfoPanel/VBoxContainer/GameStateLabel
@onready var generators_label = $GameInfoPanel/VBoxContainer/InfoContainer/GeneratorsLabel
@onready var survivors_label = $GameInfoPanel/VBoxContainer/InfoContainer/SurvivorsLabel
@onready var timer_label = $GameInfoPanel/VBoxContainer/InfoContainer/TimerLabel

# 幸存者UI
@onready var health_bar = $SurvivorHUD/HealthBar
@onready var health_label = $SurvivorHUD/HealthBar/HealthLabel
@onready var objectives_list = $SurvivorHUD/ObjectivesList
@onready var repair_generators_label = $SurvivorHUD/ObjectivesList/RepairGenerators
@onready var open_exit_gate_label = $SurvivorHUD/ObjectivesList/OpenExitGate
@onready var escape_label = $SurvivorHUD/ObjectivesList/Escape

# 杀手UI
@onready var power_bar = $KillerHUD/PowerBar
@onready var survivor_status_container = $KillerHUD/SurvivorStatus
@onready var survivor_status_rows = [
	$KillerHUD/SurvivorStatus/Survivor1,
	$KillerHUD/SurvivorStatus/Survivor2,
	$KillerHUD/SurvivorStatus/Survivor3,
	$KillerHUD/SurvivorStatus/Survivor4
]

# 游戏逻辑引用
var game_logic
var global

# 游戏时间
var game_time: float = 0.0
var is_game_active: bool = false

# 玩家角色
var is_killer: bool = false

func _ready():
	# 获取全局单例引用
	global = get_node("/root/Global")
	
	# 获取游戏逻辑引用
	game_logic = get_parent().get_node("GameLogic") if get_parent().has_node("GameLogic") else null
	
	# 连接信号
	if game_logic:
		game_logic.game_state_changed.connect(_on_game_state_changed)
		game_logic.generator_completed.connect(_on_generator_completed)
		game_logic.exit_gates_powered.connect(_on_exit_gates_powered)
		game_logic.survivor_escaped.connect(_on_survivor_escaped)
		game_logic.survivor_died.connect(_on_survivor_died)
		game_logic.game_ended.connect(_on_game_ended)
	
	# 连接QTE信号
	qte.completed.connect(_on_qte_completed)
	qte.key_hit.connect(_on_qte_key_hit)
	
	# 设置玩家角色UI
	if global:
		is_killer = global.is_killer
		survivor_hud.visible = !is_killer
		killer_hud.visible = is_killer
	
	# 初始化UI
	update_game_state_label()
	update_generators_label()
	update_survivors_label()
	
	# 暂时隐藏交互提示和QTE
	interaction_prompt.visible = false
	qte.visible = false

func _process(delta):
	# 更新游戏时间
	if is_game_active:
		game_time += delta
		update_timer_label()

# 当游戏状态改变时
func _on_game_state_changed(new_state):
	update_game_state_label()
	
	# 如果游戏开始，开始计时
	is_game_active = new_state == GameLogic.GameState.PLAYING
	
	# 如果是游戏结束，停止计时
	if new_state == GameLogic.GameState.ENDING:
		is_game_active = false

# 当发电机完成时
func _on_generator_completed(_generator):
	update_generators_label()
	
	# 勾选幸存者目标
	if game_logic and game_logic.completed_generators >= game_logic.required_generators:
		repair_generators_label.text = "✓ 修理发电机 (%d/%d)" % [game_logic.completed_generators, game_logic.required_generators]
	else:
		repair_generators_label.text = "□ 修理发电机 (%d/%d)" % [game_logic.completed_generators, game_logic.required_generators]

# 当出口门通电时
func _on_exit_gates_powered():
	# 更新状态标签
	game_state_label.text = "出口门已通电!"
	game_state_label.modulate = Color(0, 1, 0) # 绿色

# 当幸存者逃脱时
func _on_survivor_escaped(_survivor):
	update_survivors_label()
	
	# 更新目标
	escape_label.text = "✓ 逃离"

# 当幸存者死亡时
func _on_survivor_died(_survivor):
	update_survivors_label()

# 当游戏结束时
func _on_game_ended(survivors_win):
	# 根据胜利方显示不同信息
	if survivors_win:
		game_state_label.text = "幸存者胜利!"
		game_state_label.modulate = Color(0, 1, 0) # 绿色
	else:
		game_state_label.text = "杀手胜利!"
		game_state_label.modulate = Color(1, 0, 0) # 红色

# 当QTE完成时
func _on_qte_completed(success):
	# 发送信号给接收者（通常是游戏对象，如发电机等）
	if get_parent().has_method("on_qte_completed"):
		get_parent().on_qte_completed(success)

# 当QTE中点击按键时
func _on_qte_key_hit(success):
	# 可以在这里添加音效或视觉反馈
	pass

# 更新游戏状态标签
func update_game_state_label():
	if game_logic:
		match game_logic.current_state:
			GameLogic.GameState.WAITING:
				game_state_label.text = "等待玩家..."
				game_state_label.modulate = Color(1, 1, 1) # 白色
			GameLogic.GameState.PREPARING:
				game_state_label.text = "准备游戏..."
				game_state_label.modulate = Color(1, 1, 0) # 黄色
			GameLogic.GameState.PLAYING:
				game_state_label.text = "游戏进行中"
				game_state_label.modulate = Color(0, 0.5, 1) # 蓝色
			GameLogic.GameState.ENDING:
				game_state_label.text = "游戏结束"
				game_state_label.modulate = Color(1, 1, 1) # 白色

# 更新发电机标签
func update_generators_label():
	if game_logic:
		generators_label.text = "发电机: %d/%d" % [game_logic.completed_generators, game_logic.required_generators]

# 更新幸存者标签
func update_survivors_label():
	if game_logic:
		var alive = game_logic.survivors.size() - game_logic.dead_survivors - game_logic.escaped_survivors
		var total = game_logic.survivors.size()
		survivors_label.text = "幸存者: %d/%d" % [alive, total]
		
		# 更新杀手UI中的幸存者状态
		update_killer_survivor_status()

# 更新计时器标签
func update_timer_label():
	var minutes = int(game_time / 60)
	var seconds = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

# 更新杀手UI中的幸存者状态
func update_killer_survivor_status():
	if !is_killer or !game_logic or !game_logic.survivors:
		return
	
	# 遍历所有幸存者
	for i in range(min(game_logic.survivors.size(), survivor_status_rows.size())):
		var survivor = game_logic.survivors[i]
		var row = survivor_status_rows[i]
		var name_label = row.get_node("Name")
		var status_label = row.get_node("Status")
		
		# 更新名称
		name_label.text = survivor.player_name if survivor.has("player_name") else "幸存者%d" % (i + 1)
		
		# 更新状态
		var status_text = "健康"
		var status_color = Color(0, 1, 0)  # 绿色
		
		if survivor.has("state"):
			match survivor.state:
				0:  # IDLE/健康
					status_text = "健康"
					status_color = Color(0, 1, 0)  # 绿色
				1:  # INJURED/受伤
					status_text = "受伤"
					status_color = Color(1, 0.5, 0)  # 橙色
				2:  # DYING/垂死
					status_text = "垂死"
					status_color = Color(1, 0, 0)  # 红色
				3:  # HOOKED/被挂
					status_text = "被挂"
					status_color = Color(1, 0, 0)  # 红色
				4:  # ESCAPED/逃脱
					status_text = "逃脱"
					status_color = Color(0, 0.5, 1)  # 蓝色
				5:  # DEAD/死亡
					status_text = "死亡"
					status_color = Color(0.5, 0.5, 0.5)  # 灰色
		
		status_label.text = status_text
		status_label.modulate = status_color

# 更新幸存者健康状态
func update_survivor_health(health: int):
	if is_killer:
		return
	
	health_bar.value = health
	
	match health:
		2:  # 健康
			health_label.text = "健康"
			health_bar.modulate = Color(0, 1, 0)  # 绿色
		1:  # 受伤
			health_label.text = "受伤"
			health_bar.modulate = Color(1, 0.5, 0)  # 橙色
		0:  # 垂死
			health_label.text = "垂死"
			health_bar.modulate = Color(1, 0, 0)  # 红色

# 显示交互提示
func show_interaction_prompt(object_type: int, custom_text: String = "", custom_actions = null):
	interaction_prompt.show_prompt(object_type, custom_text, custom_actions)

# 隐藏交互提示
func hide_interaction_prompt():
	interaction_prompt.hide_prompt()

# 开始QTE
func start_qte(difficulty: float = 1.0, time_limit: float = 5.0, hits_required: int = 3):
	qte.difficulty = difficulty
	qte.time_limit = time_limit
	qte.min_hits_required = hits_required
	qte.start()

# 停止QTE
func stop_qte():
	qte.stop() 