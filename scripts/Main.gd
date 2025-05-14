extends Node

func _ready():
	# 获取Global单例
	var global = get_node("/root/Global")
	
	# 设置音频总线
	_setup_audio_buses()
	
	# 连接信号
	if global:
		print("游戏初始化完成")

# 设置音频总线
func _setup_audio_buses():
	# 确保Master总线存在
	var master_bus_idx = AudioServer.get_bus_index("Master")
	
	# 创建Music总线
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var music_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_send(music_bus_idx, "Master")
		
		# 为Music总线设置默认音量
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(0.7))
	
	# 创建SFX总线
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(sfx_bus_idx, "Master")
		
		# 为SFX总线设置默认音量
		AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(0.8)) 