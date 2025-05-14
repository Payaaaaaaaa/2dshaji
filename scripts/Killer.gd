extends Character
class_name Killer

# 杀手特有状态
enum KillerState {
	PATROLLING,  # 巡逻
	CHASING,     # 追逐
	ATTACKING,   # 攻击
	CARRYING,    # 携带幸存者
	STUNNED      # 被眩晕
}

# 当前状态
var killer_state: int = KillerState.PATROLLING

# 攻击相关
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_DURATION: float = 1.0  # 攻击冷却时间
var attack_range: float = 50.0  # 攻击距离
var is_attack_ready: bool = true
var attack_angle: float = 60.0 # 攻击角度（度）

# 目标幸存者
var chase_target = null
var carried_survivor = null

# 眩晕相关
var stun_timer: Timer = null
var stun_duration: float = 3.0  # 眩晕持续时间

# 信号
signal attack_cooldown_changed(progress)
signal carrying_survivor_changed(survivor)

# 其他属性
var lunge_multiplier: float = 1.5 # 袭击时速度提升倍数

# 节点引用
@onready var attack_area = $AttackArea

func _ready():
	super._ready()
	
	# 设置杀手特有属性
	walk_speed = 120.0  # 杀手移动比幸存者快一些
	run_speed = 140.0
	current_speed = walk_speed
	
	# 初始化眩晕计时器
	stun_timer = Timer.new()
	stun_timer.one_shot = true
	stun_timer.wait_time = stun_duration
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	add_child(stun_timer)

	# 设置攻击区域形状和碰撞
	if attack_area:
		var shape = attack_area.get_node("CollisionShape2D").shape
		# 调整形状大小为攻击范围
		if shape:
			shape.radius = attack_range

func _physics_process(delta):
	super._physics_process(delta)
	if !is_local_player:
		return
	
	# 处理攻击冷却
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			attack_cooldown = 0
			is_attack_ready = true
		emit_signal("attack_cooldown_changed", 1.0 - attack_cooldown / ATTACK_COOLDOWN_DURATION)
	
	# 状态处理
	match killer_state:
		KillerState.PATROLLING, KillerState.CHASING:
			handle_attack_input()
		KillerState.CARRYING:
			handle_hook_input()

# 重写交互方法
func interact_with(object):
	if killer_state == KillerState.STUNNED:
		# 眩晕状态无法交互
		return
	
	if killer_state == KillerState.CARRYING and object.has_method("can_hook_survivor") and object.can_hook_survivor():
		hook_survivor(object)
	elif object.has_method("damage") and killer_state != KillerState.CARRYING:
		# 破坏物品，如发电机
		object.damage(self)
	else:
		# 默认交互处理
		super.interact_with(object)

# 处理攻击输入
func handle_attack_input():
	if Input.is_action_just_pressed("attack") and is_attack_ready:
		start_attack()

# 开始攻击
func start_attack():
	if killer_state == KillerState.STUNNED or killer_state == KillerState.CARRYING:
		return
	
	change_killer_state(KillerState.ATTACKING)
	is_attack_ready = false
	attack_cooldown = ATTACK_COOLDOWN_DURATION
	play_animation("attack")
	play_sound("attack")
	
	# 通知服务器开始攻击
	rpc_id(1, "server_start_attack")
	
	# 短暂暂停移动
	can_move = false
	get_tree().create_timer(0.5).timeout.connect(func(): 
		if killer_state == KillerState.ATTACKING:
			finish_attack()
	)
	
	# 本地攻击判定
	check_attack_hit()

# 服务器验证开始攻击
@rpc("any_peer", "call_local", "reliable")
func server_start_attack():
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器处理此请求
	if !multiplayer.is_server():
		return
	
	# 通知所有客户端杀手攻击动作
	rpc("sync_attack")

# 同步攻击动作
@rpc("authority", "call_remote", "reliable")
func sync_attack():
	if !is_local_player:
		change_killer_state(KillerState.ATTACKING)
		play_animation("attack")
		play_sound("attack")
		
		# 非本地玩家动画完成后恢复
		get_tree().create_timer(0.5).timeout.connect(func(): 
			if killer_state == KillerState.ATTACKING:
				change_killer_state(KillerState.PATROLLING)
		)

# 检查攻击是否命中幸存者
func check_attack_hit():
	# 获取攻击方向
	var attack_direction = current_direction.normalized()
	
	# 攻击判定：创建扇形区域检测碰撞
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = global_position + attack_direction * attack_range
	params.collision_mask = 2  # 假设幸存者在第2层碰撞层
	params.collide_with_bodies = true
	
	var results = space_state.intersect_point(params)
	for result in results:
		var collider = result.collider
		if collider is Survivor and collider.health_state != Survivor.HealthState.DEAD:
			# 幸存者在攻击范围内
			var survivor_dir = (collider.global_position - global_position).normalized()
			var dot_product = survivor_dir.dot(attack_direction)
			
			# 判断幸存者是否在杀手前方扇形区域
			if dot_product > 0.5:  # 大约60度扇形
				# 通知服务器命中
				rpc_id(1, "server_attack_hit", collider.name)
				break

# 服务器验证攻击命中
@rpc("any_peer", "call_local", "reliable")
func server_attack_hit(survivor_name):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器处理此请求
	if !multiplayer.is_server():
		return
	
	# 找到被攻击的幸存者
	var survivor = get_node("/root/Game/Players/" + survivor_name)
	if survivor and survivor is Survivor:
		# 根据幸存者当前状态决定行为
		match survivor.health_state:
			Survivor.HealthState.HEALTHY:
				# 由健康变为受伤
				survivor.rpc("take_damage", name)
			Survivor.HealthState.INJURED:
				# 由受伤变为倒地
				survivor.rpc("take_damage", name)
				
		# 通知其他客户端
		rpc("sync_attack_hit", survivor_name)

# 同步攻击命中
@rpc("authority", "call_remote", "reliable")
func sync_attack_hit(survivor_name):
	play_sound("hit")
	
	# 命中提示音效/特效
	if is_local_player:
		print("命中幸存者:", survivor_name)

# 完成攻击
func finish_attack():
	can_move = true
	if killer_state == KillerState.ATTACKING:
		if chase_target != null:
			change_killer_state(KillerState.CHASING)
		else:
			change_killer_state(KillerState.PATROLLING)

# 处理挂钩输入
func handle_hook_input():
	if Input.is_action_just_pressed("interact") and carried_survivor != null:
		# 检查附近是否有钩子
		var hook = find_nearest_hook()
		if hook != null:
			hook_survivor_on(hook)

# 寻找最近的钩子
func find_nearest_hook():
	var nearest_hook = null
	var min_distance = 100.0  # 最大检测距离
	
	# 实际游戏中应该有更好的钩子检索方法，如通过父节点获取所有钩子
	# 这里简化为检查交互范围内的物体
	if interactable_in_range != null and interactable_in_range.has_method("can_hook_survivor"):
		return interactable_in_range
	
	return null

# 扛起幸存者
func pick_up_survivor(survivor):
	if killer_state == KillerState.CARRYING or killer_state == KillerState.STUNNED:
		return
	
	rpc_id(1, "server_pick_up_survivor", survivor.name)
	change_killer_state(KillerState.CARRYING)
	carried_survivor = survivor
	play_animation("carry")
	
	# 减速
	current_speed = walk_speed * 0.8

# 服务器验证扛起幸存者
@rpc("any_peer", "call_local", "reliable")
func server_pick_up_survivor(survivor_name):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器处理此请求
	if !multiplayer.is_server():
		return
	
	# 找到对应幸存者
	var survivor = get_node("/root/Game/Players/" + survivor_name)
	if survivor and survivor is Survivor and survivor.health_state == Survivor.HealthState.DOWNED:
		# 通知幸存者被扛起
		survivor.rpc("get_carried", self)
		
		# 同步杀手状态
		carried_survivor = survivor
		change_killer_state(KillerState.CARRYING)
		rpc("sync_carrying_state", survivor_name)

# 同步携带状态
@rpc("authority", "call_remote", "reliable")
func sync_carrying_state(survivor_name):
	change_killer_state(KillerState.CARRYING)
	
	var survivor = get_node("/root/Game/Players/" + survivor_name)
	if survivor:
		carried_survivor = survivor
		
	play_animation("carry")
	current_speed = walk_speed * 0.8
	
	emit_signal("carrying_survivor_changed", carried_survivor)

# 将幸存者挂到钩子上
func hook_survivor_on(hook):
	if killer_state != KillerState.CARRYING or carried_survivor == null:
		return
	
	rpc_id(1, "server_hook_survivor", hook.name)
	
	# 重置状态
	change_killer_state(KillerState.PATROLLING)
	var survivor = carried_survivor
	carried_survivor = null
	current_speed = walk_speed
	play_animation("idle")
	
	# 播放挂钩音效
	play_sound("hook")

# 服务器验证挂钩
@rpc("any_peer", "call_local", "reliable")
func server_hook_survivor(hook_name):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器处理此请求
	if !multiplayer.is_server():
		return
	
	if killer_state != KillerState.CARRYING or carried_survivor == null:
		return
	
	# 找到对应钩子
	var hook = get_node("/root/Game/Objects/Hooks/" + hook_name)
	if hook:
		# 通知幸存者被挂上钩子
		carried_survivor.rpc("hook_on", hook)
		
		# 重置杀手状态
		change_killer_state(KillerState.PATROLLING)
		carried_survivor = null
		rpc("sync_hook_completed")

# 同步挂钩完成
@rpc("authority", "call_remote", "reliable")
func sync_hook_completed():
	change_killer_state(KillerState.PATROLLING)
	carried_survivor = null
	current_speed = walk_speed
	play_animation("idle")
	emit_signal("carrying_survivor_changed", null)

# 幸存者从肩上逃脱
@rpc("authority", "call_remote", "reliable")
func on_survivor_escaped():
	if killer_state == KillerState.CARRYING:
		change_killer_state(KillerState.PATROLLING)
		carried_survivor = null
		current_speed = walk_speed
		play_animation("idle")
		play_sound("survivor_escaped")
		emit_signal("carrying_survivor_changed", null)

# 被幸存者眩晕（比如板子砸中）
func stun(duration = stun_duration):
	if killer_state == KillerState.STUNNED:
		return
	
	rpc_id(1, "server_stun", duration)
	change_killer_state(KillerState.STUNNED)
	can_move = false
	can_interact = false
	play_animation("stunned")
	play_sound("stunned")
	
	# 如果正在扛人，放下幸存者
	if carried_survivor != null:
		carried_survivor = null
		emit_signal("carrying_survivor_changed", null)
	
	# 设置眩晕时间
	stun_timer.wait_time = duration
	stun_timer.start()

# 服务器验证眩晕
@rpc("any_peer", "call_local", "reliable")
func server_stun(duration):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器处理此请求
	if !multiplayer.is_server():
		return
	
	# 通知所有客户端杀手被眩晕
	rpc("sync_stunned_state", duration)
	
	# 如果正在扛人，让幸存者逃脱
	if carried_survivor != null:
		carried_survivor.rpc("wiggle_escape")
		carried_survivor = null

# 同步眩晕状态
@rpc("authority", "call_remote", "reliable")
func sync_stunned_state(duration):
	change_killer_state(KillerState.STUNNED)
	can_move = false
	can_interact = false
	play_animation("stunned")
	play_sound("stunned")
	
	# 如果正在扛人，放下幸存者
	if carried_survivor != null:
		carried_survivor = null
		emit_signal("carrying_survivor_changed", null)
	
	# 设置眩晕时间
	if is_local_player:
		stun_timer.wait_time = duration
		stun_timer.start()

# 眩晕结束
func _on_stun_timer_timeout():
	if killer_state == KillerState.STUNNED:
		change_killer_state(KillerState.PATROLLING)
		can_move = true
		can_interact = true
		play_animation("idle")

# 改变杀手状态
func change_killer_state(new_state: int):
	var old_state = killer_state
	killer_state = new_state
	
	# 根据状态播放动画
	match killer_state:
		KillerState.PATROLLING:
			# 如果有什么特效，可以在这里关闭
			pass
		KillerState.CHASING:
			# 追逐时可能有特效或音乐变化
			pass
		KillerState.ATTACKING:
			# 攻击动画在start_attack处理
			pass
		KillerState.CARRYING:
			# 携带幸存者时的减速在其他地方处理
			pass
		KillerState.STUNNED:
			# 眩晕时的受限在stun函数处理
			pass
	
	# 同步状态到服务器
	if is_local_player and old_state != new_state:
		rpc_id(1, "sync_killer_state", new_state)

# 同步杀手状态
@rpc("any_peer", "call_local", "reliable")
func sync_killer_state(state: int):
	if !multiplayer.is_server():
		return
	
	# 服务器验证并更新杀手状态
	killer_state = state
	rpc("update_killer_state", state)

# 更新杀手状态
@rpc("authority", "call_remote", "reliable")
func update_killer_state(state: int):
	if is_local_player:
		return  # 本地玩家已经更新了状态
		
	killer_state = state
	
	# 根据状态播放动画
	match killer_state:
		KillerState.PATROLLING, KillerState.CHASING:
			if killer_state == KillerState.CHASING:
				# 追逐可能有特殊效果
				pass
				
			if velocity.length() > 0:
				play_animation("walk")
			else:
				play_animation("idle")
		KillerState.ATTACKING:
			play_animation("attack")
		KillerState.CARRYING:
			play_animation("carry")
		KillerState.STUNNED:
			play_animation("stunned")

# 寻找最近的倒地幸存者
func find_nearest_downed_survivor():
	var nearest_survivor = null
	var min_distance = 100.0  # 最大检测距离
	
	# 实际游戏中应该有更好的幸存者检索方法，如通过父节点获取所有幸存者
	# 这里简化为检查交互范围内的物体
	if interactable_in_range != null and interactable_in_range is Survivor and interactable_in_range.health_state == Survivor.HealthState.DOWNED:
		return interactable_in_range
	
	return null

# 开始追逐特定幸存者
func start_chasing(survivor):
	if killer_state == KillerState.STUNNED or killer_state == KillerState.CARRYING:
		return
	
	change_killer_state(KillerState.CHASING)
	chase_target = survivor
	play_sound("chase_start")

# 停止追逐
func stop_chasing():
	if killer_state == KillerState.CHASING:
		change_killer_state(KillerState.PATROLLING)
		chase_target = null
		play_sound("chase_end")

# 重写受伤处理（杀手不会受伤，只会被眩晕）
func take_damage(attacker = null):
	# 杀手免疫伤害，但可以被眩晕
	stun()

# 在交互区域检测到可交互物体
func _on_interaction_area_entered(body):
	if body is Survivor and body.health_state == Survivor.HealthState.DOWNED and killer_state != KillerState.CARRYING:
		# 如果是倒地的幸存者且杀手没有正在携带其他人
		interactable_in_range = body
		if is_local_player:
			# 显示交互提示UI
			print("可以拾起幸存者:", body.name)
	elif body.has_method("can_hook_survivor") and killer_state == KillerState.CARRYING:
		# 如果是钩子且杀手正在携带幸存者
		interactable_in_range = body
		if is_local_player:
			# 显示交互提示UI
			print("可以将幸存者挂在钩子上")
	else:
		super._on_interaction_area_entered(body)

# 处理交互，用于捡起倒地的幸存者或将其挂在钩子上
func handle_interaction():
	if Input.is_action_just_pressed("interact"):
		if killer_state == KillerState.CARRYING and interactable_in_range != null and interactable_in_range.has_method("can_hook_survivor"):
			# 如果正在扛幸存者且附近有钩子
			hook_survivor_on(interactable_in_range)
		elif killer_state != KillerState.CARRYING and interactable_in_range is Survivor and interactable_in_range.health_state == Survivor.HealthState.DOWNED:
			# 如果没有扛幸存者且附近有倒地的幸存者
			pick_up_survivor(interactable_in_range)
		elif interactable_in_range != null:
			# 其他交互情况
			interact_with(interactable_in_range) 