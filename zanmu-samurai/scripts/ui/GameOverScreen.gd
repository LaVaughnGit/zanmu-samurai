extends CanvasLayer
class_name GameOverScreen

func _ready() -> void:
	layer = 10

	# Full-screen dark overlay
	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(overlay)

	# Central card
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -160.0
	panel.offset_top = -130.0
	panel.offset_right = 160.0
	panel.offset_bottom = 130.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.88, 0.14, 0.14))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "You have been defeated."
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var try_again := Button.new()
	try_again.text = "Rebirth"
	try_again.custom_minimum_size = Vector2(220, 44)
	try_again.pressed.connect(_on_try_again)
	vbox.add_child(try_again)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(220, 44)
	quit_btn.pressed.connect(get_tree().quit)
	vbox.add_child(quit_btn)

func _on_try_again() -> void:
	GameState.reset()
	get_tree().reload_current_scene()
