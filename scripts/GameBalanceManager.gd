extends Node
class_name GameBalanceManager

# 单例实例
static var instance = null

# 难度预设枚举
enum DifficultyPreset {
	EASY,       # 简单
	BALANCED,   # 平衡
	HARD,       # 困难
	CUSTOM      # 自定义
}

# 当前使用的难度预设
var current_preset: int = DifficultyPreset.BALANCED

#region 角色速度参数
var survivor_walk_speed: float = 100.0
var survivor_run_speed: float = 150.0
var killer_speed: float = 160.0
#endregion

#region 状态修正参数
var injured_speed_multiplier: float = 0.7
var carrying_speed_multiplier: float = 0.8
var speed_boost_after_hit: float = 1.5
var speed_boost_duration: float = 2.0
#endregion

#region 技能检测参数
var skill_check_base_difficulty: float = 0.5  # 基础难度(0-1)
var skill_check_zone_size: float = 0.08       # 成功区域大小(0-1)
var skill_check_great_zone_size: float = 0.03 # 完美区域大小(0-1)
var skill_check_min_interval: float = 5.0     # 最小触发间隔
var skill_check_max_interval: float = 15.0    # 最大触发间隔
var skill_check_fail_regression: float = 0.12 # 失败倒退进度
#endregion

#region 钩子相关参数
var hook_struggle_time: float = 60.0         # 首次挂钩时间
var hook_second_struggle_time: float = 30.0  # 第二次挂钩时间
var self_unhook_base_chance: float = 0.04    # 自救基础概率
var self_unhook_max_attempts: int = 3        # 最大自救尝试次数
#endregion

#region 发电机相关参数
var generator_repair_time: float = 80.0      # 单人修理完成时间(秒)
var repair_speed_per_survivor: float = 0.05  # 每增加一名幸存者的速度提升
#endregion

#region 游戏参数
var generators_required: int = 5           # 需要修好几个发电机
var generator_total: int = 7               # 地图上总共有几个发电机
#endregion

#region 地图生成参数
var map_max_size: Vector2i = Vector2i(100, 100)
var min_room_size: int = 8
var max_room_size: int = 15
var corridor_width: int = 2

# 物件生成参数
var hooks_min_count: int = 8
var hooks_max_count: int = 12
var hook_min_distance: float = 20.0

# 物件分布参数
var generator_min_distance: float = 25.0
var exit_gate_min_distance: float = 60.0
#endregion

# 配置文件路径
const CONFIG_FILE_PATH = "user://game_balance.cfg"

func _init():
	# 设置单例实例
	instance = self

func _ready():
	# 加载平衡设置
	load_balance_settings()

# 应用预设难度
func apply_preset(preset: int):
	current_preset = preset
	
	match preset:
		DifficultyPreset.EASY:
			apply_easy_preset()
		DifficultyPreset.BALANCED:
			apply_balanced_preset()
		DifficultyPreset.HARD:
			apply_hard_preset()
		# CUSTOM预设不做任何改动，保持当前值

# 应用简单难度
func apply_easy_preset():
	# 角色速度参数 - 幸存者更快，杀手更慢
	survivor_walk_speed = 110.0
	survivor_run_speed = 165.0
	killer_speed = 150.0
	
	# 状态修正参数 - 减轻惩罚
	injured_speed_multiplier = 0.8
	carrying_speed_multiplier = 0.7
	speed_boost_after_hit = 1.7
	speed_boost_duration = 3.0
	
	# 技能检测参数 - 更容易
	skill_check_base_difficulty = 0.3
	skill_check_zone_size = 0.12
	skill_check_great_zone_size = 0.05
	skill_check_min_interval = 7.0
	skill_check_max_interval = 20.0
	skill_check_fail_regression = 0.08
	
	# 钩子相关参数 - 更长时间
	hook_struggle_time = 80.0
	hook_second_struggle_time = 40.0
	self_unhook_base_chance = 0.08
	self_unhook_max_attempts = 5
	
	# 发电机相关参数 - 修理更快
	generator_repair_time = 60.0
	repair_speed_per_survivor = 0.08
	
	# 游戏参数 - 需要的发电机更少
	generators_required = 4
	generator_total = 6

# 应用平衡难度（默认）
func apply_balanced_preset():
	# 角色速度参数
	survivor_walk_speed = 100.0
	survivor_run_speed = 150.0
	killer_speed = 160.0
	
	# 状态修正参数
	injured_speed_multiplier = 0.7
	carrying_speed_multiplier = 0.8
	speed_boost_after_hit = 1.5
	speed_boost_duration = 2.0
	
	# 技能检测参数
	skill_check_base_difficulty = 0.5
	skill_check_zone_size = 0.08
	skill_check_great_zone_size = 0.03
	skill_check_min_interval = 5.0
	skill_check_max_interval = 15.0
	skill_check_fail_regression = 0.12
	
	# 钩子相关参数
	hook_struggle_time = 60.0
	hook_second_struggle_time = 30.0
	self_unhook_base_chance = 0.04
	self_unhook_max_attempts = 3
	
	# 发电机相关参数
	generator_repair_time = 80.0
	repair_speed_per_survivor = 0.05
	
	# 游戏参数
	generators_required = 5
	generator_total = 7

# 应用困难难度
func apply_hard_preset():
	# 角色速度参数 - 幸存者更慢，杀手更快
	survivor_walk_speed = 90.0
	survivor_run_speed = 140.0
	killer_speed = 170.0
	
	# 状态修正参数 - 加重惩罚
	injured_speed_multiplier = 0.6
	carrying_speed_multiplier = 0.85
	speed_boost_after_hit = 1.3
	speed_boost_duration = 1.5
	
	# 技能检测参数 - 更难
	skill_check_base_difficulty = 0.7
	skill_check_zone_size = 0.05
	skill_check_great_zone_size = 0.02
	skill_check_min_interval = 3.0
	skill_check_max_interval = 10.0
	skill_check_fail_regression = 0.15
	
	# 钩子相关参数 - 更短时间
	hook_struggle_time = 45.0
	hook_second_struggle_time = 20.0
	self_unhook_base_chance = 0.02
	self_unhook_max_attempts = 2
	
	# 发电机相关参数 - 修理更慢
	generator_repair_time = 100.0
	repair_speed_per_survivor = 0.03
	
	# 游戏参数 - 需要的发电机更多
	generators_required = 6
	generator_total = 8

# 获取技能检测参数
func get_skill_check_params() -> Dictionary:
	return {
		"difficulty": skill_check_base_difficulty,
		"zone_size": skill_check_zone_size,
		"great_zone_size": skill_check_great_zone_size,
		"interval_min": skill_check_min_interval,
		"interval_max": skill_check_max_interval,
		"fail_regression": skill_check_fail_regression
	}

# 保存平衡设置到配置文件
func save_balance_settings():
	var config = ConfigFile.new()
	
	# 保存当前预设
	config.set_value("general", "current_preset", current_preset)
	
	# 保存角色速度参数
	config.set_value("character", "survivor_walk_speed", survivor_walk_speed)
	config.set_value("character", "survivor_run_speed", survivor_run_speed)
	config.set_value("character", "killer_speed", killer_speed)
	
	# 保存状态修正参数
	config.set_value("states", "injured_speed_multiplier", injured_speed_multiplier)
	config.set_value("states", "carrying_speed_multiplier", carrying_speed_multiplier)
	config.set_value("states", "speed_boost_after_hit", speed_boost_after_hit)
	config.set_value("states", "speed_boost_duration", speed_boost_duration)
	
	# 保存技能检测参数
	config.set_value("skill_check", "base_difficulty", skill_check_base_difficulty)
	config.set_value("skill_check", "zone_size", skill_check_zone_size)
	config.set_value("skill_check", "great_zone_size", skill_check_great_zone_size)
	config.set_value("skill_check", "min_interval", skill_check_min_interval)
	config.set_value("skill_check", "max_interval", skill_check_max_interval)
	config.set_value("skill_check", "fail_regression", skill_check_fail_regression)
	
	# 保存钩子相关参数
	config.set_value("hook", "struggle_time", hook_struggle_time)
	config.set_value("hook", "second_struggle_time", hook_second_struggle_time)
	config.set_value("hook", "self_unhook_chance", self_unhook_base_chance)
	config.set_value("hook", "max_attempts", self_unhook_max_attempts)
	
	# 保存发电机相关参数
	config.set_value("generator", "repair_time", generator_repair_time)
	config.set_value("generator", "speed_per_survivor", repair_speed_per_survivor)
	
	# 保存游戏参数
	config.set_value("game", "generators_required", generators_required)
	config.set_value("game", "generator_total", generator_total)
	
	# 保存地图参数
	config.set_value("map", "max_size_x", map_max_size.x)
	config.set_value("map", "max_size_y", map_max_size.y)
	config.set_value("map", "min_room_size", min_room_size)
	config.set_value("map", "max_room_size", max_room_size)
	config.set_value("map", "corridor_width", corridor_width)
	config.set_value("map", "hooks_min", hooks_min_count)
	config.set_value("map", "hooks_max", hooks_max_count)
	config.set_value("map", "hook_min_distance", hook_min_distance)
	config.set_value("map", "generator_min_distance", generator_min_distance)
	config.set_value("map", "exit_gate_min_distance", exit_gate_min_distance)
	
	# 保存到文件
	var error = config.save(CONFIG_FILE_PATH)
	if error != OK:
		print("保存平衡设置失败: ", error)
		return false
	
	print("平衡设置已保存")
	return true

# 加载平衡设置
func load_balance_settings():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)
	
	if err == OK:
		# 从配置文件加载值
		current_preset = config.get_value("general", "current_preset", DifficultyPreset.BALANCED)
		
		# 如果不是自定义预设，则应用预设值（配置文件中的值可能已过时）
		if current_preset != DifficultyPreset.CUSTOM:
			apply_preset(current_preset) # 这会覆盖下面从config加载的特定值
			# 在应用预设后，再次从config加载值，以允许自定义预设的覆盖
			# 但要确保是在apply_preset之后，这样预设值是基础

		survivor_walk_speed = config.get_value("character", "survivor_walk_speed", survivor_walk_speed)
		survivor_run_speed = config.get_value("character", "survivor_run_speed", survivor_run_speed)
		killer_speed = config.get_value("character", "killer_speed", killer_speed)
		
		injured_speed_multiplier = config.get_value("states", "injured_speed_multiplier", injured_speed_multiplier)
		carrying_speed_multiplier = config.get_value("states", "carrying_speed_multiplier", carrying_speed_multiplier)
		speed_boost_after_hit = config.get_value("states", "speed_boost_after_hit", speed_boost_after_hit)
		speed_boost_duration = config.get_value("states", "speed_boost_duration", speed_boost_duration)
		
		skill_check_base_difficulty = config.get_value("skill_check", "base_difficulty", skill_check_base_difficulty)
		skill_check_zone_size = config.get_value("skill_check", "zone_size", skill_check_zone_size)
		skill_check_great_zone_size = config.get_value("skill_check", "great_zone_size", skill_check_great_zone_size)
		skill_check_min_interval = config.get_value("skill_check", "min_interval", skill_check_min_interval)
		skill_check_max_interval = config.get_value("skill_check", "max_interval", skill_check_max_interval)
		skill_check_fail_regression = config.get_value("skill_check", "fail_regression", skill_check_fail_regression)
		
		hook_struggle_time = config.get_value("hook", "struggle_time", hook_struggle_time)
		hook_second_struggle_time = config.get_value("hook", "second_struggle_time", hook_second_struggle_time)
		self_unhook_base_chance = config.get_value("hook", "self_unhook_chance", self_unhook_base_chance)
		self_unhook_max_attempts = config.get_value("hook", "max_attempts", self_unhook_max_attempts)
		
		generator_repair_time = config.get_value("generator", "repair_time", generator_repair_time)
		repair_speed_per_survivor = config.get_value("generator", "speed_per_survivor", repair_speed_per_survivor)
		
		generators_required = config.get_value("game", "generators_required", generators_required)
		generator_total = config.get_value("game", "generator_total", generator_total)

		map_max_size.x = config.get_value("map", "max_size_x", map_max_size.x)
		map_max_size.y = config.get_value("map", "max_size_y", map_max_size.y)
		min_room_size = config.get_value("map", "min_room_size", min_room_size)
		max_room_size = config.get_value("map", "max_room_size", max_room_size)
		corridor_width = config.get_value("map", "corridor_width", corridor_width)
		hooks_min_count = config.get_value("map", "hooks_min", hooks_min_count)
		hooks_max_count = config.get_value("map", "hooks_max", hooks_max_count)
		hook_min_distance = config.get_value("map", "hook_min_distance", hook_min_distance)
		generator_min_distance = config.get_value("map", "generator_min_distance", generator_min_distance)
		exit_gate_min_distance = config.get_value("map", "exit_gate_min_distance", exit_gate_min_distance)
		
		print("平衡设置已加载.")
	else:
		print("找不到平衡设置文件，使用默认设置并创建新文件.")
		# 应用默认预设（例如平衡）以填充值
		apply_preset(DifficultyPreset.BALANCED)
		# 保存当前（默认）设置以创建文件
		save_balance_settings()

# 重置为默认设置
func reset_to_default():
	apply_balanced_preset()
	current_preset = DifficultyPreset.BALANCED
	save_balance_settings() 