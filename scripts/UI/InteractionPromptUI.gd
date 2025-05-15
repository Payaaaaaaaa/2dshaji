extends Control
class_name InteractionPromptUI

# 节点引用
@onready var prompt_label = $PromptLabel
@onready var key_icon = $KeyIcon
@onready var progress_bar = $ProgressBar
@onready var animation_player = $AnimationPlayer

# 配置
@export var fade_time: float = 0.2
@export var progress_visible: bool = true

# 状态变量
var current_interactable: Interactable = null
var interaction_in_progress: bool = false

func _ready():
	# 默认隐藏
	visible = false
	
	# 如果有进度条
	if progress_bar:
		progress_bar.visible = false
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 0

# 显示交互提示
func show_prompt(interactable: Interactable, action_text: String = "交互"):
	current_interactable = interactable
	
	# 设置文本
	if prompt_label:
		if interactable.has_method("get_interaction_text"):
			prompt_label.text = interactable.get_interaction_text()
		else:
			prompt_label.text = "按 E 键" + action_text
	
	# 显示UI
	visible = true
	interaction_in_progress = false
	
	# 播放显示动画
	if animation_player and animation_player.has_animation("show"):
		animation_player.play("show")
	else:
		# 渐变显示
		modulate.a = 0
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, fade_time)
	
	# 重置进度条
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0

# 隐藏交互提示
func hide_prompt():
	if not visible:
		return
		
	current_interactable = null
	interaction_in_progress = false
	
	# 播放隐藏动画
	if animation_player and animation_player.has_animation("hide"):
		animation_player.play("hide")
	else:
		# 渐变隐藏
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, fade_time)
		tween.tween_callback(func(): visible = false)

# 更新交互进度
func update_progress(progress: float):
	interaction_in_progress = progress > 0
	
	if progress_bar:
		if progress > 0 and progress_visible:
			progress_bar.visible = true
		
		progress_bar.value = progress * 100
		
		if progress >= 1.0:
			# 完成动画
			if animation_player and animation_player.has_animation("complete"):
				animation_player.play("complete")

# 设置提示位置(跟随世界坐标)
func set_world_position(world_pos: Vector2, offset: Vector2 = Vector2(0, -50)):
	if not visible:
		return
		
	# 将世界坐标转换为屏幕坐标
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_2d()
		if camera:
			var screen_pos = camera.global_position + (world_pos - camera.global_position) + offset
			global_position = screen_pos

# 跟随交互物体
func follow_target():
	if current_interactable:
		set_world_position(current_interactable.global_position)

func _process(_delta):
	# 跟随目标
	if visible and current_interactable:
		follow_target() 