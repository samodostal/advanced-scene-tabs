@tool
class_name ASTTabBarUI

var _original_tab_bar: TabBar
var _main_container: HBoxContainer
var _btn_group: ButtonGroup
var _drop_line: ColorRect

var _store: ASTGroupStore
var _popups: ASTPopups
var _editor: EditorInterface

var _ctx_scene_path := ""
var _pending_pin_close_path := ""

var _last_tab_count := -1
var _last_titles_hash := 0
var _last_current := -1


func setup(
	original_tab_bar: TabBar, store: ASTGroupStore, popups: ASTPopups, editor: EditorInterface
) -> void:
	_original_tab_bar = original_tab_bar
	_store = store
	_popups = popups
	_editor = editor

	_btn_group = ButtonGroup.new()
	_btn_group.allow_unpress = false

	var parent := _original_tab_bar.get_parent()

	_main_container = HBoxContainer.new()
	_main_container.name = "AdvancedSceneTabs"
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_main_container)
	parent.move_child(_main_container, _original_tab_bar.get_index())

	_drop_line = ColorRect.new()
	_drop_line.color = Color.WHITE
	_drop_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_line.visible = false
	parent.add_child(_drop_line)

	_original_tab_bar.visible = false


func teardown() -> void:
	if is_instance_valid(_original_tab_bar):
		_original_tab_bar.visible = true

	if is_instance_valid(_main_container):
		_main_container.queue_free()

	if is_instance_valid(_drop_line):
		_drop_line.queue_free()

	_main_container = null
	_original_tab_bar = null
	_btn_group = null
	_drop_line = null
	_pending_pin_close_path = ""
	_last_tab_count = -1
	_last_titles_hash = 0
	_last_current = -1


func process() -> void:
	if is_instance_valid(_drop_line):
		var vp := _drop_line.get_viewport()
		if vp and not vp.gui_is_dragging():
			_drop_line.visible = false

	if not is_instance_valid(_original_tab_bar) or not is_instance_valid(_main_container):
		return

	var count := _original_tab_bar.tab_count
	var current := _original_tab_bar.current_tab
	var thash := _titles_hash()

	if count != _last_tab_count or thash != _last_titles_hash:
		rebuild()

	elif current != _last_current:
		_refresh_highlight()


func is_ready() -> bool:
	return is_instance_valid(_main_container) and is_instance_valid(_original_tab_bar)


func rebuild() -> void:
	if not is_ready():
		return

	for child in _main_container.get_children():
		_main_container.remove_child(child)
		child.queue_free()

	var rows_vbox := VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 0)
	_main_container.add_child(rows_vbox)

	var actions_vbox := VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 2)
	_main_container.add_child(actions_vbox)

	var open_scenes := _editor.get_open_scenes()
	var current := _original_tab_bar.current_tab

	for gi in _store.groups.size():
		var grp: Dictionary = _store.groups[gi]
		var grp_open: Array = []

		for spath in grp["scenes"]:
			if spath in open_scenes:
				grp_open.append(spath)

		if grp_open.is_empty():
			continue

		rows_vbox.add_child(_build_group_row(gi, grp, grp_open, open_scenes, current))

	var ungrouped: Array = []
	for spath in open_scenes:
		if _store.group_index_for(spath) == -1:
			ungrouped.append(spath)

	rows_vbox.add_child(_build_ungrouped_row(ungrouped, open_scenes, current))

	_build_action_buttons(actions_vbox, not ungrouped.is_empty())

	_last_tab_count = _original_tab_bar.tab_count
	_last_current = current
	_last_titles_hash = _titles_hash()


func get_ctx_scene_path() -> String:
	return _ctx_scene_path


func _build_group_row(
	gi: int, grp: Dictionary, grp_open: Array, all_open: PackedStringArray, current: int
) -> PanelContainer:
	var color: Color = ASTConstants.COLORS.get(grp["color"], ASTConstants.COLORS["Grey"])

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()

	ps.bg_color = Color(color, 0.08)
	ps.border_color = Color(color, 0.25)
	ps.border_width_bottom = 1
	ps.content_margin_left = 0
	ps.content_margin_right = 0
	ps.content_margin_top = 1
	ps.content_margin_bottom = 1

	panel.add_theme_stylebox_override("panel", ps)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	panel.add_child(hbox)

	hbox.add_child(_build_group_label(gi, grp, grp_open))

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 0)

	hbox.add_child(flow)

	var bound_gi := gi
	var bound_open := grp_open

	flow.set_drag_forwarding(
		func(_p): return null,
		func(at_pos, data):
			if not _is_tab_drag(data):
				return false

			_show_drop_line(flow, at_pos)
			return true,
		func(at_pos, data):
			if is_instance_valid(_drop_line):
				_drop_line.visible = false

			if _is_tab_drag(data):
				_store.move_scene_to_group(
					data["path"], bound_gi, _get_drop_index(flow, at_pos), bound_open
				)
				rebuild()
	)

	for spath in grp_open:
		var tab_idx := _tab_index_of(spath, all_open)
		if tab_idx == -1:
			continue

		flow.add_child(_build_tab_button(spath, tab_idx, tab_idx == current, gi, grp_open, flow))

	return panel


func _build_ungrouped_row(
	ungrouped: Array, all_open: PackedStringArray, current: int
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 0)
	row.add_child(flow)

	flow.set_drag_forwarding(
		func(_p): return null,
		func(at_pos, data):
			if not _is_tab_drag(data):
				return false

			_show_drop_line(flow, at_pos)
			return true,
		func(_at_pos, data):
			if is_instance_valid(_drop_line):
				_drop_line.visible = false

			if _is_tab_drag(data):
				_store.remove_scene_from_all(data["path"])
				_store.save_to_disk()
				rebuild()
	)

	for spath in ungrouped:
		var tab_idx := _tab_index_of(spath, all_open)
		if tab_idx == -1:
			continue

		flow.add_child(_build_tab_button(spath, tab_idx, tab_idx == current, -1, ungrouped, flow))

	return row


func _build_group_label(gi: int, grp: Dictionary, grp_open: Array) -> Control:
	var color: Color = ASTConstants.COLORS.get(grp["color"], ASTConstants.COLORS["Grey"])

	if grp["name"].is_empty():
		var stripe := ColorRect.new()
		stripe.custom_minimum_size = Vector2(6, 0)
		stripe.color = color
		stripe.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		stripe.tooltip_text = "(" + grp["color"] + ")"

		var bound_gi := gi
		stripe.gui_input.connect(func(e): _on_group_label_input(e, bound_gi, stripe))

		_attach_group_label_drop(stripe, gi, grp_open)
		return stripe

	var label := Button.new()
	label.text = " " + grp["name"] + " "
	label.focus_mode = Control.FOCUS_NONE

	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(color, 0.2)
	ns.border_color = color
	ns.border_width_bottom = 2
	ns.set_corner_radius_all(2)
	ns.content_margin_left = 6
	ns.content_margin_right = 6
	ns.content_margin_top = 2
	ns.content_margin_bottom = 2

	label.add_theme_stylebox_override("normal", ns)

	var hs := ns.duplicate() as StyleBoxFlat
	hs.bg_color = Color(color, 0.4)

	label.add_theme_stylebox_override("hover", hs)
	label.add_theme_stylebox_override("pressed", hs)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_hover_color", Color.WHITE)
	label.add_theme_color_override("font_pressed_color", Color.WHITE)
	label.add_theme_color_override("font_hover_pressed_color", Color.WHITE)

	var bound_gi := gi
	label.gui_input.connect(func(e): _on_group_label_input(e, bound_gi, label))
	_attach_group_label_drop(label, gi, grp_open)

	return label


func _attach_group_label_drop(ctrl: Control, gi: int, grp_open: Array) -> void:
	var bound_gi := gi
	var bound_open := grp_open

	ctrl.set_drag_forwarding(
		func(_p): return null,
		func(_p, data): return _is_tab_drag(data),
		func(_p, data):
			if _is_tab_drag(data):
				_store.move_scene_to_group(data["path"], bound_gi, 0, bound_open)
				rebuild()
	)


func _build_tab_button(
	scene_path: String,
	tab_idx: int,
	is_current: bool,
	owning_group: int,
	grp_open: Array,
	parent_flow: Container
) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_group = _btn_group
	btn.text = _original_tab_bar.get_tab_title(tab_idx)
	btn.button_pressed = is_current
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("scene_path", scene_path)
	btn.set_meta("tab_idx", tab_idx)

	var icon := _original_tab_bar.get_tab_icon(tab_idx)
	if icon:
		btn.icon = icon

	_style_tab_button(btn, is_current)

	if _store.is_pinned(scene_path):
		var dot := Panel.new()

		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = Color(0.65, 0.65, 0.65, 0.9)
		dot_style.set_corner_radius_all(3)
		dot.add_theme_stylebox_override("panel", dot_style)

		dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -9
		dot.offset_top = 2
		dot.offset_right = -3
		dot.offset_bottom = 8

		btn.add_child(dot)

	btn.pressed.connect(func(): _switch_tab(tab_idx))
	btn.gui_input.connect(func(e): _on_tab_input(e, tab_idx, scene_path))

	var bound_path := scene_path
	var bound_group := owning_group
	var bound_open := grp_open

	btn.set_drag_forwarding(
		func(_at_pos):
			var preview := Label.new()
			preview.text = "  " + btn.text + "  "

			var ps := StyleBoxFlat.new()
			ps.bg_color = Color(0.2, 0.2, 0.2, 0.85)
			ps.set_corner_radius_all(4)
			ps.content_margin_left = 6
			ps.content_margin_right = 6
			ps.content_margin_top = 3
			ps.content_margin_bottom = 3

			preview.add_theme_stylebox_override("normal", ps)

			btn.set_drag_preview(preview)

			return {"type": "scene_tab", "path": bound_path},
		func(at_pos, data):
			if not _is_tab_drag(data):
				return false

			_show_drop_line(parent_flow, btn.position + at_pos)
			return true,
		func(at_pos, data):
			if is_instance_valid(_drop_line):
				_drop_line.visible = false

			if _is_tab_drag(data):
				var t_idx := _get_drop_index(parent_flow, btn.position + at_pos)

				if bound_group >= 0:
					_store.move_scene_to_group(data["path"], bound_group, t_idx, bound_open)
				else:
					_store.remove_scene_from_all(data["path"])
					_store.save_to_disk()

				rebuild()
	)

	return btn


func _build_action_buttons(vbox: VBoxContainer, has_ungrouped: bool) -> void:
	var base := _editor.get_base_control()

	var undo_btn := Button.new()
	undo_btn.icon = base.get_theme_icon("Reload", "EditorIcons")
	undo_btn.flat = true
	undo_btn.focus_mode = Control.FOCUS_NONE
	undo_btn.tooltip_text = "Restore Closed Scene"
	undo_btn.disabled = _store.closed_history.is_empty()
	undo_btn.pressed.connect(_restore_last_closed.bind())

	vbox.add_child(undo_btn)

	if has_ungrouped:
		var close_btn := Button.new()
		close_btn.icon = base.get_theme_icon("Remove", "EditorIcons")
		close_btn.flat = true
		close_btn.focus_mode = Control.FOCUS_NONE
		close_btn.tooltip_text = "Close all ungrouped scenes"
		close_btn.pressed.connect(func(): _popups.show_close_ungrouped_confirm())

		vbox.add_child(close_btn)


func _restore_last_closed() -> void:
	var entry := _store.pop_closed()
	if entry.is_empty():
		return

	_editor.open_scene_from_path(entry["scene"])
	_store.restore_scene_to_group(entry["scene"], entry["group"], entry["group_pos"])

	rebuild()


func _on_group_label_input(event: InputEvent, gi: int, ctrl: Control) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		_popups.show_group_popup(gi, ctrl.get_screen_position() + event.position, _store.groups)


func _on_tab_input(event: InputEvent, tab_idx: int, scene_path: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if _store.is_pinned(scene_path):
			_pending_pin_close_path = scene_path
			_popups.show_pin_close_confirm()
		else:
			_close_tab(tab_idx)

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_ctx_scene_path = scene_path
		_popups.show_tab_popup(
			event.global_position, _store.groups, scene_path, _store.is_pinned(scene_path)
		)


func _close_tab(idx: int) -> void:
	if not is_instance_valid(_original_tab_bar):
		return

	var open := _editor.get_open_scenes()
	if idx >= 0 and idx < open.size():
		_store.push_closed(open[idx])

	_original_tab_bar.tab_close_pressed.emit(idx)


func close_all_ungrouped() -> void:
	if not is_instance_valid(_original_tab_bar):
		return

	var open := _editor.get_open_scenes()
	var to_close: Array = []
	for i in open.size():
		if _store.group_index_for(open[i]) == -1 and not _store.is_pinned(open[i]):
			to_close.append(i)

	to_close.reverse()
	for idx in to_close:
		var open2 := _editor.get_open_scenes()
		if idx < open2.size():
			_store.push_closed(open2[idx])

		_original_tab_bar.tab_close_pressed.emit(idx)


func close_tab_by_index(idx: int) -> void:
	var open := _editor.get_open_scenes()

	if idx >= 0 and idx < open.size() and _store.is_pinned(open[idx]):
		_pending_pin_close_path = open[idx]
		_popups.show_pin_close_confirm()
		return

	_close_tab(idx)


func close_pinned() -> void:
	if _pending_pin_close_path.is_empty():
		return

	var open := _editor.get_open_scenes()
	var idx := _tab_index_of(_pending_pin_close_path, open)

	_pending_pin_close_path = ""

	if idx >= 0:
		_close_tab(idx)


func close_all_in_group(gi: int) -> void:
	if gi >= _store.groups.size() or not is_instance_valid(_original_tab_bar):
		return

	var open := _editor.get_open_scenes()
	var to_close: Array = []
	for spath in _store.groups[gi]["scenes"]:
		var idx := _tab_index_of(spath, open)
		if idx >= 0:
			to_close.append(idx)

	to_close.sort()
	to_close.reverse()

	for idx in to_close:
		_original_tab_bar.tab_close_pressed.emit(idx)


func _switch_tab(idx: int) -> void:
	if is_instance_valid(_original_tab_bar):
		_original_tab_bar.current_tab = idx


func _style_tab_button(btn: Button, active: bool) -> void:
	var base := _editor.get_base_control()

	if active:
		var s := base.get_theme_stylebox("tab_selected", "TabBar")
		if s:
			s = s.duplicate()
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_stylebox_override("pressed", s)
			btn.add_theme_stylebox_override("hover", s)

		var c := base.get_theme_color("font_selected_color", "TabBar")
		btn.add_theme_color_override("font_color", c)
		btn.add_theme_color_override("font_pressed_color", c)
		btn.add_theme_color_override("font_hover_color", c)
		btn.add_theme_color_override("font_hover_pressed_color", c)

	else:
		var s := base.get_theme_stylebox("tab_unselected", "TabBar")
		if s:
			s = s.duplicate()
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_stylebox_override("pressed", s)

		var h := base.get_theme_stylebox("tab_hovered", "TabBar")
		if h:
			h = h.duplicate()
			btn.add_theme_stylebox_override("hover", h)

		var c := base.get_theme_color("font_unselected_color", "TabBar")
		btn.add_theme_color_override("font_color", c)
		btn.add_theme_color_override("font_pressed_color", c)

		var hc := base.get_theme_color("font_hovered_color", "TabBar")
		btn.add_theme_color_override("font_hover_color", hc)
		btn.add_theme_color_override("font_hover_pressed_color", hc)


func _refresh_highlight() -> void:
	if not is_instance_valid(_original_tab_bar) or not is_instance_valid(_btn_group):
		return

	var current := _original_tab_bar.current_tab
	for btn in _btn_group.get_buttons():
		if btn.has_meta("tab_idx"):
			var should_active: bool = btn.get_meta("tab_idx") == current

			if btn.button_pressed != should_active:
				btn.button_pressed = should_active

			_style_tab_button(btn, should_active)

	_last_current = current


func _show_drop_line(flow: Container, pos: Vector2) -> void:
	if not is_instance_valid(_drop_line):
		return

	var target_idx := _get_drop_index(flow, pos)
	var rect := Rect2()

	if flow.get_child_count() == 0:
		rect = Rect2(flow.global_position, Vector2(2, flow.size.y))

	elif target_idx < flow.get_child_count():
		var c := flow.get_child(target_idx) as Control
		rect = Rect2(c.global_position - Vector2(2, 0), Vector2(2, c.size.y))

	else:
		var c := flow.get_child(flow.get_child_count() - 1) as Control
		rect = Rect2(c.global_position + Vector2(c.size.x, 0), Vector2(2, c.size.y))

	_drop_line.global_position = rect.position
	_drop_line.size = rect.size
	_drop_line.visible = true
	_drop_line.move_to_front()


func _get_drop_index(flow: Container, pos: Vector2) -> int:
	for i in flow.get_child_count():
		var c := flow.get_child(i) as Control
		if not c.visible:
			continue

		if pos.x < c.position.x + c.size.x * 0.5:
			return i

	return flow.get_child_count()


func _tab_index_of(scene_path: String, open_scenes: PackedStringArray) -> int:
	for i in open_scenes.size():
		if open_scenes[i] == scene_path:
			return i

	return -1


func _titles_hash() -> int:
	if not is_instance_valid(_original_tab_bar):
		return 0

	var s := ""
	for i in _original_tab_bar.tab_count:
		s += _original_tab_bar.get_tab_title(i) + "|"

	return s.hash()


func _is_tab_drag(data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data["type"] == "scene_tab"
