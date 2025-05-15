extends Control
class_name LobbyUI

# 节点引用
@onready var lobby_title = $HeaderPanel/LobbyTitle
@onready var room_code = $HeaderPanel/RoomCode
@onready var player_list = $PlayersPanel/PlayerList
@onready var chat_history = $ChatPanel/ChatHistory
@onready var chat_input = $ChatPanel/ChatInput
@onready var send_button = $ChatPanel/SendButton

# 按钮控件
@onready var start_button = $ControlsPanel/StartButton
@onready var ready_button = $ControlsPanel/ReadyButton
@onready var back_button = $ControlsPanel/BackButton
@onready var role_button = $ControlsPanel/RoleButton

# 模板和预制体
@onready var player_item_template = preload("res://scenes/UI/PlayerListItem.tscn")

# 游戏信息
var is_host: bool = false
var is_ready: bool = false
var player_role: String = "survivor" # 或 "killer"
var local_player_id: int = 0
var player_items = {}  # 玩家列表项 {player_id: Control}

# 信号
signal start_game_requested
signal player_ready_toggled(is_ready: bool)
signal role_selected(role: String)
signal player_chat_sent(message: String)
signal back_to_menu_requested

func _ready():
	# 连接按钮信号
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if ready_button:
		ready_button.pressed.connect(_on_ready_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if role_button:
		role_button.pressed.connect(_on_role_button_pressed)
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)
	
	# 聊天输入框
	if chat_input:
		chat_input.text_submitted.connect(_on_chat_input_submitted)
	
	# 设置初始状态
	update_ui_state()

# 设置房间信息
func set_lobby_info(title: String, code: String):
	if lobby_title:
		lobby_title.text = title
	
	if room_code:
		room_code.text = "房间代码: " + code

# 设置是否为主机
func set_is_host(host: bool):
	is_host = host
	update_ui_state()

# 设置本地玩家ID
func set_local_player_id(id: int):
	local_player_id = id

# 更新UI状态
func update_ui_state():
	if start_button:
		start_button.visible = is_host
		start_button.disabled = !can_start_game()
	
	if ready_button:
		ready_button.text = "取消准备" if is_ready else "准备"
	
	if role_button:
		role_button.text = "角色: " + ("杀手" if player_role == "killer" else "幸存者")

# 判断是否可以开始游戏
func can_start_game() -> bool:
	# 检查是否所有玩家都已准备
	for player_id in player_items:
		var item = player_items[player_id]
		if item and not item.get_meta("is_ready", false):
			return false
	
	# 检查是否有足够的玩家
	var killers = 0
	var survivors = 0
	
	for player_id in player_items:
		var item = player_items[player_id]
		if item:
			var role = item.get_meta("role", "survivor")
			if role == "killer":
				killers += 1
			else:
				survivors += 1
	
	# 至少需要1个杀手和1个幸存者
	return killers >= 1 and survivors >= 1

# 添加玩家到列表
func add_player(player_id: int, player_name: String, role: String = "survivor", player_is_ready: bool = false):
	# 检查玩家是否已在列表中
	if player_id in player_items:
		update_player(player_id, player_name, role, player_is_ready)
		return
	
	# 创建玩家列表项
	if not player_item_template:
		print("错误: 玩家列表项模板未设置")
		return
	
	var item = player_item_template.instantiate()
	player_list.add_child(item)
	
	# 设置玩家信息
	var name_label = item.get_node_or_null("NameLabel")
	if name_label:
		name_label.text = player_name
	
	var role_icon = item.get_node_or_null("RoleIcon")
	if role_icon:
		# 设置角色图标
		var texture_name = "killer_icon" if role == "killer" else "survivor_icon"
		role_icon.texture = load("res://assets/icons/" + texture_name + ".png")
	
	var ready_icon = item.get_node_or_null("ReadyIcon")
	if ready_icon:
		ready_icon.visible = player_is_ready
	
	# 存储元数据
	item.set_meta("player_id", player_id)
	item.set_meta("player_name", player_name)
	item.set_meta("role", role)
	item.set_meta("is_ready", player_is_ready)
	
	# 高亮本地玩家
	if player_id == local_player_id:
		item.modulate = Color(1, 1, 0.8) # 轻微黄色高亮
	
	# 保存到列表
	player_items[player_id] = item
	
	# 更新UI状态
	update_ui_state()

# 更新玩家信息
func update_player(player_id: int, player_name: String = "", role: String = "", is_player_ready: bool = false):
	if not player_id in player_items:
		return
	
	var item = player_items[player_id]
	
	# 更新玩家名称
	if player_name:
		var name_label = item.get_node_or_null("NameLabel")
		if name_label:
			name_label.text = player_name
		item.set_meta("player_name", player_name)
	
	# 更新角色
	if role:
		var role_icon = item.get_node_or_null("RoleIcon")
		if role_icon:
			var texture_name = "killer_icon" if role == "killer" else "survivor_icon"
			role_icon.texture = load("res://assets/icons/" + texture_name + ".png")
		item.set_meta("role", role)
	
	# 更新准备状态
	var ready_icon = item.get_node_or_null("ReadyIcon")
	if ready_icon:
		ready_icon.visible = is_player_ready
	item.set_meta("is_ready", is_player_ready)
	
	# 更新UI状态
	update_ui_state()

# 移除玩家
func remove_player(player_id: int):
	if not player_id in player_items:
		return
	
	var item = player_items[player_id]
	player_items.erase(player_id)
	
	if item:
		item.queue_free()
	
	# 更新UI状态
	update_ui_state()

# 清空玩家列表
func clear_player_list():
	for player_id in player_items:
		var item = player_items[player_id]
		if item:
			item.queue_free()
	
	player_items.clear()
	
	# 更新UI状态
	update_ui_state()

# 添加聊天消息
func add_chat_message(player_name: String, message: String, is_system: bool = false):
	if not chat_history:
		return
	
	var text = ""
	
	if is_system:
		text = "[系统] " + message
	else:
		text = player_name + ": " + message
	
	chat_history.text += text + "\n"
	
	# 滚动到底部
	chat_history.scroll_vertical = chat_history.get_line_count() * chat_history.get_line_height()

# 设置本地玩家准备状态
func set_local_player_ready(new_ready_state: bool):
	is_ready = new_ready_state
	
	# 更新UI
	if ready_button:
		ready_button.text = "取消准备" if is_ready else "准备"
	
	# 更新玩家列表
	update_player(local_player_id, "", "", is_ready)
	
	# 发送准备信号
	player_ready_toggled.emit(is_ready)

# 设置本地玩家角色
func set_local_player_role(role: String):
	player_role = role
	
	# 更新UI
	if role_button:
		role_button.text = "角色: " + ("杀手" if player_role == "killer" else "幸存者")
	
	# 更新玩家列表
	update_player(local_player_id, "", player_role, is_ready)
	
	# 发送角色选择信号
	role_selected.emit(player_role)

# 发送聊天消息
func send_chat_message():
	if not chat_input or chat_input.text.strip_edges().is_empty():
		return
	
	var message = chat_input.text.strip_edges()
	
	# 清空输入框
	chat_input.text = ""
	
	# 发送消息信号
	player_chat_sent.emit(message)

# 按钮回调
func _on_start_button_pressed():
	if is_host and can_start_game():
		start_game_requested.emit()

func _on_ready_button_pressed():
	is_ready = !is_ready
	player_ready_toggled.emit(is_ready)
	update_ui_state()

func _on_back_button_pressed():
	back_to_menu_requested.emit()

func _on_role_button_pressed():
	# 切换角色（简单示例，实际可能更复杂）
	if player_role == "survivor":
		player_role = "killer"
	else:
		player_role = "survivor"
	
	role_selected.emit(player_role)
	update_ui_state()

func _on_send_button_pressed():
	send_chat_message()

func _on_chat_input_submitted(_text: String):
	send_chat_message()

# 服务器更新了玩家的准备状态
func on_player_ready_state_changed(player_id: int, new_ready_status: bool):
	if player_id in player_items:
		var item = player_items[player_id]
		item.set_meta("is_ready", new_ready_status)
		var ready_icon = item.get_node_or_null("ReadyIcon")
		if ready_icon:
			ready_icon.visible = new_ready_status
		
		update_ui_state() # 更新开始按钮的状态 
