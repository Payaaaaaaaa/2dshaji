extends Control
class_name MainMenuUI

# 节点引用
@onready var title_label = $TitlePanel/TitleLabel
@onready var version_label = $VersionLabel

# 主菜单按钮
@onready var host_button = $ButtonsPanel/HostButton
@onready var join_button = $ButtonsPanel/JoinButton
@onready var settings_button = $ButtonsPanel/SettingsButton
@onready var exit_button = $ButtonsPanel/ExitButton

# 加入游戏面板
@onready var join_panel = $JoinPanel
@onready var ip_input = $JoinPanel/IPInput
@onready var port_input = $JoinPanel/PortInput
@onready var connect_button = $JoinPanel/ConnectButton
@onready var back_button = $JoinPanel/BackButton

# 设置面板
@onready var settings_panel = $SettingsPanel
@onready var music_slider = $SettingsPanel/MusicSlider
@onready var sfx_slider = $SettingsPanel/SFXSlider
@onready var fullscreen_check = $SettingsPanel/FullscreenCheck
@onready var settings_back_button = $SettingsPanel/BackButton

# 动画控制
@onready var animation_player = $AnimationPlayer

# 信号
signal host_game_requested(port: int)
signal join_game_requested(ip: String, port: int)
signal settings_changed(settings: Dictionary)

# 默认端口
@export var default_port: int = 7777
@export var game_version: String = "v0.1"

func _ready():
	# 设置默认值
	if port_input:
		port_input.text = str(default_port)
		
	if version_label:
		version_label.text = "版本: " + game_version
	
	# 隐藏子面板
	if join_panel:
		join_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	
	# 连接按钮信号
	if host_button:
		host_button.pressed.connect(_on_host_button_pressed)
	if join_button:
		join_button.pressed.connect(_on_join_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	
	if connect_button:
		connect_button.pressed.connect(_on_connect_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	if settings_back_button:
		settings_back_button.pressed.connect(_on_settings_back_button_pressed)
	
	# 开场动画
	if animation_player and animation_player.has_animation("intro"):
		animation_player.play("intro")

# 显示主菜单
func show_main_menu():
	if join_panel:
		join_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	
	# 显示主按钮面板
	var buttons_panel = $ButtonsPanel
	if buttons_panel:
		buttons_panel.visible = true
	
	# 播放显示动画
	if animation_player and animation_player.has_animation("show_menu"):
		animation_player.play("show_menu")

# 显示加入游戏面板
func show_join_panel():
	var buttons_panel = $ButtonsPanel
	if buttons_panel:
		buttons_panel.visible = false
	
	if join_panel:
		join_panel.visible = true
		
		# 聚焦IP输入框
		if ip_input:
			ip_input.grab_focus()
		
		# 播放显示动画
		if animation_player and animation_player.has_animation("show_join"):
			animation_player.play("show_join")

# 显示设置面板
func show_settings_panel():
	var buttons_panel = $ButtonsPanel
	if buttons_panel:
		buttons_panel.visible = false
	
	if settings_panel:
		settings_panel.visible = true
		
		# 播放显示动画
		if animation_player and animation_player.has_animation("show_settings"):
			animation_player.play("show_settings")

# 应用设置
func apply_settings():
	var settings = {}
	
	# 收集设置值
	if music_slider:
		settings["music_volume"] = music_slider.value
	
	if sfx_slider:
		settings["sfx_volume"] = sfx_slider.value
	
	if fullscreen_check:
		settings["fullscreen"] = fullscreen_check.button_pressed
	
	# 发送信号
	settings_changed.emit(settings)
	
	# 应用全屏设置
	if fullscreen_check:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_check.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED)

# 按钮回调函数
func _on_host_button_pressed():
	var port = default_port
	host_game_requested.emit(port)

func _on_join_button_pressed():
	show_join_panel()

func _on_settings_button_pressed():
	show_settings_panel()

func _on_exit_button_pressed():
	# 播放退出动画
	if animation_player and animation_player.has_animation("exit"):
		animation_player.play("exit")
		await animation_player.animation_finished
	
	# 退出游戏
	get_tree().quit()

func _on_connect_button_pressed():
	if !ip_input or ip_input.text.is_empty():
		return
	
	var ip = ip_input.text
	var port = default_port
	
	if port_input and !port_input.text.is_empty():
		port = int(port_input.text)
	
	join_game_requested.emit(ip, port)

func _on_back_button_pressed():
	show_main_menu()

func _on_settings_back_button_pressed():
	# 应用设置
	apply_settings()
	
	# 返回主菜单
	show_main_menu()

# 设置默认值
func set_default_settings(music_vol: float, sfx_vol: float, is_fullscreen: bool):
	if music_slider:
		music_slider.value = music_vol
	
	if sfx_slider:
		sfx_slider.value = sfx_vol
	
	if fullscreen_check:
		fullscreen_check.button_pressed = is_fullscreen 