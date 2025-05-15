extends Control
class_name GameResultUI

# 节点引用
@onready var result_title = $ResultTitle
@onready var player_stats_container = $PlayerStats/VBoxContainer
@onready var player_stats_item = preload("res://scenes/ui/PlayerStatsItem.tscn")
@onready var continue_button = $ContinueButton
@onready var background = $Background
@onready var animation_player = $AnimationPlayer

# 游戏数据
var game_result: Dictionary = {}
var player_stats: Dictionary = {}
var killer_won: bool = false

# 信号
signal continue_pressed

func _ready():
	# 隐藏界面，等待显示调用
	visible = false
	
	# 连接按钮信号
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)

# 显示结算界面
func show_results(result: Dictionary):
	game_result = result
	killer_won = result.get("killer_won", false)
	player_stats = result.get("player_stats", {})
	
	# 设置标题
	if result_title:
		result_title.text = killer_won ? "杀手胜利" : "幸存者胜利"
		result_title.add_theme_color_override("font_color", Color(1, 0, 0) if killer_won else Color(0, 0.8, 1))
	
	# 填充玩家数据
	_populate_player_stats()
	
	# 显示界面
	visible = true
	
	# 播放动画
	if animation_player and animation_player.has_animation("show"):
		animation_player.play("show")
	else:
		# 简单淡入动画
		modulate.a = 0
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.5)

# 填充玩家统计数据
func _populate_player_stats():
	# 首先清空容器
	for child in player_stats_container.get_children():
		player_stats_container.remove_child(child)
		child.queue_free()
	
	# 添加杀手数据
	if player_stats.has("killer"):
		var killer_data = player_stats["killer"]
		var killer_item = player_stats_item.instantiate()
		killer_item.setup_killer_stats(
			killer_data.get("name", "杀手"),
			killer_data.get("hook_count", 0),
			killer_data.get("hit_count", 0),
			killer_data.get("kill_count", 0)
		)
		player_stats_container.add_child(killer_item)
	
	# 添加幸存者数据
	if player_stats.has("survivors"):
		var survivor_list = player_stats["survivors"]
		for survivor_data in survivor_list:
			var survivor_item = player_stats_item.instantiate()
			survivor_item.setup_survivor_stats(
				survivor_data.get("name", "幸存者"),
				survivor_data.get("generator_count", 0),
				survivor_data.get("rescue_count", 0),
				survivor_data.get("escaped", false)
			)
			player_stats_container.add_child(survivor_item)

# 隐藏结算界面
func hide_results():
	# 播放动画
	if animation_player and animation_player.has_animation("hide"):
		animation_player.play("hide")
		await animation_player.animation_finished
		visible = false
	else:
		# 简单淡出动画
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		await tween.finished
		visible = false

# 继续按钮回调
func _on_continue_button_pressed():
	continue_pressed.emit()
	hide_results() 