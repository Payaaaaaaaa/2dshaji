extends Node

# 调试控制器
# 用于控制地图生成和调试功能

var debug_ui: Control
var map_generator: MapGenerator
var game_map: GameMap

# 地图主题选择
var theme_options = [
	"随机", "森林", "医院", "工厂", "学校", "营地"
]

# 特殊区域类型
var area_types = [
	"普通", "板区", "追逐区", "安全区", "危险区"
]

func _ready():
	# 创建调试界面
	setup_debug_ui()
	
	# 查找地图生成器和游戏地图
	await get_tree().process_frame
	find_map_references()
	
	# 注册快捷键
	set_process_input(true)

func _input(event):
	# 按F3隐藏/显示调试UI
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			toggle_debug_ui()
		elif event.keycode == KEY_F4:
			# 按F4切换地图调试绘制
			toggle_debug_drawing()

# 设置调试界面
func setup_debug_ui():
	debug_ui = Control.new()
	debug_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.size = Vector2(300, 500)
	panel.position = Vector2(-320, 20)
	panel.modulate.a = 0.9
	debug_ui.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(280, 480)
	panel.add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.text = "地图生成调试"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 地图主题选择
	add_section_title(vbox, "地图主题")
	var theme_option = OptionButton.new()
	for i in range(theme_options.size()):
		theme_option.add_item(theme_options[i], i-1)  # -1表示随机
	theme_option.select(0)
	theme_option.item_selected.connect(_on_theme_selected)
	vbox.add_child(theme_option)
	
	# 调试绘制选项
	add_section_title(vbox, "调试绘制")
	var draw_toggle = CheckButton.new()
	draw_toggle.text = "显示调试绘制"
	draw_toggle.toggled.connect(_on_debug_draw_toggled)
	vbox.add_child(draw_toggle)
	
	# 再生成按钮
	add_section_title(vbox, "重新生成")
	var regen_button = Button.new()
	regen_button.text = "重新生成地图"
	regen_button.pressed.connect(_on_regenerate_pressed)
	vbox.add_child(regen_button)
	
	# 连通性检查按钮
	var check_conn_button = Button.new()
	check_conn_button.text = "检查地图连通性"
	check_conn_button.pressed.connect(_on_check_connectivity_pressed)
	vbox.add_child(check_conn_button)
	
	# 特殊区域生成
	add_section_title(vbox, "特殊区域")
	var area_option = OptionButton.new()
	for i in range(area_types.size()):
		area_option.add_item(area_types[i], i)
	area_option.select(0)
	vbox.add_child(area_option)
	
	var create_area_button = Button.new()
	create_area_button.text = "将选中房间设为特殊区域"
	create_area_button.pressed.connect(func(): _on_create_special_area_pressed(area_option.selected))
	vbox.add_child(create_area_button)
	
	# 初始隐藏
	debug_ui.visible = false
	add_child(debug_ui)

# 添加分区标题
func add_section_title(parent, title_text):
	var title = Label.new()
	title.text = title_text
	parent.add_child(title)
	
	var separator = HSeparator.new()
	parent.add_child(separator)

# 查找地图引用
func find_map_references():
	# 查找游戏地图
	var game_node = get_node_or_null("/root/Game")
	if game_node:
		game_map = game_node.get_node_or_null("GameMap")
		if game_map and game_map.map_generator:
			map_generator = game_map.map_generator

# 切换调试UI显示
func toggle_debug_ui():
	if debug_ui:
		debug_ui.visible = !debug_ui.visible

# 切换调试绘制
func toggle_debug_drawing():
	if game_map:
		game_map.toggle_debug_drawing(!game_map.debug_active)

# 地图主题选择回调
func _on_theme_selected(index):
	if map_generator:
		var theme_id = index - 1  # -1表示随机
		map_generator.current_theme = theme_id if theme_id >= 0 else randi() % map_generator.MapTheme.size()

# 调试绘制切换回调
func _on_debug_draw_toggled(enabled):
	if game_map:
		game_map.toggle_debug_drawing(enabled)

# 重新生成地图
func _on_regenerate_pressed():
	if game_map:
		var current_theme = map_generator.current_theme if map_generator else -1
		game_map.generate_map(-1, current_theme)

# 检查连通性
func _on_check_connectivity_pressed():
	if map_generator:
		var connected = map_generator.check_and_fix_connectivity()
		
		# 显示结果
		var result_dialog = AcceptDialog.new()
		result_dialog.title = "连通性检查结果"
		result_dialog.dialog_text = "地图连通性: " + ("已连通" if connected else "已修复断开的区域")
		add_child(result_dialog)
		result_dialog.popup_centered()
		
		# 对话框关闭时自动清理
		result_dialog.confirmed.connect(func(): result_dialog.queue_free())

# 创建特殊区域
func _on_create_special_area_pressed(area_type):
	if map_generator and map_generator.select_mode_enabled:
		var selected_room = map_generator.get_selected_room()
		if selected_room:
			selected_room.type = area_type
			
			# 通知生成器更新
			map_generator.update_room_type(selected_room, area_type)
			
			# 重新放置物件
			map_generator.place_objects_by_room_type() 