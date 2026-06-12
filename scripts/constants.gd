@tool
class_name ASTConstants

const SAVE_PATH := "user://advanced_tabs_groups.json"

const COLORS := {
	"White": Color(1.0, 1.0, 1.0),
	"Grey": Color(0.50, 0.50, 0.50),
	"Blue": Color(0.33, 0.55, 0.93),
	"Red": Color(0.88, 0.33, 0.33),
	"Yellow": Color(0.92, 0.75, 0.10),
	"Green": Color(0.33, 0.68, 0.35),
	"Pink": Color(0.88, 0.38, 0.62),
	"Purple": Color(0.62, 0.35, 0.85),
	"Cyan": Color(0.10, 0.72, 0.80),
	"Orange": Color(0.95, 0.58, 0.10),
}

const UNDO_LIMIT := 10
const RETRY_INTERVAL := 30

const TAB_MENU_NEW_GROUP := 0
const TAB_MENU_UNGROUP := 1
const TAB_MENU_CLOSE := 2
const TAB_MENU_PIN := 3
const TAB_MENU_SHOW_IN_FILESYSTEM := 4
const TAB_MENU_CLOSE_LEFT := 5
const TAB_MENU_CLOSE_RIGHT := 6
const TAB_MENU_CLOSE_OTHERS := 7
const TAB_MENU_MOVE_BASE := 100

const GROUP_MENU_RENAME := 0
const GROUP_MENU_UNGROUP_ALL := 1
const GROUP_MENU_CLOSE_ALL := 2
const GROUP_MENU_DELETE := 3
const GROUP_MENU_COLOR_BASE := 100
