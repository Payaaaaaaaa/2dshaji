extends Node
class_name MapGenerator

# 地图生成配置
@export var map_width: int = 100  # 地图宽度(格子数)
@export var map_height: int = 100  # 地图高度(格子数)
@export var min_room_size: int = 8  # 最小房间尺寸
@export var max_room_size: int = 15  # 最大房间尺寸
@export var room_count: int = 15  # 目标房间数量
@export var corridor_width: int = 2  # 走廊宽度

# 地图主题枚举
enum MapTheme {
	FOREST,    # 森林
	HOSPITAL,  # 医院
	FACTORY,   # 工厂
	SCHOOL,    # 学校
	CAMPSITE   # 营地
}

# 当前主题
var current_theme: int = MapTheme.FOREST

# 各主题的Tile配置
var theme_tiles = {
	MapTheme.FOREST: {
		"floor": Vector2i(0, 0),
		"wall": Vector2i(1, 0),
		"decoration": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	},
	MapTheme.HOSPITAL: {
		"floor": Vector2i(0, 1),
		"wall": Vector2i(1, 1),
		"decoration": [Vector2i(2, 1), Vector2i(3, 1)]
	},
	MapTheme.FACTORY: {
		"floor": Vector2i(0, 2),
		"wall": Vector2i(1, 2),
		"decoration": [Vector2i(2, 2), Vector2i(3, 2)]
	},
	MapTheme.SCHOOL: {
		"floor": Vector2i(0, 3),
		"wall": Vector2i(1, 3),
		"decoration": [Vector2i(2, 3), Vector2i(3, 3)]
	},
	MapTheme.CAMPSITE: {
		"floor": Vector2i(0, 4),
		"wall": Vector2i(1, 4),
		"decoration": [Vector2i(2, 4), Vector2i(3, 4)]
	}
}

# 物件生成配置
@export var generators_count: int = 7  # 发电机数量
@export var hooks_count: int = 7  # 钩子数量
@export var chests_count: int = 5  # 宝箱数量
@export var pallets_count: int = 12  # 木板数量
@export var gates_count: int = 2  # 出口门数量

# 引用场景
var generator_scene = preload("res://scenes/objects/Generator.tscn")
var hook_scene = preload("res://scenes/objects/Hook.tscn")
var chest_scene = preload("res://scenes/objects/Chest.tscn")
var pallet_scene = preload("res://scenes/objects/Pallet.tscn")
var exit_gate_scene = preload("res://scenes/objects/ExitGate.tscn")

# 地图数据
var map_seed: int = 0  # 随机种子
var rooms = []  # 房间列表
var corridors = []  # 走廊列表
var tilemap = null  # TileMap引用
var object_container = null  # 物件容器节点

# 特殊区域类型枚举
enum AreaType {
	NORMAL,        # 普通区域
	DENSE_PALLETS, # 密集板区
	OPEN_CHASE,    # 开阔追逐区
	SAFE_ZONE,     # 安全区(较多窗户/板)
	DANGEROUS_ZONE # 危险区(遮挡物少)
}

# 信号
signal map_generation_started
signal map_generation_completed
signal object_placement_completed

# 地图生成参数
var map_size: Vector2i = Vector2i(40, 40)  # 地图大小，以格子为单位
var min_room_size: int = 4  # 最小房间尺寸
var max_room_size: int = 8  # 最大房间尺寸
var corridor_width: int = 2  # 走廊宽度

# 物件生成参数
var generators_required: int = 5  # 修好几个才能开门
var hooks_min_count: int = 8  # 最少钩子数量
var hooks_max_count: int = 12  # 最多钩子数量
var hooks_min_distance: float = 20.0  # 钩子之间的最小距离

# 物件分布参数
var generator_min_distance: float = 25.0  # 发电机之间的最小距离
var exit_gate_distance: float = 60.0  # 出口门之间的距离

# 路径缓存
var path_cache = {}

# 构造函数，初始化随机数生成器
func _init():
	# 默认随机种子
	randomize()

# 设置地图种子
func set_seed(new_seed: int):
	map_seed = new_seed
	seed(map_seed)

# 设置地图主题
func set_theme(theme_id: int):
	if theme_id >= 0 and theme_id < MapTheme.size():
		current_theme = theme_id
	else:
		# 随机选择一个主题
		current_theme = randi() % MapTheme.size()

# 更新地图参数
func _ready():
	# 如果平衡管理器已初始化，应用平衡参数
	apply_balance_settings()

# 应用平衡管理器中的地图参数
func apply_balance_settings():
	if GameBalanceManager.instance:
		# 应用地图大小
		map_size = GameBalanceManager.instance.map_max_size
		min_room_size = GameBalanceManager.instance.min_room_size
		max_room_size = GameBalanceManager.instance.max_room_size
		corridor_width = GameBalanceManager.instance.corridor_width
		
		# 应用物件生成参数
		generators_count = GameBalanceManager.instance.generator_total
		generators_required = GameBalanceManager.instance.generators_required
		hooks_min_count = GameBalanceManager.instance.hooks_min_count
		hooks_max_count = GameBalanceManager.instance.hooks_max_count
		hooks_min_distance = GameBalanceManager.instance.hook_min_distance
		
		# 应用物件分布参数
		generator_min_distance = GameBalanceManager.instance.generator_min_distance
		exit_gate_distance = GameBalanceManager.instance.exit_gate_min_distance
		
		# 更新全局游戏参数
		Global.GENERATORS_REQUIRED = generators_required

# 生成地图
func generate_map(tilemap_node, object_container_node = null, custom_seed: int = -1, theme_id: int = -1):
	# 设置引用
	tilemap = tilemap_node
	object_container = object_container_node
	
	# 如果提供了自定义种子，使用它
	if custom_seed >= 0:
		set_seed(custom_seed)
	else:
		# 否则创建新的随机种子
		set_seed(randi())
	
	# 设置主题
	set_theme(theme_id)
	
	# 发出开始生成信号
	map_generation_started.emit()
	
	# 清空现有数据
	clear_map()
	
	# 生成基础房间
	generate_rooms()
	
	# 生成走廊连接房间
	connect_rooms()
	
	# 检查并修复连通性
	check_and_fix_connectivity()
	
	# 应用TileMap
	apply_to_tilemap()
	
	# 放置物件
	if object_container:
		place_objects()
	
	# 发出完成信号
	map_generation_completed.emit()
	
	# 返回种子，便于网络同步
	return map_seed

# 清空地图数据
func clear_map():
	rooms.clear()
	corridors.clear()
	path_cache.clear()
	
	# 清空TileMap
	if tilemap:
		tilemap.clear()
	
	# 清空物件容器
	if object_container:
		for child in object_container.get_children():
			child.queue_free()

# 使用BSP(二叉空间划分)算法生成房间
func generate_rooms():
	# 创建根区域
	var root_region = {
		"x": 0,
		"y": 0,
		"width": map_width,
		"height": map_height
	}
	
	# 递归划分区域
	var leaf_regions = []
	subdivide_region(root_region, leaf_regions)
	
	# 在每个叶子区域中创建房间
	for region in leaf_regions:
		create_room_in_region(region)

# 递归划分区域（改进版）
func subdivide_region(region, leaf_regions, depth = 0, variation = 0.3):
	# 限制递归深度，防止无限分裂
	if depth > 5:
		leaf_regions.append(region)
		return
	
	# 随机决定是否继续分割
	if depth > 2 and randf() < 0.3:
		leaf_regions.append(region)
		return
	
	# 是否水平分割（带一定随机性）
	var split_horizontal = (region.width < region.height * (1.0 - variation)) or (region.width < region.height * (1.0 + variation) and randf() < 0.5)
	
	# 如果区域太小，则不再分割
	if (split_horizontal and region.height < min_room_size * 2) or (!split_horizontal and region.width < min_room_size * 2):
		leaf_regions.append(region)
		return
	
	var region1 = {}
	var region2 = {}
	
	# 添加非对称分割以增加变化
	var split_ratio = 0.5 + (randf() - 0.5) * variation
	
	if split_horizontal:
		# 水平分割(上下)
		var split_point = region.y + min_room_size + int((region.height - min_room_size * 2) * split_ratio)
		
		region1 = {
			"x": region.x,
			"y": region.y,
			"width": region.width,
			"height": split_point - region.y
		}
		
		region2 = {
			"x": region.x,
			"y": split_point,
			"width": region.width,
			"height": region.height - (split_point - region.y)
		}
	else:
		# 垂直分割(左右)
		var split_point = region.x + min_room_size + int((region.width - min_room_size * 2) * split_ratio)
		
		region1 = {
			"x": region.x,
			"y": region.y,
			"width": split_point - region.x,
			"height": region.height
		}
		
		region2 = {
			"x": split_point,
			"y": region.y,
			"width": region.width - (split_point - region.x),
			"height": region.height
		}
	
	# 继续递归分割子区域
	subdivide_region(region1, leaf_regions, depth + 1, variation)
	subdivide_region(region2, leaf_regions, depth + 1, variation)

# 在区域内创建房间
func create_room_in_region(region):
	# 确定房间尺寸(稍小于区域，留出走廊空间)
	var room_width = min_room_size + randi() % min(max_room_size - min_room_size, region.width - min_room_size - 2)
	var room_height = min_room_size + randi() % min(max_room_size - min_room_size, region.height - min_room_size - 2)
	
	# 确定房间位置(在区域内随机)
	var room_x = region.x + 1 + randi() % (region.width - room_width - 2)
	var room_y = region.y + 1 + randi() % (region.height - room_height - 2)
	
	# 随机选择区域类型，但确保均衡分布
	var area_distribution = {
		AreaType.NORMAL: 0.5,        # 50%为普通房间
		AreaType.DENSE_PALLETS: 0.2, # 20%为密集板区
		AreaType.OPEN_CHASE: 0.2,    # 20%为开阔追逐区
		AreaType.SAFE_ZONE: 0.05,    # 5%为安全区
		AreaType.DANGEROUS_ZONE: 0.05 # 5%为危险区
	}
	
	var room_type = select_room_type(area_distribution)
	
	# 创建房间
	var room = {
		"x": room_x,
		"y": room_y,
		"width": room_width,
		"height": room_height,
		"center_x": room_x + room_width / 2,
		"center_y": room_y + room_height / 2,
		"type": room_type  # 添加房间类型
	}
	
	# 添加到房间列表
	rooms.append(room)

# 根据分布选择房间类型
func select_room_type(distribution):
	var roll = randf()
	var cumulative = 0.0
	
	for type in distribution:
		cumulative += distribution[type]
		if roll <= cumulative:
			return type
			
	# 默认为普通房间
	return AreaType.NORMAL

# 连接房间生成走廊
func connect_rooms():
	# 如果没有房间，无法连接
	if rooms.size() < 2:
		return
	
	# 对房间进行排序（可以按照位置排序，简化连接）
	rooms.sort_custom(func(a, b): return a.center_x < b.center_x)
	
	# 连接相邻房间
	for i in range(rooms.size() - 1):
		var room1 = rooms[i]
		var room2 = rooms[i + 1]
		create_corridor(room1, room2)
	
	# 添加一些额外连接，增加地图复杂度
	for _i in range(rooms.size() / 3):
		var room1 = rooms[randi() % rooms.size()]
		var room2 = rooms[randi() % rooms.size()]
		
		if room1 != room2:
			create_corridor(room1, room2)

# 创建走廊连接两个房间
func create_corridor(room1, room2):
	# 获取房间中心点
	var start_x = room1.center_x
	var start_y = room1.center_y
	var end_x = room2.center_x
	var end_y = room2.center_y
	
	# 创建L型走廊
	var corridor1 = {}
	var corridor2 = {}
	
	# 随机决定先水平后垂直，或先垂直后水平
	if randf() < 0.5:
		corridor1 = {
			"x": min(start_x, end_x),
			"y": start_y - corridor_width / 2,
			"width": abs(start_x - end_x),
			"height": corridor_width
		}
		
		corridor2 = {
			"x": end_x - corridor_width / 2,
			"y": min(start_y, end_y),
			"width": corridor_width,
			"height": abs(start_y - end_y)
		}
	else:
		corridor1 = {
			"x": start_x - corridor_width / 2,
			"y": min(start_y, end_y),
			"width": corridor_width,
			"height": abs(start_y - end_y)
		}
		
		corridor2 = {
			"x": min(start_x, end_x),
			"y": end_y - corridor_width / 2,
			"width": abs(start_x - end_x),
			"height": corridor_width
		}
	
	corridors.append(corridor1)
	corridors.append(corridor2)

# 应用到TileMap
func apply_to_tilemap():
	if !tilemap:
		return
	
	# 设置地面和墙壁 (根据当前主题选择)
	var floor_cell = theme_tiles[current_theme]["floor"]
	var wall_cell = theme_tiles[current_theme]["wall"]
	var decoration_cells = theme_tiles[current_theme]["decoration"]
	
	# 先将整个地图填充为墙壁
	for x in range(map_width):
		for y in range(map_height):
			tilemap.set_cell(0, Vector2i(x, y), 0, wall_cell)
	
	# 将房间区域设置为地面
	for room in rooms:
		for x in range(room.x, room.x + room.width):
			for y in range(room.y, room.y + room.height):
				tilemap.set_cell(0, Vector2i(x, y), 0, floor_cell)
				
				# 随机添加装饰元素
				if randf() < 0.05 and decoration_cells.size() > 0:  # 5%的概率添加装饰
					var decoration = decoration_cells[randi() % decoration_cells.size()]
					tilemap.set_cell(1, Vector2i(x, y), 0, decoration)
	
	# 将走廊区域设置为地面
	for corridor in corridors:
		for x in range(corridor.x, corridor.x + corridor.width):
			for y in range(corridor.y, corridor.y + corridor.height):
				tilemap.set_cell(0, Vector2i(x, y), 0, floor_cell)

# 根据房间类型放置物件
func place_objects_by_room_type():
	if !object_container:
		return
	
	for room in rooms:
		match room.get("type", AreaType.NORMAL):
			AreaType.DENSE_PALLETS:
				# 在板区放置更多的板子
				place_objects_in_room(pallet_scene, 4 + randi() % 3, room)
				# 减少其他物件
				place_objects_in_room(generator_scene, 0 + randi() % 2, room)
				
			AreaType.OPEN_CHASE:
				# 追逐区几乎没有板子
				place_objects_in_room(pallet_scene, 0 + randi() % 2, room)
				# 但可能有发电机
				place_objects_in_room(generator_scene, 1 + randi() % 2, room)
				
			AreaType.SAFE_ZONE:
				# 安全区有很多板子和宝箱
				place_objects_in_room(pallet_scene, 2 + randi() % 3, room)
				place_objects_in_room(chest_scene, 1 + randi() % 2, room)
				
			AreaType.DANGEROUS_ZONE:
				# 危险区放置更多钩子
				place_objects_in_room(hook_scene, 1 + randi() % 3, room)
				# 可能有发电机
				place_objects_in_room(generator_scene, 1, room)
				
			AreaType.NORMAL:
				# 普通区域，放置适量的所有物件
				if randf() < 0.5:
					place_objects_in_room(generator_scene, 1, room)
				if randf() < 0.3:
					place_objects_in_room(hook_scene, 1, room)
				if randf() < 0.4:
					place_objects_in_room(pallet_scene, 1 + randi() % 2, room)
				if randf() < 0.3:
					place_objects_in_room(chest_scene, 1, room)

# 在指定房间中放置物件
func place_objects_in_room(scene, count, room):
	var placed = 0
	for _i in range(count):
		if placed >= count:
			break
		
		# 在房间中找一个随机位置
		var pos_x = room.x + 1 + randi() % (room.width - 2)
		var pos_y = room.y + 1 + randi() % (room.height - 2)
		
		# 检查该位置是否已有物件
		var position_vector = Vector2i(pos_x, pos_y)
		if is_position_occupied(position_vector):
			continue
		
		# 创建物件
		var object = scene.instantiate()
		object_container.add_child(object)
		
		# 设置位置(转换为世界坐标)
		object.global_position = tilemap.map_to_local(position_vector)
		
		placed += 1

# 检查位置是否已被占用
func is_position_occupied(pos: Vector2i) -> bool:
	if object_container:
		for object in object_container.get_children():
			var object_tile_pos = tilemap.local_to_map(object.global_position)
			if object_tile_pos.distance_to(pos) < 3:  # 使用一定距离作为占用判定
				return true
	return false

# 重写放置物件方法，使用新的特殊区域逻辑
func place_objects():
	if !object_container:
		return
	
	# 首先根据房间类型放置物件
	place_objects_by_room_type()
	
	# 检查发电机和钩子的数量，确保满足最低要求
	var generators = 0
	var hooks = 0
	
	for object in object_container.get_children():
		if object.is_in_group("generators"):
			generators += 1
		elif object.is_in_group("hooks"):
			hooks += 1
	
	# 如果发电机数量不足，补充放置
	if generators < generators_count:
		place_objects_in_rooms(generator_scene, generators_count - generators)
	
	# 如果钩子数量不足，补充放置
	if hooks < hooks_min_count:
		place_objects_in_rooms(hook_scene, hooks_min_count - hooks)
	
	# 放置出口门(在地图边缘)
	place_exit_gates(exit_gate_scene, gates_count)
	
	# 发出物件放置完成信号
	object_placement_completed.emit()

# 在房间中放置物件
func place_objects_in_rooms(scene, count):
	var available_rooms = rooms.duplicate()
	available_rooms.shuffle()
	
	var placed = 0
	for room in available_rooms:
		if placed >= count or placed >= available_rooms.size():
			break
		
		# 在房间中找一个随机位置
		var pos_x = room.x + randi() % (room.width - 2) + 1
		var pos_y = room.y + randi() % (room.height - 2) + 1
		
		# 创建物件
		var object = scene.instantiate()
		object_container.add_child(object)
		
		# 设置位置(转换为世界坐标)
		object.global_position = tilemap.map_to_local(Vector2i(pos_x, pos_y))
		
		placed += 1

# 在走廊中放置物件
func place_objects_in_corridors(scene, count):
	var available_corridors = corridors.duplicate()
	available_corridors.shuffle()
	
	var placed = 0
	for corridor in available_corridors:
		if placed >= count or placed >= available_corridors.size():
			break
		
		# 检查走廊是否足够大
		if corridor.width <= 2 and corridor.height <= 2:
			continue
		
		# 在走廊中找一个随机位置
		var pos_x = corridor.x + max(1, randi() % (corridor.width - 1))
		var pos_y = corridor.y + max(1, randi() % (corridor.height - 1))
		
		# 创建物件
		var object = scene.instantiate()
		object_container.add_child(object)
		
		# 设置位置(转换为世界坐标)
		object.global_position = tilemap.map_to_local(Vector2i(pos_x, pos_y))
		
		placed += 1

# 放置出口门
func place_exit_gates(scene, count):
	# 找到地图边缘的可用位置
	var edge_positions = []
	
	# 扫描地图边缘
	for x in range(map_width):
		check_edge_position(x, 0, edge_positions)  # 上边缘
		check_edge_position(x, map_height - 1, edge_positions)  # 下边缘
	
	for y in range(map_height):
		check_edge_position(0, y, edge_positions)  # 左边缘
		check_edge_position(map_width - 1, y, edge_positions)  # 右边缘
	
	# 随机打乱边缘位置
	edge_positions.shuffle()
	
	# 放置出口门
	for i in range(min(count, edge_positions.size())):
		var pos = edge_positions[i]
		
		# 创建出口门
		var gate = scene.instantiate()
		object_container.add_child(gate)
		
		# 设置位置
		gate.global_position = tilemap.map_to_local(Vector2i(pos.x, pos.y))
		
		# 设置朝向(朝向地图内部)
		if pos.x == 0:  # 左边缘
			gate.rotation_degrees = 90
		elif pos.x == map_width - 1:  # 右边缘
			gate.rotation_degrees = -90
		elif pos.y == 0:  # 上边缘
			gate.rotation_degrees = 180
		# 下边缘默认朝上(0度)

# 检查边缘位置是否适合放置出口门
func check_edge_position(x, y, edge_positions):
	# 检查当前位置是否为地面
	if tilemap.get_cell_source_id(0, Vector2i(x, y)) == 0:
		# 检查旁边的位置是否也是地面，确保有足够空间
		var has_floor_neighbor = false
		
		# 检查相邻的四个方向
		var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for dir in directions:
			var nx = x + dir.x
			var ny = y + dir.y
			
			if nx >= 0 and nx < map_width and ny >= 0 and ny < map_height:
				if tilemap.get_cell_source_id(0, Vector2i(nx, ny)) == 0:
					has_floor_neighbor = true
					break
		
		if has_floor_neighbor:
			edge_positions.append({"x": x, "y": y})

# 获取地图数据，便于网络同步
func get_map_data() -> Dictionary:
	return {
		"seed": map_seed,
		"width": map_width,
		"height": map_height,
		"room_count": rooms.size(),
		"corridor_count": corridors.size(),
		"theme": current_theme
	}

# 从网络同步的数据重建地图
func rebuild_from_data(data: Dictionary, tilemap_node, object_container_node = null):
	if data.has("seed"):
		var theme_id = data.get("theme", -1)
		generate_map(tilemap_node, object_container_node, data.seed, theme_id)
		return true
	return false

# 生成发电机
func generate_generators():
	# ... existing code ...
	pass

# 检查并修复地图连通性
func check_and_fix_connectivity():
	var start_point = find_floor_tile()
	if start_point == Vector2i(-1, -1):
		return false  # 没有找到地板块
	
	var visited = {}
	var floor_count = count_floor_tiles()
	
	flood_fill(start_point, visited)
	
	# 如果访问的地板数少于总地板数，说明地图不连通
	if visited.size() < floor_count:
		fix_connectivity(visited)
		return false
	return true

# 找到第一个地板块作为洪水填充起点
func find_floor_tile() -> Vector2i:
	for room in rooms:
		return Vector2i(room.x + room.width / 2, room.y + room.height / 2)
	
	# 如果没有房间，扫描整个地图
	for x in range(map_width):
		for y in range(map_height):
			if is_floor_tile(Vector2i(x, y)):
				return Vector2i(x, y)
	
	return Vector2i(-1, -1)

# 统计地图中地板块数量
func count_floor_tiles() -> int:
	var count = 0
	for x in range(map_width):
		for y in range(map_height):
			if is_floor_tile(Vector2i(x, y)):
				count += 1
	return count

# 检查指定位置是否为地板
func is_floor_tile(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return false
	
	if !tilemap:
		# 如果TileMap尚未设置，检查该位置是否在房间或走廊内
		for room in rooms:
			if pos.x >= room.x and pos.x < room.x + room.width and pos.y >= room.y and pos.y < room.y + room.height:
				return true
		
		for corridor in corridors:
			if pos.x >= corridor.x and pos.x < corridor.x + corridor.width and pos.y >= corridor.y and pos.y < corridor.y + corridor.height:
				return true
		
		return false
	else:
		# 使用TileMap检查
		var atlas_coords = tilemap.get_cell_atlas_coords(0, pos)
		var floor_cell = theme_tiles[current_theme]["floor"]
		return atlas_coords == floor_cell

# 洪水填充算法检查连通区域
func flood_fill(point: Vector2i, visited: Dictionary):
	# 创建唯一键表示位置
	var key = str(point.x) + "," + str(point.y)
	
	if key in visited or !is_floor_tile(point):
		return
	
	visited[key] = point
	
	# 检查四个方向
	flood_fill(Vector2i(point.x + 1, point.y), visited)
	flood_fill(Vector2i(point.x - 1, point.y), visited)
	flood_fill(Vector2i(point.x, point.y + 1), visited)
	flood_fill(Vector2i(point.x, point.y - 1), visited)

# 修复不连通区域
func fix_connectivity(visited: Dictionary):
	print("修复地图连通性...")
	
	# 找出所有独立的区域
	var disconnected_regions = find_disconnected_regions(visited)
	
	# 将主区域(最大连通区域)作为参考
	var main_region = visited
	
	# 连接每个独立区域到主区域
	for region in disconnected_regions:
		connect_region_to_main(region, main_region)

# 找出所有不连通的区域
func find_disconnected_regions(main_region: Dictionary) -> Array:
	var regions = []
	var checked = main_region.duplicate()
	
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			var key = str(pos.x) + "," + str(pos.y)
			
			if key in checked or !is_floor_tile(pos):
				continue
			
			# 发现一个新的未连通区域
			var new_region = {}
			flood_fill(pos, new_region)
			
			# 添加到区域列表并标记为已检查
			regions.append(new_region)
			for k in new_region:
				checked[k] = new_region[k]
	
	return regions

# 将独立区域连接到主区域
func connect_region_to_main(region: Dictionary, main_region: Dictionary):
	var closest_point_in_region = null
	var closest_point_in_main = null
	var min_distance = INF
	
	# 寻找两个区域中最近的点对
	for region_key in region:
		var region_point = region[region_key]
		
		for main_key in main_region:
			var main_point = main_region[main_key]
			var distance = region_point.distance_to(main_point)
			
			if distance < min_distance:
				min_distance = distance
				closest_point_in_region = region_point
				closest_point_in_main = main_point
	
	if closest_point_in_region and closest_point_in_main:
		# 创建连接走廊
		create_direct_corridor(closest_point_in_region, closest_point_in_main)

# 创建直接连接两点的走廊
func create_direct_corridor(from_point: Vector2i, to_point: Vector2i):
	var corridor = {
		"x": min(from_point.x, to_point.x) - corridor_width / 2,
		"y": min(from_point.y, to_point.y) - corridor_width / 2,
		"width": abs(from_point.x - to_point.x) + corridor_width,
		"height": abs(from_point.y - to_point.y) + corridor_width
	}
	
	corridors.append(corridor)
	
	# 在TileMap上设置走廊
	if tilemap:
		var floor_cell = theme_tiles[current_theme]["floor"]
		for x in range(corridor.x, corridor.x + corridor.width):
			for y in range(corridor.y, corridor.y + corridor.height):
				if x >= 0 and x < map_width and y >= 0 and y < map_height:
					tilemap.set_cell(0, Vector2i(x, y), 0, floor_cell)

# 添加调试绘制函数
func draw_debug_map(canvas):
	if !canvas:
		return
	
	# 绘制所有房间
	for room in rooms:
		var rect = Rect2(room.x * 16, room.y * 16, room.width * 16, room.height * 16)
		var color = Color(0.5, 0.5, 1.0, 0.3)
		
		# 根据房间类型使用不同颜色
		match room.get("type", AreaType.NORMAL):
			AreaType.DENSE_PALLETS:
				color = Color(1.0, 0.5, 0.5, 0.3)  # 红色
			AreaType.OPEN_CHASE:
				color = Color(1.0, 1.0, 0.5, 0.3)  # 黄色
			AreaType.SAFE_ZONE:
				color = Color(0.5, 1.0, 0.5, 0.3)  # 绿色
			AreaType.DANGEROUS_ZONE:
				color = Color(1.0, 0.5, 1.0, 0.3)  # 紫色
		
		canvas.draw_rect(rect, color)
		
	# 绘制所有走廊
	for corridor in corridors:
		var rect = Rect2(corridor.x * 16, corridor.y * 16, corridor.width * 16, corridor.height * 16)
		canvas.draw_rect(rect, Color(0.7, 0.7, 0.7, 0.3))
	
	# 绘制物件位置
	if object_container:
		for object in object_container.get_children():
			var pos = object.global_position / 16
			var color = Color(1.0, 0.5, 0.5, 0.7)
			
			# 根据物件类型使用不同颜色
			if object.is_in_group("generators"):
				color = Color(1.0, 1.0, 0.0, 0.7)  # 黄色
			elif object.is_in_group("hooks"):
				color = Color(1.0, 0.0, 0.0, 0.7)  # 红色
			elif object.is_in_group("pallets"):
				color = Color(0.0, 1.0, 0.0, 0.7)  # 绿色
			elif object.is_in_group("gates"):
				color = Color(0.0, 0.0, 1.0, 0.7)  # 蓝色
				
			canvas.draw_circle(Vector2(pos.x, pos.y), 5, color)

# 分步骤生成地图，避免卡顿
func generate_map_step_by_step(tilemap_node, object_container_node = null, custom_seed: int = -1, theme_id: int = -1):
	# 设置引用
	tilemap = tilemap_node
	object_container = object_container_node
	
	# 如果提供了自定义种子，使用它
	if custom_seed >= 0:
		set_seed(custom_seed)
	else:
		# 否则创建新的随机种子
		set_seed(randi())
	
	# 设置主题
	set_theme(theme_id)
	
	# 发出开始生成信号
	map_generation_started.emit()
	
	# 清空现有数据
	clear_map()
	
	# 步骤1: 生成房间
	call_deferred("_step_generate_rooms")
	return map_seed

# 步骤1: 生成房间
func _step_generate_rooms():
	generate_rooms()
	await get_tree().process_frame
	call_deferred("_step_connect_rooms")

# 步骤2: 连接房间
func _step_connect_rooms():
	connect_rooms()
	await get_tree().process_frame
	call_deferred("_step_check_connectivity")

# 步骤3: 检查连通性
func _step_check_connectivity():
	check_and_fix_connectivity()
	await get_tree().process_frame
	call_deferred("_step_apply_tilemap")

# 步骤4: 应用TileMap
func _step_apply_tilemap():
	apply_to_tilemap()
	await get_tree().process_frame
	call_deferred("_step_place_objects")

# 步骤5: 放置物件
func _step_place_objects():
	if object_container:
		place_objects()
	
	# 完成
	map_generation_completed.emit() 