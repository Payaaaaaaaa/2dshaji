extends StaticBody2D
class_name Interactable

# 常量定义
const INTERACTION_COOLDOWN = 0.5  # 交互冷却时间

# 信号
signal interaction_started(player)
signal interaction_completed(player)
signal interaction_canceled(player)

# 交互属性
@export var interaction_time: float = 3.0  # 完成交互所需时间
@export var interaction_progress: float = 0.0:  # 当前交互进度
	set(value):
		interaction_progress = value
		if interaction_progress_bar:
			interaction_progress_bar.value = interaction_progress * 100

# 状态标志
@export var is_interactable: bool = true  # 是否可交互
@export var is_being_interacted: bool = false  # 是否正在被交互
var interacting_players = {}  # 正在交互的玩家 {player_id: progress}
var cooldown_timer: Timer

# 子节点引用
@onready var sprite = $Sprite2D
@onready var interaction_area = $InteractionArea
@onready var interaction_progress_bar = $ProgressBar
@onready var sync_node: MultiplayerSynchronizer = $Synchronizer

# 初始化
func _ready():
	# 初始化冷却计时器
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = INTERACTION_COOLDOWN
	add_child(cooldown_timer)
	
	# 初始化同步节点
	if sync_node:
		setup_syncing()
	else:
		push_error("交互物件缺少MultiplayerSynchronizer节点")
	
	# 隐藏进度条
	if interaction_progress_bar:
		interaction_progress_bar.visible = false
		interaction_progress_bar.max_value = 100
	
	# 连接交互区域信号
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

# 设置同步属性
func setup_syncing():
	var config = sync_node.get_replication_config()
	
	# 基础状态同步
	config.add_property("is_interactable")
	config.add_property("is_being_interacted")
	config.add_property("interaction_progress")
	
	# 子类可添加更多同步属性
	setup_additional_syncing(config)

# 子类可覆盖此方法添加更多同步属性
func setup_additional_syncing(_config):
	pass

# 处理交互
func _process(delta):
	# 更新交互进度
	if is_being_interacted and interacting_players.size() > 0:
		for player_id in interacting_players.keys():
			# 如果是服务器，更新进度
			if multiplayer.is_server():
				interacting_players[player_id] += delta / interaction_time
				
				# 如果进度达到100%，完成交互
				if interacting_players[player_id] >= 1.0:
					complete_interaction(player_id)
		
		# 更新总进度
		if multiplayer.is_server():
			var total_progress = 0.0
			for progress in interacting_players.values():
				total_progress += progress
			
			# 平均进度或根据游戏设计调整
			if interacting_players.size() > 0:
				interaction_progress = min(1.0, total_progress / interacting_players.size())

# 检查是否可以被特定角色交互
func can_interact_with(character: Character) -> bool:
	if !is_interactable or cooldown_timer.time_left > 0:
		return false
	
	# 检查角色是否有交互权限(由子类实现具体逻辑)
	return has_interaction_permission(character)

# 检查角色是否有交互权限(由子类实现)
func has_interaction_permission(character: Character) -> bool:
	# 基础实现：杀手和幸存者有不同权限
	var _is_killer = Global.network_manager.is_killer(character.player_id)
	
	# 默认情况下，任何人都可以交互
	# 子类应该覆盖此方法以限制特定角色
	return true

# 开始交互
func start_interaction(character: Character):
	var player_id = character.player_id
	
	# 客户端发送请求到服务器
	if !multiplayer.is_server():
		rpc_id(1, "server_request_start_interaction", player_id)
		return
	
	# 服务器处理开始交互
	if can_interact_with(character):
		# 将玩家添加到交互列表
		interacting_players[player_id] = 0.0
		is_being_interacted = true
		
		# 通知所有客户端
		rpc("client_start_interaction", player_id)
		
		# 触发信号
		interaction_started.emit(character)

# 取消交互
func cancel_interaction(character: Character):
	var player_id = character.player_id
	
	# 客户端发送请求到服务器
	if !multiplayer.is_server():
		rpc_id(1, "server_request_cancel_interaction", player_id)
		return
	
	# 服务器处理取消交互
	if player_id in interacting_players:
		interacting_players.erase(player_id)
		
		# 如果没有玩家交互，重置状态
		if interacting_players.size() == 0:
			is_being_interacted = false
		
		# 通知所有客户端
		rpc("client_cancel_interaction", player_id)
		
		# 触发信号
		interaction_canceled.emit(character)

# 完成交互
func complete_interaction(player_id: int):
	# 仅服务器处理完成交互
	if !multiplayer.is_server():
		return
	
	# 从交互列表中移除玩家
	if player_id in interacting_players:
		interacting_players.erase(player_id)
		
		# 如果没有玩家交互，重置状态
		if interacting_players.size() == 0:
			is_being_interacted = false
			
			# 开始冷却
			cooldown_timer.start()
		
		# 获取角色引用
		var character = get_node_or_null("/root/Game/Players/" + str(player_id))
		
		# 通知所有客户端
		rpc("client_complete_interaction", player_id)
		
		# 如果有角色引用，触发信号
		if character:
			interaction_completed.emit(character)
		
		# 执行完成交互的特定逻辑(由子类实现)
		on_interaction_completed(player_id)

# 交互完成后的特定逻辑(由子类实现)
func on_interaction_completed(_player_id: int):
	pass

# 服务器RPC处理函数
@rpc("any_peer", "call_local", "reliable")
func server_request_start_interaction(player_id: int):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_id:
		return
	
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if character:
		start_interaction(character)

@rpc("any_peer", "call_local", "reliable")
func server_request_cancel_interaction(player_id: int):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_id:
		return
	
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if character:
		cancel_interaction(character)

# 客户端RPC处理函数
@rpc("authority", "call_remote", "reliable")
func client_start_interaction(_player_id: int):
	# 显示进度条
	if interaction_progress_bar:
		interaction_progress_bar.visible = true
	
	# 设置标志
	is_being_interacted = true
	
	# 处理视觉反馈(如动画)
	on_interaction_visual_start()

@rpc("authority", "call_remote", "reliable")
func client_cancel_interaction(_player_id: int):
	# 如果没有玩家交互，隐藏进度条
	if interacting_players.size() == 0:
		if interaction_progress_bar:
			interaction_progress_bar.visible = false
		
		# 重置标志
		is_being_interacted = false
	
	# 处理视觉反馈
	on_interaction_visual_cancel()

@rpc("authority", "call_remote", "reliable")
func client_complete_interaction(_player_id: int):
	# 如果没有玩家交互，隐藏进度条
	if interacting_players.size() == 0:
		if interaction_progress_bar:
			interaction_progress_bar.visible = false
		
		# 重置标志
		is_being_interacted = false
	
	# 处理视觉反馈
	on_interaction_visual_complete()

# 视觉反馈函数(由子类实现)
func on_interaction_visual_start():
	pass

func on_interaction_visual_cancel():
	pass

func on_interaction_visual_complete():
	pass

# 交互区域信号处理
func _on_body_entered(body):
	if body is Character and body.has_method("on_interactable_entered"):
		body.on_interactable_entered(self)

func _on_body_exited(body):
	if body is Character and body.has_method("on_interactable_exited"):
		body.on_interactable_exited(self) 
