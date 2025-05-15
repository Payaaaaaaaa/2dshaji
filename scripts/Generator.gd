extends Interactable
class_name Generator

# 发电机状态
enum GeneratorState {
	BROKEN,    # 未修理
	REPAIRING, # 修理中
	COMPLETED  # 已修好
}

# 当前状态
var state: int = GeneratorState.BROKEN

# 修理进度 (0-1)
var repair_progress: float = 0.0

# 修理相关
var repairing_survivors = [] # 正在修理的幸存者列表
var repair_speed: float = 0.1 # 每秒修理进度
var repair_boost_per_survivor: float = 0.05 # 每增加一名幸存者的速度提升

# QTE相关
var qte_timer: Timer
var qte_min_interval: float = 5.0 # 最小QTE触发间隔
var qte_max_interval: float = 15.0 # 最大QTE触发间隔
var qte_fail_regress: float = 0.15 # QTE失败倒退百分比

# 破坏相关
var damage_cooldown: float = 0.0
var damage_cooldown_duration: float = 5.0 # 破坏冷却时间

# 视觉和音效
@onready var sprite = $AnimatedSprite2D
@onready var repair_sound = $RepairSound
@onready var complete_sound = $CompleteSound
@onready var explode_sound = $ExplodeSound
@onready var light = $Light2D
@onready var particles = $Particles2D

# 信号
signal repair_progress_changed(progress)
signal generator_completed
signal generator_damaged

# 发电机特有属性
@export var is_completed: bool = false  # 是否修理完成
@export var is_sabotaged: bool = false  # 是否被破坏
@export var skill_check_chance: float = 0.25  # 技能检测触发概率

# 破坏相关
var sabotage_progress: float = 0.0  # 破坏进度
var sabotage_time: float = 2.0  # 破坏所需时间

# 音频和特效资源
@onready var sound_repair = $SoundRepair
@onready var sound_complete = $SoundComplete
@onready var sound_sabotage = $SoundSabotage

# 灯光节点
@onready var light_on = $LightOn
@onready var light_off = $LightOff

func _ready():
	super._ready()  # 调用父类的_ready()
	
	# 初始化状态
	state = GeneratorState.BROKEN
	repair_progress = 0.0
	
	# 应用平衡参数
	apply_balance_settings()
	
	# 创建QTE计时器
	qte_timer = Timer.new()
	qte_timer.one_shot = true
	qte_timer.timeout.connect(_on_qte_timer_timeout)
	add_child(qte_timer)
	
	# 初始化视觉效果
	update_visuals()
	
	# 将发电机添加到组便于管理
	add_to_group("generators")
	
	# 初始化灯光状态
	update_visual_state()

# 应用平衡设置
func apply_balance_settings():
	if GameBalanceManager.instance:
		# 应用发电机维修时间
		repair_speed = 1.0 / GameBalanceManager.instance.generator_repair_time  # 转换维修时间为每秒进度
		repair_boost_per_survivor = GameBalanceManager.instance.repair_speed_per_survivor
		
		# 应用QTE设置
		qte_min_interval = GameBalanceManager.instance.skill_check_min_interval
		qte_max_interval = GameBalanceManager.instance.skill_check_max_interval
		qte_fail_regress = GameBalanceManager.instance.skill_check_fail_regression

# 添加额外同步属性
func setup_additional_syncing(config):
	config.add_property("is_completed")
	config.add_property("is_sabotaged")

# 设置完成状态
func set_completed(value: bool):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_completed", value)
		return
	
	is_completed = value
	
	# 更新是否可交互
	is_interactable = !is_completed
	
	# 通知Game脚本发电机完成
	if is_completed and get_node_or_null("/root/Game"):
		var game = get_node("/root/Game")
		game.on_game_event("generator_completed", {})
	
	# 同步到所有客户端
	rpc("client_set_completed", value)

# 设置破坏状态
func set_sabotaged(value: bool):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_sabotaged", value)
		return
	
	is_sabotaged = value
	
	# 如果被破坏，重置进度
	if is_sabotaged:
		interaction_progress = 0.0
	
	# 同步到所有客户端
	rpc("client_set_sabotaged", value)

# 检查交互权限
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	# 如果已完成，不能再交互
	if is_completed:
		return false
	
	# 杀手可以破坏，幸存者可以修理
	if is_killer:
		# 杀手只能破坏未被破坏的发电机
		return !is_sabotaged and !is_completed
	else:
		# 幸存者只能修理未完成的发电机
		return !is_completed

# 交互完成后的特定逻辑
func on_interaction_completed(player_id: int):
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if !character:
		return
	
	# 检查是否为杀手
	var is_killer = Global.network_manager.is_killer(player_id)
	
	if is_killer:
		# 杀手完成破坏
		set_sabotaged(true)
	else:
		# 幸存者完成修理
		set_completed(true)

# 处理交互进度
func _process(delta):
	super._process(delta)  # 调用父类的_process()
	
	if is_completed:
		return
	
	# 服务器端处理修理进度和技能检测
	if multiplayer.is_server() and is_being_interacted and !is_completed:
		var survivors_count = 0
		
		# 计算修理中的幸存者数量
		for player_id in interacting_players:
			if !Global.network_manager.is_killer(player_id):
				survivors_count += 1
		
		if survivors_count > 0:
			# 计算修理速度
			var base_repair = repair_speed
			var boost_multiplier = 1.0
			
			# 多人修理加成
			if survivors_count > 1:
				for i in range(1, survivors_count):
					boost_multiplier += repair_boost_per_survivor
			
			# 更新修理进度
			var progress_delta = base_repair * boost_multiplier * delta
			interaction_progress += progress_delta
			
			# 修理完成
			if interaction_progress >= 1.0:
				interaction_progress = 1.0
				complete_interaction()
				
			# 同步交互进度到所有客户端
			rpc("client_set_interaction_progress", interaction_progress)
			
			# 修理中随机触发QTE检测
			_handle_qte_triggers(delta, survivors_count)

# 视觉反馈函数实现
func on_interaction_visual_start():
	if sound_repair and !is_completed:
		sound_repair.play()

func on_interaction_visual_cancel():
	if sound_repair and sound_repair.playing:
		sound_repair.stop()

func on_interaction_visual_complete():
	# 播放完成音效
	if is_completed:
		if sound_complete:
			sound_complete.play()
		
		# 启动粒子效果
		if particles:
			particles.emitting = true
	
	# 更新灯光
	update_visual_state()

# 更新视觉状态
func update_visual_state():
	# 更新灯光状态
	if light_on:
		light_on.visible = is_completed
	
	if light_off:
		light_off.visible = !is_completed
	
	# 更新精灵动画
	if sprite.has_method("play"):
		if is_completed:
			sprite.play("completed")
		elif is_being_interacted:
			sprite.play("working")
		else:
			sprite.play("idle")

# RPC处理函数
@rpc("any_peer", "call_local", "reliable")
func server_request_set_completed(value: bool):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器或管理员可以设置完成状态
	if sender_id == 1 or sender_id == get_multiplayer_authority():
		set_completed(value)

@rpc("any_peer", "call_local", "reliable")
func server_request_set_sabotaged(value: bool):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有杀手可以破坏发电机
	if Global.network_manager.is_killer(sender_id):
		set_sabotaged(value)

@rpc("authority", "call_remote", "reliable")
func client_set_completed(value: bool):
	is_completed = value
	is_interactable = !is_completed
	
	# 更新视觉状态
	update_visual_state()
	
	# 如果完成，播放完成音效
	if is_completed and sound_complete:
		sound_complete.play()

@rpc("authority", "call_remote", "reliable")
func client_set_sabotaged(value: bool):
	is_sabotaged = value
	
	# 如果被破坏，播放破坏音效
	if is_sabotaged and sound_sabotage:
		sound_sabotage.play()

# 触发技能检测(服务器调用特定客户端)
@rpc("authority", "call_remote", "reliable")
func trigger_skill_check():
	# 在客户端显示技能检测UI
	# 在实际项目中，这里应该和UI系统交互
	print("触发技能检测!")
	
	# 模拟玩家响应(实际会连接到UI信号)
	var success = randf() > 0.5
	
	# 通知服务器结果
	rpc_id(1, "skill_check_result", success)

# 处理技能检测结果
@rpc("any_peer", "call_local", "reliable")
func skill_check_result(success: bool):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	
	if player_id in interacting_players:
		if success:
			# 技能检测成功，加速进度
			interacting_players[player_id] += 0.2
		else:
			# 技能检测失败，减少进度并发出声音提示
			interacting_players[player_id] -= 0.1
			interacting_players[player_id] = max(0, interacting_players[player_id])
			
			# 通知客户端播放失败音效
			rpc("play_skill_check_fail_sound")

func _physics_process(delta):
	# 处理修理逻辑
	if state == GeneratorState.REPAIRING and repairing_survivors.size() > 0:
		# 计算修理速度
		var total_speed = repair_speed + (repairing_survivors.size() - 1) * repair_boost_per_survivor
		
		# 增加修理进度
		repair_progress += delta * total_speed
		repair_progress = min(repair_progress, 1.0)
		
		# 发送进度变化信号
		emit_signal("repair_progress_changed", repair_progress)
		
		# 更新视觉效果
		update_visuals()
		
		# 检查是否修好
		if repair_progress >= 1.0:
			complete_repair()
	
	# 破坏冷却
	if damage_cooldown > 0:
		damage_cooldown -= delta

# 开始修理
func start_repair(survivor):
	if state == GeneratorState.COMPLETED:
		return false
	
	# 添加到修理列表
	if not survivor in repairing_survivors:
		repairing_survivors.append(survivor)
	
	# 如果是第一个修理者，改变状态
	if repairing_survivors.size() == 1:
		state = GeneratorState.REPAIRING
		
		# 启动QTE计时器
		reset_qte_timer()
		
		# 播放修理音效
		if repair_sound:
			repair_sound.play()
	
	# 更新视觉效果
	update_visuals()
	
	return true

# 停止修理
func stop_repair(survivor):
	# 从修理列表移除
	if survivor in repairing_survivors:
		repairing_survivors.erase(survivor)
	
	# 如果没有人修理了，改变状态
	if repairing_survivors.size() == 0:
		state = GeneratorState.BROKEN
		
		# 停止QTE计时器
		qte_timer.stop()
		
		# 停止修理音效
		if repair_sound and repair_sound.playing:
			repair_sound.stop()
	
	# 更新视觉效果
	update_visuals()

# 完成修理
func complete_repair():
	if state == GeneratorState.COMPLETED:
		return
	
	state = GeneratorState.COMPLETED
	repair_progress = 1.0
	
	# 清空修理列表
	repairing_survivors.clear()
	
	# 停止计时器
	qte_timer.stop()
	
	# 停止修理音效
	if repair_sound and repair_sound.playing:
		repair_sound.stop()
	
	# 播放完成音效
	if complete_sound:
		complete_sound.play()
	
	# 更新视觉效果
	update_visuals()
	
	# 发送完成信号
	emit_signal("generator_completed")
	
	# 通知游戏管理器
	if multiplayer.is_server():
		Global.generator_completed()

# 处理QTE触发
func _on_qte_timer_timeout():
	if state != GeneratorState.REPAIRING or repairing_survivors.size() == 0:
		return
	
	# 随机选择一名修理者触发QTE
	var target_survivor = repairing_survivors[randi() % repairing_survivors.size()]
	
	# 通知该幸存者
	if multiplayer.is_server():
		target_survivor.rpc("trigger_qte")
	
	# 重置计时器
	reset_qte_timer()

# 重置QTE计时器
func reset_qte_timer():
	var interval = randf_range(qte_min_interval, qte_max_interval)
	qte_timer.wait_time = interval
	qte_timer.start()

# QTE成功
func qte_success(survivor):
	# 无特殊效果，继续修理
	pass

# QTE失败
func qte_failed(survivor):
	# 发电机爆炸，进度倒退
	explode()

# 发电机爆炸
func explode():
	# 倒退进度
	repair_progress = max(0.0, repair_progress - qte_fail_regress)
	
	# 播放爆炸音效
	if explode_sound:
		explode_sound.play()
	
	# 播放爆炸特效
	if particles:
		particles.emitting = true
		particles.amount = 30
		particles.lifetime = 1.0
	
	# 通知UI更新进度
	emit_signal("repair_progress_changed", repair_progress)
	
	# 重设特效
	get_tree().create_timer(1.0).timeout.connect(func(): 
		if particles:
			particles.amount = 5
	)

# 被杀手破坏
func damage(amount: float = 0.1):
	if state == GeneratorState.COMPLETED or damage_cooldown > 0:
		return
	
	# 倒退进度
	repair_progress = max(0.0, repair_progress - amount)
	
	# 设置破坏冷却
	damage_cooldown = damage_cooldown_duration
	
	# 播放破坏音效和特效
	explode()
	
	# 发送破坏信号
	emit_signal("generator_damaged")

# 更新视觉效果
func update_visuals():
	match state:
		GeneratorState.BROKEN:
			if sprite:
				sprite.play("broken")
			if light:
				light.energy = 0.2 + repair_progress * 0.3
		GeneratorState.REPAIRING:
			if sprite:
				sprite.play("repairing")
			if light:
				light.energy = 0.5 + repair_progress * 0.3
			if particles:
				particles.emitting = true
		GeneratorState.COMPLETED:
			if sprite:
				sprite.play("completed")
			if light:
				light.energy = 1.0
			if particles:
				particles.emitting = true

# 获取当前进度
func get_progress() -> float:
	return repair_progress

# 检查是否可以修理
func can_be_repaired() -> bool:
	return state != GeneratorState.COMPLETED

# 获取当前状态文本
func get_state_text() -> String:
	match state:
		GeneratorState.BROKEN:
			if repair_progress == 0:
				return "待修理"
			else:
				return "已修理 %d%%" % int(repair_progress * 100)
		GeneratorState.REPAIRING:
			return "修理中 %d%%" % int(repair_progress * 100)
		GeneratorState.COMPLETED:
			return "已修好"
	return ""

# 处理QTE触发
func _handle_qte_triggers(delta: float, survivors_count: int):
	# QTE触发逻辑
	if qte_timer and !qte_timer.is_stopped():
		return  # 如果定时器正在运行，不再触发新的QTE
	
	# 根据修理进度调整QTE难度和频率
	var progress_factor = repair_progress
	var base_chance = skill_check_chance * (1.0 + progress_factor)  # 随着进度增加，QTE概率提高
	
	# 按幸存者数量添加随机概率
	for i in range(survivors_count):
		if randf() < base_chance * delta:
			# 随机选择一个正在修理的幸存者触发QTE
			var survivor_index = randi() % survivors_count
			var target_player = interacting_players[survivor_index]
			
			# 设置QTE难度和成功区域大小
			var difficulty = GameBalanceManager.instance.skill_check_base_difficulty
			var zone_size = GameBalanceManager.instance.skill_check_zone_size
			
			# 根据修理进度调整难度
			difficulty += progress_factor * 0.2  # 进度越高难度越大
			zone_size *= (1.0 - progress_factor * 0.3)  # 进度越高成功区域越小
			
			# 发送QTE触发到客户端
			rpc_id(target_player, "trigger_skill_check", difficulty, zone_size)
			
			# 启动QTE间隔定时器
			qte_timer.wait_time = randf_range(qte_min_interval, qte_max_interval)
			qte_timer.start()
			
			break  # 每次只对一名玩家触发QTE

# 技能检测失败处理
@rpc("authority", "call_local", "reliable")
func on_skill_check_failure(player_id: int):
	# 在服务器确认技能检测失败
	if multiplayer.is_server():
		# 倒退修理进度
		interaction_progress = max(0.0, interaction_progress - qte_fail_regress)
		
		# 发出爆炸音效和特效
		rpc("client_generate_explosion", player_id)
		
		# 同步进度到所有客户端
		rpc("client_set_interaction_progress", interaction_progress) 