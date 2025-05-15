extends Node

# UI场景引用
var main_menu_scene = preload("res://scenes/UI/MainMenuUI.tscn") 
var lobby_scene = preload("res://scenes/UI/LobbyUI.tscn")
var game_hud_scene = preload("res://scenes/UI/GameHUD.tscn")

# 当前激活的UI
var current_ui: Control
var network_manager
var game_manager

# 节点引用
@onready var main_menu = $MainMenuUI

func _ready():
	# 初始化
	current_ui = main_menu
	
	# 连接主菜单信号
	if main_menu:
		main_menu.host_game_requested.connect(_on_host_game_requested)
		main_menu.join_game_requested.connect(_on_join_game_requested)
		main_menu.settings_changed.connect(_on_settings_changed)
	
	# 初始化全局单例
	if !get_node_or_null("/root/Global"):
		print("警告: 未找到Global单例")
	else:
		# 获取网络管理器引用
		network_manager = get_node("/root/Global").network_manager
		
		# 连接网络管理器信号
		if network_manager:
			network_manager.lobby_created.connect(_on_lobby_created)
			network_manager.lobby_joined.connect(_on_lobby_joined)
			network_manager.game_started.connect(_on_game_started)
			network_manager.disconnected_from_host.connect(_on_disconnected)

# 切换UI界面
func switch_to_ui(ui_type: String):
	# 移除当前UI
	if current_ui:
		current_ui.queue_free()
	
	var new_ui
	
	# 创建新UI
	match ui_type:
		"main_menu":
			new_ui = main_menu_scene.instantiate()
			add_child(new_ui)
			
			# 连接信号
			new_ui.host_game_requested.connect(_on_host_game_requested)
			new_ui.join_game_requested.connect(_on_join_game_requested)
			new_ui.settings_changed.connect(_on_settings_changed)
			
		"lobby":
			new_ui = lobby_scene.instantiate()
			add_child(new_ui)
			
			# 连接信号
			new_ui.start_game_requested.connect(_on_start_game_requested)
			new_ui.player_ready_toggled.connect(_on_player_ready_toggled)
			new_ui.role_selected.connect(_on_role_selected)
			new_ui.back_to_menu_requested.connect(_on_back_to_menu_requested)
			new_ui.player_chat_sent.connect(_on_player_chat_sent)
			
			# 设置大厅信息
			if network_manager:
				new_ui.set_lobby_info("游戏大厅", network_manager.get_room_code())
				new_ui.set_is_host(network_manager.is_host())
				new_ui.set_local_player_id(network_manager.get_unique_id())
				
				# 添加玩家列表
				var player_list = network_manager.get_player_list()
				for player_id in player_list:
					var player_info = player_list[player_id]
					new_ui.add_player(
						player_id, 
						player_info.get("name", "玩家" + str(player_id)),
						player_info.get("role", "survivor"),
						player_info.get("ready", false)
					)
			
		"game":
			new_ui = game_hud_scene.instantiate()
			add_child(new_ui)
			
			# 获取本地玩家引用并设置到HUD
			var local_player = get_node_or_null("/root/Game/Players/" + str(network_manager.get_unique_id()))
			if local_player:
				new_ui.set_player(local_player)
			
			# 设置游戏信息
			if get_node_or_null("/root/Game"):
				var game = get_node("/root/Game")
				var generator_count = game.get_meta("total_generators", 5)
				var survivor_count = game.get_meta("total_survivors", 4)
				
				new_ui.update_generators_count(0, generator_count)
				new_ui.update_survivors_count(survivor_count, survivor_count)
	
	# 更新当前UI引用
	current_ui = new_ui

# 信号处理函数

func _on_host_game_requested(port: int):
	if network_manager:
		network_manager.create_server(port)

func _on_join_game_requested(ip: String, port: int):
	if network_manager:
		network_manager.join_server(ip, port)

func _on_settings_changed(settings: Dictionary):
	# 应用设置
	if settings.has("music_volume"):
		# TODO: 设置音乐音量
		pass
		
	if settings.has("sfx_volume"):
		# TODO: 设置音效音量
		pass
		
	# 全屏设置已在MainMenuUI中直接应用

func _on_lobby_created():
	switch_to_ui("lobby")

func _on_lobby_joined():
	switch_to_ui("lobby")

func _on_start_game_requested():
	if network_manager and network_manager.is_host():
		network_manager.start_game()

func _on_player_ready_toggled(is_ready: bool):
	if network_manager:
		network_manager.set_player_ready(is_ready)

func _on_role_selected(role: String):
	if network_manager:
		network_manager.set_player_role(role)

func _on_back_to_menu_requested():
	if network_manager:
		network_manager.disconnect_from_server()
	
	switch_to_ui("main_menu")

func _on_player_chat_sent(message: String):
	if network_manager:
		network_manager.send_chat_message(message)

func _on_game_started():
	switch_to_ui("game")

func _on_disconnected():
	switch_to_ui("main_menu") 