extends Interactable
class_name Hook

# 钩子状态枚举
enum HookState {
	IDLE,           # 空闲状态
	HOOKED,         # 有人被挂上
	SABOTAGED       # 被破坏
}

# 钩子特有属性
@export var current_state: int = HookState.IDLE
@export var sacrifice_progress: float = 0.0
@export var max_sacrifice_time: float = 60.0  # 完全牺牲所需时间
@export var struggle_time: float = 30.0  # 挣扎可持续时间

# 挣扎和救援设置
var first_hook_time: float = 60.0  # 首次被挂时间
var second_hook_time: float = 30.0  # 第二次被挂时间
var struggle_timer: float = 0.0  # 挣扎倒计时
var hook_stage: int = 0  # 挂钩阶段: 0=第一次, 1=挣扎阶段, 2=第二次(危险)
var self_unhook_chance: float = 0.04  # 自救基础概率
var max_self_unhook_attempts: int = 3  # 最大自救尝试次数
var self_unhook_attempts: int = 0  # 当前自救尝试次数

# 当前挂在钩子上的幸存者
var hooked_survivor_id: int = -1
var struggle_progress: float = 0.0  # 挣扎进度

# 音频资源
@onready var sound_hook = $SoundHook
@onready var sound_struggle = $SoundStruggle
@onready var sound_sacrifice = $SoundSacrifice

# 视觉效果
@onready var blood_effect = $BloodEffect
@onready var aura_effect = $AuraEffect

func _ready():
	super._ready()
	
	# 应用平衡设置
	apply_balance_settings()
	
	# 初始化视觉状态
	update_visual_state()
	
	# 添加到钩子组
	add_to_group("hooks")

# 添加额外同步属性
func setup_additional_syncing(config):
	config.add_property("current_state")
	config.add_property("sacrifice_progress")
	config.add_property("hooked_survivor_id")
	config.add_property("struggle_progress")

# 逻辑更新
func _process(delta):
	super._process(delta)
	
	# 服务器处理钩子逻辑
	if multiplayer.is_server():
		match current_state:
			HookState.HOOKED:
				# 减少挣扎时间
				struggle_timer -= delta
				
				# 同步挣扎进度到客户端
				var progress = struggle_timer / (hook_stage == 0 ? first_hook_time : second_hook_time)
				rpc("update_struggle_progress", progress)
				
				# 挣扎时间结束
				if struggle_timer <= 0:
					handle_struggle_timeout()

# 设置钩子状态
func set_state(new_state: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_state", new_state)
		return
	
	var old_state = current_state
	current_state = new_state
	
	# 根据状态变化处理
	match new_state:
		HookState.IDLE:
			sacrifice_progress = 0.0
			struggle_progress = 0.0
			hooked_survivor_id = -1
			is_interactable = true
			
		HookState.HOOKED:
			struggle_progress = 0.0
			is_interactable = true
			
		HookState.SABOTAGED:
			is_interactable = false
	
	# 同步到所有客户端
	rpc("client_set_state", new_state)
	
	# 更新视觉状态
	update_visual_state()

# 钩住幸存者
func hook_survivor(player_id: int, has_been_hooked_before: bool = false):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_hook_survivor", player_id)
		return
	
	# 检查钩子是否为空
	if current_state != HookState.IDLE:
		return
	
	# 获取幸存者引用
	var survivor = get_node_or_null("/root/Game/Players/" + str(player_id))
	if not survivor or not survivor is Character or survivor.is_killer():
		return
	
	# 设置钩子状态
	set_state(HookState.HOOKED)
	hooked_survivor_id = player_id
	
	# 确定挂钩阶段
	if has_been_hooked_before:
		hook_stage = 2  # 第二次被挂(危险阶段)
		struggle_timer = second_hook_time
	else:
		hook_stage = 0  # 首次被挂
		struggle_timer = first_hook_time
	
	# 重置自救尝试次数
	self_unhook_attempts = 0
	
	# 获取幸存者引用
	if survivor:
		# 设置幸存者状态
		survivor.server_set_variable("health_state", survivor.HealthState.DOWNED)
		
		# 移动幸存者到钩子位置
		survivor.global_position = global_position
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("survivor_hooked", {"hook": get_path(), "player_id": player_id})

# 从钩子上救下幸存者
func rescue_survivor(rescuer_id: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_rescue_survivor", rescuer_id)
		return
	
	# 检查是否有幸存者在钩子上
	if current_state == HookState.IDLE or hooked_survivor_id == -1:
		return
	
	# 获取被钩幸存者引用
	var survivor = get_node_or_null("/root/Game/Players/" + str(hooked_survivor_id))
	if survivor:
		# 设置幸存者状态
		survivor.server_set_variable("health_state", survivor.HealthState.INJURED)
		
		# 移动幸存者到救援者旁边
		var rescuer = get_node_or_null("/root/Game/Players/" + str(rescuer_id))
		if rescuer:
			survivor.global_position = rescuer.global_position + Vector2(50, 0)
	
	# 重置钩子状态
	set_state(HookState.IDLE)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("survivor_rescued", {"hook": get_path(), "player_id": hooked_survivor_id, "rescuer_id": rescuer_id})

# 幸存者开始挣扎
func start_struggle():
	if !multiplayer.is_server():
		rpc_id(1, "server_request_start_struggle")
		return
	
	# 检查状态
	if current_state != HookState.HOOKED:
		return
	
	# 更新状态
	set_state(HookState.HOOKED)

# 幸存者完成牺牲
func complete_sacrifice():
	if !multiplayer.is_server():
		return
	
	# 获取被钩幸存者引用
	var survivor = get_node_or_null("/root/Game/Players/" + str(hooked_survivor_id))
	if survivor:
		# 设置幸存者状态为死亡
		survivor.server_set_variable("health_state", survivor.HealthState.DEAD)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("survivor_died", {"player_id": hooked_survivor_id, "cause": "sacrifice"})
	
	# 重置钩子状态
	set_state(HookState.IDLE)

# 交互权限检查
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	match current_state:
		HookState.IDLE:
			# 空钩子:杀手可以挂人,幸存者不能交互
			return is_killer and character.is_carrying_survivor
		
		HookState.HOOKED:
			# 有人的钩子:幸存者可以救人,杀手不能交互
			return !is_killer and character.health_state == character.HealthState.HEALTHY
		
		HookState.SABOTAGED:
			# 被破坏:任何人都不能交互
			return false
	
	return false

# 交互完成后的特定逻辑
func on_interaction_completed(player_id: int):
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if !character:
		return
	
	# 判断交互类型
	var is_killer = Global.network_manager.is_killer(player_id)
	
	if is_killer:
		# 杀手将幸存者挂到钩子上
		if character.is_carrying_survivor and character.carried_survivor_id != -1:
			hook_survivor(character.carried_survivor_id)
			
			# 放下幸存者
			character.server_set_variable("is_carrying_survivor", false)
			character.server_set_variable("carried_survivor_id", -1)
	else:
		# 幸存者救人
		if current_state == HookState.HOOKED:
			rescue_survivor(player_id)

# 更新视觉状态
func update_visual_state():
	# 更新精灵动画
	if sprite and sprite.has_method("play"):
		match current_state:
			HookState.IDLE:
				sprite.play("idle")
			HookState.HOOKED:
				sprite.play("hooked")
			HookState.SABOTAGED:
				sprite.play("sabotaged")
	
	# 更新特效
	if blood_effect:
		blood_effect.visible = current_state != HookState.IDLE
	
	if aura_effect:
		aura_effect.visible = current_state == HookState.SABOTAGED

# 视觉反馈函数实现
func on_interaction_visual_start():
	# 根据当前状态播放适当的音效
	match current_state:
		HookState.IDLE:
			# 杀手挂人音效
			if sound_hook:
				sound_hook.play()
		HookState.HOOKED:
			# 救援音效(由具体的UI处理)
			pass

func on_interaction_visual_complete():
	# 播放交互完成音效
	match current_state:
		HookState.IDLE:
			# 挂人成功
			if sound_hook:
				sound_hook.play()
		HookState.HOOKED:
			# 救援成功
			pass

# RPC处理函数
@rpc("any_peer", "call_local", "reliable")
func server_request_set_state(new_state: int):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器可以设置状态
	if sender_id == 1:
		set_state(new_state)

@rpc("any_peer", "call_local", "reliable")
func server_request_hook_survivor(player_id: int):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为杀手
	if Global.network_manager.is_killer(sender_id):
		hook_survivor(player_id)

@rpc("any_peer", "call_local", "reliable")
func server_request_rescue_survivor(rescuer_id: int):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为幸存者
	if Global.network_manager.is_survivor(sender_id):
		rescue_survivor(sender_id)

@rpc("any_peer", "call_local", "reliable")
func server_request_start_struggle():
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为被钩的幸存者
	if sender_id == hooked_survivor_id:
		start_struggle()

@rpc("authority", "call_remote", "reliable")
func client_set_state(new_state: int):
	current_state = new_state
	
	# 更新视觉状态
	update_visual_state()
	
	# 播放对应的音效
	match new_state:
		HookState.HOOKED:
			if sound_hook:
				sound_hook.play()
		HookState.SABOTAGED:
			if sound_sacrifice:
				sound_sacrifice.play()

# 技能检测接口(用于挣扎阶段)
@rpc("authority", "call_remote", "reliable")
func trigger_struggle_skill_check():
	# 在客户端显示技能检测UI
	print("钩子挣扎技能检测!")
	
	# 模拟玩家响应(实际会连接到UI信号)
	var success = randf() > 0.5
	
	# 通知服务器结果
	rpc_id(1, "struggle_skill_check_result", success)

# 处理挣扎技能检测结果
@rpc("any_peer", "call_local", "reliable")
func struggle_skill_check_result(success: bool):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为被钩的幸存者
	if player_id == hooked_survivor_id:
		if success:
			# 技能检测成功，减缓牺牲进度
			struggle_progress -= 5.0
			struggle_progress = max(0, struggle_progress)
		else:
			# 技能检测失败，加速牺牲进度
			struggle_progress += 5.0
			
			# 检查是否应该进入下一阶段
			if struggle_progress >= struggle_time:
				set_state(HookState.SABOTAGED) 

# 应用平衡参数
func apply_balance_settings():
	if GameBalanceManager.instance:
		first_hook_time = GameBalanceManager.instance.hook_struggle_time
		second_hook_time = GameBalanceManager.instance.hook_second_struggle_time
		self_unhook_chance = GameBalanceManager.instance.self_unhook_base_chance

# 处理钩子状态更新
func _process(delta):
	if multiplayer.is_server():
		# 减少挣扎时间
		struggle_timer -= delta
		
		# 同步挣扎进度到客户端
		var progress = struggle_timer / (hook_stage == 0 ? first_hook_time : second_hook_time)
		rpc("update_struggle_progress", progress)
		
		# 挣扎时间结束
		if struggle_timer <= 0:
			handle_struggle_timeout()

# 进入挣扎阶段
func enter_struggle_phase():
	if hook_stage == 0:
		hook_stage = 1
		
		# 播放进入挣扎音效和动画
		rpc("play_enter_struggle_animation")
		
		# 通知所有客户端幸存者进入挣扎阶段
		rpc("notify_struggle_phase_entered", hooked_survivor_id)

# 尝试自救
func try_self_unhook() -> bool:
	if multiplayer.is_server() and current_state == HookState.HOOKED and hooked_survivor_id != -1:
		# 检查自救尝试次数是否超过上限
		if self_unhook_attempts >= max_self_unhook_attempts:
			return false
		
		# 增加尝试次数
		self_unhook_attempts += 1
		
		# 计算自救概率
		var success_chance = self_unhook_chance
		
		# 根据钩子阶段调整概率
		if hook_stage > 0:
			success_chance *= 0.5  # 挣扎阶段自救概率减半
		
		# 随机决定是否自救成功
		if randf() < success_chance:
			# 自救成功，解救幸存者
			unhook_survivor(hooked_survivor_id, true)
			return true
	
	return false

# 解救幸存者
func unhook_survivor(rescuer_id: int, is_self_rescue: bool = false):
	if multiplayer.is_server() and current_state == HookState.HOOKED and hooked_survivor_id != -1:
		# 获取被钩幸存者引用
		var survivor = get_node_or_null("/root/Game/Players/" + str(hooked_survivor_id))
		if survivor:
			# 设置幸存者状态
			survivor.server_set_variable("health_state", survivor.HealthState.INJURED)
			
			# 移动幸存者到救援者旁边
			var rescuer = get_node_or_null("/root/Game/Players/" + str(rescuer_id))
			if rescuer:
				survivor.global_position = rescuer.global_position + Vector2(50, 0)
		
		# 重置钩子状态
		set_state(HookState.IDLE)
		
		# 通知游戏逻辑
		if get_node_or_null("/root/Game"):
			get_node("/root/Game").on_game_event("survivor_rescued", {"hook": get_path(), "player_id": hooked_survivor_id, "rescuer_id": rescuer_id})

# 处理挣扎时间结束
func handle_struggle_timeout():
	if hook_stage == 0:
		# 第一阶段结束，进入挣扎阶段
		hook_stage = 1
		struggle_timer = first_hook_time * 0.5  # 挣扎阶段通常时间较短
		
		# 播放进入挣扎音效和动画
		rpc("play_enter_struggle_animation")
		
		# 通知所有客户端幸存者进入挣扎阶段
		rpc("notify_struggle_phase_entered", hooked_survivor_id)
	else:
		# 第二阶段结束，进入牺牲阶段
		set_state(HookState.SABOTAGED)
		
		# 获取被钩幸存者引用
		var survivor = get_node_or_null("/root/Game/Players/" + str(hooked_survivor_id))
		if survivor:
			# 设置幸存者状态为死亡
			survivor.server_set_variable("health_state", survivor.HealthState.DEAD)
		
		# 通知游戏逻辑
		if get_node_or_null("/root/Game"):
			get_node("/root/Game").on_game_event("survivor_died", {"player_id": hooked_survivor_id, "cause": "struggle_timeout"})
		
		# 重置钩子状态
		set_state(HookState.IDLE) 