extends Control
class_name BalanceSettingsUI

# 节点引用
@onready var difficulty_option = $DifficultyOption
@onready var save_button = $SaveButton
@onready var reset_button = $ResetButton
@onready var back_button = $BackButton

# 角色速度滑块
@onready var survivor_walk_slider = $CharacterSettings/SurvivorWalkSlider
@onready var survivor_run_slider = $CharacterSettings/SurvivorRunSlider
@onready var killer_speed_slider = $CharacterSettings/KillerSpeedSlider

# 状态修正滑块
@onready var injured_multiplier_slider = $StateSettings/InjuredMultiplierSlider
@onready var carrying_multiplier_slider = $StateSettings/CarryingMultiplierSlider

# 技能检测滑块
@onready var skill_check_difficulty_slider = $SkillCheckSettings/DifficultySlider
@onready var skill_check_zone_slider = $SkillCheckSettings/ZoneSizeSlider
@onready var skill_check_regression_slider = $SkillCheckSettings/RegressionSlider

# 钩子设置滑块
@onready var hook_time_slider = $HookSettings/HookTimeSlider
@onready var second_hook_time_slider = $HookSettings/SecondHookTimeSlider
@onready var self_unhook_chance_slider = $HookSettings/SelfUnhookChanceSlider

# 游戏参数设置
@onready var generators_required_spinner = $GameSettings/GeneratorsRequiredSpinner
@onready var generators_total_spinner = $GameSettings/GeneratorsTotalSpinner

func _ready():
	# 初始化下拉菜单
	_setup_difficulty_dropdown()
	
	# 连接按钮信号
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# 连接值变更信号
	_connect_slider_signals()
	
	# 加载当前平衡设置到UI
	load_settings_to_ui()

# 设置难度下拉菜单
func _setup_difficulty_dropdown():
	if difficulty_option:
		difficulty_option.clear()
		difficulty_option.add_item("简单", GameBalanceManager.DifficultyPreset.EASY)
		difficulty_option.add_item("平衡", GameBalanceManager.DifficultyPreset.BALANCED)
		difficulty_option.add_item("困难", GameBalanceManager.DifficultyPreset.HARD)
		difficulty_option.add_item("自定义", GameBalanceManager.DifficultyPreset.CUSTOM)
		difficulty_option.select(GameBalanceManager.instance.current_preset)
		difficulty_option.item_selected.connect(_on_difficulty_selected)

# 连接滑块信号
func _connect_slider_signals():
	# 角色速度滑块
	if survivor_walk_slider:
		survivor_walk_slider.value_changed.connect(_on_survivor_walk_changed)
	if survivor_run_slider:
		survivor_run_slider.value_changed.connect(_on_survivor_run_changed)
	if killer_speed_slider:
		killer_speed_slider.value_changed.connect(_on_killer_speed_changed)
	
	# 状态修正滑块
	if injured_multiplier_slider:
		injured_multiplier_slider.value_changed.connect(_on_injured_multiplier_changed)
	if carrying_multiplier_slider:
		carrying_multiplier_slider.value_changed.connect(_on_carrying_multiplier_changed)
	
	# 技能检测滑块
	if skill_check_difficulty_slider:
		skill_check_difficulty_slider.value_changed.connect(_on_skill_check_difficulty_changed)
	if skill_check_zone_slider:
		skill_check_zone_slider.value_changed.connect(_on_skill_check_zone_changed)
	if skill_check_regression_slider:
		skill_check_regression_slider.value_changed.connect(_on_skill_check_regression_changed)
	
	# 钩子设置滑块
	if hook_time_slider:
		hook_time_slider.value_changed.connect(_on_hook_time_changed)
	if second_hook_time_slider:
		second_hook_time_slider.value_changed.connect(_on_second_hook_time_changed)
	if self_unhook_chance_slider:
		self_unhook_chance_slider.value_changed.connect(_on_self_unhook_chance_changed)
	
	# 游戏参数设置
	if generators_required_spinner:
		generators_required_spinner.value_changed.connect(_on_generators_required_changed)
	if generators_total_spinner:
		generators_total_spinner.value_changed.connect(_on_generators_total_changed)

# 从平衡管理器加载设置到UI
func load_settings_to_ui():
	var balance = GameBalanceManager.instance
	
	# 角色速度
	if survivor_walk_slider:
		survivor_walk_slider.value = balance.survivor_walk_speed
	if survivor_run_slider:
		survivor_run_slider.value = balance.survivor_run_speed
	if killer_speed_slider:
		killer_speed_slider.value = balance.killer_speed
	
	# 状态修正
	if injured_multiplier_slider:
		injured_multiplier_slider.value = balance.injured_speed_multiplier
	if carrying_multiplier_slider:
		carrying_multiplier_slider.value = balance.carrying_speed_multiplier
	
	# 技能检测
	if skill_check_difficulty_slider:
		skill_check_difficulty_slider.value = balance.skill_check_base_difficulty
	if skill_check_zone_slider:
		skill_check_zone_slider.value = balance.skill_check_zone_size
	if skill_check_regression_slider:
		skill_check_regression_slider.value = balance.skill_check_fail_regression
	
	# 钩子设置
	if hook_time_slider:
		hook_time_slider.value = balance.hook_struggle_time
	if second_hook_time_slider:
		second_hook_time_slider.value = balance.hook_second_struggle_time
	if self_unhook_chance_slider:
		self_unhook_chance_slider.value = balance.self_unhook_base_chance
	
	# 游戏参数
	if generators_required_spinner:
		generators_required_spinner.value = balance.generators_required
	if generators_total_spinner:
		generators_total_spinner.value = balance.generator_total
	
	# 设置选项下拉菜单
	if difficulty_option:
		difficulty_option.select(balance.current_preset)

# 应用UI设置到平衡管理器
func apply_settings_to_manager():
	var balance = GameBalanceManager.instance
	
	# 角色速度
	balance.survivor_walk_speed = survivor_walk_slider.value
	balance.survivor_run_speed = survivor_run_slider.value
	balance.killer_speed = killer_speed_slider.value
	
	# 状态修正
	balance.injured_speed_multiplier = injured_multiplier_slider.value
	balance.carrying_speed_multiplier = carrying_multiplier_slider.value
	
	# 技能检测
	balance.skill_check_base_difficulty = skill_check_difficulty_slider.value
	balance.skill_check_zone_size = skill_check_zone_slider.value
	balance.skill_check_fail_regression = skill_check_regression_slider.value
	
	# 钩子设置
	balance.hook_struggle_time = hook_time_slider.value
	balance.hook_second_struggle_time = second_hook_time_slider.value
	balance.self_unhook_base_chance = self_unhook_chance_slider.value
	
	# 游戏参数
	balance.generators_required = int(generators_required_spinner.value)
	balance.generator_total = int(generators_total_spinner.value)
	
	# 标记为自定义预设
	balance.current_preset = GameBalanceManager.DifficultyPreset.CUSTOM
	
	# 更新下拉菜单选择
	if difficulty_option:
		difficulty_option.select(GameBalanceManager.DifficultyPreset.CUSTOM)

# 信号处理函数
func _on_difficulty_selected(index: int):
	var preset = difficulty_option.get_item_id(index)
	GameBalanceManager.instance.apply_preset(preset)
	load_settings_to_ui()

func _on_save_button_pressed():
	apply_settings_to_manager()
	GameBalanceManager.instance.save_balance_settings()
	show_message("平衡设置已保存")

func _on_reset_button_pressed():
	GameBalanceManager.instance.apply_preset(GameBalanceManager.DifficultyPreset.BALANCED)
	load_settings_to_ui()
	show_message("已重置为默认平衡设置")

func _on_back_button_pressed():
	hide()
	if has_node("/root/Main"):
		var main = get_node("/root/Main")
		if main.has_method("show_settings_menu"):
			main.show_settings_menu()

# 滑块值变更处理
func _on_survivor_walk_changed(value: float):
	if survivor_walk_slider.value >= survivor_run_slider.value:
		survivor_walk_slider.value = survivor_run_slider.value - 10
	_mark_as_custom()

func _on_survivor_run_changed(value: float):
	if survivor_run_slider.value <= survivor_walk_slider.value:
		survivor_run_slider.value = survivor_walk_slider.value + 10
	_mark_as_custom()

func _on_killer_speed_changed(value: float):
	_mark_as_custom()

func _on_injured_multiplier_changed(value: float):
	_mark_as_custom()

func _on_carrying_multiplier_changed(value: float):
	_mark_as_custom()

func _on_skill_check_difficulty_changed(value: float):
	_mark_as_custom()

func _on_skill_check_zone_changed(value: float):
	_mark_as_custom()

func _on_skill_check_regression_changed(value: float):
	_mark_as_custom()

func _on_hook_time_changed(value: float):
	if hook_time_slider.value <= second_hook_time_slider.value:
		hook_time_slider.value = second_hook_time_slider.value + 5
	_mark_as_custom()

func _on_second_hook_time_changed(value: float):
	if second_hook_time_slider.value >= hook_time_slider.value:
		second_hook_time_slider.value = hook_time_slider.value - 5
	_mark_as_custom()

func _on_self_unhook_chance_changed(value: float):
	_mark_as_custom()

func _on_generators_required_changed(value: float):
	if generators_required_spinner.value >= generators_total_spinner.value:
		generators_required_spinner.value = generators_total_spinner.value - 1
	_mark_as_custom()

func _on_generators_total_changed(value: float):
	if generators_total_spinner.value <= generators_required_spinner.value:
		generators_total_spinner.value = generators_required_spinner.value + 1
	_mark_as_custom()

# 标记为自定义设置
func _mark_as_custom():
	if difficulty_option:
		difficulty_option.select(difficulty_option.get_item_index(GameBalanceManager.DifficultyPreset.CUSTOM))

# 显示消息
func show_message(text: String):
	if has_node("MessageLabel"):
		var label = get_node("MessageLabel")
		label.text = text
		label.visible = true
		
		# 创建淡出动画
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.3)
		tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(1.0)
		tween.tween_callback(func(): label.visible = false) 