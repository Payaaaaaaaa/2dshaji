extends Control
class_name InventoryUI

# 物品槽节点
@export var item_slots: Array[Control] = []

# 物品数据
var items = []
var max_items = 1  # 默认一个物品槽
var selected_slot = 0

# 信号
signal item_selected(index: int, item_name: String)
signal item_used(item_name: String, uses_left: int)

func _ready():
	# 初始化物品槽
	max_items = max(1, item_slots.size())
	items.resize(max_items)
	
	# 清空所有物品
	for i in range(max_items):
		items[i] = null
	
	# 连接物品槽点击事件
	for i in range(item_slots.size()):
		if item_slots[i] is Button:
			item_slots[i].pressed.connect(_on_item_slot_clicked.bind(i))
	
	# 默认选择第一个槽
	select_slot(0)
	
	# 初始更新UI
	update_ui()

func _input(event):
	# 数字键1-9选择物品槽
	for i in range(min(9, max_items)):
		if event.is_action_pressed("slot_" + str(i + 1)):
			select_slot(i)
			break
	
	# 使用物品 (E键或右键)
	if event.is_action_pressed("use_item") and selected_slot >= 0:
		use_selected_item()

# 选择物品槽
func select_slot(index: int):
	if index < 0 or index >= max_items:
		return
	
	# 更新选择状态
	var prev_selected = selected_slot
	selected_slot = index
	
	# 更新UI
	if prev_selected >= 0 and prev_selected < item_slots.size():
		item_slots[prev_selected].remove_theme_stylebox_override("panel")
	
	if selected_slot >= 0 and selected_slot < item_slots.size():
		# 添加选中样式
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 0, 0.2)
		style.border_width_all = 2
		style.border_color = Color(1, 1, 0)
		item_slots[selected_slot].add_theme_stylebox_override("panel", style)
	
	# 发出选择信号
	if selected_slot >= 0 and selected_slot < items.size() and items[selected_slot]:
		item_selected.emit(selected_slot, items[selected_slot].name)

# 添加物品
func add_item(item_name: String, uses: int = -1, icon_texture: Texture = null) -> bool:
	# 寻找空槽位
	var slot_index = -1
	for i in range(items.size()):
		if items[i] == null:
			slot_index = i
			break
	
	# 如果没有空槽位，使用选中的槽位
	if slot_index == -1:
		slot_index = selected_slot
	
	# 创建物品数据
	var item = {
		"name": item_name,
		"uses": uses,
		"icon": icon_texture
	}
	
	# 添加到槽位
	items[slot_index] = item
	
	# 更新UI
	update_ui()
	
	# 自动选择新添加的物品槽
	select_slot(slot_index)
	
	return true

# 移除物品
func remove_item(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	
	items[index] = null
	update_ui()
	return true

# 使用选中的物品
func use_selected_item() -> bool:
	if selected_slot < 0 or selected_slot >= items.size():
		return false
		
	var item = items[selected_slot]
	if item == null:
		return false
	
	# 减少使用次数
	if item.uses > 0:
		item.uses -= 1
		
		# 发送使用信号
		item_used.emit(item.name, item.uses)
		
		# 如果用完了，移除物品
		if item.uses <= 0:
			remove_item(selected_slot)
			
		return true
	elif item.uses == -1:
		# 无限使用
		item_used.emit(item.name, -1)
		return true
	
	return false

# 获取选中的物品信息
func get_selected_item() -> Dictionary:
	if selected_slot >= 0 and selected_slot < items.size() and items[selected_slot]:
		return items[selected_slot]
	return {}

# 获取所有物品
func get_all_items() -> Array:
	return items

# 清空物品栏
func clear_inventory():
	for i in range(items.size()):
		items[i] = null
	
	update_ui()

# 更新UI显示
func update_ui():
	for i in range(item_slots.size()):
		var slot = item_slots[i]
		
		# 检查索引是否有效
		if i >= items.size():
			continue
			
		var item = items[i]
		
		# 更新图标
		var icon_node = slot.get_node_or_null("Icon")
		if icon_node and icon_node is TextureRect:
			if item and item.icon:
				icon_node.texture = item.icon
				icon_node.visible = true
			else:
				icon_node.visible = false
		
		# 更新名称
		var name_node = slot.get_node_or_null("Name")
		if name_node and name_node is Label:
			if item:
				name_node.text = item.name
				name_node.visible = true
			else:
				name_node.text = ""
				name_node.visible = false
		
		# 更新使用次数
		var uses_node = slot.get_node_or_null("Uses")
		if uses_node and uses_node is Label:
			if item and item.uses > 0:
				uses_node.text = str(item.uses)
				uses_node.visible = true
			else:
				uses_node.visible = false

# 物品槽点击回调
func _on_item_slot_clicked(index: int):
	select_slot(index) 