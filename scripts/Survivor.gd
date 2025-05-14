extends Character
class_name Survivor

# 幸存者特有状态
enum SurvivorState {
	IDLE,      # 待命/移动
	REPAIRING, # 修理中
	HELPING,   # 救援/治疗中
	CARRIED,   # 被扛起
	HOOKED     # 被挂钩
}

# 当前幸存者状态
var survivor_state: int = SurvivorState.IDLE

# 状态计时器
var state_timer: float = 0.0

# 修理相关
var current_generator = null
var repair_progress: float = 0.0

# 被挂钩相关
var hook_struggle_timer: float = 0.0
var hook_stage: int = 0  # 0=第一阶段, 1=挣扎阶段
var hook_death_time: float = 60.0  # 默认60秒倒计时

# 被扛起相关
var wiggle_progress: float = 0.0
var wiggle_threshold: float = 100.0
var carrier = null

# 其他玩家特性
var has_medkit: bool = false

# 节点引用
@onready var struggle_timer = $StruggleTimer

func _ready():
	super._ready()
	walk_speed = 110.0
	run_speed = 160.0
	
	# 创建挣扎计时器(从钩子上)
	struggle_timer = Timer.new()
	struggle_timer.one_shot = true
	add_child(struggle_timer)
	struggle_timer.timeout.connect(_on_struggle_timer_timeout)

func _physics_process(delta):
	super._physics_process(delta)
	
	if !is_local_player:
		return
	
	# 被扛起时的挣扎逻辑
	if survivor_state == SurvivorState.CARRIED and carrier != null:
		if Input.is_action_pressed("wiggle"):
			wiggle_progress += delta * 20.0
			if wiggle_progress >= wiggle_threshold:
				rpc_id(1, "try_escape_from_carrier")
				wiggle_progress = 0.0
	
	# 被挂钩时的挣扎逻辑
	if survivor_state == SurvivorState.HOOKED:
		if Input.is_action_pressed("struggle") and hook_stage == 1:
			# 延缓死亡
			hook_death_time += delta * 0.5
			# 很小概率自救
			if randf() < 0.001:  # 0.1%自救几率
				rpc_id(1, "try_self_unhook")
	
	# 更新UI显示(实际项目中应连接到UI更新)
	update_ui()

# 覆盖基类的交互方法
func interact_with(object):
	if !can_interact or survivor_state != SurvivorState.IDLE:
		return
	
	if object is Generator:
		start_repair(object)
	elif object is Survivor and object.health_state == HealthState.DOWNED:
		start_helping(object)
	elif object is Hook and object.has_survivor():
		start_unhooking(object)
	elif object is ExitGate and object.is_powered:
		start_opening(object)

# 开始修理发电机
func start_repair(generator):
	if generator == null or survivor_state != SurvivorState.IDLE:
		return
	
	current_generator = generator
	change_survivor_state(SurvivorState.REPAIRING)
	rpc_id(1, "server_start_repair", generator.get_path())

# 请求服务器开始修理
@rpc("any_peer", "call_remote", "reliable")
func server_start_repair(generator_path):
	var generator = get_node_or_null(generator_path)
	if generator == null:
		return
	
	# 服务器验证并广播开始修理
	if multiplayer.get_remote_sender_id() == player_id and generator.can_be_repaired():
		generator.start_repair(self)
		rpc("client_update_repair_state", true, generator_path)

# 服务器通知客户端更新修理状态
@rpc("authority", "call_remote", "reliable")
func client_update_repair_state(is_repairing, generator_path):
	if is_repairing:
		var generator = get_node_or_null(generator_path)
		if generator != null:
			current_generator = generator
			change_survivor_state(SurvivorState.REPAIRING)
	else:
		current_generator = null
		change_survivor_state(SurvivorState.IDLE)

# 停止修理
func stop_repair():
	if survivor_state == SurvivorState.REPAIRING and current_generator != null:
		rpc_id(1, "server_stop_repair", current_generator.get_path())
		current_generator = null
		change_survivor_state(SurvivorState.IDLE)

# 请求服务器停止修理
@rpc("any_peer", "call_remote", "reliable")
func server_stop_repair(generator_path):
	var generator = get_node_or_null(generator_path)
	if generator == null:
		return
	
	# 服务器验证并广播停止修理
	if multiplayer.get_remote_sender_id() == player_id:
		generator.stop_repair(self)
		rpc("client_update_repair_state", false, "")

# 处理QTE事件
func handle_qte_event(success: bool):
	if survivor_state == SurvivorState.REPAIRING and current_generator != null:
		rpc_id(1, "server_qte_result", current_generator.get_path(), success)

# 向服务器报告QTE结果
@rpc("any_peer", "call_remote", "reliable")
func server_qte_result(generator_path, success):
	var generator = get_node_or_null(generator_path)
	if generator == null:
		return
	
	# 服务器处理QTE结果
	if multiplayer.get_remote_sender_id() == player_id:
		if success:
			# QTE成功，继续修理
			generator.qte_success(self)
		else:
			# QTE失败，可能爆炸并中断修理
			generator.qte_failed(self)
			rpc("client_update_repair_state", false, "")

# 开始救援倒地的幸存者
func start_helping(survivor):
	if survivor == null or survivor.health_state != HealthState.DOWNED:
		return
		
	rpc_id(1, "server_start_helping", survivor.get_path())
	change_survivor_state(SurvivorState.HELPING)

# 请求服务器开始救援
@rpc("any_peer", "call_remote", "reliable")
func server_start_helping(survivor_path):
	var survivor_to_help = get_node_or_null(survivor_path)
	if survivor_to_help == null:
		return
	
	# 服务器验证并处理救援
	if multiplayer.get_remote_sender_id() == player_id and survivor_to_help.health_state == HealthState.DOWNED:
		# 这里可以添加救援进度逻辑
		# 为简化，这里直接恢复被救者状态
		survivor_to_help.rpc("client_revive")
		rpc("client_update_helping_state", false)

# 客户端被救援
@rpc("authority", "call_remote", "reliable")
func client_revive():
	if health_state == HealthState.DOWNED:
		change_health_state(HealthState.INJURED)
		change_survivor_state(SurvivorState.IDLE)
		play_sound("revive")

# 服务器通知客户端更新救援状态
@rpc("authority", "call_remote", "reliable")
func client_update_helping_state(is_helping):
	if is_helping:
		change_survivor_state(SurvivorState.HELPING)
	else:
		change_survivor_state(SurvivorState.IDLE)

# 从钩子上救下队友
func start_unhooking(hook):
	if hook == null or !hook.has_survivor():
		return
		
	rpc_id(1, "server_start_unhooking", hook.get_path())
	change_survivor_state(SurvivorState.HELPING)

# 请求服务器从钩子救人
@rpc("any_peer", "call_remote", "reliable")
func server_start_unhooking(hook_path):
	var hook = get_node_or_null(hook_path)
	if hook == null or !hook.has_survivor():
		return
	
	# 服务器验证并处理救援
	if multiplayer.get_remote_sender_id() == player_id:
		hook.unhook_survivor(self)
		rpc("client_update_helping_state", false)

# 被杀手扛起
func get_carried(killer):
	if health_state != HealthState.DOWNED:
		return false
		
	carrier = killer
	change_survivor_state(SurvivorState.CARRIED)
	wiggle_progress = 0.0
	return true

# 尝试从扛起状态挣脱
@rpc("any_peer", "call_remote", "reliable")
func try_escape_from_carrier():
	if multiplayer.get_remote_sender_id() != player_id or survivor_state != SurvivorState.CARRIED:
		return
		
	# 服务器决定是否允许逃脱
	if multiplayer.is_server():
		# 通知杀手幸存者已挣脱
		if carrier != null:
			carrier.rpc("survivor_escaped", get_path())
		
		# 重置状态为倒地
		change_survivor_state(SurvivorState.IDLE)
		carrier = null
		global_position += Vector2(randf_range(-50, 50), randf_range(-50, 50))
		
		# 通知客户端
		rpc("client_escaped_from_carrier")

# 客户端被挂钩
@rpc("authority", "call_remote", "reliable")
func client_hooked(hook_path):
	var hook = get_node_or_null(hook_path)
	if hook == null:
		return
	
	carrier = null
	change_survivor_state(SurvivorState.HOOKED)
	hook_stage = 0
	hook_death_time = 60.0  # 第一阶段60秒
	struggle_timer.start(hook_death_time)
	play_sound("hooked")

# 客户端从杀手身上逃脱
@rpc("authority", "call_remote", "reliable")
func client_escaped_from_carrier():
	if survivor_state == SurvivorState.CARRIED:
		change_survivor_state(SurvivorState.IDLE)
		change_health_state(HealthState.DOWNED)
		carrier = null
		play_sound("escape")

# 尝试从钩子自救
@rpc("any_peer", "call_remote", "reliable")
func try_self_unhook():
	if multiplayer.get_remote_sender_id() != player_id or survivor_state != SurvivorState.HOOKED:
		return
		
	# 服务器决定是否允许自救
	if multiplayer.is_server():
		# 找到钩子并解钩
		var hooks = get_tree().get_nodes_in_group("hooks")
		for hook in hooks:
			if hook.has_survivor() and hook.current_survivor == self:
				hook.unhook_survivor(self)
				break

# 覆盖基类的take_damage方法
func take_damage(attacker = null):
	# 如果正在修理，先停止
	if survivor_state == SurvivorState.REPAIRING:
		stop_repair()
	
	# 调用基类方法处理实际伤害
	super.take_damage(attacker)

# 幸存者被挂钩计时器超时处理
func _on_struggle_timer_timeout():
	if survivor_state == SurvivorState.HOOKED:
		if hook_stage == 0:
			# 进入挣扎阶段
			hook_stage = 1
			hook_death_time = 30.0  # 挣扎阶段只有30秒
			struggle_timer.start(hook_death_time)
			play_sound("struggle")
		else:
			# 死亡
			die()

# 实现基类的die方法
func die():
	super.die()
	
	# 通知服务器此幸存者已死亡
	if multiplayer.is_server():
		Global.survivors_alive -= 1
		Global.check_game_end()
	else:
		rpc_id(1, "server_survivor_died")

# 通知服务器幸存者死亡
@rpc("any_peer", "call_remote", "reliable")
func server_survivor_died():
	if multiplayer.get_remote_sender_id() == player_id and multiplayer.is_server():
		Global.survivors_alive -= 1
		Global.check_game_end()

# 尝试逃离出口
func start_opening(exit_gate):
	if exit_gate == null or !exit_gate.is_powered:
		return
		
	rpc_id(1, "server_try_escape", exit_gate.get_path())

# 请求服务器尝试逃脱
@rpc("any_peer", "call_remote", "reliable")
func server_try_escape(gate_path):
	var gate = get_node_or_null(gate_path)
	if gate == null or !gate.is_powered:
		return
	
	# 服务器验证并处理逃脱
	if multiplayer.get_remote_sender_id() == player_id:
		# 逃脱成功
		Global.survivor_escaped += 1
		Global.check_game_end()
		rpc("client_escaped")

# 客户端逃脱
@rpc("authority", "call_remote", "reliable")
func client_escaped():
	play_sound("escape")
	# 隐藏玩家或播放逃脱效果
	visible = false
	can_move = false
	can_interact = false
	# 可能切换到观察者模式

# 更改幸存者状态
func change_survivor_state(new_state):
	survivor_state = new_state
	
	# 根据状态调整可移动和可交互性
	match new_state:
		SurvivorState.IDLE:
			can_move = (health_state != HealthState.DOWNED)
			can_interact = (health_state != HealthState.DOWNED)
		SurvivorState.REPAIRING, SurvivorState.HELPING:
			can_move = false
			can_interact = false
		SurvivorState.CARRIED, SurvivorState.HOOKED:
			can_move = false
			can_interact = false
	
	# 更新动画
	update_animation()

# 更新动画
func update_animation():
	match survivor_state:
		SurvivorState.IDLE:
			if health_state == HealthState.DOWNED:
				play_animation("crawl")
			elif velocity.length() > 0:
				if is_running:
					play_animation("run")
				else:
					play_animation("walk")
			else:
				play_animation("idle")
		SurvivorState.REPAIRING:
			play_animation("repair")
		SurvivorState.HELPING:
			play_animation("helping")
		SurvivorState.CARRIED:
			play_animation("carried")
		SurvivorState.HOOKED:
			play_animation("hooked")

# 更新UI
func update_ui():
	# 实际项目中这里应连接到UI更新
	# 可以发出信号更新血量、状态、修理进度等
	pass 