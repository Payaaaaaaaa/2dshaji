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
var health_state: int = HealthState.HEALTHY

# 移动参数
var walk_speed: float = 100.0
var run_speed: float = 150.0
var current_speed: float = walk_speed
var is_running: bool = false

# 状态控制
var can_move: bool = true
var can_interact: bool = true

# 当前交互目标
var interactable_in_range = null

# 网络相关
@onready var player_id: int = 0
var is_local_player: bool = false

# 子节点引用
@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var interaction_area = $InteractionArea

# 动画状态
var current_animation: String = "idle"
var current_direction: Vector2 = Vector2.DOWN

func _ready():
	# 获取玩家ID
	player_id = get_multiplayer_authority()
	is_local_player = player_id == multiplayer.get_unique_id()
	
	# 如果是本地玩家，设置摄像机跟随
	if is_local_player:
		var camera = Camera2D.new()
		add_child(camera)
		camera.make_current()
	
	# 连接交互区域信号
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)

func _physics_process(delta):
	if !is_local_player:
		return
	
	if can_move:
		handle_movement()
	
	if can_interact:
		handle_interaction()

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
	move_and_slide()
	
	# 发送位置更新到服务器
	rpc_id(1, "update_position", global_position, velocity)

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
	if sprite.has_animation(animation_to_play) and current_animation != animation_to_play:
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

# 受到伤害时调用
func take_damage(attacker = null):
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

# 死亡处理
func die():
	change_health_state(HealthState.DEAD)
	# 通知游戏逻辑
	# 在子类中实现具体逻辑

# 播放声音
func play_sound(sound_name: String):
	var audio_player = $AudioStreamPlayer2D
	if audio_player:
		# 此处实际项目中应该根据sound_name设置对应的音频资源
		# 例如 audio_player.stream = preload("res://assets/audio/sfx_" + sound_name + ".wav")
		audio_player.play()

# 当有物体进入交互范围
func _on_interaction_area_entered(body):
	if body.has_method("can_interact_with") and body.can_interact_with(self):
		interactable_in_range = body
		# 显示交互提示UI
		if is_local_player:
			# 在实际项目中，这里应该调用UI显示交互提示
			print("可以与", body.name, "交互")

# 当物体离开交互范围
func _on_interaction_area_exited(body):
	if interactable_in_range == body:
		interactable_in_range = null
		# 隐藏交互提示UI
		if is_local_player:
			# 在实际项目中，这里应该调用UI隐藏交互提示
			print("无法再与", body.name, "交互")

# 同步位置（客户端 -> 服务器）
@rpc("any_peer", "unreliable")
func update_position(pos: Vector2, vel: Vector2):
	if multiplayer.get_remote_sender_id() == player_id:
		global_position = pos
		velocity = vel
		
		# 服务器接收到位置更新后，广播给所有其他客户端
		if multiplayer.is_server():
			for id in Global.player_info.keys():
				if id != player_id:
					rpc_id(id, "sync_position", pos, vel)

# 同步位置（服务器 -> 其他客户端）
@rpc("authority", "unreliable")
func sync_position(pos: Vector2, vel: Vector2):
	if !is_local_player:
		global_position = pos
		velocity = vel
		
		# 根据速度方向更新动画
		if vel.length() > 0:
			update_direction(vel.normalized())
			if vel.length() > walk_speed:
				play_animation("run")
			else:
				play_animation("walk")
		else:
			play_animation("idle") 