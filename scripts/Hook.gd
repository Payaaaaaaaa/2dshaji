extends StaticBody2D
class_name Hook

# 钩子状态
enum HookState {
	EMPTY,      # 空闲
	OCCUPIED    # 有幸存者
}

# 当前状态
var state: int = HookState.EMPTY

# 当前被挂的幸存者
var current_survivor = null

# 救援进度
var rescue_progress: float = 0.0
var rescue_time: float = 2.0  # 救援需要的时间

# 视觉和音效
@onready var sprite = $AnimatedSprite2D
@onready var light = $Light2D
@onready var hook_point = $HookPoint  # 挂钩位置点
@onready var hook_sound = $HookSound
@onready var rescue_sound = $RescueSound

# 信号
signal survivor_hooked(survivor)
signal survivor_rescued(survivor, rescuer)
signal survivor_died(survivor)

func _ready():
	# 初始化状态
	state = HookState.EMPTY
	
	# 更新视觉效果
	update_visuals()
	
	# 添加到钩子组
	add_to_group("hooks")

# 尝试挂幸存者
func hook_survivor(survivor):
	if state != HookState.EMPTY or !survivor:
		return false
	
	# 更新状态
	state = HookState.OCCUPIED
	current_survivor = survivor
	
	# 设置幸存者位置
	if hook_point:
		survivor.global_position = hook_point.global_position
	
	# 播放挂钩声音
	if hook_sound:
		hook_sound.play()
	
	# 更新视觉效果
	update_visuals()
	
	# 发送信号
	emit_signal("survivor_hooked", survivor)
	
	return true

# 解钩幸存者
func unhook_survivor(rescuer = null):
	if state != HookState.OCCUPIED or !current_survivor:
		return false
	
	var saved_survivor = current_survivor
	
	# 更新状态
	state = HookState.EMPTY
	current_survivor = null
	
	# 播放救援声音
	if rescue_sound:
		rescue_sound.play()
	
	# 更新视觉效果
	update_visuals()
	
	# 发送信号
	emit_signal("survivor_rescued", saved_survivor, rescuer)
	
	return true

# 幸存者在钩子上死亡
func on_survivor_death():
	if state != HookState.OCCUPIED or !current_survivor:
		return
	
	var dead_survivor = current_survivor
	
	# 更新状态
	state = HookState.EMPTY
	current_survivor = null
	
	# 更新视觉效果
	update_visuals()
	
	# 发送信号
	emit_signal("survivor_died", dead_survivor)

# 更新视觉效果
func update_visuals():
	match state:
		HookState.EMPTY:
			if sprite:
				sprite.play("idle")
			if light:
				light.energy = 0.5
		HookState.OCCUPIED:
			if sprite:
				sprite.play("occupied")
			if light:
				light.energy = 1.0

# 检查是否有幸存者被挂
func has_survivor() -> bool:
	return state == HookState.OCCUPIED && current_survivor != null

# 检查是否可以挂幸存者
func can_hook_survivor() -> bool:
	return state == HookState.EMPTY

# 检查是否可以救幸存者
func can_rescue_survivor(rescuer = null) -> bool:
	if state != HookState.OCCUPIED or !current_survivor:
		return false
	
	# 确保救援者不是被挂的幸存者
	if rescuer == current_survivor:
		return false
	
	# 只有幸存者可以救援
	if rescuer and rescuer is Survivor and rescuer.health_state != Survivor.HealthState.DOWNED:
		return true
	
	return false

# 开始救援
func start_rescue(rescuer):
	if !can_rescue_survivor(rescuer):
		return false
	
	rescue_progress = 0.0
	return true

# 更新救援进度
func update_rescue_progress(rescuer, delta):
	if !can_rescue_survivor(rescuer):
		return false
	
	rescue_progress += delta / rescue_time
	
	if rescue_progress >= 1.0:
		# 完成救援
		unhook_survivor(rescuer)
		rescue_progress = 0.0
		return true
	
	return false

# 中断救援
func cancel_rescue():
	rescue_progress = 0.0

# 获取当前状态文本
func get_status_text() -> String:
	match state:
		HookState.EMPTY:
			return "空闲"
		HookState.OCCUPIED:
			if current_survivor:
				return "挂着: " + current_survivor.name
			else:
				return "已占用"
	return "" 