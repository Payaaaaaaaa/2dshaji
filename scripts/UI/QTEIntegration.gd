extends Node
class_name QTEIntegration

# 节点引用
var skill_check_ui: SkillCheckUI
var skill_check_controller: SkillCheckController

# 对象引用
var current_player: Character
var current_interactable: Interactable

# 设置值
var success_callback: Callable
var fail_callback: Callable
var complete_callback: Callable

func _init(ui_node: SkillCheckUI):
	skill_check_ui = ui_node
	skill_check_controller = ui_node.controller
	
	# 连接技能检测信号
	if skill_check_controller:
		skill_check_controller.skill_check_succeeded.connect(_on_skill_check_succeeded)
		skill_check_controller.skill_check_failed.connect(_on_skill_check_failed)
		skill_check_controller.skill_check_completed.connect(_on_skill_check_completed)

# 设置当前交互对象
func set_current_interactable(interactable: Interactable):
	current_interactable = interactable

# 设置当前玩家
func set_current_player(player: Character):
	current_player = player

# 设置回调
func set_callbacks(on_success: Callable, on_fail: Callable, on_complete: Callable):
	success_callback = on_success
	fail_callback = on_fail
	complete_callback = on_complete

# 触发技能检测
func trigger_skill_check(difficulty: float = 0.5, zone_size: float = 0.1):
	if skill_check_ui:
		skill_check_ui.trigger_skill_check(difficulty, zone_size)

# 取消技能检测
func cancel():
	if skill_check_ui:
		skill_check_ui.cancel()

# 服务器端生成QTE，发送到客户端
func server_trigger_qte_for_player(player_id: int, difficulty: float = 0.5, zone_size: float = 0.1):
	if not multiplayer.is_server():
		return
	
	rpc_id(player_id, "client_trigger_qte", difficulty, zone_size)

# 客户端触发QTE
@rpc("authority", "call_remote", "reliable")
func client_trigger_qte(difficulty: float, zone_size: float):
	trigger_skill_check(difficulty, zone_size)

# 当成功时通知服务器
func report_qte_result(success: bool):
	if current_interactable and current_player:
		rpc_id(1, "server_receive_qte_result", current_player.player_id, current_interactable.get_instance_id(), success)

# 服务器接收QTE结果
@rpc("any_peer", "call_local", "reliable")
func server_receive_qte_result(player_id: int, interactable_id: int, success: bool):
	if not multiplayer.is_server():
		return
	
	# 查找交互对象
	var interactable = instance_from_id(interactable_id) as Interactable
	var player = _find_player_by_id(player_id)
	
	if not interactable or not player:
		return
	
	# 处理结果
	if success:
		# QTE成功
		if interactable.has_method("on_skill_check_success"):
			interactable.on_skill_check_success(player)
	else:
		# QTE失败
		if interactable.has_method("on_skill_check_failure"):
			interactable.on_skill_check_failure(player)

# 查找玩家角色
func _find_player_by_id(player_id: int) -> Character:
	var players_node = get_node_or_null("/root/Game/Players")
	if not players_node:
		return null
	
	for player in players_node.get_children():
		if player is Character and player.player_id == player_id:
			return player
	
	return null

# 技能检测回调
func _on_skill_check_succeeded():
	if success_callback.is_valid():
		success_callback.call()
	
	# 向服务器报告成功
	report_qte_result(true)

func _on_skill_check_failed():
	if fail_callback.is_valid():
		fail_callback.call()
	
	# 向服务器报告失败
	report_qte_result(false)

func _on_skill_check_completed(success: bool):
	if complete_callback.is_valid():
		complete_callback.call(success) 