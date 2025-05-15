extends Control
class_name InteractionPromptMenu

# 互动对象类型
enum ObjectType {
	NONE,
	GENERATOR,
	HOOK,
	EXIT_GATE,
	PALLET,
	SURVIVOR
}

# 动作映射
const ACTION_MAP = {
	ObjectType.GENERATOR: [
		{key = "E", action = "修理", enabled = true},
		{key = "F", action = "破坏", enabled = false}
	],
	ObjectType.HOOK: [
		{key = "E", action = "救援", enabled = true}
	],
	ObjectType.EXIT_GATE: [
		{key = "E", action = "开门", enabled = true}
	],
	ObjectType.PALLET: [
		{key = "E", action = "放下", enabled = true}
	],
	ObjectType.SURVIVOR: [
		{key = "E", action = "治疗", enabled = true},
		{key = "F", action = "背起", enabled = false}
	]
}

# 对象名称映射
const OBJECT_NAMES = {
	ObjectType.GENERATOR: "发电机",
	ObjectType.HOOK: "钩子",
	ObjectType.EXIT_GATE: "出口门",
	ObjectType.PALLET: "木板",
	ObjectType.SURVIVOR: "幸存者"
}

# UI 引用
@onready var object_label = $VBoxContainer/ObjectLabel
@onready var action_container = $VBoxContainer/ActionContainer
@onready var action_rows = [
	$VBoxContainer/ActionContainer/ActionRow1,
	$VBoxContainer/ActionContainer/ActionRow2,
	$VBoxContainer/ActionContainer/ActionRow3
]

# 当前交互对象
var current_object_type = ObjectType.NONE
var current_custom_text = ""

func _ready():
	# 初始状态隐藏
	visible = false

# 显示交互提示
func show_prompt(object_type: int, custom_text: String = "", custom_actions = null):
	if object_type == ObjectType.NONE:
		visible = false
		return
	
	current_object_type = object_type
	current_custom_text = custom_text
	
	# 设置对象名称
	if custom_text.is_empty():
		object_label.text = OBJECT_NAMES.get(object_type, "未知对象")
	else:
		object_label.text = custom_text
	
	# 获取动作列表
	var actions = custom_actions if custom_actions else ACTION_MAP.get(object_type, [])
	
	# 隐藏所有行
	for row in action_rows:
		row.visible = false
	
	# 显示有效动作
	for i in range(min(actions.size(), action_rows.size())):
		var action = actions[i]
		var row = action_rows[i]
		
		if action.enabled:
			row.get_node("KeyLabel").text = "[%s]" % action.key
			row.get_node("ActionLabel").text = action.action
			row.visible = true
	
	# 显示提示
	visible = true

# 隐藏交互提示
func hide_prompt():
	visible = false
	current_object_type = ObjectType.NONE
	current_custom_text = ""

# 更新特定动作的状态
func update_action_state(object_type: int, action_index: int, enabled: bool):
	# 确保映射存在
	if not object_type in ACTION_MAP:
		return
		
	# 确保动作索引有效
	var actions = ACTION_MAP[object_type]
	if action_index < 0 or action_index >= actions.size():
		return
	
	# 更新状态
	actions[action_index].enabled = enabled
	
	# 如果是当前显示的对象，刷新显示
	if current_object_type == object_type:
		show_prompt(object_type, current_custom_text)

# 设置自定义动作
func set_custom_actions(object_type: int, actions: Array):
	ACTION_MAP[object_type] = actions
	
	# 如果是当前显示的对象，刷新显示
	if current_object_type == object_type:
		show_prompt(object_type, current_custom_text) 