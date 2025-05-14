extends Control
class_name QTE

# 信号
signal completed(success)
signal key_hit(success)
signal progress_changed(value)

# QTE配置
@export var time_limit: float = 5.0  # 完成QTE的时间限制
@export var min_hits_required: int = 3  # 需要成功点击的次数
@export var auto_start: bool = true  # 是否自动开始
@export var difficulty: float = 1.0  # 难度系数，影响目标区域大小和移动速度

# QTE状态
var is_active: bool = false
var success_hits: int = 0
var total_hits: int = 0
var current_progress: float = 0.0
var marker_position: float = 0.0
var marker_direction: int = 1  # 1: 右, -1: 左
var marker_speed: float = 1.0
var current_key: String = "SPACE"
var possible_keys = ["SPACE", "E", "F", "R", "1", "2", "3", "4"]

# UI引用
@onready var progress_bar = $ProgressBar
@onready var target_zone = $ProgressBar/TargetZone
@onready var key_prompt = $KeyContainer/KeyPrompt
@onready var timer_label = $TimerLabel
@onready var timer = $Timer

func _ready():
	if auto_start:
		start()
	else:
		visible = false

# 开始QTE
func start():
	# 重置状态
	is_active = true
	success_hits = 0
	total_hits = 0
	current_progress = 0.0
	marker_position = 0.0
	marker_direction = 1
	
	# 根据难度设置参数
	marker_speed = 0.5 + (difficulty * 0.5)  # 0.5-1.0
	
	# 调整目标区域大小（难度越高越小）
	var target_width = 25 - (difficulty * 10)  # 15-25 像素
	target_zone.size.x = target_width
	
	# 随机位置
	randomize_target_position()
	
	# 设置新的目标按键
	randomize_key()
	
	# 更新UI
	progress_bar.value = current_progress
	timer.wait_time = time_limit
	timer.start()
	
	visible = true
	
	# 每帧更新
	set_process(true)
	set_process_input(true)

# 停止QTE
func stop(success := false):
	is_active = false
	timer.stop()
	visible = false
	set_process(false)
	set_process_input(false)
	
	emit_signal("completed", success)

# 输入检测
func _input(event):
	if not is_active:
		return
	
	# 检测按键
	if event is InputEventKey and event.pressed and not event.is_echo():
		var pressed_key = OS.get_keycode_string(event.keycode)
		
		# 检查是否是目标按键
		if pressed_key == current_key:
			check_hit()

# 检查点击是否命中目标区域
func check_hit():
	var marker_rect = Rect2(marker_position * progress_bar.size.x, 0, 5, progress_bar.size.y)
	var target_rect = Rect2(progress_bar.size.x - target_zone.size.x, 0, target_zone.size.x, progress_bar.size.y)
	
	# 检查是否在目标区域内
	var hit_success = marker_rect.intersects(target_rect)
	
	# 增加计数
	total_hits += 1
	if hit_success:
		success_hits += 1
		current_progress = float(success_hits) / float(min_hits_required)
		progress_bar.value = current_progress
		
		# 修改目标位置和按键
		randomize_target_position()
		randomize_key()
		
		# 检查是否完成
		if success_hits >= min_hits_required:
			stop(true)
	
	# 发出信号
	emit_signal("key_hit", hit_success)
	emit_signal("progress_changed", current_progress)

# 随机化目标区域位置
func randomize_target_position():
	# 在进度条的20%-80%范围内随机放置目标区域
	var min_pos = 0.2
	var max_pos = 0.8
	var random_pos = min_pos + (max_pos - min_pos) * randf()
	
	target_zone.position.x = (progress_bar.size.x * random_pos) - target_zone.size.x

# 随机化目标按键
func randomize_key():
	var prev_key = current_key
	while current_key == prev_key:
		current_key = possible_keys[randi() % possible_keys.size()]
	key_prompt.text = current_key

# 每帧更新
func _process(delta):
	if not is_active:
		return
	
	# 更新计时器
	timer_label.text = "%.1f" % timer.time_left
	
	# 移动标记
	marker_position += marker_direction * marker_speed * delta
	
	# 边界检查
	if marker_position <= 0:
		marker_position = 0
		marker_direction = 1
	elif marker_position >= 1.0:
		marker_position = 1.0
		marker_direction = -1
	
	# 在ProgressBar上可视化移动标记 (使用ProgressBar值作为临时方案)
	progress_bar.value = marker_position

# 当计时器结束时
func _on_timer_timeout():
	# 如果成功点击达到要求，则成功
	var success = success_hits >= min_hits_required
	stop(success)

# 滴答计时器超时
func _on_tick_timer_timeout():
	if is_active:
		# 这里可以添加滴答音效或视觉效果
		pass 