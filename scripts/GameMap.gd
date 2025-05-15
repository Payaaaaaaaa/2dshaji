extends Node2D
class_name GameMap

# 节点引用
@onready var tilemap = $TileMap
@onready var objects_container = $Objects
@onready var spawn_points = $SpawnPoints
@onready var camera = $Camera2D

# 地图生成器
var map_generator = null

# 网络相关
var is_server: bool = false
var map_data: Dictionary = {}

# 生成配置
@export var generate_on_ready: bool = true
@export var map_seed: int = -1  # -1表示随机种子
@export var map_theme: int = -1  # -1表示随机主题
@export var use_step_by_step_generation: bool = true  # 是否使用分步生成以减少卡顿
@export var enable_debug_draw: bool = false  # 是否启用调试绘制

# 调试绘制
var debug_canvas = null
var debug_active = false

# 信号
signal map_ready(map_data: Dictionary)
signal map_seed_received(seed_value: int)

func _ready():
	# 创建地图生成器
	map_generator = MapGenerator.new()
	add_child(map_generator)
	
	# 连接信号
	map_generator.map_generation_completed.connect(_on_map_generation_completed)
	
	# 准备调试绘制
	if enable_debug_draw:
		setup_debug_drawing()
	
	# 如果是服务器且配置为自动生成地图，则生成
	if is_multiplayer_authority() and generate_on_ready:
		generate_map()

# 生成地图
func generate_map(custom_seed: int = -1, theme_id: int = -1):
	if custom_seed >= 0:
		map_seed = custom_seed
	if theme_id >= 0:
		map_theme = theme_id
	
	# 使用地图生成器生成地图
	var used_seed
	
	if use_step_by_step_generation:
		# 分步生成，避免卡顿
		used_seed = map_generator.generate_map_step_by_step(tilemap, objects_container, map_seed, map_theme)
	else:
		# 一次性生成
		used_seed = map_generator.generate_map(tilemap, objects_container, map_seed, map_theme)
	
	# 记录地图数据
	map_data = map_generator.get_map_data()
	
	# 如果是服务器，则同步地图数据到客户端
	if is_multiplayer_authority():
		rpc("receive_map_data", map_data)
		update_spawn_points()
	
	# 调整摄像机位置到地图中心
	center_camera()
	
	# 发出地图就绪信号
	map_ready.emit(map_data)
	
	return used_seed

# 设置调试绘制
func setup_debug_drawing():
	# 创建CanvasLayer用于调试绘制
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10  # 设置为较高层级以显示在地图上方
	add_child(canvas_layer)
	
	# 创建Control用于绘制
	debug_canvas = Control.new()
	debug_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不要阻挡鼠标事件
	canvas_layer.add_child(debug_canvas)
	
	# 连接绘制信号
	debug_canvas.draw.connect(_on_debug_canvas_draw)
	
	# 默认禁用
	debug_canvas.visible = false
	debug_active = false

# 打开/关闭调试绘制
func toggle_debug_drawing(enabled: bool = true):
	if debug_canvas:
		debug_canvas.visible = enabled
		debug_active = enabled
		if enabled:
			debug_canvas.queue_redraw()

# 调试绘制回调
func _on_debug_canvas_draw():
	if !debug_active or !map_generator:
		return
	
	# 使用地图生成器绘制调试信息
	map_generator.draw_debug_map(debug_canvas)

# 更新出生点位置(基于地图)
func update_spawn_points():
	if !map_generator or !spawn_points:
		return
		
	# 获取房间列表
	var rooms = map_generator.rooms
	if rooms.is_empty() or rooms.size() < 5: # 需要至少5个房间(1个杀手，4个幸存者)
		return
	
	# 随机打乱房间顺序
	var shuffled_rooms = rooms.duplicate()
	shuffled_rooms.shuffle()
	
	# 设置杀手出生点
	var killer_room = shuffled_rooms[0]
	var killer_spawn = spawn_points.get_node("KillerSpawn")
	if killer_spawn:
		killer_spawn.global_position = tilemap.map_to_local(
			Vector2i(killer_room.center_x, killer_room.center_y)
		)
	
	# 设置幸存者出生点
	for i in range(1, 5):
		if i >= shuffled_rooms.size():
			break
			
		var survivor_room = shuffled_rooms[i]
		var spawn_node = spawn_points.get_node_or_null("SurvivorSpawn" + str(i))
		if spawn_node:
			spawn_node.global_position = tilemap.map_to_local(
				Vector2i(survivor_room.center_x, survivor_room.center_y)
			)

# 将摄像机居中到地图
func center_camera():
	if !camera or !tilemap:
		return
		
	var map_size = Vector2(map_generator.map_width, map_generator.map_height)
	var map_center = Vector2(map_size.x / 2, map_size.y / 2)
	
	# 转换为世界坐标
	camera.global_position = tilemap.map_to_local(Vector2i(map_center.x, map_center.y))

# 从网络接收地图数据
@rpc("authority", "reliable")
func receive_map_data(data: Dictionary):
	map_data = data
	map_seed_received.emit(data.seed)
	
	# 重建地图
	if !is_multiplayer_authority():
		map_generator.rebuild_from_data(data, tilemap, objects_container)
		center_camera()

# 获取指定类型的物件列表
func get_objects_of_type(type: String) -> Array:
	var result = []
	
	if !objects_container:
		return result
		
	for obj in objects_container.get_children():
		if obj.is_in_group(type):
			result.append(obj)
	
	return result

# 获取杀手出生点
func get_killer_spawn_position() -> Vector2:
	var spawn = spawn_points.get_node_or_null("KillerSpawn")
	if spawn:
		return spawn.global_position
	return Vector2.ZERO

# 获取幸存者出生点
func get_survivor_spawn_position(index: int) -> Vector2:
	var spawn = spawn_points.get_node_or_null("SurvivorSpawn" + str(index))
	if spawn:
		return spawn.global_position
	return Vector2.ZERO

# 获取随机幸存者出生点
func get_random_survivor_spawn() -> Vector2:
	var index = randi() % 4 + 1
	return get_survivor_spawn_position(index)

# 当地图生成完成时
func _on_map_generation_completed():
	# 更新出生点
	update_spawn_points()
	
	# 如果启用了调试绘制，则刷新
	if debug_active and debug_canvas:
		debug_canvas.queue_redraw() 