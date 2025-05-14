extends Control

# 默认端口
const DEFAULT_PORT = 9999
# 音频总线名称
const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"

# 全局单例
var global

# UI引用
@onready var join_popup = $JoinPopup
@onready var ip_input = $JoinPopup/IPInput
@onready var port_input = $JoinPopup/PortInput
@onready var name_input = $JoinPopup/NameInput
@onready var settings_popup = $SettingsPopup
@onready var music_slider = $SettingsPopup/VBoxContainer/MusicVolume/MusicSlider
@onready var sfx_slider = $SettingsPopup/VBoxContainer/SFXVolume/SFXSlider
@onready var fullscreen_toggle = $SettingsPopup/VBoxContainer/FullscreenToggle

func _ready():
	# 获取Global单例
	global = get_node("/root/Global")
	
	# 初始化设置
	load_settings()
	
	# 设置默认值
	port_input.text = str(DEFAULT_PORT)
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		fullscreen_toggle.disabled = true
	
	# 连接信号
	if global:
		global.connection_failed.connect(_on_connection_failed)
		global.connection_succeeded.connect(_on_connection_succeeded)
		global.server_created.connect(_on_server_created)
	
	# 播放背景音乐
	# AudioManager.play_music("menu_theme")

# 创建房间按钮
func _on_create_room_button_pressed():
	if global:
		# 保存玩家名称
		global.player_name = name_input.text if !name_input.text.is_empty() else "杀手"
		global.is_killer = true
		
		# 创建服务器
		global.create_server(DEFAULT_PORT)
	else:
		print("错误: 无法找到Global单例")

# 加入房间按钮
func _on_join_room_button_pressed():
	join_popup.visible = true

# 实际连接到服务器
func _on_join_button_pressed():
	var ip = ip_input.text
	var port = int(port_input.text)
	var player_name = name_input.text
	
	if ip.is_empty():
		ip = "127.0.0.1"  # 默认本地
	
	if player_name.is_empty():
		player_name = "幸存者"
	
	if global:
		# 保存玩家信息
		global.player_name = player_name
		global.is_killer = false
		
		# 尝试连接
		global.join_server(ip, port)
	else:
		print("错误: 无法找到Global单例")
	
	join_popup.visible = false

# 取消连接
func _on_cancel_button_pressed():
	join_popup.visible = false

# 设置按钮
func _on_settings_button_pressed():
	settings_popup.visible = true

# 保存设置
func _on_settings_save_button_pressed():
	# 设置音量
	var music_db = linear_to_db(music_slider.value)
	var sfx_db = linear_to_db(sfx_slider.value)
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), sfx_db)
	
	# 设置全屏
	if fullscreen_toggle.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# 保存设置
	save_settings()
	
	settings_popup.visible = false

# 退出按钮
func _on_quit_button_pressed():
	get_tree().quit()

# 连接失败回调
func _on_connection_failed():
	print("连接失败")
	# 显示错误对话框
	var dialog = AcceptDialog.new()
	dialog.title = "连接错误"
	dialog.dialog_text = "无法连接到服务器，请检查IP和端口是否正确。"
	add_child(dialog)
	dialog.popup_centered()

# 连接成功回调
func _on_connection_succeeded():
	print("连接成功")
	# 切换到大厅场景
	get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")

# 服务器创建成功回调
func _on_server_created():
	print("服务器创建成功")
	# 切换到大厅场景
	get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")

# 保存设置
func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("video", "fullscreen", fullscreen_toggle.button_pressed)
	
	var err = config.save("user://settings.cfg")
	if err != OK:
		print("保存设置时出错!")

# 加载设置
func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# 读取音量设置
		music_slider.value = config.get_value("audio", "music_volume", 0.7)
		sfx_slider.value = config.get_value("audio", "sfx_volume", 0.8)
		
		# 应用音量
		var music_db = linear_to_db(music_slider.value)
		var sfx_db = linear_to_db(sfx_slider.value)
		
		if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), music_db)
		if AudioServer.get_bus_index(SFX_BUS) >= 0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), sfx_db)
		
		# 读取全屏设置
		fullscreen_toggle.button_pressed = config.get_value("video", "fullscreen", false)
		
		# 应用全屏
		if fullscreen_toggle.button_pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		print("没有找到设置文件，使用默认设置") 