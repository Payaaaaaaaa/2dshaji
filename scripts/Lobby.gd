extends Control

# 常量
const MAX_PLAYERS = 5  # 1杀手 + 4幸存者

# 全局单例
var global

# 玩家数据
var players = {}  # 存储玩家信息：{id: {name, role, ready}}
var is_ready = false
var room_id = "N/A"

# UI引用
@onready var room_info_label = $RoomInfoPanel/RoomInfoLabel
@onready var player_list = $PlayerListPanel/PlayerList
@onready var ready_button = $ButtonsPanel/HBoxContainer/ReadyButton
@onready var start_button = $ButtonsPanel/HBoxContainer/StartButton
@onready var chat_box = $ChatArea/ChatBox
@onready var chat_input = $ChatArea/ChatInput

# 玩家行UI缓存
@onready var player_rows = [
	$PlayerListPanel/PlayerList/PlayerRow0,
	$PlayerListPanel/PlayerList/PlayerRow1,
	$PlayerListPanel/PlayerList/PlayerRow2,
	$PlayerListPanel/PlayerList/PlayerRow3,
	$PlayerListPanel/PlayerList/PlayerRow4
]

func _ready():
	# 获取全局单例
	global = get_node("/root/Global")
	
	# 连接信号
	if global:
		global.player_list_updated.connect(_on_player_list_updated)
		global.player_ready_changed.connect(_on_player_ready_changed)
		global.chat_message_received.connect(_on_chat_message_received)
		global.game_started.connect(_on_game_started)
		
		# 获取房间ID
		if global.room_id:
			room_id = global.room_id
		
		# 向服务器请求玩家列表
		global.request_player_list()
	
	# 根据玩家角色设置UI状态
	update_ui_for_role()
	
	# 请求初始玩家列表
	request_update()

# 更新UI以适应角色（杀手/幸存者）
func update_ui_for_role():
	if global:
		# 根据角色显示/隐藏开始游戏按钮
		start_button.visible = global.is_killer
		
		# 如果是杀手（房主），无需准备
		ready_button.visible = !global.is_killer

# 更新玩家列表UI
func update_player_list_ui():
	# 更新房间信息
	var player_count = players.size()
	room_info_label.text = "房间ID: %s  |  玩家: %d/%d" % [room_id, player_count, MAX_PLAYERS]
	
	# 先隐藏所有行
	for row in player_rows:
		row.visible = false
	
	# 获取玩家ID列表并排序（确保杀手始终在第一位）
	var player_ids = players.keys()
	player_ids.sort_custom(func(a, b): 
		if players[a].role == "killer":
			return true
		elif players[b].role == "killer":
			return false
		else:
			return a < b
	)
	
	# 更新每个玩家的显示
	var index = 0
	for player_id in player_ids:
		if index < player_rows.size():
			var player_data = players[player_id]
			var row = player_rows[index]
			
			# 设置玩家信息
			row.get_node("NameLabel").text = player_data.name
			
			# 设置角色
			var role_text = "幸存者"
			if player_data.role == "killer":
				role_text = "杀手"
			row.get_node("RoleLabel").text = role_text
			
			# 设置准备状态
			var ready_text = "未准备"
			var ready_color = Color(1, 1, 0)  # 黄色
			
			if player_data.role == "killer":
				ready_text = "房主"
				ready_color = Color(1, 0, 0)  # 红色
			elif player_data.ready:
				ready_text = "已准备"
				ready_color = Color(0, 1, 0)  # 绿色
			
			row.get_node("ReadyLabel").text = ready_text
			row.get_node("ReadyLabel").add_theme_color_override("font_color", ready_color)
			
			# 显示这一行
			row.visible = true
			
			index += 1
	
	# 更新开始游戏按钮状态（只有当所有幸存者都准备好时，杀手才能开始游戏）
	if global and global.is_killer:
		var can_start = true
		
		# 检查至少有一个幸存者
		var has_survivor = false
		
		for player_id in players:
			var player_data = players[player_id]
			if player_data.role == "survivor":
				has_survivor = true
				if not player_data.ready:
					can_start = false
					break
		
		# 至少需要一个幸存者才能开始
		start_button.disabled = !can_start or !has_survivor

# 请求更新玩家列表
func request_update():
	if global:
		global.request_player_list()

# 准备按钮
func _on_ready_button_pressed():
	if global:
		is_ready = !is_ready
		ready_button.text = "取消准备" if is_ready else "准备"
		global.set_player_ready(is_ready)

# 开始游戏按钮
func _on_start_button_pressed():
	if global and global.is_killer and !start_button.disabled:
		global.start_game()

# 离开房间按钮
func _on_leave_button_pressed():
	if global:
		global.leave_room()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

# 定时更新UI
func _on_update_timer_timeout():
	request_update()

# 当玩家列表更新时
func _on_player_list_updated(player_data):
	players = player_data
	update_player_list_ui()

# 当玩家准备状态改变时
func _on_player_ready_changed(player_id, is_ready):
	if player_id in players:
		players[player_id].ready = is_ready
		update_player_list_ui()

# 当收到聊天消息时
func _on_chat_message_received(sender_name, message):
	chat_box.text += "\n%s: %s" % [sender_name, message]
	# 自动滚动到底部
	chat_box.scroll_to_line(chat_box.get_line_count() - 1)

# 当游戏开始时
func _on_game_started():
	# 切换到游戏场景
	get_tree().change_scene_to_file("res://scenes/Game.tscn") 