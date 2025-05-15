extends Node

class_name SkillCheckController

# 技能检测相关信号
signal skill_check_triggered(difficulty: float, success_zone_size: float)
signal skill_check_succeeded
signal skill_check_failed
signal skill_check_completed(success: bool)
signal skill_check_great_success

# 技能检测状态
enum SkillCheckState {
	INACTIVE,   # 未激活
	ACTIVE,     # 已激活，等待玩家输入
	COMPLETED   # 已完成（成功或失败）
}

# 技能检测配置
@export var min_difficulty: float = 0.2  # 最小难度(0-1)
@export var max_difficulty: float = 0.8  # 最大难度(0-1)
@export var min_success_zone: float = 0.05  # 最小成功区域大小(0-1)
@export var max_success_zone: float = 0.2   # 最大成功区域大小(0-1)
@export var default_timeout: float = 2.0    # 默认超时时间(秒)

# QTE配置
var min_interval: float = 5.0  # 最小触发间隔
var max_interval: float = 15.0  # 最大触发间隔
var base_difficulty: float = 0.5  # 基础难度(0-1)
var base_zone_size: float = 0.08  # 成功区域大小
var great_zone_size: float = 0.03  # 完美区域大小
var fail_regression: float = 0.12  # 失败倒退进度

# 技能检测状态
var current_state: int = SkillCheckState.INACTIVE
var current_difficulty: float = 0.5  # 当前难度(0-1)
var success_zone_size: float = 0.1   # 成功区域大小(0-1)
var current_zone_size: float = 0.1   # 当前成功区域大小(0-1)
var success_zone_position: float = 0.0  # 成功区域位置(0-1)
var timer: Timer
var timeout: float = default_timeout  # 当前超时时间
var skill_check_active: bool = false  # 原is_active变量

# 音频资源
@onready var sound_trigger = $SoundTrigger
@onready var sound_success = $SoundSuccess
@onready var sound_fail = $SoundFail

func _ready():
	# 创建计时器
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)

# 触发技能检测
func trigger_skill_check(difficulty: float = -1, zone_size: float = -1, custom_timeout: float = -1):
	if skill_check_active:
		return
	
	# 应用平衡设置
	apply_balance_settings()
	
	# 确定参数
	current_difficulty = difficulty if difficulty >= 0 else base_difficulty
	current_zone_size = zone_size if zone_size >= 0 else base_zone_size
	
	# 调整参数范围
	current_difficulty = clamp(current_difficulty, 0.1, 0.9)
	current_zone_size = clamp(current_zone_size, 0.03, 0.2)
	
	# 设置随机成功区域位置
	success_zone_position = randf()
	
	# 根据游戏进度调整难度
	adjust_difficulty_by_progress()
	
	# 设置定时器
	timer = Timer.new()
	timer.one_shot = true
	if custom_timeout > 0:
		timer.wait_time = custom_timeout
	else:
		timer.wait_time = 3.0  # 默认3秒超时
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	
	# 激活状态并发出信号
	skill_check_active = true
	current_state = SkillCheckState.ACTIVE
	skill_check_triggered.emit(current_difficulty, current_zone_size)
	timer.start()

# 应用平衡参数设置
func apply_balance_settings():
	if GameBalanceManager.instance:
		var params = GameBalanceManager.instance.get_skill_check_params()
		base_difficulty = params.difficulty
		base_zone_size = params.zone_size
		great_zone_size = params.great_zone_size
		min_interval = params.interval_min
		max_interval = params.interval_max
		fail_regression = params.fail_regression

# 根据游戏进度调整难度
func adjust_difficulty_by_progress():
	# 如果发电机完成数量越多，难度越大
	if Global.generators_completed > 0:
		var progress_factor = min(Global.generators_completed / float(Global.GENERATORS_REQUIRED), 1.0)
		# 增加难度，减小成功区域
		current_difficulty += progress_factor * 0.2
		current_zone_size *= (1.0 - progress_factor * 0.3)
		
		# 确保在合理范围内
		current_difficulty = clamp(current_difficulty, 0.1, 0.9)
		current_zone_size = clamp(current_zone_size, 0.03, 0.2)

# 处理玩家输入
func handle_input(_position: float) -> bool:
	if not skill_check_active:
		return false
	
	# 计算目标区域
	var target_position = success_zone_position  # 使用已设置的位置，而不是随机值
	var half_zone = current_zone_size / 2.0
	var target_start = target_position - half_zone
	var target_end = target_position + half_zone
	
	# 检查是否在目标区域内
	var within_zone = (_position >= target_start and _position <= target_end)
	
	# 检查是否在完美区域内
	var half_great_zone = great_zone_size / 2.0
	var great_start = target_position - half_great_zone
	var great_end = target_position + half_great_zone
	var within_great_zone = (_position >= great_start and _position <= great_end)
	
	# 触发结果
	if within_great_zone:
		# 完美成功
		skill_check_succeeded.emit()
		skill_check_great_success.emit()
	elif within_zone:
		# 普通成功
		skill_check_succeeded.emit()
	else:
		# 失败
		skill_check_failed.emit()
	
	# 完成技能检测
	skill_check_completed.emit(within_zone or within_great_zone)
	
	# 清理
	skill_check_active = false
	timer.stop()
	if timer:
		timer.queue_free()
		timer = null
	
	return within_zone or within_great_zone

# 重置技能检测
func reset():
	current_state = SkillCheckState.INACTIVE
	skill_check_active = false
	if timer:
		timer.stop()

# 取消技能检测
func cancel():
	if skill_check_active:
		if timer:
			timer.stop()
		current_state = SkillCheckState.INACTIVE
		skill_check_active = false

# 计时器超时处理
func _on_timeout():
	if skill_check_active:
		# 超时视为失败
		complete_skill_check(false)

# 获取当前难度
func get_difficulty() -> float:
	return current_difficulty

# 获取成功区域信息
func get_success_zone() -> Dictionary:
	return {
		"position": success_zone_position,
		"size": success_zone_size
	}

# 检查是否处于激活状态
func is_active() -> bool:
	return skill_check_active

# 处理技能检测完成
func complete_skill_check(success: bool):
	# 更新状态
	current_state = SkillCheckState.COMPLETED
	skill_check_active = false
	
	# 播放对应音效
	if success:
		if sound_success:
			sound_success.play()
		skill_check_succeeded.emit()
	else:
		if sound_fail:
			sound_fail.play()
		skill_check_failed.emit()
	
	# 发送完成信号
	skill_check_completed.emit(success) 