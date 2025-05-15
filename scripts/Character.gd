extends CharacterBody2D
class_name Character

# 通用角色状态
enum HealthState {
	HEALTHY,
	INJURED,
	DOWNED,
	DEAD
}

# 当前健康状态
@export var health_state: int = HealthState.HEALTHY:
	set(value):
		health_state = value
		# 根据状态调整可移动性
		match health_state:
			HealthState.HEALTHY, HealthState.INJURED:
				can_move = true
			HealthState.DOWNED:
				can_move = false
				can_interact = false
			HealthState.DEAD:
				can_move = false
				can_interact = false
		
		# 播放对应的受伤/倒地声音
		match health_state:
			HealthState.INJURED:
				play_sound("hurt")
			HealthState.DOWNED:
				play_sound("down")
			HealthState.DEAD:
				play_sound("death")
		
		# 更新动画
		play_animation(current_animation)

# 移动参数
@export var walk_speed: float = 100.0
@export var run_speed: float = 150.0
var current_speed = run_speed if is_running else walk_speed
@export var is_running: bool = false:
	set(value):
		is_running = value
		# 更新速度
		current_speed = run_speed if is_running else walk_speed

# 状态控制
@export var can_move: bool = true
@export var can_interact: bool = true

# 当前交互目标
var interactable_in_range = null

# 网络相关
@export var player_id: int = 0
var is_local_player: bool = false

# 同步变量
var last_position: Vector2 = Vector2.ZERO
var interpolation_speed: float = 10.0
var position_buffer: Array = []
const BUFFER_SIZE = 5

# 子节点引用
@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var interaction_area = $InteractionArea
@onready var sync_node: MultiplayerSynchronizer = $Synchronizer
@onready var audio_player = $AudioStreamPlayer2D

# 动画状态
var current_animation: String = "idle"
var current_direction: Vector2 = Vector2.DOWN

# 应用平衡管理器的速度参数
func _ready():
	# 获取玩家ID
	player_id = get_multiplayer_authority()
	is_local_player = player_id == multiplayer.get_unique_id()
	
	# 初始化同步节点
	if sync_node:
		# 如果没有设置过同步属性，则设置
		if sync_node.get_replication_config().get_property_count() == 0:
			setup_syncing()
	else:
		print("警告: 角色缺少MultiplayerSynchronizer节点")
	
	# 如果是本地玩家，设置摄像机跟随
	if is_local_player:
		var camera = Camera2D.new()
		add_child(camera)
		camera.make_current()
	
	# 连接交互区域信号
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# 设置初始位置记录
	last_position = global_position
	
	# 如果平衡管理器已初始化，应用平衡参数
	if GameBalanceManager.instance:
		update_balance_parameters()

func setup_syncing():
	# 设置同步属性
	var config = sync_node.get_replication_config()
	
	# 同步位置和速度
	config.add_property("global_position")
	config.add_property("velocity")
	
	# 同步状态
	config.add_property("health_state")
	config.add_property("is_running")
	config.add_property("can_move")
	config.add_property("can_interact")
	
	# 同步动画
	config.add_property("current_animation")
	config.add_property("current_direction")
	
	# 为角色特有状态添加钩子，由子类填充
	setup_additional_syncing(config)

# 子类可覆盖此方法添加更多同步属性
func setup_additional_syncing(_config):
	pass

func _physics_process(delta):
	if is_local_player:
		if can_move:
			handle_movement()
		
		if can_interact:
			handle_interaction()
	else:
		# 非本地玩家平滑插值移动
		smooth_remote_movement(delta)

# 平滑远程玩家移动
func smooth_remote_movement(delta):
	if position_buffer.size() > 0:
		# 从缓冲区获取下一个目标位置
		var target_pos = position_buffer[0]
		global_position = global_position.lerp(target_pos, delta * interpolation_speed)
		
		# 如果足够接近目标位置，移除这个位置
		if global_position.distance_to(target_pos) < 5.0:
			position_buffer.pop_front()
	
	# 根据移动情况更新动画
	if last_position != global_position:
		var move_vector = global_position - last_position
		if move_vector.length() > 0.1:
			update_direction(move_vector.normalized())
			if move_vector.length() > 1.0:
				if is_running:
					play_animation("run")
				else:
					play_animation("walk")
			else:
				play_animation("idle")
		else:
			play_animation("idle")
	
	last_position = global_position

# 处理移动输入并应用
func handle_movement():
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	
	# 奔跑状态判断
	if Input.is_action_pressed("sprint"):
		is_running = true
		current_speed = run_speed
	else:
		is_running = false
		current_speed = walk_speed
	
	# 如果受伤，速度减慢
	if health_state == HealthState.INJURED:
		current_speed *= 0.7
	
	# 标准化向量以防止对角线移动更快
	if direction.length() > 0:
		direction = direction.normalized()
		update_direction(direction)
		
		# 选择适当的动画
		if is_running:
			play_animation("run")
		else:
			play_animation("walk")
	else:
		play_animation("idle")
	
	# 设置速度并移动
	velocity = direction * current_speed
	if can_move:
		move_and_slide()

# 更新朝向并选择对应方向的动画
func update_direction(dir: Vector2):
	if dir != Vector2.ZERO:
		current_direction = dir
	
	# 根据方向翻转精灵
	if dir.x < 0:
		sprite.flip_h = true
	elif dir.x > 0:
		sprite.flip_h = false

# 播放对应的动画
func play_animation(anim_name: String):
	var animation_to_play = anim_name
	
	# 如果受伤，使用受伤版本的动画
	if health_state == HealthState.INJURED and anim_name in ["walk", "run", "idle"]:
		animation_to_play = "injured_" + anim_name
	
	# 如果倒地，总是播放爬行动画
	if health_state == HealthState.DOWNED:
		animation_to_play = "crawl"
	
	# 播放动画
	if sprite and sprite.has_animation(animation_to_play) and current_animation != animation_to_play:
		sprite.play(animation_to_play)
		current_animation = animation_to_play

# 处理交互按键
func handle_interaction():
	if Input.is_action_just_pressed("interact") and interactable_in_range != null:
		interact_with(interactable_in_range)

# 与物体交互的基础方法(由子类实现具体逻辑)
func interact_with(object):
	# 基类中是空实现，由幸存者和杀手子类重写
	print("与对象交互:", object.name)
	
	# 如果对象是Interactable类型，调用开始交互
	if object is Interactable:
		object.start_interaction(self)
		
		# 持续交互直到玩家松开交互键或离开范围
		while Input.is_action_pressed("interact") and interactable_in_range == object:
			await get_tree().process_frame
		
		# 交互结束，取消交互
		object.cancel_interaction(self)

# 受到伤害时调用
func take_damage(_attacker = null):
	# 基础伤害逻辑，子类可以扩展
	match health_state:
		HealthState.HEALTHY:
			change_health_state(HealthState.INJURED)
		HealthState.INJURED:
			change_health_state(HealthState.DOWNED)
		HealthState.DOWNED:
			die()

# 改变健康状态
func change_health_state(new_state: int):
	health_state = new_state

# 死亡处理
func die():
	change_health_state(HealthState.DEAD)
	# 通知游戏逻辑
	# 在子类中实现具体逻辑

# 播放声音
func play_sound(_sound_name: String):
	if audio_player:
		# 此处实际项目中应该根据sound_name设置对应的音频资源
		# 例如 audio_player.stream = preload("res://assets/audio/sfx_" + sound_name + ".wav")
		if audio_player.stream:
			audio_player.play()

# 当有物体进入交互范围
func _on_interaction_area_entered(body):
	if is_local_player and body.has_method("can_interact_with") and body.can_interact_with(self):
		interactable_in_range = body
		# 显示交互提示UI
		if is_local_player:
			# 在实际项目中，这里应该调用UI显示交互提示
			print("可以与", body.name, "交互")

# 当物体离开交互范围
func _on_interaction_area_exited(body):
	if is_local_player and interactable_in_range == body:
		interactable_in_range = null
		# 隐藏交互提示UI
		if is_local_player:
			# 在实际项目中，这里应该调用UI隐藏交互提示
			print("无法再与", body.name, "交互")
			
# 处理被告知有交互物体
func on_interactable_entered(interactable: Interactable):
	if is_local_player:
		# 如果角色状态允许交互，更新当前交互目标
		if can_interact:
			interactable_in_range = interactable
			# 显示交互提示UI
			print("可以与", interactable.name, "交互")

# 处理被告知交互物体离开
func on_interactable_exited(interactable: Interactable):
	if is_local_player and interactable_in_range == interactable:
		interactable_in_range = null
		# 隐藏交互提示UI
		print("无法再与", interactable.name, "交互")

# 接收远程玩家新位置
func _on_position_updated(_old_value, new_value):
	# 仅处理远程角色
	if !is_local_player:
		# 添加到位置缓冲区
		position_buffer.append(new_value)
		# 限制缓冲区大小
		while position_buffer.size() > BUFFER_SIZE:
			position_buffer.pop_front()

# 从服务器设置值
func server_set_variable(var_name: String, value):
	if multiplayer.is_server():
		set(var_name, value)
		rpc("client_set_variable", var_name, value)
	else:
		# 客户端发送请求到服务器
		rpc_id(1, "server_request_set_variable", var_name, value)

# 客户端请求设置变量
@rpc("any_peer", "call_local", "reliable")
func server_request_set_variable(var_name: String, value):
	if !multiplayer.is_server():
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	# 确保只有变量拥有者可以修改
	if sender_id == player_id:
		server_set_variable(var_name, value)

# 服务器通知所有客户端变量变化
@rpc("authority", "call_remote", "reliable")
func client_set_variable(var_name: String, value):
	set(var_name, value)

# 更新平衡参数
func update_balance_parameters():
	if is_killer():
		walk_speed = GameBalanceManager.instance.killer_speed
	else:
		walk_speed = GameBalanceManager.instance.survivor_walk_speed
		run_speed = GameBalanceManager.instance.survivor_run_speed

# 获取当前移动速度，考虑健康状态和其他效果
func get_current_speed() -> float:
	# 基础值
	var movement_speed = run_speed if is_running else walk_speed
	var speed_modifier = 1.0
	
	# 根据状态应用修改
	if is_killer():
		# 杀手是否扛着幸存者
		if is_carrying_survivor():
			speed_modifier *= GameBalanceManager.instance.carrying_speed_multiplier
	else: 
		# 幸存者是否受伤
		if health_state == HealthState.INJURED:
			speed_modifier *= GameBalanceManager.instance.injured_speed_multiplier
		
		# 速度提升效果（如被击中后的短暂加速）
		if has_speed_boost:
			speed_modifier *= GameBalanceManager.instance.speed_boost_after_hit
	
	return movement_speed * speed_modifier

# 判断是否为杀手
func is_killer() -> bool:
	return false  # 基类默认返回false，子类重写

# 判断杀手是否正在扛起幸存者(Killer子类将重写)
func is_carrying_survivor() -> bool:
	return false  # 基类默认返回false

# 幸存者速度提升标志和计时器
var has_speed_boost: bool = false
var speed_boost_timer: float = 0.0

# 被击中时速度提升效果
func apply_hit_speed_boost():
	if not is_killer():
		has_speed_boost = true
		speed_boost_timer = GameBalanceManager.instance.speed_boost_duration
		
		# 创建一个 Timer 来管理速度提升持续时间
		var timer = Timer.new()
		timer.wait_time = speed_boost_timer
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(func(): 
			has_speed_boost = false
			timer.queue_free()
		)
		timer.start() 
