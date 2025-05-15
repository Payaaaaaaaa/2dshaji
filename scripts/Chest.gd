extends Interactable
class_name Chest

# 宝箱状态枚举
enum ChestState {
	CLOSED,      # 关闭状态
	OPENING,     # 开启中
	OPENED,      # 已开启
	EMPTY        # 已被拿空
}

# 宝箱特有属性
@export var current_state: int = ChestState.CLOSED
@export var contains_item: bool = true  # 是否包含物品
@export var skill_check_chance: float = 0.3  # 技能检测触发概率
@export var skill_check_bonus: float = 0.2   # 技能检测成功进度奖励
@export var skill_check_penalty: float = 0.1 # 技能检测失败进度惩罚

# 物品属性
@export var possible_items = [
	"急救包",       # 可以治疗自己或队友
	"工具箱",       # 加速修理发电机
	"地图",         # 可以看到地图上的重要物品
	"手电筒",       # 可以致盲杀手
	"钥匙",         # 可以开启地下室
]
var contained_item: String = ""

# 音频资源
@onready var sound_open = $SoundOpen
@onready var sound_opening = $SoundOpening
@onready var sound_empty = $SoundEmpty
@onready var sound_skill_success = $SoundSkillSuccess
@onready var sound_skill_fail = $SoundSkillFail

# 粒子效果
@onready var particles_glitter = $ParticlesGlitter
@onready var light = $Light2D

func _ready():
	super._ready()
	
	# 初始化宝箱内物品
	if contains_item and multiplayer.is_server():
		# 随机选择一个物品
		contained_item = possible_items[randi() % possible_items.size()]
	
	# 初始化视觉状态
	update_visual_state()
	
	# 添加到宝箱组
	add_to_group("chests")

# 添加额外同步属性
func setup_additional_syncing(config):
	config.add_property("current_state")
	config.add_property("contains_item")
	config.add_property("contained_item")

# 设置宝箱状态
func set_state(new_state: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_set_state", new_state)
		return
		
	current_state = new_state
	
	# 根据状态更新交互性
	match new_state:
		ChestState.CLOSED:
			is_interactable = true
		ChestState.OPENING:
			is_interactable = true
		ChestState.OPENED:
			is_interactable = contains_item
		ChestState.EMPTY:
			is_interactable = false
	
	# 同步到客户端
	rpc("client_set_state", new_state)

# 开始开启宝箱
func start_opening():
	if !multiplayer.is_server():
		return
		
	if current_state != ChestState.CLOSED:
		return
		
	# 更新状态
	set_state(ChestState.OPENING)

# 完成开启宝箱
func complete_opening():
	if !multiplayer.is_server():
		return
		
	if current_state != ChestState.OPENING:
		return
		
	# 更新状态
	set_state(ChestState.OPENED)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("chest_opened", {"chest": get_path(), "contains_item": contains_item})

# 尝试获取物品
func get_item(player_id: int):
	if !multiplayer.is_server():
		rpc_id(1, "server_request_get_item")
		return
		
	if current_state != ChestState.OPENED or !contains_item:
		return
		
	# 获取物品
	contains_item = false
	
	# 更新状态
	set_state(ChestState.EMPTY)
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("item_obtained", {
			"chest": get_path(), 
			"player_id": player_id, 
			"item": contained_item
		})
		
	# 通知客户端玩家获得了物品
	rpc_id(player_id, "on_item_received", contained_item)

# 处理逻辑更新
func _process(delta):
	super._process(delta)
	
	# 服务器处理技能检测
	if multiplayer.is_server() and current_state == ChestState.OPENING and is_being_interacted:
		for player_id in interacting_players:
			# 随机触发技能检测
			if randf() < skill_check_chance * delta:
				rpc_id(player_id, "trigger_skill_check")

# 交互权限检查
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	# 只有幸存者可以开启宝箱
	if is_killer:
		return false
		
	# 根据宝箱状态决定
	match current_state:
		ChestState.CLOSED:
			return true
		ChestState.OPENING:
			return true
		ChestState.OPENED:
			return contains_item
		ChestState.EMPTY:
			return false
	
	return false

# 交互完成处理
func on_interaction_completed(player_id: int):
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if !character:
		return
		
	# 必须是幸存者
	if Global.network_manager.is_killer(player_id):
		return
		
	# 根据状态处理
	match current_state:
		ChestState.CLOSED, ChestState.OPENING:
			# 完成开启
			complete_opening()
		ChestState.OPENED:
			if contains_item:
				# 获取物品
				get_item(player_id)

# 更新视觉状态
func update_visual_state():
	# 更新精灵动画
	if sprite and sprite.has_method("play"):
		match current_state:
			ChestState.CLOSED:
				sprite.play("closed")
			ChestState.OPENING:
				sprite.play("opening")
			ChestState.OPENED:
				if contains_item:
					sprite.play("opened_with_item")
				else:
					sprite.play("opened_empty")
			ChestState.EMPTY:
				sprite.play("opened_empty")
	
	# 更新粒子效果
	if particles_glitter:
		particles_glitter.emitting = current_state == ChestState.OPENED and contains_item
	
	# 更新灯光
	if light:
		light.enabled = current_state == ChestState.OPENED and contains_item

# 视觉反馈函数
func on_interaction_visual_start():
	if current_state == ChestState.CLOSED:
		if sound_opening:
			sound_opening.play()

func on_interaction_visual_cancel():
	if sound_opening and sound_opening.playing:
		sound_opening.stop()

func on_interaction_visual_complete():
	match current_state:
		ChestState.OPENED:
			if sound_open:
				sound_open.play()
		ChestState.EMPTY:
			if sound_empty:
				sound_empty.play()

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
func server_request_get_item():
	if !multiplayer.is_server():
		return
		
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 检查请求者是否为幸存者
	if Global.network_manager.is_survivor(sender_id):
		get_item(sender_id)

@rpc("authority", "call_remote", "reliable")
func client_set_state(new_state: int):
	current_state = new_state
	
	# 更新视觉状态
	update_visual_state()
	
	# 播放对应音效
	match new_state:
		ChestState.OPENING:
			if sound_opening:
				sound_opening.play()
		ChestState.OPENED:
			if sound_open:
				sound_open.play()
		ChestState.EMPTY:
			if sound_empty:
				sound_empty.play()

# 触发技能检测
@rpc("authority", "call_remote", "reliable")
func trigger_skill_check():
	# 在客户端显示技能检测UI
	print("宝箱技能检测!")
	
	# 模拟玩家响应(实际会连接到UI信号)
	var success = randf() > 0.5
	
	# 通知服务器结果
	rpc_id(1, "skill_check_result", success)

# 处理技能检测结果
@rpc("any_peer", "call_local", "reliable")
func skill_check_result(success: bool):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	
	if player_id in interacting_players:
		if success:
			# 播放成功音效
			rpc_id(player_id, "play_skill_check_success")
			
			# 加速进度
			interacting_players[player_id] += skill_check_bonus
		else:
			# 播放失败音效
			rpc_id(player_id, "play_skill_check_fail")
			
			# 减慢进度
			interacting_players[player_id] -= skill_check_penalty
			interacting_players[player_id] = max(0, interacting_players[player_id])

# 播放技能检测成功音效
@rpc("authority", "call_remote", "reliable")
func play_skill_check_success():
	if sound_skill_success:
		sound_skill_success.play()

# 播放技能检测失败音效
@rpc("authority", "call_remote", "reliable")
func play_skill_check_fail():
	if sound_skill_fail:
		sound_skill_fail.play()

# 通知客户端收到物品
@rpc("authority", "call_remote", "reliable")
func on_item_received(item_name: String):
	print("获得物品: ", item_name)
	# 在实际项目中，这里会调用UI系统显示获得物品的提示
	# 并将物品添加到玩家的背包中 