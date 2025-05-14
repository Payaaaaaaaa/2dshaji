extends StaticBody2D
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

func _ready():
	# 初始化状态
	state = GeneratorState.BROKEN
	repair_progress = 0.0
	
	# 创建QTE计时器
	qte_timer = Timer.new()
	qte_timer.one_shot = true
	qte_timer.timeout.connect(_on_qte_timer_timeout)
	add_child(qte_timer)
	
	# 初始化视觉效果
	update_visuals()
	
	# 将发电机添加到组便于管理
	add_to_group("generators")

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