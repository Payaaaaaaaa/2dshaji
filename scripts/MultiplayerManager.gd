extends Node

class_name MultiplayerManager

# 预加载角色场景
@onready var survivor_scene = preload("res://scenes/characters/Survivor.tscn")
@onready var killer_scene = preload("res://scenes/characters/Killer.tscn")

# 场景中节点引用
@onready var spawner: MultiplayerSpawner = null
@onready var players_node: Node = null
@onready var objects_node: Node = null

# 同步处理器
var synchronizers = {}

func _ready():
	# 查找场景中必要的节点
	spawner = find_spawner()
	players_node = get_node_or_null("../Players")
	objects_node = get_node_or_null("../Objects")
	
	# 设置Spawner
	if spawner:
		# 配置要同步的场景
		spawner.add_spawnable_scene(survivor_scene.resource_path)
		spawner.add_spawnable_scene(killer_scene.resource_path)
		
		# 配置可能的交互物件场景
		var object_paths = [
			"res://scenes/objects/Generator.tscn",
			"res://scenes/objects/Hook.tscn",
			"res://scenes/objects/Pallet.tscn",
			"res://scenes/objects/ExitGate.tscn"
		]
		
		for path in object_paths:
			spawner.add_spawnable_scene(path)
		
		# 连接信号
		spawner.spawn_function = spawn_character
	else:
		push_error("无法找到MultiplayerSpawner节点!")

# 查找场景中的MultiplayerSpawner节点
func find_spawner() -> MultiplayerSpawner:
	# 首先在当前节点的子节点中查找
	for child in get_children():
		if child is MultiplayerSpawner:
			return child
			
	# 然后在父节点中查找
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is MultiplayerSpawner:
				return child
				
	# 最后在整个场景中查找
	return get_node_or_null("/root/Game/MultiplayerSpawner")

# 生成角色
func spawn_character(data: Array):
	# 处理生成角色的逻辑
	# data 包含: [character_type, player_id, spawn_position]
	if data.size() < 3:
		push_error("生成角色数据不完整!")
		return null
		
	var character_type = data[0]
	var player_id = data[1]
	var spawn_pos = data[2]
	
	# 根据类型选择场景
	var character_scene
	match character_type:
		"survivor":
			character_scene = survivor_scene
		"killer":
			character_scene = killer_scene
		_:
			push_error("未知角色类型: " + character_type)
			return null
	
	# 实例化角色
	var character = character_scene.instantiate()
	character.name = str(player_id)  # 用玩家ID命名
	character.set_multiplayer_authority(player_id)
	
	# 设置初始属性
	character.global_position = spawn_pos
	
	# 添加到玩家节点
	if players_node:
		players_node.add_child(character, true)
		return character
	
	# 如果players_node不存在，添加到当前节点
	add_child(character, true)
	return character

# 请求服务器生成角色
func request_spawn_character(character_type: String, spawn_position: Vector2):
	var my_id = multiplayer.get_unique_id()
	
	if Global.network_manager.is_server:
		# 服务器直接生成
		spawn_character_at(character_type, my_id, spawn_position)
	else:
		# 客户端请求生成
		rpc_id(1, "spawn_character_at", character_type, my_id, spawn_position)

# 服务器处理生成角色
@rpc("any_peer", "call_local", "reliable")
func spawn_character_at(character_type: String, player_id: int, spawn_position: Vector2):
	# 验证请求是否合法
	if !multiplayer.is_server():
		return
		
	# 简单验证：确保玩家ID匹配
	if player_id != multiplayer.get_remote_sender_id() and multiplayer.get_remote_sender_id() != 1:
		push_error("非法的生成请求: 玩家ID不匹配")
		return
	
	# 通知所有客户端生成角色
	rpc("do_spawn_character", character_type, player_id, spawn_position)

# 在所有客户端执行生成
@rpc("authority", "call_remote", "reliable")
func do_spawn_character(character_type: String, player_id: int, spawn_position: Vector2):
	# 如果这个角色已经存在，先销毁它
	var existing_character = get_node_or_null("../Players/" + str(player_id))
	if existing_character:
		existing_character.queue_free()
	
	# 调用spawner生成角色
	if spawner:
		spawner.spawn([character_type, player_id, spawn_position])
	else:
		# 手动生成
		spawn_character([character_type, player_id, spawn_position])

# 生成游戏物件
func spawn_object(object_type: String, world_position: Vector2, properties: Dictionary = {}) -> Node:
	if !Global.network_manager.is_server:
		# 只有服务器可以生成物件
		rpc_id(1, "request_spawn_object", object_type, world_position, properties)
		return null
	
	# 创建物件（服务器端）
	var path = "res://scenes/objects/" + object_type + ".tscn"
	var object_scene = load(path)
	if not object_scene:
		push_error("无法加载物件场景: " + path)
		return null
	
	var object = object_scene.instantiate()
	object.global_position = world_position
	
	# 设置属性
	for key in properties:
		if object.has_method("set_" + key):
			object.call("set_" + key, properties[key])
		elif key in object:
			object[key] = properties[key]
	
	# 添加到物件节点
	if objects_node:
		objects_node.add_child(object, true)
	else:
		add_child(object, true)
	
	# 通知所有客户端
	rpc("sync_spawn_object", object_type, object.get_path(), world_position, properties)
	
	return object

# 客户端请求生成物件
@rpc("any_peer", "call_local", "reliable")
func request_spawn_object(object_type: String, world_position: Vector2, properties: Dictionary = {}):
	if !multiplayer.is_server():
		return
		
	# 服务器处理生成请求
	spawn_object(object_type, world_position, properties)

# 同步生成物件到客户端
@rpc("authority", "call_remote", "reliable")
func sync_spawn_object(object_type: String, object_path: NodePath, world_position: Vector2, properties: Dictionary = {}):
	# 检查对象是否已存在
	var existing_object = get_node_or_null(object_path)
	if existing_object:
		# 如果已存在，更新属性
		existing_object.global_position = world_position
		
		for key in properties:
			if existing_object.has_method("set_" + key):
				existing_object.call("set_" + key, properties[key])
			elif key in existing_object:
				existing_object[key] = properties[key]
				
		return
	
	# 创建新物件
	var path = "res://scenes/objects/" + object_type + ".tscn"
	var object_scene = load(path)
	if not object_scene:
		push_error("无法加载物件场景: " + path)
		return
	
	var object = object_scene.instantiate()
	object.global_position = world_position
	
	# 设置属性
	for key in properties:
		if object.has_method("set_" + key):
			object.call("set_" + key, properties[key])
		elif key in object:
			object[key] = properties[key]
	
	# 添加到物件节点
	if objects_node:
		objects_node.add_child(object, true)
	else:
		add_child(object, true)
	
	# 确保路径匹配
	if object.get_path() != object_path:
		object.name = object_path.get_name(object_path.get_name_count() - 1)

# 获取玩家出生点
func get_spawn_position(role: String, player_id: int = 0) -> Vector2:
	# 检查是否有GameMap节点
	var game_map = get_node_or_null("/root/Game/GameMap")
	
	if game_map and game_map.has_method("get_killer_spawn_position"):
		# 使用程序化地图的出生点
		if role == "killer":
			return game_map.get_killer_spawn_position()
		else:
			# 为幸存者分配出生点（基于玩家ID）
			var survivor_index = 1
			
			# 计算幸存者索引（基于玩家ID的哈希值）
			if player_id > 0:
				var player_data = Global.network_manager.player_info
				var survivor_count = 0
				var survivor_ids = []
				
				# 找出所有幸存者并排序
				for id in player_data:
					if player_data[id].role != "killer":
						survivor_count += 1
						survivor_ids.append(id)
				
				survivor_ids.sort()
				
				# 找出当前玩家在幸存者中的索引
				for i in range(survivor_ids.size()):
					if survivor_ids[i] == player_id:
						survivor_index = (i % 4) + 1
						break
			
			return game_map.get_survivor_spawn_position(survivor_index)
	
	# 默认出生点（如果没有地图）
	if role == "killer":
		return Vector2(500, 150)
	else:
		# 为幸存者提供不同起始位置
		var positions = [
			Vector2(150, 150),
			Vector2(150, 500),
			Vector2(850, 150),
			Vector2(850, 500)
		]
		
		if player_id > 0:
			# 使用玩家ID来确定位置
			return positions[(player_id % 4)]
		else:
			# 随机选择一个位置
			return positions[randi() % positions.size()]

# 初始化游戏
func initialize_game():
	if !Global.network_manager.is_server:
		return
	
	print("初始化游戏...")
	
	# 等待一帧确保场景已加载
	await get_tree().process_frame
	
	# 1. 生成所有玩家角色
	for player_id in Global.network_manager.player_info:
		var player_data = Global.network_manager.player_info[player_id]
		var spawn_pos = get_spawn_position(player_data.role, player_id)  # 使用新函数获取生成位置
		
		# 生成角色
		var character_type = "killer" if player_data.role == "杀手" else "survivor"
		do_spawn_character(character_type, player_id, spawn_pos)
	
	# 2. 初始化发电机和其他物件
	var random_generator = RandomNumberGenerator.new()
	random_generator.seed = Global.current_seed  # 使用全局种子确保一致
	
	# 生成发电机
	var generator_positions = [
		Vector2(250, 300),
		Vector2(450, 350),
		Vector2(650, 250),
		Vector2(350, 500),
		Vector2(550, 450),
		Vector2(300, 200),
		Vector2(700, 400)
	]
	
	# 打乱位置
	generator_positions.shuffle_buffered(random_generator)
	
	# 选择指定数量的发电机位置
	for i in range(min(Global.GENERATORS_REQUIRED + 1, generator_positions.size())):
		var pos = generator_positions[i]
		spawn_object("Generator", pos)
	
	# 生成钩子
	var hook_positions = [
		Vector2(200, 250),
		Vector2(400, 300),
		Vector2(600, 200),
		Vector2(300, 450),
		Vector2(500, 400),
		Vector2(700, 350),
		Vector2(450, 500)
	]
	
	# 打乱位置
	hook_positions.shuffle_buffered(random_generator)
	
	# 选择指定数量的钩子位置
	for i in range(min(6, hook_positions.size())):
		var pos = hook_positions[i]
		spawn_object("Hook", pos)
	
	# 生成出口门
	spawn_object("ExitGate", Vector2(200, 500), {"is_powered": false})
	
	# 通知所有玩家游戏初始化完成
	rpc("on_game_initialized")

# 通知游戏初始化完成
@rpc("authority", "call_remote", "reliable")
func on_game_initialized():
	print("游戏初始化完成!") 