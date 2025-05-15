extends Node
class_name AudioManager

# 音频类型
enum AudioType {
	MUSIC,    # 背景音乐
	SFX,      # 音效
	UI,       # 界面音效
	AMBIENT   # 环境音效
}

# 音频播放器节点
var music_player: AudioStreamPlayer
var sfx_players: Node
var ui_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# 音频设置
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var ui_volume: float = 0.8
var ambient_volume: float = 0.8
var master_volume: float = 1.0

# 音频资源缓存
var audio_cache = {}

# 当前播放的背景音乐
var current_music: String = ""
var current_ambient: String = ""

# 预加载音频路径
const MUSIC_PATH = "res://assets/audio/music/"
const SFX_PATH = "res://assets/audio/sfx/"
const UI_PATH = "res://assets/audio/ui/"
const AMBIENT_PATH = "res://assets/audio/ambient/"

# SFX播放器池大小
const SFX_POOL_SIZE = 8

func _ready():
	# 确保目录存在
	var dir = DirAccess.open("res://")
	if !dir.dir_exists("assets/audio"):
		dir.make_dir_recursive("assets/audio/music")
		dir.make_dir_recursive("assets/audio/sfx")
		dir.make_dir_recursive("assets/audio/ui")
		dir.make_dir_recursive("assets/audio/ambient")
	
	# 创建音频播放器
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	sfx_players = Node.new()
	sfx_players.name = "SFXPlayers"
	add_child(sfx_players)
		
	# 创建SFX播放器池
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer" + str(i)
		player.bus = "SFX"
		sfx_players.add_child(player)
	
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = "UI"
	add_child(ui_player)
	
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	# 应用初始音量
	apply_volumes()

# 应用音量设置到所有播放器
func apply_volumes():
	if music_player:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
	
	if sfx_players:
		for player in sfx_players.get_children():
			if player is AudioStreamPlayer:
				player.volume_db = linear_to_db(sfx_volume * master_volume)
	
	if ui_player:
		ui_player.volume_db = linear_to_db(ui_volume * master_volume)
	
	if ambient_player:
		ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)

# 设置音量
func set_volume(type: AudioType, volume: float):
	volume = clamp(volume, 0.0, 1.0)
	
	match type:
		AudioType.MUSIC:
			music_volume = volume
			if music_player:
				music_player.volume_db = linear_to_db(music_volume * master_volume)
		
		AudioType.SFX:
			sfx_volume = volume
			if sfx_players:
				for player in sfx_players.get_children():
					if player is AudioStreamPlayer:
						player.volume_db = linear_to_db(sfx_volume * master_volume)
		
		AudioType.UI:
			ui_volume = volume
			if ui_player:
				ui_player.volume_db = linear_to_db(ui_volume * master_volume)
		
		AudioType.AMBIENT:
			ambient_volume = volume
			if ambient_player:
				ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)
	
	# 保存设置
	save_settings()

# 设置主音量
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	apply_volumes()
	
	# 保存设置
	save_settings()

# 保存音频设置
func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.save("user://audio_settings.cfg")

# 加载音频设置
func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		ui_volume = config.get_value("audio", "ui_volume", 0.8)
		ambient_volume = config.get_value("audio", "ambient_volume", 0.8)
		
		apply_volumes()

# 加载或从缓存获取音频资源
func get_audio_resource(audio_name: String, type: AudioType) -> AudioStream:
	var cache_key = str(type) + "_" + audio_name
	
	# 检查缓存
	if audio_cache.has(cache_key):
		return audio_cache[cache_key]
	
	# 构建路径
	var path = ""
	match type:
		AudioType.MUSIC:
			path = MUSIC_PATH + audio_name
		AudioType.SFX:
			path = SFX_PATH + audio_name
		AudioType.UI:
			path = UI_PATH + audio_name
		AudioType.AMBIENT:
			path = AMBIENT_PATH + audio_name
	
	# 加载资源
	var resource = load(path)
	if resource:
		audio_cache[cache_key] = resource
		return resource
	
	push_error("无法加载音频资源: " + path)
	return null

# 播放音乐
func play_music(music_name: String, transition: bool = true, loop: bool = true):
	# 检查是否已经在播放该音乐
	if current_music == music_name and music_player.playing:
		return
	
	var music = get_audio_resource(music_name, AudioType.MUSIC)
	if not music:
		return
	
	if transition and music_player.playing:
		# 渐变切换背景音乐
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 1.0)
		tween.tween_callback(func():
			music_player.stream = music
			music_player.volume_db = linear_to_db(music_volume * master_volume)
			music_player.play()
		)
	else:
		# 直接切换
		music_player.stream = music
		music_player.volume_db = linear_to_db(music_volume * master_volume)
		music_player.play()
	
	current_music = music_name
	
	# 设置循环
	if music_player.stream and music_player.stream is AudioStreamOggVorbis:
		music_player.stream.loop = loop

# 停止音乐
func stop_music(fade_out: bool = true):
	if !music_player.playing:
		return
	
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 1.0)
		tween.tween_callback(func():
			music_player.stop()
			music_player.volume_db = linear_to_db(music_volume * master_volume)
		)
	else:
		music_player.stop()
	
	current_music = ""

# 播放音效
func play_sfx(sfx_name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	var sfx = get_audio_resource(sfx_name, AudioType.SFX)
	if not sfx:
		return null
	
	# 寻找可用的音效播放器
	var player = get_available_sfx_player()
	if player:
		player.stream = sfx
		player.volume_db = linear_to_db(sfx_volume * master_volume * volume_scale)
		player.pitch_scale = pitch_scale
		player.play()
		
		# 连接播放完成信号
		player.finished.connect(func(): _on_sfx_finished(player), CONNECT_ONE_SHOT)
		
		return player
	
	return null

# 获取可用的SFX播放器
func get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players.get_children():
		if player is AudioStreamPlayer and !player.playing:
			return player
	
	# 如果没有空闲的播放器，则创建一个新的临时播放器
	var temp_player = AudioStreamPlayer.new()
	temp_player.name = "TempSFXPlayer"
	temp_player.bus = "SFX"
	sfx_players.add_child(temp_player)
	
	# 设置在播放完成后自动删除
	temp_player.finished.connect(func(): temp_player.queue_free())
	
	return temp_player

# SFX播放完成回调
func _on_sfx_finished(player: AudioStreamPlayer):
	player.stop()
	player.stream = null

# 播放UI音效
func play_ui_sound(sound_name: String):
	var sound = get_audio_resource(sound_name, AudioType.UI)
	if not sound:
		return
	
	ui_player.stream = sound
	ui_player.volume_db = linear_to_db(ui_volume * master_volume)
	ui_player.play()

# 播放环境音效
func play_ambient(ambient_name: String, loop: bool = true):
	# 检查是否已经在播放
	if current_ambient == ambient_name and ambient_player.playing:
		return
	
	var ambient = get_audio_resource(ambient_name, AudioType.AMBIENT)
	if not ambient:
		return
	
	ambient_player.stream = ambient
	ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)
	
	# 设置循环
	if ambient_player.stream and ambient_player.stream is AudioStreamOggVorbis:
		ambient_player.stream.loop = loop
	
	ambient_player.play()
	current_ambient = ambient_name

# 停止环境音效
func stop_ambient(fade_out: bool = true):
	if !ambient_player.playing:
		return
	
	if fade_out:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -40.0, 1.0)
		tween.tween_callback(func():
			ambient_player.stop()
			ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)
		)
	else:
		ambient_player.stop()
	
	current_ambient = ""

# 静音所有声音
func mute_all(mute: bool = true):
	if mute:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

# 预加载常用音频资源
func preload_common_audio():
	# 预加载常用音乐
	get_audio_resource("main_menu.ogg", AudioType.MUSIC)
	get_audio_resource("game_loop.ogg", AudioType.MUSIC)
	get_audio_resource("chase.ogg", AudioType.MUSIC)
	
	# 预加载常用音效
	get_audio_resource("generator_repair.wav", AudioType.SFX)
	get_audio_resource("hook.wav", AudioType.SFX)
	get_audio_resource("injury.wav", AudioType.SFX)
	get_audio_resource("heartbeat.wav", AudioType.SFX)
	
	# 预加载UI音效
	get_audio_resource("click.wav", AudioType.UI)
	get_audio_resource("hover.wav", AudioType.UI)
	
	# 预加载环境音效
	get_audio_resource("forest_ambience.ogg", AudioType.AMBIENT) 
