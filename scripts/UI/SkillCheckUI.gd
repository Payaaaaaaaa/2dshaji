extends Control
class_name SkillCheckUI

# 预加载依赖的脚本
const SkillCheckControllerScript = preload("res://scripts/SkillCheckController.gd")

# 节点引用
@onready var circle_background = $CircleBackground
@onready var success_zone = $SuccessZone
@onready var needle = $Needle
@onready var animation_player = $AnimationPlayer
@onready var timer_progress = $TimerProgress

# 配置参数
@export var rotation_speed: float = 1.0  # 指针旋转速度倍数
@export var success_flash_color: Color = Color(0, 1, 0, 0.5)  # 成功时的闪烁颜色
@export var fail_flash_color: Color = Color(1, 0, 0, 0.5)     # 失败时的闪烁颜色

# 状态变量
var is_active: bool = false
var current_angle: float = 0.0
var success_zone_start: float = 0.0
var success_zone_end: float = 0.0
var success_zone_size: float = 0.0
var needle_rotation_speed: float = 360.0  # 每秒旋转角度

# 控制器引用
var controller

# 信号
signal skill_check_input(position: float)

func _ready():
	# 默认隐藏
	visible = false
	
	# 创建控制器实例
	controller = SkillCheckControllerScript.new()
	add_child(controller)
	
	# 连接控制器信号
	controller.skill_check_triggered.connect(_on_skill_check_triggered)
	controller.skill_check_succeeded.connect(_on_skill_check_succeeded)
	controller.skill_check_failed.connect(_on_skill_check_failed)
	controller.skill_check_completed.connect(_on_skill_check_completed)
	
	# 连接到自身信号
	skill_check_input.connect(_on_skill_check_input)

func _process(delta):
	if !is_active:
		return
	
	# 更新指针旋转
	current_angle += needle_rotation_speed * delta * rotation_speed
	current_angle = fmod(current_angle, 360.0)
	needle.rotation_degrees = current_angle
	
	# 更新计时器进度条
	if timer_progress and controller.timer:
		timer_progress.value = (controller.timer.wait_time - controller.timer.time_left) / controller.timer.wait_time * 100

func _input(event):
	if !is_active:
		return
	
	# 检测空格键或鼠标左键按下
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		# 计算当前位置(0-1范围)
		var needle_position = fmod(current_angle, 360.0) / 360.0
		skill_check_input.emit(needle_position)

# 触发技能检测
func trigger_skill_check(difficulty: float = -1, zone_size: float = -1, custom_timeout: float = -1):
	controller.trigger_skill_check(difficulty, zone_size, custom_timeout)

# 取消技能检测
func cancel():
	if is_active:
		controller.cancel()
		hide_ui()

# 显示UI
func show_ui(difficulty: float, zone_size: float):
	# 计算成功区域角度
	success_zone_size = zone_size * 360.0
	var success_zone_position = controller.success_zone_position * 360.0
	success_zone_start = success_zone_position - (success_zone_size / 2.0)
	success_zone_end = success_zone_position + (success_zone_size / 2.0)
	
	# 设置成功区域位置和大小
	success_zone.rotation_degrees = success_zone_start
	success_zone.get_node("Arc").max_angle = success_zone_size
	
	# 设置旋转速度 (难度越高转得越快)
	needle_rotation_speed = 180.0 + (difficulty * 360.0)
	
	# 重置指针位置(随机起点)
	current_angle = randf() * 360.0
	needle.rotation_degrees = current_angle
	
	# 显示UI
	visible = true
	is_active = true
	
	# 播放出现动画
	if animation_player and animation_player.has_animation("show"):
		animation_player.play("show")

# 隐藏UI
func hide_ui():
	is_active = false
	
	# 播放隐藏动画
	if animation_player and animation_player.has_animation("hide"):
		animation_player.play("hide")
	else:
		visible = false

# 闪烁效果
func flash(success: bool):
	var flash_color = success_flash_color if success else fail_flash_color
	var flash_rect = ColorRect.new()
	flash_rect.color = flash_color
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash_rect)
	
	# 创建闪烁动画
	var tween = create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(flash_rect.queue_free)

# 信号处理

func _on_skill_check_triggered(difficulty: float, zone_size: float):
	show_ui(difficulty, zone_size)

func _on_skill_check_succeeded():
	flash(true)

func _on_skill_check_failed():
	flash(false)

func _on_skill_check_completed(_success: bool):
	# 短暂延迟后隐藏UI
	get_tree().create_timer(0.3).timeout.connect(hide_ui)

func _on_skill_check_input(needle_position: float):
	controller.handle_input(needle_position) 
