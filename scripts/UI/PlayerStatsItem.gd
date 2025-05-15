extends Control
class_name PlayerStatsItem

# 节点引用
@onready var player_name_label = $PlayerName
@onready var role_icon = $RoleIcon
@onready var stat1_container = $Stat1
@onready var stat1_icon = $Stat1/Icon
@onready var stat1_label = $Stat1/Value
@onready var stat2_container = $Stat2
@onready var stat2_icon = $Stat2/Icon
@onready var stat2_label = $Stat2/Value
@onready var stat3_container = $Stat3
@onready var stat3_icon = $Stat3/Icon
@onready var stat3_label = $Stat3/Value
@onready var status_label = $StatusLabel

# 预加载图标资源
var killer_icon = preload("res://assets/sprites/ui/icon_killer.png")
var survivor_icon = preload("res://assets/sprites/ui/icon_survivor.png")
var hook_icon = preload("res://assets/sprites/ui/icon_hook.png")
var hit_icon = preload("res://assets/sprites/ui/icon_hit.png")
var kill_icon = preload("res://assets/sprites/ui/icon_kill.png")
var generator_icon = preload("res://assets/sprites/ui/icon_generator.png")
var rescue_icon = preload("res://assets/sprites/ui/icon_rescue.png")
var escape_icon = preload("res://assets/sprites/ui/icon_escape.png")

var is_killer: bool = false

func _ready():
	# 设置初始值
	reset()

# 重置状态
func reset():
	if player_name_label:
		player_name_label.text = ""
	
	if status_label:
		status_label.text = ""
		status_label.visible = false
	
	# 隐藏统计容器
	if stat1_container:
		stat1_container.visible = false
	if stat2_container:
		stat2_container.visible = false
	if stat3_container:
		stat3_container.visible = false

# 设置杀手统计数据
func setup_killer_stats(killer_name: String, hook_count: int, hit_count: int, kill_count: int):
	is_killer = true
	
	# 设置名称
	if player_name_label:
		player_name_label.text = killer_name
		player_name_label.add_theme_color_override("font_color", Color(1, 0, 0))
	
	# 设置角色图标
	if role_icon:
		role_icon.texture = killer_icon
	
	# 设置钩子数量
	if stat1_container and stat1_icon and stat1_label:
		stat1_container.visible = true
		stat1_icon.texture = hook_icon
		stat1_label.text = str(hook_count)
	
	# 设置命中数量
	if stat2_container and stat2_icon and stat2_label:
		stat2_container.visible = true
		stat2_icon.texture = hit_icon
		stat2_label.text = str(hit_count)
	
	# 设置击杀数量
	if stat3_container and stat3_icon and stat3_label:
		stat3_container.visible = true
		stat3_icon.texture = kill_icon
		stat3_label.text = str(kill_count)

# 设置幸存者统计数据
func setup_survivor_stats(survivor_name: String, generator_count: int, rescue_count: int, escaped: bool):
	is_killer = false
	
	# 设置名称
	if player_name_label:
		player_name_label.text = survivor_name
		player_name_label.add_theme_color_override("font_color", Color(0, 0.8, 1))
	
	# 设置角色图标
	if role_icon:
		role_icon.texture = survivor_icon
	
	# 设置发电机数量
	if stat1_container and stat1_icon and stat1_label:
		stat1_container.visible = true
		stat1_icon.texture = generator_icon
		stat1_label.text = str(generator_count)
	
	# 设置救援数量
	if stat2_container and stat2_icon and stat2_label:
		stat2_container.visible = true
		stat2_icon.texture = rescue_icon
		stat2_label.text = str(rescue_count)
	
	# 隐藏第三个统计
	if stat3_container:
		stat3_container.visible = false
	
	# 设置状态标签
	if status_label:
		status_label.visible = true
		if escaped:
			status_label.text = "逃脱"
			status_label.add_theme_color_override("font_color", Color(0, 1, 0))
		else:
			status_label.text = "死亡"
			status_label.add_theme_color_override("font_color", Color(1, 0, 0)) 