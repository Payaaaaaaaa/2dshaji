extends StaticBody2D
class_name ExitGate

# 出口门状态
enum ExitGateState {
	UNPOWERED,   # 未通电
	POWERED,     # 已通电但未开启
	OPENING,     # 正在开启
	OPENED       # 已开启
}

# 当前状态
var state: int = ExitGateState.UNPOWERED

# 开门进度 (0-1)
var open_progress: float = 0.0
var open_time: float = 20.0  # 完全开启需要的时间

# 当前正在开门的幸存者列表
var opening_survivors = []

# 逃生相关
var escape_area: Area2D
var escaped_survivors = []   # 已经逃生的幸存者

# 动画组件引用
@onready var sprite = $AnimatedSprite2D
@onready var light = $Light2D
@onready var particles = $Particles2D

# 音频组件引用
@onready var power_sound = $PowerSound
@onready var opening_sound = $OpeningSound
@onready var opened_sound = $OpenedSound
@onready var escape_sound = $EscapeSound

# 信号
signal powered()
signal opening_progress_changed(progress)
signal opened()
signal survivor_escaped(survivor)

func _ready():
	# 初始化状态
	state = ExitGateState.UNPOWERED
	open_progress = 0.0
	
	# 获取逃生区域
	escape_area = $EscapeArea
	if escape_area:
		escape_area.body_entered.connect(_on_escape_area_body_entered)
		# 初始禁用逃生区域
		escape_area.monitoring = false
	
	# 设置动画
	update_visuals()
	
	# 添加到出口门组
	add_to_group("exit_gates")

func _physics_process(delta):
	# 处理开门逻辑
	if state == ExitGateState.OPENING and opening_survivors.size() > 0:
		# 增加开门进度
		open_progress += delta / open_time
		open_progress = min(open_progress, 1.0)
		
		# 发送进度变化信号
		emit_signal("opening_progress_changed", open_progress)
		
		# 更新视觉效果
		update_visuals()
		
		# 检查是否完全开启
		if open_progress >= 1.0:
			complete_opening()

# 设置出口通电状态
func set_powered(powered: bool = true):
	if powered == is_powered:
		return
	
	is_powered = powered
	
	if powered:
		# 从未通电变为已通电
		if state == ExitGateState.UNPOWERED:
			state = ExitGateState.POWERED
			
			# 播放通电音效
			if power_sound:
				power_sound.play()
				
			# 发送通电信号
			emit_signal("powered")
	else:
		# 断电
		if state == ExitGateState.POWERED or state == ExitGateState.OPENING:
			state = ExitGateState.UNPOWERED
			open_progress = 0.0
			opening_survivors.clear()
	
	# 更新视觉效果
	update_visuals()

# 检查是否已通电
func is_powered() -> bool:
	return state != ExitGateState.UNPOWERED

# 开始开门
func start_opening(survivor):
	if state != ExitGateState.POWERED and state != ExitGateState.OPENING:
		return false
	
	# 添加到开门列表
	if not survivor in opening_survivors:
		opening_survivors.append(survivor)
	
	# 如果是第一个开门者，改变状态
	if opening_survivors.size() == 1 and state == ExitGateState.POWERED:
		state = ExitGateState.OPENING
		
		# 播放开门音效
		if opening_sound:
			opening_sound.play()
	
	# 更新视觉效果
	update_visuals()
	
	return true

# 停止开门
func stop_opening(survivor):
	# 从开门列表移除
	if survivor in opening_survivors:
		opening_survivors.erase(survivor)
	
	# 如果没有人开门了，但门还没开完
	if opening_survivors.size() == 0 and state == ExitGateState.OPENING:
		# 停止开门音效
		if opening_sound and opening_sound.playing:
			opening_sound.stop()

# 设置开门进度
func set_progress(progress: float):
	open_progress = clamp(progress, 0.0, 1.0)
	
	# 如果进度达到100%，完成开门
	if open_progress >= 1.0 and state == ExitGateState.OPENING:
		complete_opening()
	
	# 发出进度更新信号
	emit_signal("opening_progress_changed", open_progress)
	
	# 更新视觉效果
	update_visuals()

# 获取当前进度
func get_progress() -> float:
	return open_progress

# 完成开门
func complete_opening():
	if state == ExitGateState.OPENED:
		return
	
	state = ExitGateState.OPENED
	open_progress = 1.0
	
	# 清空列表
	opening_survivors.clear()
	
	# 停止开门音效
	if opening_sound and opening_sound.playing:
		opening_sound.stop()
	
	# 播放开门完成音效
	if opened_sound:
		opened_sound.play()
	
	# 更新视觉效果
	update_visuals()
	
	# 启用逃生区域
	if escape_area:
		escape_area.monitoring = true
	
	# 发送开门完成信号
	emit_signal("opened")

# 更新视觉效果
func update_visuals():
	match state:
		ExitGateState.UNPOWERED:
			# 未通电状态显示为关闭的门
			if sprite.has_animation("unpowered"):
				sprite.play("unpowered")
				
			# 灯光关闭
			if light:
				light.energy = 0.0
				
			# 粒子效果关闭
			if particles:
				particles.emitting = false
				
		ExitGateState.POWERED:
			# 通电但未开启的门
			if sprite.has_animation("powered"):
				sprite.play("powered")
				
			# 灯光微亮
			if light:
				light.energy = 0.5
				
			# 有少量粒子效果
			if particles:
				particles.emitting = true
				particles.amount = 5
				
		ExitGateState.OPENING:
			# 正在开启的门
			if sprite.has_animation("opening"):
				sprite.play("opening")
				
			# 灯光逐渐变亮
			if light:
				light.energy = 0.5 + open_progress * 0.5
				
			# 粒子效果增加
			if particles:
				particles.emitting = true
				particles.amount = 10
				
		ExitGateState.OPENED:
			# 已开启的门
			if sprite.has_animation("opened"):
				sprite.play("opened")
				
			# 灯光明亮
			if light:
				light.energy = 1.0
				
			# 持续的粒子效果
			if particles:
				particles.emitting = true
				particles.amount = 20
				
	# 根据进度调整某些效果
	if state == ExitGateState.OPENING and light:
		light.energy = 0.5 + open_progress * 0.5  # 随进度增亮

# 播放音效
func play_sound(sound_name: String):
	if power_sound:
		power_sound.play()
	if escape_sound:
		escape_sound.play()

# 当幸存者进入逃生区域
func _on_escape_area_body_entered(body):
	if state != ExitGateState.OPENED:
		return
	
	if body is Survivor and body.health_state != Survivor.HealthState.DEAD and not body in escaped_survivors:
		# 通知幸存者逃脱
		body.start_opening(self)
		
		# 添加到已逃脱列表
		escaped_survivors.append(body)
		
		# 播放逃脱音效
		if escape_sound:
			escape_sound.play()
		
		# 发送逃脱信号
		emit_signal("survivor_escaped", body)
		
		# 通知服务器记录逃脱
		if multiplayer.is_server():
			Global.survivor_escaped += 1
			Global.check_game_end()

# 检查是否可以开门
func can_open() -> bool:
	return state == ExitGateState.POWERED or state == ExitGateState.OPENING

# 检查是否可以逃生
func can_escape() -> bool:
	return state == ExitGateState.OPENED

# 获取状态文本（用于UI显示）
func get_state_text() -> String:
	match state:
		ExitGateState.UNPOWERED:
			return "未通电"
		ExitGateState.POWERED:
			return "已通电，等待开启"
		ExitGateState.OPENING:
			return "正在开启 (%d%%)" % (open_progress * 100)
		ExitGateState.OPENED:
			return "已开启，可以逃生"
	return "" 