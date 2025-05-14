extends Node
class_name GameLogic

# 游戏状态
enum GameState {
	WAITING,      # 等待玩家加入
	PREPARING,    # 准备阶段
	PLAYING,      # 游戏进行中
	ENDING        # 游戏结束
}

# 游戏配置
@export var required_generators: int = 5  # 需要修理的发电机数量
@export var generator_count: int = 7      # 地图上的发电机总数
@export var hook_count: int = 8           # 地图上的钩子总数
@export var pallet_count: int = 12        # 地图上的木板总数

# 当前游戏状态
var current_state: int = GameState.WAITING
var completed_generators: int = 0
var exit_gates_powered: bool = false
var escaped_survivors: int = 0
var dead_survivors: int = 0

# 网络同步属性
@export var sync_state: int = GameState.WAITING:
	set(value):
		sync_state = value
		current_state = value
		_on_game_state_changed()

@export var sync_completed_generators: int = 0:
	set(value):
		sync_completed_generators = value
		completed_generators = value
		if value >= required_generators:
			power_exit_gates()

@export var sync_escaped_survivors: int = 0:
	set(value):
		sync_escaped_survivors = value
		escaped_survivors = value
		check_game_end()

@export var sync_dead_survivors: int = 0:
	set(value):
		sync_dead_survivors = value
		dead_survivors = value
		check_game_end()

# 连接到Global单例
var global

# 引用各个游戏对象组
var generators: Array = []
var hooks: Array = []
var pallets: Array = []
var exit_gates: Array = []
var survivors: Array = []
var killer = null

# 信号
signal generator_completed(generator)
signal exit_gates_powered
signal game_state_changed(new_state)
signal survivor_escaped(survivor)
signal survivor_died(survivor)
signal game_ended(winner)

func _ready():
	# 获取全局单例引用
	global = get_node("/root/Global")
	
	# 连接到全局信号
	if global:
		global.game_started.connect(_on_game_started)
	
	# 初始化游戏对象引用
	_initialize_game_objects()
	
	# 设置初始状态
	current_state = GameState.WAITING
	sync_state = GameState.WAITING

# 初始化各种游戏对象引用
func _initialize_game_objects():
	generators = get_tree().get_nodes_in_group("generators")
	hooks = get_tree().get_nodes_in_group("hooks")
	pallets = get_tree().get_nodes_in_group("pallets")
	exit_gates = get_tree().get_nodes_in_group("exit_gates")
	
	# 连接发电机完成信号
	for generator in generators:
		generator.generator_completed.connect(_on_generator_completed)
	
	# 连接出口门信号
	for gate in exit_gates:
		gate.survivor_escaped.connect(_on_survivor_escaped)

# 当游戏开始时
func _on_game_started():
	# 只有服务器才能控制游戏状态
	if global.is_server():
		set_game_state.rpc(GameState.PREPARING)
		
		# 2秒后进入游戏状态
		get_tree().create_timer(2.0).timeout.connect(func():
			set_game_state.rpc(GameState.PLAYING)
		)

# 当发电机完成时
func _on_generator_completed(generator):
	if global.is_server():
		increment_completed_generators.rpc()
		emit_signal("generator_completed", generator)

# 当幸存者逃脱时
func _on_survivor_escaped(survivor):
	if global.is_server():
		increment_escaped_survivors.rpc()
		emit_signal("survivor_escaped", survivor)

# 当幸存者死亡时
func on_survivor_died(survivor):
	if global.is_server():
		increment_dead_survivors.rpc()
		emit_signal("survivor_died", survivor)

# 给出口门供电
func power_exit_gates():
	if not exit_gates_powered:
		exit_gates_powered = true
		
		# 通知所有出口门
		for gate in exit_gates:
			gate.set_powered.rpc(true)
		
		emit_signal("exit_gates_powered")

# 检查游戏是否结束
func check_game_end():
	if current_state != GameState.PLAYING:
		return
		
	# 获取幸存者总数
	var total_survivors = survivors.size()
	
	# 如果所有幸存者都逃脱或死亡，游戏结束
	if escaped_survivors + dead_survivors >= total_survivors:
		var survivors_win = escaped_survivors > 0
		end_game.rpc(survivors_win)

# 游戏状态改变时
func _on_game_state_changed():
	emit_signal("game_state_changed", current_state)
	
	# 根据不同状态执行相应逻辑
	match current_state:
		GameState.WAITING:
			print("游戏等待中...")
		GameState.PREPARING:
			print("游戏准备中...")
		GameState.PLAYING:
			print("游戏开始!")
		GameState.ENDING:
			print("游戏结束!")

# RPC函数 - 设置游戏状态
@rpc("authority", "call_local")
func set_game_state(new_state: int):
	sync_state = new_state

# RPC函数 - 增加完成的发电机数量
@rpc("authority", "call_local")
func increment_completed_generators():
	sync_completed_generators += 1

# RPC函数 - 增加逃脱的幸存者数量
@rpc("authority", "call_local")
func increment_escaped_survivors():
	sync_escaped_survivors += 1

# RPC函数 - 增加死亡的幸存者数量
@rpc("authority", "call_local")
func increment_dead_survivors():
	sync_dead_survivors += 1

# RPC函数 - 结束游戏
@rpc("authority", "call_local")
func end_game(survivors_win: bool):
	current_state = GameState.ENDING
	sync_state = GameState.ENDING
	
	emit_signal("game_ended", survivors_win)
	
	# 延迟几秒后返回大厅
	get_tree().create_timer(5.0).timeout.connect(func():
		global.return_to_lobby.rpc()
	)

# 更新玩家引用
func update_players():
	survivors = get_tree().get_nodes_in_group("survivors")
	
	var killers = get_tree().get_nodes_in_group("killers")
	if killers.size() > 0:
		killer = killers[0] 