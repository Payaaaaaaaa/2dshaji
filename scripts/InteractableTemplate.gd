extends Interactable
class_name InteractableTemplate

# 特有属性示例
@export var custom_property: bool = false

# 子节点引用示例
@onready var custom_node = $CustomNode

func _ready():
	super._ready()  # 必须调用父类的_ready()
	
	# 初始化视觉状态
	update_visual_state()

# 添加额外同步属性
func setup_additional_syncing(config):
	# 添加需要同步的属性
	config.add_property("custom_property")

# 检查交互权限
func has_interaction_permission(character: Character) -> bool:
	var is_killer = Global.network_manager.is_killer(character.player_id)
	
	# 根据游戏规则定义谁可以与此物体交互
	# 例如：只允许幸存者、只允许杀手、或根据角色状态决定
	
	return true  # 默认允许交互，根据实际需求修改

# 交互完成后的特定逻辑
func on_interaction_completed(player_id: int):
	# 获取角色引用
	var character = get_node_or_null("/root/Game/Players/" + str(player_id))
	if !character:
		return
	
	# 执行交互完成后的逻辑
	# 例如：触发事件、改变状态等
	
	# 通知游戏逻辑
	if get_node_or_null("/root/Game"):
		get_node("/root/Game").on_game_event("custom_event", {"object": get_path(), "player_id": player_id})

# 视觉反馈函数实现
func on_interaction_visual_start():
	# 播放开始交互的视觉/音频效果
	pass

func on_interaction_visual_cancel():
	# 播放取消交互的视觉/音频效果
	pass

func on_interaction_visual_complete():
	# 播放完成交互的视觉/音频效果
	pass

# 更新视觉状态
func update_visual_state():
	# 根据当前状态更新视觉效果
	# 例如：更新精灵动画、灯光等
	pass

# 自定义RPC请求示例
@rpc("any_peer", "call_local", "reliable")
func server_request_custom_action(param: Variant):
	if !multiplayer.is_server():
		return
	
	# 验证请求有效性
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 执行自定义操作
	# 并通知其他客户端
	rpc("client_custom_action", param)

# 自定义客户端RPC响应示例
@rpc("authority", "call_remote", "reliable")
func client_custom_action(param: Variant):
	# 处理服务器发来的自定义操作
	# 更新视觉状态等
	update_visual_state() 