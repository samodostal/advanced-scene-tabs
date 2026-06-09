@tool
class_name ASTGroupStore

var groups: Array = []
var closed_history: Array = []


func load_from_disk() -> void:
	groups.clear()
	if not FileAccess.file_exists(ASTConstants.SAVE_PATH):
		return

	var f := FileAccess.open(ASTConstants.SAVE_PATH, FileAccess.READ)
	if not f:
		return

	var parsed = JSON.parse_string(f.get_as_text())
	f.close()

	if not (parsed is Dictionary) or not parsed.has("groups"):
		return

	for g in parsed["groups"]:
		if g is Dictionary and g.has("name") and g.has("color") and g.has("scenes"):
			(
				groups
				. append(
					{
						"name": str(g["name"]),
						"color": str(g["color"]),
						"scenes": Array(g["scenes"]),
					}
				)
			)


func save_to_disk() -> void:
	var data := []
	for g in groups:
		(
			data
			. append(
				{
					"name": g["name"],
					"color": g["color"],
					"scenes": Array(g["scenes"]),
				}
			)
		)
	var f := FileAccess.open(ASTConstants.SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"groups": data}, "\t"))
		f.close()


func group_index_for(scene_path: String) -> int:
	for i in groups.size():
		if scene_path in groups[i]["scenes"]:
			return i

	return -1


func remove_scene_from_all(scene_path: String) -> void:
	for g in groups:
		g["scenes"].erase(scene_path)


func add_group(name: String, color: String, scene_path: String) -> void:
	for g in groups:
		g["scenes"].erase(scene_path)

	groups.append({"name": name, "color": color, "scenes": [scene_path]})

	save_to_disk()


func move_scene_to_group(scene_path: String, gi: int, target_idx: int, grp_open: Array) -> void:
	remove_scene_from_all(scene_path)

	if gi < 0 or gi >= groups.size():
		save_to_disk()
		return

	var scenes: Array = groups[gi]["scenes"]

	if target_idx >= grp_open.size():
		scenes.append(scene_path)
	else:
		var ref_path: String = grp_open[target_idx]
		var actual := scenes.find(ref_path)

		if actual >= 0:
			scenes.insert(actual, scene_path)
		else:
			scenes.append(scene_path)

	save_to_disk()


func push_closed(scene_path: String) -> void:
	var gi := group_index_for(scene_path)
	var pos := -1

	if gi >= 0:
		pos = groups[gi]["scenes"].find(scene_path)

	closed_history.append({"scene": scene_path, "group": gi, "group_pos": pos})

	while closed_history.size() > ASTConstants.UNDO_LIMIT:
		closed_history.pop_front()


func pop_closed() -> Dictionary:
	if closed_history.is_empty():
		return {}

	return closed_history.pop_back()


func restore_scene_to_group(scene_path: String, gi: int, pos: int) -> void:
	if gi < 0 or gi >= groups.size():
		return

	var scenes: Array = groups[gi]["scenes"]
	scenes.erase(scene_path)

	if pos >= 0 and pos <= scenes.size():
		scenes.insert(pos, scene_path)
	else:
		scenes.append(scene_path)

	save_to_disk()


func pick_unused_color() -> String:
	var used := []

	for g in groups:
		used.append(g["color"])

	for cname in ASTConstants.COLORS:
		if cname != "Grey" and not (cname in used):
			return cname

	return "Blue"
