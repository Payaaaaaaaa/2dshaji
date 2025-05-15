@tool
extends EditorScript

# 此脚本用于创建/更新多主题TileSet
# 在Godot编辑器中通过"工具 > 运行EditorScript"运行此脚本

func _run():
	# 地图主题数量
	var theme_count = 5  # 森林、医院、工厂、学校、营地
	
	# 创建新的TileSet
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	
	# 为每个主题创建TileSetAtlasSource
	for theme_id in range(theme_count):
		var theme_name = get_theme_name(theme_id)
		var source = TileSetAtlasSource.new()
		
		# 设置源纹理，这里假设您有对应的纹理文件
		# 实际使用时请替换为真实的纹理路径
		var texture_path = "res://assets/tilesets/tileset_" + theme_name + ".png"
		if ResourceLoader.exists(texture_path):
			source.texture = load(texture_path)
		
		# 设置图块大小
		source.texture_region_size = Vector2i(32, 32)
		
		# 添加基本图块
		# 0,0 = 地板
		source.create_tile(Vector2i(0, 0))
		
		# 1,0 = 墙壁
		source.create_tile(Vector2i(1, 0))
		
		# 装饰图块 (2,0), (3,0), (4,0)
		for i in range(3):
			source.create_tile(Vector2i(2 + i, 0))
		
		# 将主题源添加到TileSet
		tileset.add_source(source, theme_id)
	
	# 创建第二个图层
	tileset.add_layer(1)
	tileset.set_layer_name(1, "Decoration")
	
	# 保存TileSet
	var save_path = "res://assets/tilesets/multi_theme_tileset.tres"
	var error = ResourceSaver.save(tileset, save_path)
	
	if error == OK:
		print("多主题TileSet已保存到: " + save_path)
	else:
		print("保存TileSet失败，错误码: " + str(error))

# 获取主题名称
func get_theme_name(theme_id: int) -> String:
	match theme_id:
		0:
			return "forest"
		1:
			return "hospital"
		2:
			return "factory"
		3:
			return "school"
		4:
			return "campsite"
		_:
			return "unknown" 