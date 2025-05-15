extends CanvasLayer
class_name GameHUD

# 节点引用
# 状态指示器
@onready var health_bar = $HealthPanel/HealthBar
@onready var health_label = $HealthPanel/HealthLabel
@onready var status_icon = $StatusPanel/StatusIcon
@onready var status_label = $StatusPanel/StatusLabel

# 游戏信息
@onready var generators_panel = $GameInfoPanel/GeneratorsPanel
@onready var generators_label = $GameInfoPanel/GeneratorsPanel/CountLabel
@onready var survivors_panel = $GameInfoPanel/SurvivorsPanel
@onready var survivors_label = $GameInfoPanel/SurvivorsPanel/CountLabel
@onready var time_label = $GameInfoPanel/TimeLabel

# 物品栏
@onready var inventory_panel = $InventoryPanel
@onready var item_icon = $InventoryPanel/ItemIcon
@onready var item_label = $InventoryPanel/ItemLabel
@onready var item_uses = $InventoryPanel/UsesLabel

# 提示和通知
@onready var notification_panel = $NotificationPanel
@onready var notification_label = $NotificationPanel/Label
@onready var interaction_prompt = $InteractionPrompt

# 技能检测
@onready var skill_check_ui = $SkillCheckUI

# 游戏状态
var game_time: float = 0
var generators_completed: int = 0
var total_generators: int = 0
var survivors_alive: int = 0
var total_survivors: int = 0
var is_killer: bool = false
var current_player: Character = null

# 计时器
var notification_timer: Timer

func _ready():
	# 初始化UI
	setup_ui()
	
	# 创建通知计时器
	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)
	add_child(notification_timer)
	
	# 隐藏不需要的面板
	notification_panel.visible = false
	
	# 监听全局事件
	if get_node_or_null("/root/Global"):
		var global = get_node("/root/Global")
		if global.has_signal("game_event"):
			global.game_event.connect(_on_game_event)

func setup_ui():
	# 初始化血条
	if health_bar:
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = 100
	
	# 初始化交互提示
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# 初始化物品栏
	if inventory_panel:
		inventory_panel.visible = false
	
	# 初始化技能检测UI
	if skill_check_ui:
		skill_check_ui.visible = false

func _process(delta):
	# 更新游戏时间
	if get_node_or_null("/root/Game"):
		game_time += delta
		update_time_display()
	
	# 更新角色状态(如果有)
	if current_player:
		update_player_status()

# 设置关联角色
func set_player(player: Character):
	current_player = player
	
	# 判断是否为杀手
	is_killer = player.has_method("is_killer") and player.is_killer()
	
	# 更新UI布局
	update_layout_for_role()
	
	# 注册交互信号
	if player.has_signal("interaction_started"):
		player.interaction_started.connect(_on_interaction_started)
	if player.has_signal("interaction_completed"):
		player.interaction_completed.connect(_on_interaction_completed)
	if player.has_signal("interaction_canceled"):
		player.interaction_canceled.connect(_on_interaction_canceled)
	if player.has_signal("interactable_entered"):
		player.interactable_entered.connect(_on_interactable_entered)
	if player.has_signal("interactable_exited"):
		player.interactable_exited.connect(_on_interactable_exited)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("item_obtained"):
		player.item_obtained.connect(_on_item_obtained)
	if player.has_signal("item_used"):
		player.item_used.connect(_on_item_used)

# 更新UI布局(根据角色)
func update_layout_for_role():
	if is_killer:
		# 杀手UI布局
		if generators_panel:
			generators_panel.visible = true
		if survivors_panel:
			survivors_panel.visible = true
	else:
		# 幸存者UI布局
		if generators_panel:
			generators_panel.visible = true
		if survivors_panel:
			survivors_panel.visible = true
		if inventory_panel:
			inventory_panel.visible = true

# 更新时间显示
func update_time_display():
	if time_label:
		var minutes = int(game_time / 60)
		var seconds = int(game_time) % 60
		time_label.text = "%02d:%02d" % [minutes, seconds]

# 更新角色状态显示
func update_player_status():
	# 更新健康状态
	if health_bar and current_player.has_method("get_health_percent"):
		health_bar.value = current_player.get_health_percent() * 100
	
	if health_label and current_player.has_method("get_health_state_text"):
		health_label.text = current_player.get_health_state_text()
	
	# 更新状态图标和文本
	if status_icon and current_player.has_method("get_status_icon"):
		var icon_texture = current_player.get_status_icon()
		if icon_texture:
			status_icon.texture = icon_texture
	
	if status_label and current_player.has_method("get_status_text"):
		status_label.text = current_player.get_status_text()

# 显示交互提示
func show_interaction_prompt(interactable: Interactable):
	if interaction_prompt:
		interaction_prompt.show_prompt(interactable)

# 隐藏交互提示
func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.hide_prompt()

# 更新交互进度
func update_interaction_progress(progress: float):
	if interaction_prompt:
		interaction_prompt.update_progress(progress)

# 显示通知
func show_notification(text: String, duration: float = 3.0):
	if notification_panel and notification_label:
		notification_label.text = text
		notification_panel.visible = true
		
		# 重置计时器
		notification_timer.wait_time = duration
		notification_timer.start()
		
		# 动画效果
		notification_panel.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(notification_panel, "modulate:a", 1.0, 0.3)

# 触发技能检测
func trigger_skill_check(difficulty: float = -1, zone_size: float = -1):
	if skill_check_ui:
		skill_check_ui.trigger_skill_check(difficulty, zone_size)

# 更新发电机计数
func update_generators_count(completed: int, total: int):
	generators_completed = completed
	total_generators = total
	
	if generators_label:
		generators_label.text = "%d/%d" % [completed, total]

# 更新幸存者计数
func update_survivors_count(alive: int, total: int):
	survivors_alive = alive
	total_survivors = total
	
	if survivors_label:
		survivors_label.text = "%d/%d" % [alive, total]

# 更新物品显示
func update_item_display(item_name: String, uses: int = -1):
	if inventory_panel and item_label:
		if item_name.is_empty():
			inventory_panel.visible = false
		else:
			inventory_panel.visible = true
			item_label.text = item_name
			
			if item_uses and uses >= 0:
				item_uses.text = "剩余: %d" % uses
				item_uses.visible = true
			else:
				item_uses.visible = false
			
			# 尝试设置图标
			if item_icon and item_icon.has_method("set_item"):
				item_icon.set_item(item_name)

# 信号处理
func _on_notification_timeout():
	if notification_panel:
		var tween = create_tween()
		tween.tween_property(notification_panel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): notification_panel.visible = false)

func _on_game_event(event_name: String, data: Dictionary):
	match event_name:
		"generator_completed":
			generators_completed += 1
			update_generators_count(generators_completed, total_generators)
			show_notification("发电机已修好! %d/%d" % [generators_completed, total_generators])
		
		"survivor_hooked":
			if is_killer:
				show_notification("幸存者已被挂上钩子!")
			else:
				show_notification("队友被挂上钩子了!")
		
		"survivor_died":
			survivors_alive -= 1
			update_survivors_count(survivors_alive, total_survivors)
			show_notification("一名幸存者已死亡!")
		
		"exit_opened":
			show_notification("出口门已打开!")
		
		"survivor_escaped":
			if !is_killer:
				show_notification("一名幸存者已逃脱!")
		
		"game_ended":
			var winner = data.get("winner", "")
			if winner == "killer":
				show_notification("杀手胜利!", 5.0)
			else:
				show_notification("幸存者胜利!", 5.0)

func _on_interactable_entered(interactable: Interactable):
	show_interaction_prompt(interactable)

func _on_interactable_exited(_interactable: Interactable):
	hide_interaction_prompt()

func _on_interaction_started(_interactable: Interactable):
	update_interaction_progress(0.01)  # 显示进度条

func _on_interaction_completed(_interactable: Interactable):
	update_interaction_progress(1.0)  # 完成进度

func _on_interaction_canceled(_interactable: Interactable):
	hide_interaction_prompt()

func _on_health_changed(_old_state: int, new_state: int):
	if new_state > 0:  # 受伤或更严重
		show_notification("你已受伤!")
	update_player_status()

func _on_item_obtained(item_name: String, uses: int = -1):
	update_item_display(item_name, uses)
	show_notification("获得物品: " + item_name)

func _on_item_used(item_name: String, uses_left: int):
	if uses_left <= 0:
		update_item_display("")
		show_notification("物品已耗尽: " + item_name)
	else:
		update_item_display(item_name, uses_left)
		show_notification("已使用: " + item_name) 
