extends StaticBody2D
class_name Pallet

# 木板状态
enum PalletState {
	STANDING,    # 直立状态
	DROPPED,     # 已倒下
	DESTROYED    # 已被破坏
}

# 当前状态
var state: int = PalletState.STANDING

# 交互相关
var drop_cooldown: float = 0.0
var drop_cooldown_duration: float = 1.0  # 倒下后的冷却时间
var stun_range: float = 100.0  # 眩晕杀手的范围
var stun_duration: float = 3.0  # 眩晕持续时间

# 视觉和音效
@onready var sprite = $AnimatedSprite2D
@onready var drop_sound = $DropSound
@onready var break_sound = $BreakSound
@onready var stun_sound = $StunSound
@onready var collision_stand = $CollisionStanding
@onready var collision_dropped = $CollisionDropped

# 信号
signal pallet_dropped(pallet)
signal pallet_destroyed(pallet)
signal killer_stunned(killer)

func _ready():
	# 初始化状态
	state = PalletState.STANDING
	
	# 更新碰撞和视觉效果
	update_collision()
	update_visuals()
	
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
	if state != PalletState.STANDING or drop_cooldown > 0:
		return false
	
	# 设置状态并检查是否眩晕杀手
	state = PalletState.DROPPED
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
	killer.stun(stun_duration)
	
	# 播放眩晕音效
	if stun_sound:
		stun_sound.play()
	
	# 发送眩晕信号
	emit_signal("killer_stunned", killer)

# 被杀手破坏
func break_pallet():
	if state != PalletState.DROPPED:
		return false
	
	state = PalletState.DESTROYED
	
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
	match state:
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
		PalletState.DESTROYED:
			if collision_stand:
				collision_stand.disabled = true
			if collision_dropped:
				collision_dropped.disabled = true

# 更新视觉效果
func update_visuals():
	match state:
		PalletState.STANDING:
			if sprite:
				sprite.play("standing")
		PalletState.DROPPED:
			if sprite:
				sprite.play("dropped")
		PalletState.DESTROYED:
			if sprite:
				sprite.play("destroyed")

# 检查是否可以倒下
func can_drop() -> bool:
	return state == PalletState.STANDING and drop_cooldown <= 0

# 检查是否可以被破坏
func can_break() -> bool:
	return state == PalletState.DROPPED

# 获取当前状态文本
func get_status_text() -> String:
	match state:
		PalletState.STANDING:
			return "直立"
		PalletState.DROPPED:
			return "已倒下"
		PalletState.DESTROYED:
			return "已破坏"
	return "" 