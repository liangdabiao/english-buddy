extends Control

# The header bar, footer hints, toasts and the hatch meter used to be drawn in
# App._draw(). A Control draws itself *behind* its own children, so the
# background TextureRect covered every one of them. They live in this node
# instead, which sits above the screen content through z_index.

var app: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _draw() -> void:
	if app != null and is_instance_valid(app) and app.has_method("draw_chrome"):
		app.draw_chrome(self)
