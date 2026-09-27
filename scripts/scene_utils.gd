@tool
class_name ASTSceneUtils


static func get_open_scene_paths(editor: EditorInterface) -> PackedStringArray:
	var paths := PackedStringArray()

	for root in editor.get_open_scene_roots():
		if is_instance_valid(root):
			paths.append(root.scene_file_path)

	return paths
