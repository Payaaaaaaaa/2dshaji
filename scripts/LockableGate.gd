extends Interactable
class_name LockableGate

# 栅栏状态枚举
enum GateState {
	OPEN,        # 开启状态
	CLOSING,     # 关闭中
	CLOSED,      # 关闭状态
	LOCKED,      # 锁定状态
	UNLOCKING    # 解锁中
}

# 栅栏特有属性
@export var current_state: int = GateState.OPEN
@export var lock_time: float = 2.0    # 锁定时间
@export var unlock_time: float = 5.0  # 解锁时间

# 计时器
var state_progress: float = 0.0

# 音频资源
@onready var sound_close = $SoundClose
@onready var sound_open = $SoundOpen
@onready var sound_lock = $SoundLock
@onready var sound_unlock = $SoundUnlock

# 碰撞区域
@onready var collision_body = $CollisionShape2D
@onready var passage_blocker = $PassageBlocker

func _ready():
	super._ready()
	
	# 初始化碰撞状态
	update_collision_state()
	
	# 初始化视觉状态
	update_visual_state()
	
	# 将栅栏添加到组
	add_to_group("gates")

# 添加额外同步属性
func setup_additional_syncing(config):
	config.add_property("current_state")
	config.add_property("state_progress")

# 设置栅栏状态
func set_state(new_state: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_state", new_state)
		return
		
	current_state = new_state
	state_progress = 0.0
	
	# 更新交互状态
	match new_state:
		GateState.OPEN:
			is_interactable = true
		GateState.CLOSING:
			is_interactable = false
		GateState.CLOSED:
			is_interactable = true
		GateState.LOCKED:
			is_interactable = true
		GateState.UNLOCKING:
			is_interactable = false
	
	# 更新碰撞状态
	update_collision_state()
	
	# 同步到客户端
	rpc("client_set_state", new_state)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("gate_state_changed", {
			"gate": get_path(),
			"state": new_state
		})

# 更新碰撞状态
func update_collision_state():
	if passage_blocker:
		passage_blocker.disabled = current_state == GateState.OPEN

# 开始关闭栅栏
func start_closing():
	if !multiplayer.is_server():
		rpc_id(1, "server_request_start_closing")
		return
		
	if current_state != GateState.OPEN:
		return
		
	# 更新状态
	set_state(GateState.CLOSING)

# 完成关闭栅栏
func complete_closing():
	if !multiplayer.is_server():
		return
		
	if current_state != GateState.CLOSING:
		return
		
	# 更新状态
	set_state(GateState.CLOSED)

# 锁定栅栏
func lock_gate():
	if !multiplayer.is_server():
		rpc_id(1, "server_request_lock_gate")
		return
		
	if current_state != GateState.CLOSED:
		return
		
	# 更新状态
	set_state(GateState.LOCKED)

# 开始解锁栅栏
func start_unlocking():
	if !multiplayer.is_server():
		rpc_id(1, "server_request_start_unlocking")
		return
		
	if current_state != GateState.LOCKED:
		return
		
	# 更新状态
	set_state(GateState.UNLOCKING)

# 完成解锁栅栏
func complete_unlocking():
	if !multiplayer.is_server():
		return
		
	if current_state != GateState.UNLOCKING:
		return
		
	# 更新状态
	set_state(GateState.OPEN)

# 处理逻辑更新
func _process(delta):
	super._process(delta)
	
	# 服务器处理状态进度
	if !multiplayer.is_server():
		return
		
	match current_state:
		GateState.CLOSING:
			state_progress += delta / lock_time
			
			if state_progress >= 1.0:
				complete_closing()
				
		GateState.UNLOCKING:
			state_progress += delta / unlock_time
			
			if state_progress >= 1.0:
				complete_unlocking()

# 交互权限检查
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	match current_state:
		GateState.OPEN:
			# 任何人都可以关闭栅栏
			return true
		GateState.CLOSED:
			# 只有幸存者可以锁定栅栏
			return !is_killer
		GateState.LOCKED:
			# 杀手可以开始解锁
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
	
	match current_state:
		GateState.OPEN:
			# 开始关闭栅栏
			start_closing()
		GateState.CLOSED:
			if !is_killer:
				# 幸存者锁定栅栏
				lock_gate()
		GateState.LOCKED:
			if is_killer:
				# 杀手开始解锁
				start_unlocking()

# 更新视觉状态
func update_visual_state():
	# 更新精灵动画
	if sprite and sprite.has_method("play"):
		match current_state:
			GateState.OPEN:
				sprite.play("open")
			GateState.CLOSING:
				sprite.play("closing")
			GateState.CLOSED:
				sprite.play("closed")
			GateState.LOCKED:
				sprite.play("locked")
			GateState.UNLOCKING:
				sprite.play("unlocking")

# 视觉反馈函数
func on_interaction_visual_start():
	match current_state:
		GateState.LOCKED:
			if sound_unlock:
				sound_unlock.play()

func on_interaction_visual_cancel():
	if sound_unlock and sound_unlock.playing:
		sound_unlock.stop()

func on_interaction_visual_complete():
	match current_state:
		GateState.CLOSING:
			if sound_close:
				sound_close.play()
		GateState.OPEN:
			if sound_open:
				sound_open.play()
		GateState.LOCKED:
			if sound_lock:
				sound_lock.play()

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
func server_request_start_closing():
	if !multiplayer.is_server():
		return
		
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 任何人都可以关闭栅栏
	start_closing()

@rpc("any_peer", "call_local", "reliable")
func server_request_lock_gate():
	if !multiplayer.is_server():
		return
		
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有幸存者可以锁定栅栏
	if Global.network_manager.is_survivor(sender_id):
		lock_gate()

@rpc("any_peer", "call_local", "reliable")
func server_request_start_unlocking():
	if !multiplayer.is_server():
		return
		
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有杀手可以解锁栅栏
	if Global.network_manager.is_killer(sender_id):
		start_unlocking()

@rpc("authority", "call_remote", "reliable")
func client_set_state(new_state: int):
	current_state = new_state
	state_progress = 0.0
	
	# 更新碰撞状态
	update_collision_state()
	
	# 更新视觉状态
	update_visual_state()
	
	# 播放对应音效
	match new_state:
		GateState.CLOSING:
			if sound_close:
				sound_close.play()
		GateState.OPEN:
			if sound_open:
				sound_open.play()
		GateState.LOCKED:
			if sound_lock:
				sound_lock.play()
		GateState.UNLOCKING:
			if sound_unlock:
				sound_unlock.play() 