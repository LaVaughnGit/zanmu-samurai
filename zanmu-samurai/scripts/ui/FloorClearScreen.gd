extends CanvasLayer
class_name FloorClearScreen

func _ready() -> void:
	layer = 10

	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180.0
	panel.offset_top = -140.0
	panel.offset_right = 180.0
	panel.offset_bottom = 140.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "FLOOR %d CLEARED" % GameState.floor_number
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.25, 0.90, 0.60))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "You descend deeper into the dream."
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var descend_btn := Button.new()
	descend_btn.text = "Descend"
	descend_btn.custom_minimum_size = Vector2(220, 44)
	descend_btn.pressed.connect(_on_descend)
	vbox.add_child(descend_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(220, 44)
	quit_btn.pressed.connect(get_tree().quit)
	vbox.add_child(quit_btn)

func _on_descend() -> void:
	GameState.next_floor()
	get_tree().reload_current_scene()
