extends Interactable
class_name Pallet

# 木板状态
enum PalletState {
	STANDING,    # 直立状态
	DROPPED,     # 已倒下
	BREAKING,    # 破坏中
	BROKEN       # 已被破坏
}

# 当前状态
var current_state: int = PalletState.STANDING

# 交互相关
var drop_cooldown: float = 0.0
var drop_cooldown_duration: float = 1.0  # 倒下后的冷却时间
var stun_range: float = 100.0  # 眩晕杀手的范围
var stun_duration: float = 2.0  # 眩晕持续时间
var break_time: float = 2.5     # 破坏板子所需时间

# 计时器
var break_progress: float = 0.0
var stun_timer: Timer

# 视觉和音效
@onready var sprite = $AnimatedSprite2D
@onready var drop_sound = $DropSound
@onready var break_sound = $BreakSound
@onready var stun_sound = $StunSound
@onready var collision_stand = $CollisionStanding
@onready var collision_dropped = $CollisionDropped
@onready var stun_area = $StunArea

# 信号
signal pallet_dropped(pallet)
signal pallet_destroyed(pallet)
signal killer_stunned(killer)

func _ready():
	super._ready()
	
	# 初始化状态
	current_state = PalletState.STANDING
	
	# 初始化定时器
	stun_timer = Timer.new()
	stun_timer.one_shot = true
	add_child(stun_timer)
	
	# 更新碰撞和视觉效果
	update_collision()
	update_visuals()
	
	# 连接信号
	if stun_area:
		stun_area.body_entered.connect(_on_stun_area_body_entered)
		# 初始禁用
		stun_area.monitoring = false
	
	# 添加到木板组
	add_to_group("pallets")

func _physics_process(delta):
	# 处理冷却时间
	if drop_cooldown > 0:
		drop_cooldown -= delta
		if drop_cooldown <= 0:
			drop_cooldown = 0

# 尝试倒下木板
func try_drop(survivor):
	if current_state != PalletState.STANDING or drop_cooldown > 0:
		return false
	
	# 设置状态并检查是否眩晕杀手
	current_state = PalletState.DROPPED
	drop_cooldown = drop_cooldown_duration
	
	# 更新碰撞和视觉效果
	update_collision()
	update_visuals()
	
	# 播放倒下音效
	if drop_sound:
		drop_sound.play()
	
	# 发送倒下信号
	emit_signal("pallet_dropped", self)
	
	# 检查是否有杀手在范围内，眩晕他
	check_stun_killer()
	
	return true

# 检查是否有杀手在范围内并眩晕
func check_stun_killer():
	# 创建物理查询
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsCircleShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = stun_range
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 4  # 假设杀手在第4层碰撞层
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider is Killer:
			# 眩晕杀手
			stun_killer(collider)
			
			# 只眩晕一个杀手（实际游戏中一般只有一个杀手）
			break

# 眩晕杀手
func stun_killer(killer):
	if !multiplayer.is_server():
		return
		
	if current_state != PalletState.DROPPED:
		return
		
	# 设置杀手眩晕状态
	killer.server_set_variable("can_move", false)
	killer.server_set_variable("can_interact", false)
	
	# 眩晕时长后恢复
	get_tree().create_timer(stun_duration).timeout.connect(func():
		killer.server_set_variable("can_move", true)
		killer.server_set_variable("can_interact", true)
	)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("killer_stunned", {"killer_id": killer.player_id, "pallet": get_path()})

# 被杀手破坏
func break_pallet():
	if current_state != PalletState.DROPPED:
		return false
	
	current_state = PalletState.BROKEN
	
	# 更新碰撞和视觉效果
	update_collision()
	update_visuals()
	
	# 播放破坏音效
	if break_sound:
		break_sound.play()
	
	# 发送破坏信号
	emit_signal("pallet_destroyed", self)
	
	# 在短时间后移除木板
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
	
	return true

# 更新碰撞形状
func update_collision():
	match current_state:
		PalletState.STANDING:
			if collision_stand:
				collision_stand.disabled = false
			if collision_dropped:
				collision_dropped.disabled = true
		PalletState.DROPPED:
			if collision_stand:
				collision_stand.disabled = true
			if collision_dropped:
				collision_dropped.disabled = false
		PalletState.BREAKING:
			if collision_stand:
				collision_stand.disabled = true
			if collision_dropped:
				collision_dropped.disabled = true
		PalletState.BROKEN:
			if collision_stand:
				collision_stand.disabled = true
			if collision_dropped:
				collision_dropped.disabled = true

# 更新视觉效果
func update_visuals():
	match current_state:
		PalletState.STANDING:
			if sprite:
				sprite.play("standing")
		PalletState.DROPPED:
			if sprite:
				sprite.play("dropped")
		PalletState.BREAKING:
			if sprite:
				sprite.play("breaking")
		PalletState.BROKEN:
			if sprite:
				sprite.play("broken")

# 检查是否可以倒下
func can_drop() -> bool:
	return current_state == PalletState.STANDING and drop_cooldown <= 0

# 检查是否可以被破坏
func can_break() -> bool:
	return current_state == PalletState.DROPPED

# 获取当前状态文本
func get_status_text() -> String:
	match current_state:
		PalletState.STANDING:
			return "直立"
		PalletState.DROPPED:
			return "已倒下"
		PalletState.BREAKING:
			return "破坏中"
		PalletState.BROKEN:
			return "已破坏"
	return ""

# 检测杀手是否位于眩晕区域
func _on_stun_area_body_entered(body):
	if body is Character and Global.network_manager.is_killer(body.player_id):
		if current_state == PalletState.DROPPED:
			# 眩晕杀手
			stun_killer(body)

# 设置板子状态
func set_state(new_state: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_state", new_state)
		return
		
	var old_state = current_state
	current_state = new_state
	
	# 更新碰撞和交互状态
	match new_state:
		PalletState.STANDING:
			is_interactable = true
			if old_state == PalletState.DROPPED:
				# 如果是从放倒变回直立，禁用眩晕区域
				if stun_area:
					stun_area.monitoring = false
					
		PalletState.DROPPED:
			is_interactable = true
			# 激活眩晕区域
			if stun_area:
				stun_area.monitoring = true
				# 短时间后禁用眩晕区域
				stun_timer.wait_time = 0.5  # 给杀手短暂的眩晕窗口
				stun_timer.timeout.connect(func(): stun_area.monitoring = false)
				stun_timer.start()
				
		PalletState.BREAKING:
			is_interactable = false
			break_progress = 0.0
			
		PalletState.BROKEN:
			is_interactable = false
	
	# 更新碰撞形状
	update_collision()
	
	# 同步到客户端
	rpc("client_set_state", new_state)

# 倒板
func drop_pallet():
	if !multiplayer.is_server():
		rpc_id(1, "server_request_drop_pallet")
		return
		
	if current_state != PalletState.STANDING:
		return
		
	# 改变状态为放倒
	set_state(PalletState.DROPPED)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("pallet_dropped", {"pallet": get_path()})

# 开始破坏板子
func start_breaking():
	if !multiplayer.is_server():
		rpc_id(1, "server_request_start_breaking")
		return
		
	if current_state != PalletState.DROPPED:
		return
		
	# 改变状态为破坏中
	set_state(PalletState.BREAKING)

# 完成破坏
func complete_breaking():
	if !multiplayer.is_server():
		return
		
	if current_state != PalletState.BREAKING:
		return
		
	# 改变状态为已破坏
	set_state(PalletState.BROKEN)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("pallet_broken", {"pallet": get_path()})

# 处理逻辑更新
func _process(delta):
	super._process(delta)
	
	# 服务器处理破坏进度
	if multiplayer.is_server() and current_state == PalletState.BREAKING:
		break_progress += delta / break_time
		
		# 如果破坏完成
		if break_progress >= 1.0:
			complete_breaking()

# 交互权限检查
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	match current_state:
		PalletState.STANDING:
			# 只有幸存者可以倒板
			return !is_killer
			
		PalletState.DROPPED:
			# 只有杀手可以破坏板子
			return is_killer
			
		_:
			return false

# 交互完成处理
func on_interaction_completed(player_id: int):
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if !character:
		return
		
	# 判断交互类型
	var is_killer = Global.network_manager.is_killer(player_id)
	
	if is_killer:
		# 杀手开始破坏板子
		if current_state == PalletState.DROPPED:
			start_breaking()
	else:
		# 幸存者倒板
		if current_state == PalletState.STANDING:
			drop_pallet()

# 更新视觉状态
func update_visual_state():
	# 更新精灵动画
	if sprite and sprite.has_method("play"):
		match current_state:
			PalletState.STANDING:
				sprite.play("standing")
			PalletState.DROPPED:
				sprite.play("dropped")
			PalletState.BREAKING:
				sprite.play("breaking")
			PalletState.BROKEN:
				sprite.play("broken")

# 视觉反馈函数
func on_interaction_visual_start():
	match current_state:
		PalletState.STANDING:
			# 幸存者开始倒板动画
			pass
		PalletState.DROPPED:
			# 杀手开始破坏动画
			if sound_breaking:
				sound_breaking.play()

func on_interaction_visual_cancel():
	if sound_breaking and sound_breaking.playing:
		sound_breaking.stop()

func on_interaction_visual_complete():
	match current_state:
		PalletState.DROPPED:
			# 播放倒板音效
			if sound_drop:
				sound_drop.play()
		PalletState.BROKEN:
			# 播放破坏完成音效
			if sound_break:
				sound_break.play()

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
func server_request_drop_pallet():
	if !multiplayer.is_server():
		return
		
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为幸存者
	if Global.network_manager.is_survivor(sender_id):
		drop_pallet()

@rpc("any_peer", "call_local", "reliable")
func server_request_start_breaking():
	if !multiplayer.is_server():
		return
		
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为杀手
	if Global.network_manager.is_killer(sender_id):
		start_breaking()

@rpc("authority", "call_remote", "reliable")
func client_set_state(new_state: int):
	current_state = new_state
	
	# 更新碰撞形状
	update_collision()
	
	# 更新视觉状态
	update_visual_state()
	
	# 播放对应音效
	match new_state:
		PalletState.DROPPED:
			if sound_drop:
				sound_drop.play()
		PalletState.BREAKING:
			if sound_breaking:
				sound_breaking.play()
		PalletState.BROKEN:
			if sound_break:
				sound_break.play() 