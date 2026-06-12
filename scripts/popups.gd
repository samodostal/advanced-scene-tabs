@tool
class_name ASTPopups

signal new_group_confirmed(name: String, color: String)
signal rename_confirmed(gi: int, new_name: String)
signal color_changed(gi: int, color: String)
signal tab_popup_action(id: int)
signal group_popup_action(id: int)
signal close_ungrouped_confirmed
signal pin_close_confirmed

var _tab_popup: PopupMenu
var _group_popup: PopupMenu
var _color_submenu: PopupMenu
var _new_group_dialog: ConfirmationDialog
var _rename_dialog: ConfirmationDialog
var _confirm_close: ConfirmationDialog
var _confirm_close_pinned: ConfirmationDialog

var _ctx_group_idx := -1
var _new_group_color := "Blue"


func build(base: Control) -> void:
	_tab_popup = PopupMenu.new()
	_tab_popup.id_pressed.connect(_on_tab_popup)
	base.add_child(_tab_popup)

	_color_submenu = PopupMenu.new()
	_color_submenu.name = "ColorSubmenu"
	_color_submenu.id_pressed.connect(_on_color_submenu)

	_group_popup = PopupMenu.new()
	_group_popup.id_pressed.connect(_on_group_popup)
	_group_popup.add_child(_color_submenu)
	base.add_child(_group_popup)

	_build_new_group_dialog(base)
	_build_rename_dialog(base)
	_build_close_confirm(base)
	_build_pin_close_confirm(base)


func destroy() -> void:
	for n in [
		_tab_popup,
		_group_popup,
		_new_group_dialog,
		_rename_dialog,
		_confirm_close,
		_confirm_close_pinned
	]:
		if is_instance_valid(n):
			n.queue_free()


func show_tab_popup(
	global_pos: Vector2, groups: Array, ctx_scene_path: String, is_pinned: bool
) -> void:
	var open := EditorInterface.get_open_scenes()
	var in_group := false
	var tab_count_in_same_group := 0
	var tab_count_in_all_groups := 0

	for g in groups:
		var count_in_this_group := 0
		for scene in g["scenes"]:
			if scene in open:
				count_in_this_group += 1
		tab_count_in_all_groups += count_in_this_group
		if ctx_scene_path in g["scenes"]:
			in_group = true
			tab_count_in_same_group = count_in_this_group

	if not in_group:
		tab_count_in_same_group = open.size() - tab_count_in_all_groups

	_tab_popup.clear()
	_tab_popup.add_item("Unpin" if is_pinned else "Pin", ASTConstants.TAB_MENU_PIN)

	_tab_popup.add_separator("Group")

	for gi in groups.size():
		var grp: Dictionary = groups[gi]
		var display_name: String = (
			grp["name"] if not grp["name"].is_empty() else "(" + grp["color"] + ")"
		)
		_tab_popup.add_item(display_name, ASTConstants.TAB_MENU_MOVE_BASE + gi)
		var idx := _tab_popup.get_item_index(ASTConstants.TAB_MENU_MOVE_BASE + gi)
		_tab_popup.set_item_icon(
			idx, _color_swatch(ASTConstants.COLORS.get(grp["color"], ASTConstants.COLORS["Grey"]))
		)

	_tab_popup.add_item("New Group...", ASTConstants.TAB_MENU_NEW_GROUP)

	if in_group:
		_tab_popup.add_item("Remove from Group", ASTConstants.TAB_MENU_UNGROUP)

	_tab_popup.add_separator()
	_tab_popup.add_item("Show in FileSystem", ASTConstants.TAB_MENU_SHOW_IN_FILESYSTEM)

	if tab_count_in_same_group > 1:
		_tab_popup.add_separator("Close in Group" if in_group else "Close Ungrouped")
	else:
		_tab_popup.add_separator()
	_tab_popup.add_item("Close Tab", ASTConstants.TAB_MENU_CLOSE)

	if tab_count_in_same_group > 1:
		_tab_popup.add_item("Close Other Tabs", ASTConstants.TAB_MENU_CLOSE_OTHERS)
		_tab_popup.add_item("Close Tabs to the Left", ASTConstants.TAB_MENU_CLOSE_LEFT)
		_tab_popup.add_item("Close Tabs to the Right", ASTConstants.TAB_MENU_CLOSE_RIGHT)

	_tab_popup.position = Vector2i(global_pos)
	_tab_popup.reset_size()
	_tab_popup.popup()


func show_pin_close_confirm() -> void:
	_confirm_close_pinned.popup_centered()


func show_group_popup(gi: int, global_pos: Vector2, groups: Array) -> void:
	if gi >= groups.size():
		return

	_ctx_group_idx = gi
	_group_popup.clear()
	_group_popup.add_item("Rename...", ASTConstants.GROUP_MENU_RENAME)

	_color_submenu.clear()
	var cidx := 0
	for cname in ASTConstants.COLORS:
		_color_submenu.add_item(cname, ASTConstants.GROUP_MENU_COLOR_BASE + cidx)
		var item_index := _color_submenu.get_item_index(ASTConstants.GROUP_MENU_COLOR_BASE + cidx)
		_color_submenu.set_item_icon(item_index, _color_swatch(ASTConstants.COLORS[cname]))
		cidx += 1

	_group_popup.add_submenu_item("Change Color", "ColorSubmenu")
	_group_popup.add_separator()
	_group_popup.add_item("Ungroup All", ASTConstants.GROUP_MENU_UNGROUP_ALL)
	_group_popup.add_item("Close All in Group", ASTConstants.GROUP_MENU_CLOSE_ALL)
	_group_popup.add_separator()
	_group_popup.add_item("Delete Group", ASTConstants.GROUP_MENU_DELETE)

	_group_popup.position = Vector2i(global_pos)
	_group_popup.reset_size()
	_group_popup.popup()


func show_new_group_dialog(default_color: String) -> void:
	_new_group_color = default_color

	var name_edit := _new_group_dialog.find_child("NameEdit", true, false) as LineEdit
	if name_edit:
		name_edit.text = ""
		name_edit.grab_focus.call_deferred()

	_refresh_color_buttons()
	_new_group_dialog.popup_centered()


func show_rename_dialog(gi: int, current_name: String) -> void:
	_ctx_group_idx = gi

	var edit := _rename_dialog.find_child("RenameEdit", true, false) as LineEdit
	if edit:
		edit.text = current_name
		edit.select_all()
		edit.grab_focus.call_deferred()

	_rename_dialog.popup_centered()


func show_close_ungrouped_confirm() -> void:
	_confirm_close.popup_centered()


func _on_tab_popup(id: int) -> void:
	tab_popup_action.emit(id)


func _on_group_popup(id: int) -> void:
	group_popup_action.emit(id)


func _on_color_submenu(id: int) -> void:
	var cidx := id - ASTConstants.GROUP_MENU_COLOR_BASE
	var keys := ASTConstants.COLORS.keys()

	if _ctx_group_idx >= 0 and cidx >= 0 and cidx < keys.size():
		color_changed.emit(_ctx_group_idx, keys[cidx])


func _on_new_group_confirmed() -> void:
	var name_edit := _new_group_dialog.find_child("NameEdit", true, false) as LineEdit
	var gname := name_edit.text.strip_edges() if name_edit else ""

	new_group_confirmed.emit(gname, _new_group_color)


func _on_rename_confirmed() -> void:
	var edit := _rename_dialog.find_child("RenameEdit", true, false) as LineEdit

	if edit:
		rename_confirmed.emit(_ctx_group_idx, edit.text.strip_edges())


func _on_close_confirmed() -> void:
	close_ungrouped_confirmed.emit()


func _on_pin_close_confirmed() -> void:
	pin_close_confirmed.emit()


func _on_color_btn_pressed(cname: String) -> void:
	_new_group_color = cname
	_refresh_color_buttons()


func _refresh_color_buttons() -> void:
	var row := _new_group_dialog.find_child("ColorRow", true, false)
	if not row:
		return

	for child in row.get_children():
		if child is Button:
			child.button_pressed = (child.name == _new_group_color)


func _build_new_group_dialog(base: Control) -> void:
	_new_group_dialog = ConfirmationDialog.new()
	_new_group_dialog.title = "New Group"
	_new_group_dialog.min_size = Vector2i(320, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var name_row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = "Name:"

	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "Group name (optional)"

	name_row.add_child(name_lbl)
	name_row.add_child(name_edit)

	vbox.add_child(name_row)

	var color_lbl := Label.new()
	color_lbl.text = "Color:"
	vbox.add_child(color_lbl)

	var color_row := HFlowContainer.new()
	color_row.name = "ColorRow"
	color_row.add_theme_constant_override("h_separation", 6)

	for cname in ASTConstants.COLORS:
		var cbtn := Button.new()
		cbtn.name = cname
		cbtn.custom_minimum_size = Vector2(28, 28)
		cbtn.toggle_mode = true
		cbtn.tooltip_text = cname

		var s := StyleBoxFlat.new()
		s.bg_color = ASTConstants.COLORS[cname]
		s.set_corner_radius_all(14)
		cbtn.add_theme_stylebox_override("normal", s)

		var sp := s.duplicate() as StyleBoxFlat
		sp.border_color = Color.WHITE
		sp.set_border_width_all(2)

		cbtn.add_theme_stylebox_override("pressed", sp)
		cbtn.add_theme_stylebox_override("hover", sp)

		cbtn.pressed.connect(_on_color_btn_pressed.bind(cname))

		color_row.add_child(cbtn)
	vbox.add_child(color_row)

	_new_group_dialog.add_child(vbox)
	_new_group_dialog.confirmed.connect(_on_new_group_confirmed)

	base.add_child(_new_group_dialog)


func _build_rename_dialog(base: Control) -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename Group"
	_rename_dialog.min_size = Vector2i(280, 0)

	var edit := LineEdit.new()
	edit.name = "RenameEdit"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_rename_dialog.add_child(edit)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)

	base.add_child(_rename_dialog)


func _build_close_confirm(base: Control) -> void:
	_confirm_close = ConfirmationDialog.new()
	_confirm_close.title = "Close Ungrouped Scenes"
	_confirm_close.dialog_text = "Close all ungrouped scenes?"
	_confirm_close.confirmed.connect(_on_close_confirmed)

	base.add_child(_confirm_close)


func _build_pin_close_confirm(base: Control) -> void:
	_confirm_close_pinned = ConfirmationDialog.new()
	_confirm_close_pinned.title = "Close Pinned Scene"
	_confirm_close_pinned.dialog_text = "This scene is pinned. Close it anyway?"
	_confirm_close_pinned.confirmed.connect(_on_pin_close_confirmed)

	base.add_child(_confirm_close_pinned)


func _color_swatch(color: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)

	return ImageTexture.create_from_image(img)


func get_ctx_group_idx() -> int:
	return _ctx_group_idx
