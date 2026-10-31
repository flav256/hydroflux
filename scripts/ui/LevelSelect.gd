extends Control


func _ready() -> void:
	%Points.text = "Points  %d" % GameManager.total_points()
	var list: VBoxContainer = %List
	var chapter := ""
	for entry in GameManager.LEVELS:
		if entry["chapter"] != chapter:
			chapter = entry["chapter"]
			var heading := Label.new()
			heading.text = chapter
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heading.add_theme_font_size_override("font_size", 22)
			heading.add_theme_color_override("font_color", Color(0.75, 0.92, 1, 0.9))
			list.add_child(heading)
		list.add_child(_make_button(entry))
	if OS.is_debug_build():
		%DevNote.text = "Development build — grey rooms can be opened."
	else:
		%DevNote.text = ""


func _make_button(entry: Dictionary) -> Button:
	var level_id: String = entry["id"]
	var grey: bool = entry["scene"] == GameManager.PLACEHOLDER
	var button := Button.new()
	button.custom_minimum_size = Vector2(460, 52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var stars := _star_row(GameManager.stars_for(level_id))
	var suffix := "   ·   dev" if grey and OS.is_debug_build() else ""
	button.text = "  %s      %s%s" % [entry["title"], stars, suffix]
	button.disabled = not GameManager.can_open(level_id)
	if grey:
		button.modulate = Color(0.55, 0.62, 0.66, 0.85)
	button.pressed.connect(func() -> void:
		GameManager.load_level(level_id)
	)
	return button


func _star_row(count: int) -> String:
	var text := ""
	for i in 3:
		text += "★" if i < count else "☆"
	return text


func _on_quit_pressed() -> void:
	get_tree().quit()
