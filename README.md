# Advanced Scene Tabs Plugin (Godot 4.6+)
> [!NOTE]
> This plugin is still experimental and may have bugs. New Godot versions may and probably will break it. You can always disable it in `Project Settings → Plugins`.
> Any feedback or ideas are welcome.

<img width="1275" height="190" alt="image2" src="https://github.com/user-attachments/assets/ba22affc-9ef8-4ef4-a795-500f43730a6d" />
This plugin extends the Scene Tabs bar in the Godot editor. It gives you better control over many open scenes by adding groups, warped layout, and small quality-of-life improvements.

## Features
### Groups
- Scenes can be organized into groups
- Groups can be named or unnamed
- *Drag and drop* to rearrange
<img width="1273" height="190" alt="image" src="https://github.com/user-attachments/assets/947c701f-e52a-4444-8df8-bc334a13ed93" />

### Warping
- Automatic tabs warp instead of horizontal scroll (you always see all open scenes)
<img width="1017" height="133" alt="2026-06-09T17:03:31,361608662+02:00" src="https://github.com/user-attachments/assets/b52198db-f4fa-4090-9a01-e030ed7d9a33" />

### Pins
- Scenes can be pinned so they are harder to close (confirmation modal)
- They won't be closed by the "close ungrouped scenes" button

### Small improvements
- Remembers layout between sessions
- Close ungrouped scenes (trashcan icon)
- Revert accidental scene close (back arrow icon)
- *To close scene press the scroll wheel button. I never used the close scene 'X' icon so I removed it. Can be brought back.*
- You can also use right-click on specific scene / on group to view options.

## Installation
1. Download the plugin into your Godot project’s `addons/` folder
2. Enable in `Project Settings → Plugins`

## Future improvements and ideas
This plugin was made in my free time and acts as a proof of concept. It works for my basic workflow. If someone would be interested in these or other advanced features I will look into them.
- *Smart groups* - Create rules (path, scene name) to automatically place scenes into groups.
- *Collapsing groups*
- *Workspace presets* - Groups would open based on which workspace you select. For example when working on UI part of the game relevant groups would show.
- *Pin scenes* - Pin ungrouped scenes so they can not be closed ungrouped
