extends Interactable
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

# 出口门特有属性
@export var is_powered: bool = false  # 是否已通电
@export var is_open: bool = false     # 是否已打开

func _ready():
	super._ready()
	
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

# 添加额外同步属性
func setup_additional_syncing(config):
	config.add_property("is_powered")
	config.add_property("is_open")
	config.add_property("open_progress")

# 设置通电状态
func set_powered(value: bool):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_powered", value)
		return
	
	is_powered = value
	
	# 更新是否可交互
	is_interactable = is_powered and !is_open
	
	# 同步到所有客户端
	rpc("client_set_powered", value)

# 设置开门状态
func set_open(value: bool):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_open", value)
		return
	
	is_open = value
	
	# 更新是否可交互 - 门打开后不可再交互
	is_interactable = is_powered and !is_open
	
	# 同步到所有客户端
	rpc("client_set_open", value)

# 检查交互权限
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	# 杀手不能开门
	if is_killer:
		return false
	
	# 只有通电且未开启的门可以交互
	return is_powered and !is_open

# 交互完成后的特定逻辑
func on_interaction_completed(player_id: int):
	# 门开启后，可以让幸存者逃脱
	set_open(true)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("exit_gate_opened", {"gate": get_path(), "player_id": player_id})

# 处理交互进度
func _process(delta):
	super._process(delta)
	
	# 服务器处理进度更新
	if multiplayer.is_server() and is_powered and !is_open:
		# 如果有人正在开门，更新进度
		if is_being_interacted and interacting_players.size() > 0:
			# 打开进度直接使用交互进度
			open_progress = interaction_progress
			
			# 如果进度达到100%，完成开门
			if open_progress >= 1.0:
				set_open(true)

# 触发幸存者逃脱
func trigger_escape(player_id: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_trigger_escape", player_id)
		return
	
	# 验证门是否开启
	if !is_open:
		return
	
	# 验证是否为幸存者
	if !Global.network_manager.is_survivor(player_id):
		return
	
	# 获取幸存者引用
	var survivor = get_node_or_null("/root/Game/Players/" + str(player_id))
	if !survivor:
		return
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("survivor_escaped", {"player_id": player_id, "gate": get_path()})
	
	# 可选：移除幸存者或播放逃脱动画
	survivor.server_set_variable("health_state", survivor.HealthState.DEAD)  # 使用DEAD状态代表逃脱
	survivor.visible = false

# 更新视觉状态func update_visual_state():	# 更新灯光状态	if light_off:		light_off.visible = !is_powered		if light_on:		light_on.visible = is_powered and !is_open		if light_open:		light_open.visible = is_open		# 更新精灵动画	if sprite and sprite.has_method("play"):		if is_open:			sprite.play("open")		elif is_powered:			sprite.play("powered")		else:			sprite.play("unpowered")# 视觉反馈函数实现func on_interaction_visual_start():	if sound_opening and is_powered and !is_open:		sound_opening.play()func on_interaction_visual_cancel():	if sound_opening and sound_opening.playing:		sound_opening.stop()func on_interaction_visual_complete():	# 播放开门音效	if is_open and sound_opened:		sound_opened.play()		# 更新灯光	update_visual_state()

# RPC处理函数
@rpc("any_peer", "call_local", "reliable")
func server_request_set_powered(value: bool):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器可以设置通电状态
	if sender_id == 1:
		set_powered(value)

@rpc("any_peer", "call_local", "reliable")
func server_request_set_open(value: bool):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只有服务器可以设置开门状态
	if sender_id == 1:
		set_open(value)

@rpc("any_peer", "call_local", "reliable")
func server_request_trigger_escape(player_id: int):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 只能触发自己的逃脱
	if sender_id == player_id:
		trigger_escape(player_id)

@rpc("authority", "call_remote", "reliable")
func client_set_powered(value: bool):
	is_powered = value
	is_interactable = is_powered and !is_open
	
		# 更新视觉状态	update_visual_state()		# 播放通电音效	if is_powered and sound_powered:		sound_powered.play()@rpc("authority", "call_remote", "reliable")func client_set_open(value: bool):	is_open = value	is_interactable = is_powered and !is_open		# 更新视觉状态	update_visual_state()		# 播放开门音效	if is_open and sound_opened:
		opened_sound.play()

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