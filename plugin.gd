@tool
extends EditorPlugin

const GroupStoreScript = preload("res://addons/advanced_scene_tabs/scripts/group_store.gd")
const PopupsScript = preload("res://addons/advanced_scene_tabs/scripts/popups.gd")
const TabBarUIScript = preload("res://addons/advanced_scene_tabs/scripts/tab_bar_ui.gd")

var _store: ASTGroupStore
var _popups: ASTPopups
var _ui: ASTTabBarUI

var _retry_frames := 0


func _enter_tree() -> void:
	_store = ASTGroupStore.new()
	_store.load_from_disk()

	call_deferred("_setup")


func _exit_tree() -> void:
	_store.save_to_disk()
	_teardown()


func _setup() -> void:
	if _ui and _ui.is_ready():
		return

	var tab_bar := _find_scene_tab_bar()
	if not tab_bar:
		return

	_popups = ASTPopups.new()
	_popups.build(get_editor_interface().get_base_control())
	_wire_popup_signals()

	_ui = ASTTabBarUI.new()
	_ui.setup(tab_bar, _store, _popups, get_editor_interface())


func _teardown() -> void:
	if _ui:
		_ui.teardown()

	if is_instance_valid(_popups):
		_popups.destroy()

	_ui = null
	_popups = null
	_retry_frames = 0


func _process(_delta: float) -> void:
	if not _ui or not _ui.is_ready():
		_retry_frames += 1
		if _retry_frames >= ASTConstants.RETRY_INTERVAL:
			_retry_frames = 0
			_teardown()
			call_deferred("_setup")
		return
	_retry_frames = 0
	_ui.process()


func _wire_popup_signals() -> void:
	_popups.new_group_confirmed.connect(_on_new_group_confirmed)
	_popups.rename_confirmed.connect(_on_rename_confirmed)
	_popups.color_changed.connect(_on_color_changed)
	_popups.tab_popup_action.connect(_on_tab_popup_action)
	_popups.group_popup_action.connect(_on_group_popup_action)
	_popups.close_ungrouped_confirmed.connect(_on_close_ungrouped_confirmed)
	_popups.pin_close_confirmed.connect(_on_pin_close_confirmed)


func _on_new_group_confirmed(name: String, color: String) -> void:
	_store.add_group(name, color, _ui.get_ctx_scene_path())
	_ui.rebuild()


func _on_rename_confirmed(gi: int, new_name: String) -> void:
	if gi >= 0 and gi < _store.groups.size():
		_store.groups[gi]["name"] = new_name
		_store.save_to_disk()
		_ui.rebuild()


func _on_color_changed(gi: int, color: String) -> void:
	if gi >= 0 and gi < _store.groups.size():
		_store.groups[gi]["color"] = color
		_store.save_to_disk()
		_ui.rebuild()


func _on_tab_popup_action(id: int) -> void:
	var ctx_path := _ui.get_ctx_scene_path()

	if id == ASTConstants.TAB_MENU_NEW_GROUP:
		_popups.show_new_group_dialog(_store.pick_unused_color())
	elif id == ASTConstants.TAB_MENU_UNGROUP:
		_store.remove_scene_from_all(ctx_path)
		_ui.rebuild()
	elif id == ASTConstants.TAB_MENU_PIN:
		_store.toggle_pin(ctx_path)
		_ui.rebuild()
	elif id == ASTConstants.TAB_MENU_CLOSE:
		var open := get_editor_interface().get_open_scenes()
		var idx := _tab_index_of(ctx_path, open)

		if idx >= 0:
			_ui.close_tab_by_index(idx)

	elif id >= ASTConstants.TAB_MENU_MOVE_BASE:
		var gi := id - ASTConstants.TAB_MENU_MOVE_BASE
		if gi < _store.groups.size():
			var open_list: Array = []

			for spath in _store.groups[gi]["scenes"]:
				if spath in get_editor_interface().get_open_scenes():
					open_list.append(spath)

			_store.move_scene_to_group(ctx_path, gi, open_list.size(), open_list)
			_ui.rebuild()


func _on_group_popup_action(id: int) -> void:
	var gi := _popups.get_ctx_group_idx()
	if gi < 0 or gi >= _store.groups.size():
		return

	match id:
		ASTConstants.GROUP_MENU_RENAME:
			_popups.show_rename_dialog(gi, _store.groups[gi]["name"])

		ASTConstants.GROUP_MENU_UNGROUP_ALL:
			_store.groups[gi]["scenes"].clear()
			_store.save_to_disk()
			_ui.rebuild()

		ASTConstants.GROUP_MENU_CLOSE_ALL:
			_ui.close_all_in_group(gi)

		ASTConstants.GROUP_MENU_DELETE:
			_store.groups.remove_at(gi)
			_store.save_to_disk()
			_ui.rebuild()


func _on_close_ungrouped_confirmed() -> void:
	_ui.close_all_ungrouped()


func _on_pin_close_confirmed() -> void:
	_ui.close_pinned()


func _tab_index_of(scene_path: String, open_scenes: PackedStringArray) -> int:
	for i in open_scenes.size():
		if open_scenes[i] == scene_path:
			return i

	return -1


func _find_scene_tab_bar() -> TabBar:
	var scenes := get_editor_interface().get_open_scenes()
	if scenes.is_empty():
		return null

	return _search_for_tab_bar(get_editor_interface().get_base_control(), scenes)


func _search_for_tab_bar(node: Node, scenes: PackedStringArray) -> TabBar:
	if node is TabBar and _is_scene_tab_bar(node as TabBar, scenes):
		return node as TabBar

	for child in node.get_children():
		var hit := _search_for_tab_bar(child, scenes)
		if hit:
			return hit

	return null


func _is_scene_tab_bar(tb: TabBar, scenes: PackedStringArray) -> bool:
	if tb.tab_count != scenes.size() or tb.tab_count == 0:
		return false

	if tb.get_parent() is TabContainer:
		return false

	for i in tb.tab_count:
		var title := tb.get_tab_title(i)
		var matched := false
		for path in scenes:
			if title.begins_with(path.get_file().get_basename()):
				matched = true
				break

		if not matched:
			return false

	return true
